param(
  [Parameter(Mandatory = $true)]
  [string]$OwrtMac,

  [int]$CaptureSeconds = 900,
  [int]$HeartbeatSeconds = 15
)

$ErrorActionPreference = 'Stop'

$peerMac = 'BC-EC-A0-2D-6C-9B'
$owrtIp  = '192.168.77.1'
$hostIp  = '192.168.77.2'
$capDir  = 'C:\tftp'

if ($CaptureSeconds -lt 10) {
  throw "CaptureSeconds must be >= 10 (got $CaptureSeconds)."
}
if ($HeartbeatSeconds -lt 1) {
  throw "HeartbeatSeconds must be >= 1 (got $HeartbeatSeconds)."
}
if ($HeartbeatSeconds -gt $CaptureSeconds) {
  $HeartbeatSeconds = $CaptureSeconds
}

function Normalize-Mac([string]$mac) {
  $m = ($mac.Trim().ToUpper() -replace ':', '-')
  if ($m -notmatch '^[0-9A-F]{2}(-[0-9A-F]{2}){5}$') {
    throw "Invalid MAC format: $mac"
  }
  return $m
}

$owrtMacNorm = Normalize-Mac $OwrtMac

$suffix = 'watchdog10half-bridgehold-v13'
$etl = Join-Path $capDir "pkt-$suffix.etl"
$txt = Join-Path $capDir "pkt-$suffix.txt"
$neighProof = Join-Path $capDir "host-neigh-proof-$suffix.txt"
$routeProof = Join-Path $capDir "host-route-proof-$suffix.txt"
$linkProof = Join-Path $capDir "host-link-proof-$suffix.txt"
$pingOut = Join-Path $capDir "host-ping-window-$suffix.txt"
$metaOut = Join-Path $capDir "host-meta-$suffix.txt"

$nic = Get-NetAdapter | Where-Object { $_.MacAddress -eq $peerMac } | Select-Object -First 1
if (-not $nic) { throw "NIC with MAC $peerMac not found." }
$ifAlias = $nic.Name
$ifIndex = $nic.IfIndex

cmd /c "pktmon stop >nul 2>nul" | Out-Null
pktmon filter remove | Out-Null

Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $hostIp -PrefixLength 24 -AddressFamily IPv4 -ErrorAction SilentlyContinue | Out-Null
Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '192.168.77.0/24' -ErrorAction SilentlyContinue |
  Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
New-NetRoute -AddressFamily IPv4 -DestinationPrefix '192.168.77.0/24' -InterfaceIndex $ifIndex -NextHop '0.0.0.0' -RouteMetric 1 -PolicyStore ActiveStore | Out-Null

netsh interface ipv4 delete neighbors "$ifAlias" $owrtIp >$null 2>&1
netsh interface ipv4 add neighbors "$ifAlias" $owrtIp $owrtMacNorm | Out-Null

$speedProp = Get-NetAdapterAdvancedProperty -Name $ifAlias -AllProperties -ErrorAction SilentlyContinue |
  Where-Object { $_.RegistryKeyword -eq '*SpeedDuplex' -or $_.DisplayName -match 'Speed.*Duplex' } |
  Select-Object -First 1
if ($speedProp) {
  $candidate = $null
  if ($speedProp.ValidDisplayValues) {
    $candidate = $speedProp.ValidDisplayValues | Where-Object { $_ -match '10' -and $_ -match 'Half' } | Select-Object -First 1
  }
  if (-not $candidate) { $candidate = '10 Mbps Half Duplex' }
  try {
    Set-NetAdapterAdvancedProperty -Name $ifAlias -DisplayName $speedProp.DisplayName -DisplayValue $candidate -NoRestart:$false -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 3
  } catch {
    # Continue even if driver rejects forced mode.
  }
}

$startUtc = (Get-Date).ToUniversalTime()
@(
  "owrt_mac=$owrtMacNorm"
  "owrt_ip=$owrtIp"
  "host_ip=$hostIp"
  "if_alias=$ifAlias"
  "if_index=$ifIndex"
  "capture_seconds=$CaptureSeconds"
  "heartbeat_seconds=$HeartbeatSeconds"
  "capture_start_utc=$($startUtc.ToString('yyyy-MM-dd HH:mm:ss'))"
) | Set-Content -Path $metaOut

netsh interface ipv4 show neighbors "$ifAlias" | Set-Content -Path $neighProof
Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '192.168.77.0/24' |
  Sort-Object RouteMetric |
  Format-Table ifIndex,InterfaceAlias,DestinationPrefix,NextHop,RouteMetric -Auto |
  Out-String |
  Set-Content -Path $routeProof

@(
  '=== net adapter ==='
  (Get-NetAdapter -Name $ifAlias | Format-List Name,Status,LinkSpeed,MacAddress,InterfaceDescription | Out-String)
  '=== speed/duplex prop ==='
  (Get-NetAdapterAdvancedProperty -Name $ifAlias -AllProperties | Where-Object { $_.RegistryKeyword -eq '*SpeedDuplex' -or $_.DisplayName -match 'Speed.*Duplex' } | Format-List DisplayName,DisplayValue,ValidDisplayValues,RegistryKeyword,RegistryValue | Out-String)
  '=== owrt target ==='
  "owrt_ip=$owrtIp"
  "owrt_mac=$owrtMacNorm"
) | Set-Content -Path $linkProof

$pingProc = $null
$pktmonStarted = $false

try {
  # Keep capture focused on experiment traffic to reduce background noise.
  pktmon filter add HOST_ICMP -m $peerMac -t ICMP | Out-Null
  pktmon filter add HOST_ARP  -m $peerMac -d ARP  | Out-Null
  pktmon start --capture --comp nics --pkt-size 0 --file-name $etl | Out-Null
  $pktmonStarted = $true

  $pingProc = Start-Process -FilePath 'ping.exe' -ArgumentList "-t -w 200 $owrtIp" -NoNewWindow -RedirectStandardOutput $pingOut -PassThru
  Write-Output ("capture started: seconds={0} heartbeat={1}s target={2} owrt_mac={3}" -f $CaptureSeconds, $HeartbeatSeconds, $owrtIp, $owrtMacNorm)

  $deadline = (Get-Date).AddSeconds($CaptureSeconds)
  $hb = 0
  while ((Get-Date) -lt $deadline) {
    $remainingBefore = [int][Math]::Ceiling(($deadline - (Get-Date)).TotalSeconds)
    if ($remainingBefore -le 0) { break }
    $sleepFor = [Math]::Min($HeartbeatSeconds, $remainingBefore)
    Start-Sleep -Seconds $sleepFor

    $hb++
    $remainingNow = [int][Math]::Max(0, [Math]::Ceiling(($deadline - (Get-Date)).TotalSeconds))
    $elapsedNow = $CaptureSeconds - $remainingNow
    $pingState = 'running'
    if ($pingProc -and $pingProc.HasExited) {
      $pingState = "exited:$($pingProc.ExitCode)"
    }
    $etlBytes = 0
    if (Test-Path -LiteralPath $etl) {
      try { $etlBytes = (Get-Item -LiteralPath $etl).Length } catch {}
    }

    Write-Output ("[hb {0}] elapsed={1}s remaining={2}s ping={3} etl_bytes={4}" -f $hb, $elapsedNow, $remainingNow, $pingState, $etlBytes)
  }
}
finally {
  if ($pingProc -and -not $pingProc.HasExited) {
    Stop-Process -Id $pingProc.Id -Force
  }
  if ($pktmonStarted) {
    cmd /c "pktmon stop >nul 2>nul" | Out-Null
  }
}

pktmon etl2txt $etl -o $txt | Out-Null

$dirTx = (Select-String -Path $txt -Pattern 'Direction Tx' -SimpleMatch | Measure-Object).Count
$dirRx = (Select-String -Path $txt -Pattern 'Direction Rx' -SimpleMatch | Measure-Object).Count
$echoReq = (Select-String -Path $txt -Pattern 'ICMP echo request' -SimpleMatch | Measure-Object).Count
$echoRep = (Select-String -Path $txt -Pattern 'ICMP echo reply' -SimpleMatch | Measure-Object).Count
$owrtToHost = (Select-String -Path $txt -Pattern "$owrtMacNorm > $peerMac" -SimpleMatch | Measure-Object).Count
$hostToOwrt = (Select-String -Path $txt -Pattern "$peerMac > $owrtMacNorm" -SimpleMatch | Measure-Object).Count

Write-Output ("summary: dir_tx={0} dir_rx={1} icmp_req={2} icmp_rep={3} mac_host_to_owrt={4} mac_owrt_to_host={5}" -f $dirTx, $dirRx, $echoReq, $echoRep, $hostToOwrt, $owrtToHost)
Write-Output "Done. Artifacts:"
Write-Output $txt
Write-Output $neighProof
Write-Output $routeProof
Write-Output $linkProof
Write-Output $pingOut
Write-Output $metaOut
