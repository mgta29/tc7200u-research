# 2026-05-25 bridgehold v10 run (`picocom-20260525-220235.log`)

## Artifacts
- Serial: `records/logs/serial/picocom-20260525-220235.log`
- Host:
  - `C:\tftp\host-meta-watchdog10half-bridgehold-v10.txt`
  - `C:\tftp\host-neigh-proof-watchdog10half-bridgehold-v10.txt`
  - `C:\tftp\host-route-proof-watchdog10half-bridgehold-v10.txt`
  - `C:\tftp\host-link-proof-watchdog10half-bridgehold-v10.txt`
  - `C:\tftp\host-ping-window-watchdog10half-bridgehold-v10.txt`
  - `C:\tftp\pkt-watchdog10half-bridgehold-v10.txt`

## Host-side validity checks
- MAC alignment is correct for this boot:
  - OpenWrt target MAC in host meta: `92-58-41-34-C0-F0`
  - Neighbor entry: `192.168.77.1 -> 92-58-41-34-c0-f0 (Permanent)`
- Route pinning is correct:
  - `192.168.77.0/24` bound to `ifIndex 3` (`Ethernet`)
- Link mode is forced as intended:
  - Host NIC: `10 Mbps Half Duplex`

## Packet capture summary (`pkt-watchdog10half-bridgehold-v10.txt`)
- `lines=4304`
- `dir_tx=1630`, `dir_rx=0`
- MAC view:
  - `from_host=1630`
  - `to_host=0`
  - `to_owrt=1573`
  - `from_owrt=0`
- `icmp_echo_req=1202`, `icmp_echo_rep=0`
- first packet timestamp: `2026-05-25 22:03:29`
- last packet timestamp: `2026-05-25 22:18:29`

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
- Round-level stress progress (bounded one-shot bursts):
  - round1: `tx_delta_main=86`
  - round2: `tx_delta_main=88`
  - round3: `tx_delta_main=175`
  - round4: `tx_delta_main=0`
  - round5: `tx_delta_main=177`
  - round6: `tx_delta_main=176`
- OpenWrt counters:
  - pre:   RX `0 bytes / 0 pkts`, TX `4828 bytes / 12 pkts / 8 err`
  - post1: RX `0 bytes / 0 pkts`, TX `73764 bytes / 714 pkts / 22 err`
  - post2: RX `0 bytes / 0 pkts`, TX unchanged from post1
- IRQ/ERR:
  - IRQ64: `3300 -> 5473 -> 6741`
  - IRQ66: always `0`
  - ERR: `19171 -> 29665 -> 33028`
- Low-level stats at pre/post1/post2:
  - sysfs `rx_packets/rx_bytes/rx_errors/rx_dropped` all remain `0`
  - `ethtool -S`: `rxq0_packets/rxq0_bytes/rxq0_errors/rxq0_dropped` all remain `0`
  - `rbuf_err_cnt=1588`, `mdf_err_cnt=1592` unchanged
  - `txq0_packets` tracks TX growth (`12 -> 714`)
- Watchdog:
  - script watchdog count output: `13`
  - serial watchdog lines observed: `16`

## Host ping result
- `host-ping-window`:
  - `reply_lines=0`
  - `timeout_lines=600`

## Interpretation
- v10 is a complete, non-interrupted, strongly stressed run.
- Failure signature remains unchanged and is now confirmed at multiple layers:
  - host sees no inbound packets from target path,
  - OpenWrt netdev RX remains zero,
  - OpenWrt low-level RX queue counters remain zero.

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v11.txt`
- Host: `/home/mgta29/tc7200u-research/scripts/tftp/send-next-host-watchdog-fill-10half-bridgehold-v11.ps1.txt`

v11 focus:
- remove router-side TX stress and run a pure RX observation window,
- keep low-level checkpoint stats,
- check whether RX can increment without local TX/watchdog interference.
