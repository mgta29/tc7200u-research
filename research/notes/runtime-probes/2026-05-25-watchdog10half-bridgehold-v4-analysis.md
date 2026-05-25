# 2026-05-25 bridgehold v4 run (`picocom-20260525-121047.log`)

## Artifacts
- Serial: `evidence/serial/picocom-20260525-121047.log`
- Host:
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v4.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v4.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v4.txt`
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v4.txt`
  - `C:\tftp\host-ping-window-watchdog10half-bridgehold-v4.txt`
  - `C:\tftp\pkt-watchdog10half-bridgehold-v4.txt`

## Host-side validity checks
- MAC alignment is correct:
  - OpenWrt target MAC in host meta: `32-85-9A-5D-B3-CC`
  - Neighbor entry: `192.168.77.1 -> 32-85-9a-5d-b3-cc (Permanent)`
- Route pinning is correct:
  - `192.168.77.0/24` bound to `ifIndex 3` (`Ethernet`)
- Link mode is forced as intended:
  - Host NIC: `10 Mbps Half Duplex`

## Packet capture summary (`pkt-watchdog10half-bridgehold-v4.txt`)
- `lines=4078`
- `dir_tx=1517`, `dir_rx=0`
- `to_owrt=1517`, `from_owrt=0`
- `icmp_echo_req=1202`, `icmp_echo_rep=0`
- first packet timestamp: `2026-05-25 12:16:51`
- last packet timestamp: `2026-05-25 12:31:51`

## Serial-side observations
- Link mode confirms forced setting:
  - `Speed: 10Mb/s`
  - `Duplex: Half`
  - `Auto-negotiation: off`
- Pre snapshot:
  - RX: `0 bytes / 0 packets`
  - TX: `1629 bytes / 8 packets / 9 errors`
  - IRQ64: `13226`, IRQ66: `0`, ERR: `46421`
  - Probed MMIO values all `0x00000001`:
    - `0x12c03804`, `0x12c03808`, `0x12c03c44`, `0x12c02c44`
- Repeated watchdog events are present (`NETDEV WATCHDOG`).

## Critical test-quality issue
- The run was interrupted manually before completion:
  - `^C` appears multiple times during phase1 rounds.
- Script completion markers are missing:
  - present: `=== pre ===`
  - missing: `=== post1 ===`, `=== post2 ===`, `=== done ===`

## Conclusion
- Failure signature still looks the same (host sends directed unicast, sees no return traffic).
- But v4 cannot be used as a full checkpointed comparison because the OpenWrt script did not complete.

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v5.txt`
- Host: `/home/mgta29/send-next-host-watchdog-fill-10half-bridgehold-v5.ps1.txt`

v5 goal:
- keep the same bridge-hold and MAC-verified setup,
- use bounded phase1 timing so the run completes without manual `Ctrl+C`,
- preserve `pre/post1/post2/done` checkpoints for valid comparison.
