param(
  [string]$NameMap = "",
  [string]$RequestName = "",
  [string]$ResultName = "",
  [string]$ClientIP = "192.168.77.1",
  [bool]$ClearClientArp = $true,
  [bool]$StopClientPing = $true,
  [int]$TimeoutMs = 500,
  [int]$MaxRetries = 10,
  [bool]$UseTransferPort = $false,
  [int]$ProgressIntervalBlocks = 2048,
  [int]$PreStartDelayMs = 0,
  [bool]$EnableOptionAck = $true,
  [int]$MaxBlksize = 1428,
  [bool]$UseFastTransferLoop = $true
)

$ErrorActionPreference = "Continue"
Get-NetUDPEndpoint -LocalPort 69 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ArpEntryPresent([string]$ip) {
  if ([string]::IsNullOrWhiteSpace($ip)) { return $false }

  try {
    $entries = @(Get-NetNeighbor -IPAddress $ip -AddressFamily IPv4 -ErrorAction Stop)
    return ($entries.Count -gt 0)
  } catch {
    return $false
  }
}

function Invoke-ElevatedArpDelete([string]$ip) {
  try {
    $proc = Start-Process -FilePath "arp.exe" -ArgumentList @("-d", $ip) -Verb RunAs -PassThru -Wait
    return ($null -ne $proc -and $proc.ExitCode -eq 0)
  } catch {
    Write-Host "ARP elevation prompt was canceled or failed: $($_.Exception.Message)"
    return $false
  }
}

function Clear-ArpEntry([string]$ip, [int]$Attempts = 3, [int]$DelayMs = 150) {
  if ([string]::IsNullOrWhiteSpace($ip)) { return $true }

  if (-not (Test-ArpEntryPresent $ip)) {
    Write-Host "ARP cache entry already absent for $ip"
    return $true
  }

  $isAdmin = Test-IsAdministrator

  for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
    try {
      & arp.exe -d $ip *> $null
      if ($LASTEXITCODE -eq 0) {
        Write-Host "ARP delete command completed for $ip"
        return $true
      }

      if (-not $isAdmin) {
        Write-Host "ARP clear for $ip requires elevation; requesting UAC..."
        if (Invoke-ElevatedArpDelete $ip) {
          Write-Host "ARP delete command completed for $ip (elevated)"
          return $true
        }
      } else {
        Write-Host "ARP cache clear attempt $attempt for $ip returned exit code $LASTEXITCODE"
      }
    } catch {
      Write-Host "ARP cache clear attempt $attempt for $ip failed: $($_.Exception.Message)"
    }

    if ($attempt -lt $Attempts) {
      Start-Sleep -Milliseconds $DelayMs
    }
  }

  return $false
}

function Stop-PingProcessesForTarget([string]$ip) {
  if ([string]::IsNullOrWhiteSpace($ip)) { return 0 }

  $stopped = 0
  $pattern = '(?<![\d.])' + [regex]::Escape($ip) + '(?![\d.])'

  try {
    $targets = Get-CimInstance Win32_Process -Filter "Name = 'ping.exe'" -ErrorAction Stop | Where-Object {
      $cmd = [string]$_.CommandLine
      (-not [string]::IsNullOrWhiteSpace($cmd)) -and ($cmd -match $pattern)
    }

    foreach ($proc in $targets) {
      try {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
        $stopped++
      } catch {
        Write-Host "Failed to stop ping.exe PID $($proc.ProcessId): $($_.Exception.Message) (continuing)"
      }
    }
  } catch {
    Write-Host "Ping process scan failed: $($_.Exception.Message) (continuing)"
  }

  if ($stopped -gt 0) {
    Write-Host "Stopped $stopped ping.exe process(es) targeting $ip"
  }

  return $stopped
}

if ($StopClientPing) {
  [void](Stop-PingProcessesForTarget $ClientIP)
}

if ($ClearClientArp) {
  if (-not (Clear-ArpEntry $ClientIP)) {
    Write-Host "WARNING: failed to clear ARP cache entry for $ClientIP; continuing."
    Write-Host "If the transfer stalls, run 'arp -d $ClientIP' in a Windows shell and retry."
  }
}

if ($PreStartDelayMs -gt 0) {
  Start-Sleep -Milliseconds $PreStartDelayMs
}

$serverScript = Join-Path $PSScriptRoot 'tftp-server-cfe-77-once.ps1'
if (-not (Test-Path $serverScript)) {
  throw "Missing server script: $serverScript"
}

$serverArgs = @{
  ClientIP = $ClientIP
  ClearClientArp = $false
  TimeoutMs = $TimeoutMs
  MaxRetries = $MaxRetries
  UseTransferPort = $UseTransferPort
  ProgressIntervalBlocks = $ProgressIntervalBlocks
  EnableOptionAck = $EnableOptionAck
  MaxBlksize = $MaxBlksize
  UseFastTransferLoop = $UseFastTransferLoop
}

if (-not [string]::IsNullOrWhiteSpace($NameMap)) {
  $serverArgs.NameMap = $NameMap
}
if (-not [string]::IsNullOrWhiteSpace($RequestName)) {
  $serverArgs.RequestName = $RequestName
}
if (-not [string]::IsNullOrWhiteSpace($ResultName)) {
  $serverArgs.ResultName = $ResultName
}

& $serverScript @serverArgs