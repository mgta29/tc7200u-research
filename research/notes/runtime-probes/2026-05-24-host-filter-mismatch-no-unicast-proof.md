# 2026-05-24 - host filter mismatch and no unicast proof in capture loop

## Inputs

- Serial log:
  - `logs/picocom-20260524-204311.log`
- Host capture:
  - `C:/tftp/pkt.txt`
- Host command transcript:
  - repeated `pktmon start/stop/etl2txt` with filters

## What this run shows

OpenWrt side (from serial):

- `eth0` MAC: `16:d8:10:6e:9d:33`
- RX stayed `0 -> 0`
- TX stayed `30167/301/18`
- hwirq `64` increased `13369 -> 13916`
- hwirq `66` stayed `0`
- `ip neigh` and `/proc/net/arp` stayed empty

Host capture side:

- only peer ARP request frames captured
- no ARP replies
- no ICMP payload frames
- no OpenWrt-source MAC frames

Critical mismatch:

- host configured `OWRT` filter MAC as `4E-6A-F2-3B-A2-FA`
- serial confirms OpenWrt MAC is `16:D8:10:6E:9D:33`
- `pkt.txt` contains `4E-6A-F2-3B-A2-FA` zero times and
  `16-D8-10-6E-9D-33` zero times

## Interpretation

This capture loop does not prove host->router unicast traffic reached wire.
It demonstrates repeated peer ARP retries only.

## Corrected next test (must include active ping during capture)

### A) OpenWrt serial

Run:

- `/home/mgta29/send-next-rx-verify-host-v2.txt`

### B) Windows admin PowerShell (single contiguous run)

```powershell
$routerIp  = "192.168.77.1"
$routerMac = "16-d8-10-6e-9d-33"   # from OpenWrt pre block
$peerMac   = "bc-ec-a0-2d-6c-9b"

# pick active interface for router subnet
$route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "192.168.77.0/24" |
  Sort-Object RouteMetric,InterfaceMetric | Select-Object -First 1
$ifIndex = $route.ifIndex
$ifName  = (Get-NetIPInterface -AddressFamily IPv4 -InterfaceIndex $ifIndex).InterfaceAlias

pktmon stop | Out-Null
pktmon filter remove
pktmon filter add OWRT -m $routerMac
pktmon filter add PEER -m $peerMac
pktmon filter add ICMP -t ICMP

# pin neighbor on the selected interface and verify
netsh interface ipv4 delete neighbors "$ifName" "$routerIp" | Out-Null
netsh interface ipv4 add neighbors "$ifName" "$routerIp" "$routerMac"
Get-NetNeighbor -AddressFamily IPv4 -IPAddress $routerIp |
  Format-Table ifIndex,InterfaceAlias,IPAddress,LinkLayerAddress,State |
  Out-File C:\tftp\host-neigh-proof.txt

pktmon start --capture --comp nics --pkt-size 0 --file-name C:\tftp\pkt.etl
ping -n 300 $routerIp
pktmon stop
pktmon etl2txt C:\tftp\pkt.etl -o C:\tftp\pkt-next.txt
```

## Pass/fail gate for this branch

- Pass (traffic-generation valid):
  - `pkt-next.txt` includes frames addressed to `16-D8-10-6E-9D-33` and ICMP payload lines.
- Fail (setup still invalid):
  - capture shows only broadcast ARP `who-has 192.168.77.1 tell 192.168.77.2`.
