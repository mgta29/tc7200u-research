# 2026-05-25 bridgehold v9 run (`picocom-20260525-201714.log`)

## Artifacts
- Serial: `evidence/serial/picocom-20260525-201714.log`
- Host:
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v9.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v9.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v9.txt`
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v9.txt`
  - `C:\tftp\host-ping-window-watchdog10half-bridgehold-v9.txt`
  - `C:\tftp\pkt-watchdog10half-bridgehold-v9.txt`

## Host-side validity checks
- MAC alignment is correct:
  - OpenWrt target MAC in host meta: `86-97-3F-C0-4D-6A`
  - Neighbor entry: `192.168.77.1 -> 86-97-3f-c0-4d-6a (Permanent)`
- Route pinning is correct:
  - `192.168.77.0/24` bound to `ifIndex 3` (`Ethernet`)
- Link mode is forced as intended:
  - Host NIC: `10 Mbps Half Duplex`

## Script completion quality
- Run is incomplete:
  - reached `phase1 round 3/6`
  - missing `post1`, `post2`, `done`
- No manual interruption markers:
  - `ctrlc=0`

## Serial-side observations
- Link mode confirms forced setting:
  - `Speed: 10Mb/s`
  - `Duplex: Half`
  - `Auto-negotiation: off`
- Stress mode auto-detection result:
  - `PING_MODE=default`
- Round progress before freeze:
  - round1 main delta `0`, fallback delta `0`
  - round2 main delta `0`, fallback delta `0`
  - round3 started, then no further output
- New low-level counters were printed at pre checkpoint:
  - `ethtool -S` shows many global fields with repeated `2998927360` values
  - queue counters remained meaningful (`txq0_packets=454`, `rxq0_packets=0`)

## Packet capture summary (`pkt-watchdog10half-bridgehold-v9.txt`)
- `lines=4623`
- `dir_tx=1707`, `dir_rx=82`
- host/openwrt MAC view:
  - `from_host=1663`
  - `to_host=0`
  - `to_owrt=1599`
  - `from_owrt=0`
- `icmp_echo_req=1202`, `icmp_echo_rep=0`
- `arp_matches=62`

## Important capture nuance
- `dir_rx=82` is not ingress from OpenWrt on the test NIC.
- Component split:
  - `rx_comp197=0`, `rx_comp198=0` (test Ethernet path)
  - `rx_comp13=66` (WiFi component noise)
  - `rx_comp151=8`, `rx_comp261=8` (other Ethernet/virtual path ARP noise)
- Conclusion:
  - still no observed inbound traffic on the target host NIC path.

## Host ping result
- `host-ping-window`:
  - `reply_lines=0`
  - `timeout_lines=600`

## Interpretation
- v9 did not complete due a likely blocking stress step in phase1.
- Adding a broad ARP pktmon filter increased unrelated RX noise from non-test components.
- Core failure signature remains unchanged on the test path:
  - no host ingress from router MAC,
  - no ICMP echo replies.

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v10.txt`
- Host: `/home/mgta29/send-next-host-watchdog-fill-10half-bridgehold-v10.ps1.txt`

v10 change focus:
- replace blocking phase stress with bounded one-shot ping bursts plus heartbeat output,
- keep low-level OpenWrt stats snapshots,
- narrow host pktmon filters to host-MAC IPv4 + host-MAC ARP (remove broad ARP noise).
