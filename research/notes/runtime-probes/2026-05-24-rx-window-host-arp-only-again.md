# 2026-05-24 - RX verify-host rerun still shows host ARP-only traffic

## Inputs

- Serial log:
  - `logs/picocom-20260524-203544.log`
- Host packet trace:
  - `C:/tftp/pkt.txt`

## OpenWrt-side observed

Pre:

- RX: `0 bytes, 0 packets`
- TX: `30167 bytes, 301 packets, 18 errors`
- hwirq `64`: `10184`
- hwirq `66`: `0`
- `ERR`: `38665`

Post:

- RX: unchanged (`0 bytes, 0 packets`)
- TX: unchanged (`30167 bytes, 301 packets, 18 errors`)
- hwirq `64`: `10664` (increased)
- hwirq `66`: `0` (unchanged)
- `ERR`: `39999` (increased)

Other:

- `ip neigh show dev eth0` remained empty.
- dmesg filter block had no new useful RX/ICMP/ARP lines in this window.

## Host pkt trace observed

Decoded `pkt.txt`:

- `Direction Tx`: `68`
- `Direction Rx`: `0`
- ARP requests: `68`
- ARP replies: `0`
- all ARP requests are:
  - `BC-EC-A0-2D-6C-9B > ff:ff:ff:ff:ff:ff`
  - `who-has 192.168.77.1 tell 192.168.77.2`
- no frames from OpenWrt MAC `16:d8:10:6e:9d:33`
- no ICMP echo request/reply payload lines

Capture time window:

- first packet timestamp: `2026-05-24 20:36:08.559423800`
- last packet timestamp: `2026-05-24 20:40:57.743912400`

## Interpretation

The setup is still not sending verified host->router unicast. Traffic remains
host ARP broadcast retries only, so this run cannot validate OpenWrt RX
descriptor handling for directed unicast. OpenWrt counters stay consistent with
no RX path activity (`RX=0`, `hwirq66=0`).

## Next test (must prove host unicast first)

### OpenWrt serial

Use:

- `/home/mgta29/send-next-rx-verify-host-v2.txt`

### Host PowerShell (admin), with evidence capture

```powershell
$routerIp = "192.168.77.1"
$routerMac = "16-d8-10-6e-9d-33"  # from OpenWrt pre block

# 1) Resolve active interface to router subnet
$route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "192.168.77.0/24" |
  Sort-Object RouteMetric,InterfaceMetric | Select-Object -First 1
$ifIndex = $route.ifIndex
$ifName = (Get-NetIPInterface -InterfaceIndex $ifIndex -AddressFamily IPv4).InterfaceAlias

# 2) Re-pin neighbor on that exact interface
netsh interface ipv4 delete neighbors "$ifName" "$routerIp" | Out-Null
netsh interface ipv4 add neighbors "$ifName" "$routerIp" "$routerMac"

# 3) Save neighbor/route proof
Get-NetNeighbor -AddressFamily IPv4 -IPAddress $routerIp |
  Format-Table ifIndex,InterfaceAlias,IPAddress,LinkLayerAddress,State |
  Out-File C:\tftp\host-neigh-proof.txt
Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "192.168.77.1/32","192.168.77.0/24" |
  Format-Table DestinationPrefix,ifIndex,InterfaceAlias,NextHop,RouteMetric |
  Out-File C:\tftp\host-route-proof.txt

# 4) Capture + send traffic
pktmon stop | Out-Null
pktmon filter remove
pktmon start --etw
ping -n 300 $routerIp
pktmon stop
pktmon format PktMon.etl -o C:\tftp\pkt-next.txt
```

Pass condition:

- `pkt-next.txt` must show unicast ICMP or other unicast frames directed to
  `16-d8-10-6e-9d-33` (not only broadcast ARP).
