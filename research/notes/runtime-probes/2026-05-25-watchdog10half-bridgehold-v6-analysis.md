# 2026-05-25 bridgehold v6 run (`picocom-20260525-174217.log`)

## Artifacts
- Serial: `evidence/serial/picocom-20260525-174217.log`
- Host:
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v6.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v6.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v6.txt`
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v6.txt`
  - `C:\tftp\host-ping-window-watchdog10half-bridgehold-v6.txt`
  - `C:\tftp\pkt-watchdog10half-bridgehold-v6.txt`

## Host-side validity checks
- MAC alignment is correct for this boot:
  - OpenWrt target MAC in host meta: `86-97-3F-C0-4D-6A`
  - Neighbor entry: `192.168.77.1 -> 86-97-3f-c0-4d-6a (Permanent)`
- Route pinning is correct:
  - `192.168.77.0/24` bound to `ifIndex 3` (`Ethernet`)
- Link mode is forced as intended:
  - Host NIC: `10 Mbps Half Duplex`

## Packet capture summary (`pkt-watchdog10half-bridgehold-v6.txt`)
- `lines=4094`
- `dir_tx=1525`, `dir_rx=0`
- `to_owrt=1525`, `from_owrt=0`
- `icmp_echo_req=1202`, `icmp_echo_rep=0`
- first packet timestamp: `2026-05-25 17:57:10`
- last packet timestamp: `2026-05-25 18:12:10`

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
- Pre/post counters are flat on TX and hard-zero on RX:
  - pre:  RX `0 bytes / 0 pkts`, TX `3715 bytes / 10 pkts / 9 err`
  - post1: RX `0 bytes / 0 pkts`, TX `3715 bytes / 10 pkts / 9 err`
  - post2: RX `0 bytes / 0 pkts`, TX `3715 bytes / 10 pkts / 9 err`
- IRQ/ERR still move:
  - IRQ64: `2118 -> 3364 -> 4240`
  - IRQ66: always `0`
  - ERR: `16022 -> 19373 -> 21779`
- MMIO probes unchanged (`0x00000001` each):
  - `0x12c03804`, `0x12c03808`, `0x12c03c44`, `0x12c02c44`
- Watchdog in this run window:
  - script-reported `dmesg | grep -c NETDEV WATCHDOG` output is `0`

## Interpretation
- v6 is the first fully completed and non-interrupted bridgehold run.
- Failure signature persists (host TX only, no host RX, no replies).
- Phase1 stress appears ineffective in v6 because OpenWrt TX packet counters did not increase at all during stress rounds.

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v7.txt`
- Host: `/home/mgta29/send-next-host-watchdog-fill-10half-bridgehold-v7.ps1.txt`

v7 changes:
- explicit ping stress-mode detection (`flood` vs `-i` fallback),
- per-round TX delta logging on OpenWrt,
- fallback single-shot ping burst when round TX delta is zero.
