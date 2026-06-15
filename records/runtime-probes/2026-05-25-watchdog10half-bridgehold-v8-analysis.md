# 2026-05-25 bridgehold v8 run (`picocom-20260525-194022.log`)

## Artifacts
- Serial: `records/logs/serial/picocom-20260525-194022.log`
- Host:
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v8.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v8.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v8.txt`
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v8.txt`
  - `C:\tftp\host-ping-window-watchdog10half-bridgehold-v8.txt`
  - `C:\tftp\pkt-watchdog10half-bridgehold-v8.txt`

## Host-side validity checks
- MAC alignment is correct:
  - OpenWrt target MAC in host meta: `86-97-3F-C0-4D-6A`
  - Neighbor entry: `192.168.77.1 -> 86-97-3f-c0-4d-6a (Permanent)`
- Route pinning is correct:
  - `192.168.77.0/24` bound to `ifIndex 3` (`Ethernet`)
- Link mode is forced as intended:
  - Host NIC: `10 Mbps Half Duplex`

## Packet capture summary (`pkt-watchdog10half-bridgehold-v8.txt`)
- `lines=4448`
- `dir_tx=1702`, `dir_rx=0`
- host-MAC view:
  - `from_host=1702`
  - `to_host=0`
- OpenWrt-MAC view:
  - `to_owrt=1609`
  - `from_owrt=0`
- `icmp_echo_req=1202`, `icmp_echo_rep=0`
- first packet timestamp: `2026-05-25 19:40:47`
- last packet timestamp: `2026-05-25 19:55:47`

## Script completion quality
- Run completed cleanly:
  - `pre`, `phase1 round 1..6`, `post1`, `post2`, `done`
- No manual interruption in serial log:
  - `ctrlc=0`

## Serial-side observations
- Link mode confirms forced setting:
  - `Speed: 10Mb/s`
  - `Duplex: Half`
  - `Auto-negotiation: off`
- Stress mode auto-detection result:
  - `PING_MODE=default`
- Per-round TX delta instrumentation:
  - round1: `tx_delta_main=148`
  - round2: `tx_delta_main=0`, fallback `tx_delta_fallback=0`
  - round3: `tx_delta_main=0`, fallback `tx_delta_fallback=0`
  - round4: `tx_delta_main=143`
  - round5: `tx_delta_main=0`, fallback `tx_delta_fallback=0`
  - round6: `tx_delta_main=0`, fallback `tx_delta_fallback=0`
- OpenWrt counters:
  - pre:   RX `0 bytes / 0 pkts`, TX `19049 bytes / 163 pkts / 19 err`
  - post1: RX `0 bytes / 0 pkts`, TX `47591 bytes / 454 pkts / 30 err`
  - post2: RX `0 bytes / 0 pkts`, TX unchanged from post1
- IRQ/ERR:
  - IRQ64: `34978 -> 37091 -> 37969`
  - IRQ66: always `0`
  - ERR: `121905 -> 129270 -> 131602`
- MMIO probes unchanged (`0x00000001` each):
  - `0x12c03804`, `0x12c03808`, `0x12c03c44`, `0x12c02c44`
- Watchdog:
  - script watchdog count output: `11`
  - serial watchdog lines observed: `14`

## Host ping result
- `host-ping-window`:
  - `reply_lines=0`
  - `timeout_lines=600`

## Interpretation
- v8 is another complete and stressed run with TX growth and watchdog reproduced.
- Switching host capture to host-MAC filter did not change the failure signature:
  - still no inbound packets (`dir_rx=0`, `to_host=0`),
  - still no ICMP replies,
  - OpenWrt RX remains hard zero.
- This rules out the previous host filter hypothesis (wrong OpenWrt source MAC expectation).

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v9.txt`
- Host: `/home/mgta29/send-next-host-watchdog-fill-10half-bridgehold-v9.ps1.txt`

v9 change focus:
- keep v8 stress path for comparability,
- add OpenWrt low-level counter snapshots (`sysfs` + `ethtool -S`) at pre/post1/post2,
- add host ARP filter to catch any ARP ingress in capture window.
