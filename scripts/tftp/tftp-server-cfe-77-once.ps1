param(
  [string]$Root = "C:\tftp",
  [string]$BindIP = "192.168.77.2",
  [string]$ClientIP = "192.168.77.1",
  [bool]$ClearClientArp = $true,
  [int]$Port = 69,
  [int]$TimeoutMs = 500,
  [int]$MaxRetries = 10,
  [string]$NameMap = "",
  [string]$RequestName = "",
  [string]$ResultName = "",
  [bool]$UseTransferPort = $true,
  [int]$ProgressIntervalBlocks = 2048,
  [bool]$EnableOptionAck = $true,
  [int]$MaxBlksize = 1428,
  [bool]$UseFastTransferLoop = $true
)

$ErrorActionPreference = "Stop"
try { Clear-Host } catch {}

function U16($hi, $lo) {
  return (($hi -band 0xff) -shl 8) -bor ($lo -band 0xff)
}

function New-BoundUdpClient([Net.IPAddress]$address, [int]$port, [int]$receiveTimeoutMs, [bool]$reuseAddress) {
  $udp = [Net.Sockets.UdpClient]::new($address.AddressFamily)
  if ($reuseAddress) {
    $udp.Client.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket, [Net.Sockets.SocketOptionName]::ReuseAddress, $true)
  }
  $udp.Client.SendBufferSize = 1048576
  $udp.Client.ReceiveBufferSize = 1048576
  $udp.Client.ReceiveTimeout = $receiveTimeoutMs
  $udp.Client.Bind([Net.IPEndPoint]::new($address, $port))
  return $udp
}

function Send-UdpPacket($sock, $remote, [byte[]]$packet, [int]$packetLen) {
  if ($sock.Client.Connected) {
    [void]$sock.Send($packet, $packetLen)
  } else {
    [void]$sock.Send($packet, $packetLen, $remote)
  }
}

function Build-TftpDataPacket([byte[]]$packet, [int]$block, [byte[]]$source, [int]$sourceOffset, [int]$payloadLen) {
  $packet[0] = 0
  $packet[1] = 3
  $packet[2] = (($block -shr 8) -band 0xff)
  $packet[3] = ($block -band 0xff)
  if ($payloadLen -gt 0) {
    [Buffer]::BlockCopy($source, $sourceOffset, $packet, 4, $payloadLen)
  }
}

function Send-TftpData($sock, $remote, [byte[]]$packet, [int]$payloadLen) {
  Send-UdpPacket $sock $remote $packet ($payloadLen + 4)
}

function Send-TftpError($sock, $remote, [int]$code, [string]$msg) {
  $bytes = [Text.Encoding]::ASCII.GetBytes($msg)
  $pkt = New-Object byte[] (4 + $bytes.Length + 1)
  $pkt[0] = 0
  $pkt[1] = 5
  $pkt[2] = (($code -shr 8) -band 0xff)
  $pkt[3] = ($code -band 0xff)
  [Array]::Copy($bytes, 0, $pkt, 4, $bytes.Length)
  $pkt[$pkt.Length - 1] = 0
  Send-UdpPacket $sock $remote $pkt $pkt.Length
}

function Send-TftpOack($sock, $remote, [System.Collections.IDictionary]$options) {
  $pktLen = 2
  foreach ($entry in $options.GetEnumerator()) {
    $nameBytes = [Text.Encoding]::ASCII.GetBytes([string]$entry.Key)
    $valueBytes = [Text.Encoding]::ASCII.GetBytes([string]$entry.Value)
    $pktLen += $nameBytes.Length + $valueBytes.Length + 2
  }

  $pkt = New-Object byte[] $pktLen
  $pkt[0] = 0
  $pkt[1] = 6

  $offset = 2
  foreach ($entry in $options.GetEnumerator()) {
    $nameBytes = [Text.Encoding]::ASCII.GetBytes([string]$entry.Key)
    $valueBytes = [Text.Encoding]::ASCII.GetBytes([string]$entry.Value)

    [Buffer]::BlockCopy($nameBytes, 0, $pkt, $offset, $nameBytes.Length)
    $offset += $nameBytes.Length
    $pkt[$offset] = 0
    $offset++

    [Buffer]::BlockCopy($valueBytes, 0, $pkt, $offset, $valueBytes.Length)
    $offset += $valueBytes.Length
    $pkt[$offset] = 0
    $offset++
  }

  Send-UdpPacket $sock $remote $pkt $pkt.Length
}

function Ensure-TftpFastTransferType {
  if ('TftpFastTransferLoop' -as [type]) { return }

  Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net.Sockets;

public sealed class TftpFastTransferResult
{
    public int FinalBlock { get; set; }
    public double ElapsedMilliseconds { get; set; }
    public int LowByteAckCount { get; set; }
    public int[] ProgressBlocks { get; set; }
}

public static class TftpFastTransferLoop
{
    public static TftpFastTransferResult SendFile(Socket socket, byte[] data, int blockSize, int maxRetries, int progressIntervalBlocks)
    {
        if (socket == null) throw new ArgumentNullException("socket");
        if (data == null) throw new ArgumentNullException("data");
        if (blockSize <= 0) throw new ArgumentOutOfRangeException("blockSize");
        if (maxRetries < 0) throw new ArgumentOutOfRangeException("maxRetries");

        byte[] dataPacket = new byte[4 + blockSize];
        byte[] ack = new byte[516];
        List<int> progressBlocks = progressIntervalBlocks > 0 ? new List<int>() : null;

        int offset = 0;
        int block = 1;
        int retries = 0;
        int lowByteAckCount = 0;

        Stopwatch stopwatch = Stopwatch.StartNew();

        while (true)
        {
            int remaining = data.Length - offset;
            if (remaining < 0) remaining = 0;

            int chunkLen = remaining < blockSize ? remaining : blockSize;

            dataPacket[0] = 0;
            dataPacket[1] = 3;
            dataPacket[2] = (byte)((block >> 8) & 0xff);
            dataPacket[3] = (byte)(block & 0xff);
            if (chunkLen > 0)
            {
                Buffer.BlockCopy(data, offset, dataPacket, 4, chunkLen);
            }

            socket.Send(dataPacket, 0, chunkLen + 4, SocketFlags.None);
            if (progressBlocks != null && (block % progressIntervalBlocks) == 0)
            {
                progressBlocks.Add(block);
            }

            while (true)
            {
                int ackLen;
                try
                {
                    ackLen = socket.Receive(ack, 0, ack.Length, SocketFlags.None);
                }
                catch (SocketException ex)
                {
                    if (ex.SocketErrorCode != SocketError.TimedOut)
                    {
                        throw;
                    }

                    retries++;
                    if (retries > maxRetries)
                    {
                        throw new TimeoutException("Retry limit exceeded on block " + block);
                    }

                    socket.Send(dataPacket, 0, chunkLen + 4, SocketFlags.None);
                    continue;
                }

                if (ackLen < 4)
                {
                    continue;
                }

                int ackOp = ((ack[0] & 0xff) << 8) | (ack[1] & 0xff);
                if (ackOp == 5)
                {
                    throw new InvalidOperationException("Client ERROR packet");
                }

                if (ackOp == 1)
                {
                    socket.Send(dataPacket, 0, chunkLen + 4, SocketFlags.None);
                    continue;
                }

                if (ackOp != 4)
                {
                    continue;
                }

                int ackBlock = ((ack[2] & 0xff) << 8) | (ack[3] & 0xff);
                int lowByte = block & 0xff;

                if (ackBlock == block || (block >= 256 && ackBlock == lowByte))
                {
                    if (ackBlock != block && block >= 256)
                    {
                        lowByteAckCount++;
                    }

                    offset += chunkLen;
                    retries = 0;

                    if (chunkLen < blockSize)
                    {
                        stopwatch.Stop();
                        return new TftpFastTransferResult
                        {
                            FinalBlock = block,
                            ElapsedMilliseconds = stopwatch.Elapsed.TotalMilliseconds,
                            LowByteAckCount = lowByteAckCount,
                            ProgressBlocks = progressBlocks != null ? progressBlocks.ToArray() : new int[0]
                        };
                    }

                    block++;
                    break;
                }
            }
        }
    }
}
"@
}

function Parse-RRQ([byte[]]$buf) {
  $parts = [System.Collections.Generic.List[string]]::new()
  $fieldStart = 2
  for ($i = 2; $i -lt $buf.Length; $i++) {
    if ($buf[$i] -ne 0) { continue }
    $fieldLen = $i - $fieldStart
    if ($fieldLen -lt 0) { return $null }
    $parts.Add([Text.Encoding]::ASCII.GetString($buf, $fieldStart, $fieldLen))
    $fieldStart = $i + 1
    if ($fieldStart -ge $buf.Length) { break }
  }

  if ($parts.Count -lt 2) { return $null }

  $fn = $parts[0]
  $mode = $parts[1]
  if ([string]::IsNullOrWhiteSpace($fn) -or [string]::IsNullOrWhiteSpace($mode)) {
    return $null
  }

  $options = [ordered]@{}
  if ($parts.Count -gt 2) {
    if ((($parts.Count - 2) % 2) -ne 0) { return $null }
    for ($i = 2; $i -lt $parts.Count; $i += 2) {
      $optionName = $parts[$i].Trim().ToLowerInvariant()
      $optionValue = $parts[$i + 1].Trim()
      if ([string]::IsNullOrWhiteSpace($optionName)) { return $null }
      $options[$optionName] = $optionValue
    }
  }

  return [pscustomobject]@{
    Filename = [IO.Path]::GetFileName($fn)
    Mode = $mode
    Options = $options
  }
}

function Format-TftpOptions([System.Collections.IDictionary]$options) {
  if ($null -eq $options -or $options.Count -eq 0) { return "" }
  return (($options.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", ")
}

function Get-PositiveIntOption([System.Collections.IDictionary]$options, [string]$name) {
  if ($null -eq $options -or -not $options.Contains($name)) { return $null }
  $parsed = 0
  if ([int]::TryParse([string]$options[$name], [ref]$parsed) -and ($parsed -gt 0)) {
    return $parsed
  }
  return $null
}

function Get-TftpNegotiation([System.Collections.IDictionary]$options, [int]$fileSize, [int]$timeoutMs, [bool]$enableOptionAck, [int]$maxBlksize) {
  $accepted = [ordered]@{}
  $blockSize = 512

  if (-not $enableOptionAck -or $null -eq $options -or $options.Count -eq 0) {
    return [pscustomobject]@{
      BlockSize = $blockSize
      AcceptedOptions = $accepted
    }
  }

  $requestedBlockSize = Get-PositiveIntOption $options 'blksize'
  if ($null -ne $requestedBlockSize) {
    $blockSize = [Math]::Min([Math]::Max(8, $requestedBlockSize), [Math]::Max(512, $maxBlksize))
    $accepted['blksize'] = [string]$blockSize
  }

  if ($options.Contains('tsize')) {
    $accepted['tsize'] = [string]$fileSize
  }

  $requestedTimeout = Get-PositiveIntOption $options 'timeout'
  if ($null -ne $requestedTimeout) {
    $timeoutSeconds = [Math]::Max(1, [int][Math]::Ceiling($timeoutMs / 1000.0))
    $accepted['timeout'] = [string]$timeoutSeconds
  }

  return [pscustomobject]@{
    BlockSize = $blockSize
    AcceptedOptions = $accepted
  }
}

function Parse-NameMap([string]$mapText) {
  $txt = if ($null -eq $mapText) { "" } else { $mapText.Trim() }
  if ([string]::IsNullOrWhiteSpace($txt)) { return $null }

  if ($txt.Contains("->")) {
    $parts = $txt -split "->", 2
  } elseif ($txt.Contains("=")) {
    $parts = $txt -split "=", 2
  } elseif ($txt -match "\s-\s") {
    $parts = $txt -split "\s-\s", 2
  } else {
    throw "NameMap must be INPUT=RESULT, INPUT->RESULT, or INPUT - RESULT."
  }

  $req = $parts[0].Trim()
  $res = $parts[1].Trim()

  if ([string]::IsNullOrWhiteSpace($req) -or [string]::IsNullOrWhiteSpace($res)) {
    throw "NameMap must include non-empty input and result names."
  }

  if (($req -ne [IO.Path]::GetFileName($req)) -or ($res -ne [IO.Path]::GetFileName($res))) {
    throw "NameMap values must be plain filenames, not paths."
  }

  return [pscustomobject]@{
    RequestName = $req
    ResultName = $res
  }
}

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

$bindAddr = [Net.IPAddress]::Parse($BindIP)

if (!(Test-Path $Root)) {
  New-Item -ItemType Directory -Force -Path $Root | Out-Null
}

$effectiveRequestName = $null
$effectiveResultName = $null

if (-not [string]::IsNullOrWhiteSpace($NameMap)) {
  $parsedMap = Parse-NameMap $NameMap
  $effectiveRequestName = $parsedMap.RequestName
  $effectiveResultName = $parsedMap.ResultName
}
if (-not [string]::IsNullOrWhiteSpace($RequestName)) {
  $effectiveRequestName = $RequestName.Trim()
}
if (-not [string]::IsNullOrWhiteSpace($ResultName)) {
  $effectiveResultName = $ResultName.Trim()
}

$haveRequestName = -not [string]::IsNullOrWhiteSpace($effectiveRequestName)
$haveResultName = -not [string]::IsNullOrWhiteSpace($effectiveResultName)

if ($haveRequestName -xor $haveResultName) {
  throw "Provide both RequestName and ResultName, or neither."
}

if ($haveRequestName) {
  if (($effectiveRequestName -ne [IO.Path]::GetFileName($effectiveRequestName)) -or
      ($effectiveResultName -ne [IO.Path]::GetFileName($effectiveResultName))) {
    throw "RequestName/ResultName must be plain filenames, not paths."
  }
}

$useNameMap = $haveRequestName -and $haveResultName

$ipOk = Get-NetIPAddress -IPAddress $BindIP -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($null -eq $ipOk) {
  Write-Host "ERROR: $BindIP is not assigned to any Windows interface."
  Write-Host ""
  Get-NetIPAddress -AddressFamily IPv4 | Format-Table InterfaceAlias,IPAddress,PrefixLength
  exit 1
}

if ($ClearClientArp) {
  Clear-ArpEntry $ClientIP
}

if ($UseFastTransferLoop) {
  Ensure-TftpFastTransferType
}

$sock = New-BoundUdpClient $bindAddr $Port $TimeoutMs $true

Write-Host "CFE TFTP one-shot listening on ${BindIP}:$Port root=$Root client=$ClientIP timeout=${TimeoutMs}ms retries=$MaxRetries"
if ($useNameMap) {
  Write-Host "Name map active: $effectiveRequestName -> $effectiveResultName"
}
if ($UseTransferPort) {
  Write-Host "Dedicated transfer socket enabled."
}
Write-Host "Waiting for RRQ..."

while ($true) {
  $remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)

  try {
    $req = $sock.Receive([ref]$remote)
  } catch {
    continue
  }

  if ($remote.Address.ToString() -ne $ClientIP) {
    Write-Host "Ignoring packet from $($remote.Address):$($remote.Port)"
    continue
  }

  if ($req.Length -lt 4) { continue }

  $op = U16 $req[0] $req[1]
  if ($op -ne 1) {
    Write-Host "Ignoring non-RRQ opcode=$op from $($remote.Address):$($remote.Port)"
    continue
  }

  $rrq = Parse-RRQ $req
  if ($null -eq $rrq) {
    Write-Host "Bad RRQ from $($remote.Address):$($remote.Port)"
    Send-TftpError $sock $remote 0 "Bad RRQ"
    continue
  }

  $requestedName = $rrq.Filename
  $servedName = $requestedName

  if ($useNameMap) {
    if ($requestedName -ine $effectiveRequestName) {
      Write-Host "RRQ $requestedName does not match mapped request $effectiveRequestName"
      Send-TftpError $sock $remote 1 "File not found"
      continue
    }
    $servedName = $effectiveResultName
  }

  $path = Join-Path $Root $servedName
  if ($useNameMap) {
    Write-Host "RRQ $requestedName -> serving $servedName mode=$($rrq.Mode) from $($remote.Address):$($remote.Port)"
  } else {
    Write-Host "RRQ $requestedName mode=$($rrq.Mode) from $($remote.Address):$($remote.Port)"
  }
  if ($rrq.Options.Count -gt 0) {
    Write-Host "RRQ options: $(Format-TftpOptions $rrq.Options)"
  }

  if (!(Test-Path $path)) {
    Write-Host "Missing file: $path"
    Send-TftpError $sock $remote 1 "File not found"
    continue
  }

  $data = [IO.File]::ReadAllBytes($path)
  $xferSock = $null
  $xferOwnsSocket = $false

  try {
    if ($UseTransferPort) {
      $xferSock = New-BoundUdpClient $bindAddr 0 $TimeoutMs $false
      $xferOwnsSocket = $true
    } else {
      $xferSock = $sock
    }

    $xferSock.Connect($remote)
    $xferLocal = [Net.IPEndPoint]$xferSock.Client.LocalEndPoint
    Write-Host "Transfer session ${BindIP}:$($xferLocal.Port) -> $($remote.Address):$($remote.Port)"

    $negotiation = Get-TftpNegotiation $rrq.Options $data.Length $TimeoutMs $EnableOptionAck $MaxBlksize
    $blockSize = $negotiation.BlockSize
    $dataPacket = New-Object byte[] (4 + $blockSize)

    if ($negotiation.AcceptedOptions.Count -gt 0) {
      Write-Host "Negotiated TFTP options: $(Format-TftpOptions $negotiation.AcceptedOptions)"

      $oackRetries = 0
      Send-TftpOack $xferSock $remote $negotiation.AcceptedOptions

      while ($true) {
        $ackRemote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)

        try {
          $ack = $xferSock.Receive([ref]$ackRemote)
        } catch {
          $oackRetries++
          if ($oackRetries -gt $MaxRetries) {
            Write-Host "Retry limit exceeded waiting for OACK ACK"
            throw "OACK ACK timeout"
          }
          Send-TftpOack $xferSock $remote $negotiation.AcceptedOptions
          continue
        }

        if (($ackRemote.Address.ToString() -ne $ClientIP) -or ($ackRemote.Port -ne $remote.Port)) {
          continue
        }

        if ($ack.Length -lt 4) { continue }

        $ackOp = U16 $ack[0] $ack[1]
        if ($ackOp -eq 4) {
          $ackBlock = U16 $ack[2] $ack[3]
          if ($ackBlock -eq 0) { break }
          continue
        }

        if ($ackOp -eq 1) {
          Send-TftpOack $xferSock $remote $negotiation.AcceptedOptions
          continue
        }

        if ($ackOp -eq 5) {
          throw "Client rejected OACK"
        }
      }
    }

    if ($UseFastTransferLoop) {
      $result = [TftpFastTransferLoop]::SendFile($xferSock.Client, $data, $blockSize, $MaxRetries, $ProgressIntervalBlocks)
      foreach ($progressBlock in $result.ProgressBlocks) {
        Write-Host "sent block $progressBlock"
      }
      if ($result.LowByteAckCount -gt 0) {
        Write-Host "Accepted low-byte ACK count: $($result.LowByteAckCount)"
      }
      $elapsedSeconds = [Math]::Max(0.001, ($result.ElapsedMilliseconds / 1000.0))
      $rateKiB = [Math]::Round(($data.Length / 1KB) / $elapsedSeconds, 1)
      Write-Host "TFTP complete: sent $($data.Length) bytes in $([Math]::Round($elapsedSeconds, 3))s (~${rateKiB} KiB/s), block_size=$blockSize final block $($result.FinalBlock)"
    } else {
      $offset = 0
      $block = 1
      $done = $false
      $retries = 0
      $transferStart = Get-Date

      while (-not $done) {
        $remaining = $data.Length - $offset
        $chunkLen = [Math]::Min($blockSize, [Math]::Max(0, $remaining))
        Build-TftpDataPacket $dataPacket $block $data $offset $chunkLen

        Send-TftpData $xferSock $remote $dataPacket $chunkLen
        if (($ProgressIntervalBlocks -gt 0) -and (($block % $ProgressIntervalBlocks) -eq 0)) {
          Write-Host "sent block $block"
        }

        while ($true) {
          $ackRemote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)

          try {
            $ack = $xferSock.Receive([ref]$ackRemote)
          } catch {
            $retries++
            if ($retries -gt $MaxRetries) {
              Write-Host "Retry limit exceeded on block $block"
              $done = $true
              break
            }
            Send-TftpData $xferSock $remote $dataPacket $chunkLen
            continue
          }

          if (($ackRemote.Address.ToString() -ne $ClientIP) -or ($ackRemote.Port -ne $remote.Port)) {
            Write-Host "Ignoring ACK from $($ackRemote.Address):$($ackRemote.Port)"
            continue
          }

          if ($ack.Length -lt 4) { continue }

          $ackOp = U16 $ack[0] $ack[1]

          if ($ackOp -eq 5) {
            Write-Host "Client ERROR packet; aborting"
            $done = $true
            break
          }

          if ($ackOp -eq 1) {
            Write-Host "Duplicate RRQ while waiting for ACK block $block; resending DATA block $block"
            Send-TftpData $xferSock $remote $dataPacket $chunkLen
            continue
          }

          if ($ackOp -ne 4) {
            Write-Host "Ignoring opcode=$ackOp from $($ackRemote.Address):$($ackRemote.Port)"
            continue
          }

          $ackBlock = U16 $ack[2] $ack[3]
          $lowByte = $block -band 0xff

          if (($ackBlock -eq $block) -or (($block -ge 256) -and ($ackBlock -eq $lowByte))) {
            if (($ackBlock -ne $block) -and ($block -ge 256)) {
              Write-Host "Accepted low-byte ACK blk=$ackBlock for block $block"
            }

            $offset += $chunkLen
            $retries = 0

            if ($chunkLen -lt $blockSize) {
              $elapsedSeconds = [Math]::Max(0.001, ((Get-Date) - $transferStart).TotalSeconds)
              $rateKiB = [Math]::Round(($data.Length / 1KB) / $elapsedSeconds, 1)
              Write-Host "TFTP complete: sent $($data.Length) bytes in $([Math]::Round($elapsedSeconds, 3))s (~${rateKiB} KiB/s), block_size=$blockSize final block $block"
              $done = $true
            } else {
              $block++
            }

            break
          } else {
            Write-Host "Ignore ACK blk=$ackBlock while waiting for block $block low=$lowByte"
          }
        }
      }
    }
  } finally {
    if ($xferOwnsSocket -and $null -ne $xferSock) {
      $xferSock.Close()
    }
  }

  $sock.Close()
  Write-Host "Server closed."
  exit 0
}
