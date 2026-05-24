# 2026-05-24 - next test plan: directed unicast RX gate check

## Why this next test

Based on:

- `logs/picocom-20260524-195459.log`
- `C:/tftp/pkt.txt`

Current run result is consistent with "TX submit accounting without usable wire
traffic + no RX path":

- OpenWrt side:
  - RX stayed `0 -> 0`
  - TX increased `1699/9/9 -> 30167/301/18` (bytes/packets/errors)
  - hwirq `64` increased `503 -> 1212`
  - hwirq `66` stayed `0 -> 0`
  - repeated `NETDEV WATCHDOG`
- Host pkt trace side:
  - `Direction Tx` only, `Direction Rx` not observed
  - repeated ARP request from peer:
    - `who-has 192.168.77.1 tell 192.168.77.2`
  - no ARP reply from `192.168.77.1`
  - no OpenWrt-boot MAC seen

So the next probe should avoid local TX flood and isolate inbound directed
traffic handling.

## Next test procedure

### 1) On OpenWrt serial

Use:

- `/home/mgta29/send-next-rx.txt`

This prepares standalone `eth0` on `192.168.77.1/24`, captures pre state,
waits 20 seconds for host traffic, then captures post state.

### 2) During the 20s window, on host (admin PowerShell)

Set static L2 neighbor so traffic is forced as directed unicast to OpenWrt MAC
(replace the MAC with the one shown by OpenWrt `ip -s link` pre output):

```powershell
# Example; replace adapter name and router MAC
$ifName = "Ethernet"
$routerIp = "192.168.77.1"
$routerMac = "16-d8-10-6e-9d-33"

netsh interface ipv4 delete neighbors "$ifName" "$routerIp" | Out-Null
netsh interface ipv4 add neighbors "$ifName" "$routerIp" "$routerMac"

# Optional capture refresh
pktmon stop | Out-Null
pktmon filter remove
pktmon start --etw

ping -n 200 -l 98 $routerIp

pktmon stop
pktmon format PktMon.etl -o C:\tftp\pkt-next.txt
```

## Decision criteria

- If OpenWrt RX packets stay `0` and hwirq `66` stays `0`:
  - RX DMA/completion path is still inactive even for directed unicast.
- If RX or hwirq `66` moves:
  - inbound path is partially alive; failure focus shifts to TX completion or
    return path.
- If host capture still shows only peer ARP retries and no OpenWrt-source
  frames:
  - confirms no usable egress on wire from current GENET state.
