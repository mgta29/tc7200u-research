param(
  [string]$NameMap = "",
  [string]$RequestName = "",
  [string]$ResultName = "",
  [string]$ClientIP = "192.168.77.1",
  [bool]$ClearClientArp = $true,
  [bool]$StopClientPing = $true,
  [int]$TimeoutMs = 500,
  [int]$MaxRetries = 10,
  [bool]$UseTransferPort = $true,
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

function Invoke-ElevatedArpDelete([string]$ip) {
  try {
    $proc = Start-Process -FilePath "arp.exe" -ArgumentList @("-d", $ip) -Verb RunAs -PassThru -Wait
    return ($null -ne $proc -and $proc.ExitCode -eq 0)
  } catch {
    Write-Host "ARP elevation prompt was canceled or failed: $($_.Exception.Message) (continuing)"
    return $false
  }
}

function Clear-ArpEntry([string]$ip) {
  if ([string]::IsNullOrWhiteSpace($ip)) { return }
  $isAdmin = Test-IsAdministrator
  try {
    & arp.exe -d $ip *> $null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "ARP cache entry cleared for $ip"
      return
    }
    if (-not $isAdmin) {
      Write-Host "ARP clear for $ip requires elevation; requesting UAC..."
      if (Invoke-ElevatedArpDelete $ip) {
        Write-Host "ARP cache entry cleared for $ip (elevated)"
        return
      }
    } else {
      Write-Host "ARP cache clear for $ip returned exit code $LASTEXITCODE (continuing)"
    }
  } catch {
    Write-Host "ARP cache clear for $ip failed: $($_.Exception.Message) (continuing)"
  }
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
  Clear-ArpEntry $ClientIP
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
