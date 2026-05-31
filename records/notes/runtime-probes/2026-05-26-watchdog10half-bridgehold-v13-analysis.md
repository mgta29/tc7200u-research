# Watchdog 10Half Bridgehold v13 Analysis (2026-05-26)

## Inputs
- Serial log: `records/logs/serial/picocom-20260526-013025.log`
- Host artifacts:
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v13.txt`
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v13.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v13.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v13.txt`
  - `C:\tftp\host-ping-window-watchdog10half-bridgehold-v13.txt`
- PktMon:
  - `C:\tftp\pkt-watchdog10half-bridgehold-v13.etl`
  - decoded `C:\tftp\pkt-watchdog10half-bridgehold-v13.txt`

## Completion status
- Run completed (`post1`, `post2`, `done` all present).
- No hard freeze during the scripted sequence.

## Host setup confirmation
- OpenWrt target MAC: `C2-52-A8-6D-4C-41`
- Host NIC MAC: `BC-EC-A0-2D-6C-9B`
- Host link mode: `10 Mbps Half Duplex`
- Static neighbor entry for `192.168.77.1` present.
- Route `192.168.77.0/24` bound to test interface.

## OpenWrt phase results
- Round summaries from serial:
  - `round1`: `tx_delta=0`, `rx_delta=0`, `watchdog_count=0`
  - `round2`: `tx_delta=163`, `rx_delta=0`, `watchdog_count=4`
  - `round3`: `tx_delta=0`, `rx_delta=0`, `watchdog_count=4`
  - `round4`: `tx_delta=0`, `rx_delta=0`, `watchdog_count=4`
  - `round5`: `tx_delta=170`, `rx_delta=0`, `watchdog_count=12`
  - `round6`: `tx_delta=0`, `rx_delta=0`, `watchdog_count=12`
- Total scripted TX packet increase: `+333` (`322 -> 655`)
- RX packet increase: `0` (`0 -> 0`)

## Pre/post deltas (OpenWrt)
- `tx_packets`: `322 -> 655` (`+333`)
- `rx_packets`: `0 -> 0` (`+0`)
- `tx_errors`: `12 -> 24` (`+12`)
- `rx_errors`: `0 -> 0` (`+0`)
- `tx_dropped`: `1 -> 1` (`+0`)
- `rx_dropped`: `0 -> 0` (`+0`)
- IRQ 64 count: `9819 -> 11953` (`+2134`)
- `/proc/interrupts ERR`: `37602 -> 46024` (`+8422`)
- Register probes unchanged (`0x12c03804/08`, `0x12c03c44`, `0x12c02c44` all `0x00000001`).

## Watchdog behavior
- Real watchdog occurrences in phase window: `12` (`NETDEV WATCHDOG`).
- No `Ring 0 queue 0 status summary` lines captured.

## Host ping result
- `Sent=592`, `Received=0`, `Lost=592` (`100% loss`).
- No `Reply from` and no `Destination host unreachable` lines.

## PktMon direction evidence
- `Direction Tx`: `1186`
- `Direction Rx`: `0`
- `ICMP echo request`: `1184`
- `ICMP echo reply`: `0`
- MAC direction:
  - `BC-EC-A0-2D-6C-9B > C2-52-A8-6D-4C-41`: `1184`
  - `C2-52-A8-6D-4C-41 > BC-EC-A0-2D-6C-9B`: `0`

## Conclusion
- v13 confirms the same core failure as previous rounds:
  - Host continuously transmits directed ICMP to OpenWrt.
  - OpenWrt does not return any observed traffic to host.
  - RX counters on OpenWrt remain zero throughout.
  - TX path intermittently progresses but repeatedly hits watchdog timeouts.
- Compared with v12: run still completes, but watchdog intensity increased (v13: 12 events vs v12: 3 events), while RX remains absent.
