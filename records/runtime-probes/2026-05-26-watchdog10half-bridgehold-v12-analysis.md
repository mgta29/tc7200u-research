# Watchdog 10Half Bridgehold v12 Analysis (2026-05-26)

## Inputs
- Serial log: `records/logs/serial/picocom-20260526-011147.log`
- Host capture: `C:\tftp\pkt-watchdog10half-bridgehold-v12.etl` and converted `C:\tftp\pkt-watchdog10half-bridgehold-v12.txt`
- Host ping: `C:\tftp\host-ping-window-watchdog10half-bridgehold-v12.txt`
- Host proofs:
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v12.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v12.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v12.txt`
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v12.txt`

## Completion status
- OpenWrt run completed end-to-end (`post1`, `post2`, `done` present).
- Script did not hard-freeze this time.

## Key observations
- OpenWrt phase progress reached all rounds:
  - `round1 tx_delta_main=0`
  - `round2 tx_delta_main=0`
  - `round3 tx_delta_main=82`
  - `round4 tx_delta_main=0`
  - `round5 tx_delta_main=0`
  - `round6 tx_delta_main=162`
- `NETDEV WATCHDOG` occurred three times:
  - `[1098.985047]`
  - `[1214.024941]`
  - `[1443.905771]`
- No `Ring 0 queue 0 status summary` line captured in this run.
- Host side was configured as intended:
  - NIC `10 Mbps Half Duplex`
  - static neighbor to OpenWrt MAC `C2-52-A8-6D-4C-41`
  - route `192.168.77.0/24` via host interface
- Host ping result:
  - Sent `475`, Received `0`, Lost `475` (`100% loss`)
- PktMon decode evidence:
  - `Direction Tx`: `1409`
  - `Direction Rx`: `0`
  - `BC-EC-A0-2D-6C-9B > C2-52-A8-6D-4C-41`: `1353`
  - `C2-52-A8-6D-4C-41 > BC-EC-A0-2D-6C-9B`: `0`
  - `ICMP echo request`: `951`
  - `ICMP echo reply`: `0`

## Important script issue found
- `ip -s link show dev eth0` is not supported by this BusyBox build and prints usage.
- Result: pre/post link counters were not collected by v12 script.
- Next OpenWrt script should read counters from `/sys/class/net/eth0/statistics/*` directly.

## Conclusion
- This run confirms the same core failure pattern:
  - Host continuously transmits toward OpenWrt.
  - OpenWrt does not produce observable return traffic to host.
  - `NETDEV WATCHDOG` still appears under controlled TX rounds.
- Progress vs earlier rounds: improved liveness (full script completion), but no RX-path recovery yet.
