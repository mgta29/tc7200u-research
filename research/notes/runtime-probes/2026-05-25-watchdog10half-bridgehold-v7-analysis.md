# 2026-05-25 bridgehold v7 run (`picocom-20260525-184351.log`)

## Artifacts
- Serial: `logs/picocom/picocom-20260525-184351.log`
- Host:
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v7.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v7.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v7.txt`
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v7.txt`
  - `C:\tftp\host-ping-window-watchdog10half-bridgehold-v7.txt`
  - `C:\tftp\pkt-watchdog10half-bridgehold-v7.txt`

## Host-side validity checks
- MAC alignment is correct:
  - OpenWrt target MAC in host meta: `86-97-3F-C0-4D-6A`
  - Neighbor entry: `192.168.77.1 -> 86-97-3f-c0-4d-6a (Permanent)`
- Route pinning is correct:
  - `192.168.77.0/24` bound to `ifIndex 3` (`Ethernet`)
- Link mode is forced as intended:
  - Host NIC: `10 Mbps Half Duplex`

## Packet capture summary (`pkt-watchdog10half-bridgehold-v7.txt`)
- `lines=4366`
- `dir_tx=1661`, `dir_rx=0`
- `to_owrt=1661`, `from_owrt=0`
- `icmp_echo_req=1202`, `icmp_echo_rep=0`
- first packet timestamp: `2026-05-25 18:44:15`
- last packet timestamp: `2026-05-25 18:59:15`

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
  - round1: `tx_delta_main=9`
  - round2: `tx_delta_main=18`
  - round3: `tx_delta_main=0`, fallback `tx_delta_fallback=36`
  - round4: `tx_delta_main=0`, fallback `tx_delta_fallback=72`
  - round5: `tx_delta_main=0`, fallback `tx_delta_fallback=0`
  - round6: `tx_delta_main=0`, fallback `tx_delta_fallback=0`
- OpenWrt counters:
  - pre:   RX `0 bytes / 0 pkts`, TX `5819 bytes / 28 pkts / 10 err`
  - post1: RX `0 bytes / 0 pkts`, TX `19049 bytes / 163 pkts / 19 err`
  - post2: RX `0 bytes / 0 pkts`, TX unchanged from post1
- IRQ/ERR:
  - IRQ64: `16265 -> 18374 -> 19248`
  - IRQ66: always `0`
  - ERR: `73492 -> 80887 -> 83197`
- MMIO probes unchanged (`0x00000001` each):
  - `0x12c03804`, `0x12c03808`, `0x12c03c44`, `0x12c02c44`
- Watchdog:
  - script watchdog count output: `10`
  - serial watchdog lines observed: `13`

## Host ping result
- `host-ping-window`:
  - `reply_lines=0`
  - `timeout_lines=600`

## Interpretation
- v7 is a completed, high-quality run with effective TX growth and reproduced watchdog.
- Failure signature still persists:
  - host never sees router-originated traffic (`dir_rx=0`, no ICMP replies),
  - OpenWrt RX remains hard zero.
- New nuance:
  - stress path stalls by rounds 5-6 (both main and fallback deltas drop to zero).

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v8.txt`
- Host: `/home/mgta29/send-next-host-watchdog-fill-10half-bridgehold-v8.ps1.txt`

v8 change focus:
- keep OpenWrt stress logic same for comparability,
- switch host pktmon MAC filter from OpenWrt MAC to host NIC MAC, so inbound frames are captured even if router source MAC is unexpected.
