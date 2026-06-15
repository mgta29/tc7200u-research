# 2026-05-25 bridgehold v5 run (`picocom-20260525-140510.log`)

## Artifacts
- Serial: `records/logs/serial/picocom-20260525-140510.log`
- Host:
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v5.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v5.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v5.txt`
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v5.txt`
  - `C:\tftp\host-ping-window-watchdog10half-bridgehold-v5.txt`
  - `C:\tftp\pkt-watchdog10half-bridgehold-v5.txt`

## Host-side validity checks
- MAC alignment is correct:
  - OpenWrt target MAC in host meta: `32-85-9A-5D-B3-CC`
  - Neighbor entry: `192.168.77.1 -> 32-85-9a-5d-b3-cc (Permanent)`
- Route pinning is correct:
  - `192.168.77.0/24` bound to `ifIndex 3` (`Ethernet`)
- Link mode is forced as intended:
  - Host NIC: `10 Mbps Half Duplex`

## Packet capture summary (`pkt-watchdog10half-bridgehold-v5.txt`)
- `lines=3526`
- `dir_tx=1241`, `dir_rx=0`
- `to_owrt=1241`, `from_owrt=0`
- `icmp_echo_req=962`, `icmp_echo_rep=0`
- first packet timestamp: `2026-05-25 14:04:51`
- last packet timestamp: `2026-05-25 14:16:51`

## Serial-side observations
- Link mode confirms forced setting:
  - `Speed: 10Mb/s`
  - `Duplex: Half`
  - `Auto-negotiation: off`
- Pre snapshot:
  - RX: `0 bytes / 0 packets`
  - TX: `94697 bytes / 956 packets / 32 errors`
  - IRQ64: `22695`, IRQ66: `0`, ERR: `78854`
  - Probed MMIO values all `0x00000001`:
    - `0x12c03804`, `0x12c03808`, `0x12c03c44`, `0x12c02c44`
- Watchdog storm is very strong:
  - `NETDEV WATCHDOG` lines in serial log: `352`

## Critical test-quality issue
- Run did not complete checkpoints:
  - phase lines reached only `phase1 round 1/12` and `phase1 round 2/12`
  - missing markers: `post1`, `post2`, `done`
- Serial log contains manual interrupts:
  - `^C` appears `3` times during phase1

## Interpretation
- Host script ending automatically is expected (`capture_seconds=720` in v5 meta).
- OpenWrt script was not allowed to finish because of manual interruption during watchdog storm.
- Failure signature remains unchanged: directed host TX only, no observed return traffic.

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v6.txt`
- Host: `/home/mgta29/send-next-host-watchdog-fill-10half-bridgehold-v6.ps1.txt`

v6 changes:
- lower console loglevel (`dmesg -n 1`) to prevent serial spam from looking like a hard hang,
- bounded flood bursts with stronger kill handling,
- same route/MAC/link controls and full `pre/post1/post2/done` checkpoints.
