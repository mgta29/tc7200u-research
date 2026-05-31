# 2026-05-25 bridgehold v3 run (`picocom-20260525-115427.log`)

## Artifacts
- Serial: `records/logs/serial/picocom-20260525-115427.log`
- Host:
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v3.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v3.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v3.txt`
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v3.txt`
  - `C:\tftp\host-ping-window-watchdog10half-bridgehold-v3.txt`
  - `C:\tftp\pkt-watchdog10half-bridgehold-v3.txt` (converted from ETL)

## What improved
- Run completed all checkpoints: `pre`, `post1`, `post2`, `done`.
- MAC alignment was correct end-to-end:
  - OpenWrt `eth0`: `32:85:9a:5d:b3:cc`
  - Host target (`host-meta`): `32-85-9A-5D-B3-CC`
  - Host static neighbor points `192.168.77.1` to that same MAC.
- `eth0` stayed detached (`no master br-lan` lines observed in checkpoints).

## Observed results
- OpenWrt counters:
  - pre: RX `0/0`, TX `1629 bytes / 8 pkts / 9 err`
  - post1: RX `0/0`, TX unchanged
  - post2: RX `0/0`, TX unchanged
- IRQ/ERR:
  - IRQ64: `2211 -> 3484 -> 4357`
  - IRQ66: always `0`
  - ERR: `16252 -> 19771 -> 22165`
- Watchdog:
  - `NETDEV WATCHDOG` lines: `0` in this run.
- Host pktmon (`pkt-watchdog10half-bridgehold-v3.txt`):
  - `dir_tx=1050`, `dir_rx=0`
  - `to_owrt=1050`, `from_owrt=0`
  - `icmp_echo_req=778`, `icmp_echo_rep=0`
  - `arp_req=0`, `arp_rep=0`

## Interpretation
- This is a clean/valid run (no MAC mismatch, no bridge re-enslave, full script completion).
- Failure signature persists:
  - host sends directed unicast to router MAC,
  - host never sees any router-sourced frames,
  - router RX remains hard zero.
- `phase1` stress appears too weak in v3 (no TX growth, no watchdog), likely because the timeout branch did not provide sustained load on this image.

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v4.txt`
- Host: `/home/mgta29/send-next-host-watchdog-fill-10half-bridgehold-v4.ps1.txt`

v4 changes:
- deterministic phase1 flood (`8 rounds x 300`) instead of timeout-based branch,
- same dynamic MAC parameterization on host side,
- longer host capture window (900s).
