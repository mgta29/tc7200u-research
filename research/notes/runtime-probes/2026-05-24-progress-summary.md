# 2026-05-24 Ethernet Debug Progress Summary

## Short answer
- Not running in circles. Multiple hypotheses were eliminated with targeted experiments.

## Latest run added (2026-05-25 v10 bridgehold, complete + strongly stressed)
- Run: `picocom-20260525-220235.log` + `pkt-watchdog10half-bridgehold-v10.txt`.
- Completed cleanly:
  - `pre -> phase1 (1..6) -> post1 -> post2 -> done`
  - no manual `^C`.
- Setup checks passed:
  - host route pinned to test NIC,
  - static neighbor points to OpenWrt MAC `92:58:41:34:c0:f0`,
  - host NIC forced to `10 Mbps Half Duplex`.
- Stress effectiveness is high:
  - OpenWrt TX moved:
    - pre: `4828 bytes / 12 pkts / 8 err`
    - post1: `73764 bytes / 714 pkts / 22 err`
  - round deltas: `+86, +88, +175, +0, +177, +176`
- Watchdog reproduced in this completed run:
  - script watchdog count output: `13`
- Capture still one-way:
  - `dir_tx=1630`, `dir_rx=0`
  - `from_host=1630`, `to_host=0`
  - `to_owrt=1573`, `from_owrt=0`
  - `icmp_echo_req=1202`, `icmp_echo_rep=0`
- Host ping window:
  - `reply_lines=0`, `timeout_lines=600`
- New low-level confirmation:
  - OpenWrt sysfs RX counters remain `0` pre/post1/post2,
  - `ethtool -S` `rxq0_packets/rxq0_bytes/rxq0_errors/rxq0_dropped` remain `0`,
  - `rbuf_err_cnt` and `mdf_err_cnt` unchanged.
- Impact:
  - no evidence of ingress at host capture, netdev RX, or RX queue statistics.

## Latest run added (2026-05-25 v9 bridgehold, incomplete)
- Run: `picocom-20260525-201714.log` + `pkt-watchdog10half-bridgehold-v9.txt`.
- Setup checks passed:
  - host route pinned to test NIC,
  - static neighbor points to OpenWrt MAC `86:97:3f:c0:4d:6a`,
  - host NIC forced to `10 Mbps Half Duplex`.
- Run stalled during phase1:
  - reached `phase1 round 3/6`,
  - no `post1/post2/done`,
  - no manual `^C` markers.
- Pre-stress round deltas were zero:
  - round1 main/fallback `0/0`
  - round2 main/fallback `0/0`
- Capture still shows no inbound on the test NIC path:
  - host/openwrt MAC view: `to_host=0`, `from_owrt=0`, `icmp_echo_rep=0`
- Note on v9 capture noise:
  - `dir_rx` increased due broad ARP filter matching non-test components (WiFi/virtual),
  - test Ethernet components still showed no RX.
- Impact:
  - this is another incomplete run due phase1 blocking; broad ARP filter added noise without new evidence on target path.

## Latest run added (2026-05-25 v8 bridgehold, complete + stressed)
- Run: `picocom-20260525-194022.log` + `pkt-watchdog10half-bridgehold-v8.txt`.
- Completed cleanly:
  - `pre -> phase1 (1..6) -> post1 -> post2 -> done`
  - no manual `^C`.
- Setup checks passed:
  - host route pinned to test NIC,
  - static neighbor points to OpenWrt MAC `86:97:3f:c0:4d:6a`,
  - host NIC forced to `10 Mbps Half Duplex`.
- Stress effectiveness present:
  - OpenWrt TX moved:
    - pre: `19049 bytes / 163 pkts / 19 err`
    - post1: `47591 bytes / 454 pkts / 30 err`
  - selected round deltas:
    - round1 main `+148`
    - round4 main `+143`
- Watchdog reproduced in this completed run:
  - script watchdog count output: `11`
- Capture remains one-way, even with host-MAC filter:
  - `dir_tx=1702`, `dir_rx=0`
  - `from_host=1702`, `to_host=0`
  - `to_owrt=1609`, `from_owrt=0`
  - `icmp_echo_req=1202`, `icmp_echo_rep=0`
- Host ping window:
  - `reply_lines=0`, `timeout_lines=600`
- Impact:
  - host filter-blind-spot hypothesis is ruled out; no inbound packets are observed at host capture layer.

## Latest run added (2026-05-25 v7 bridgehold, complete + stressed)
- Run: `picocom-20260525-184351.log` + `pkt-watchdog10half-bridgehold-v7.txt`.
- Completed cleanly:
  - `pre -> phase1 (1..6) -> post1 -> post2 -> done`
  - no manual `^C`.
- Setup checks passed:
  - host route pinned to test NIC,
  - static neighbor points to OpenWrt MAC `86:97:3f:c0:4d:6a`,
  - host NIC forced to `10 Mbps Half Duplex`.
- Stress effectiveness improved:
  - OpenWrt TX moved from pre to post1:
    - pre: `5819 bytes / 28 pkts / 10 err`
    - post1: `19049 bytes / 163 pkts / 19 err`
  - round-level deltas:
    - main: `9, 18, 0, 0, 0, 0`
    - fallback: `36, 72, 0, 0` (rounds 3..6)
- Watchdog reproduced in this completed run:
  - script watchdog count output: `10`
- Capture still one-way:
  - `dir_tx=1661`, `dir_rx=0`
  - `to_owrt=1661`, `from_owrt=0`
  - `icmp_echo_req=1202`, `icmp_echo_rep=0`
- Host ping window:
  - `reply_lines=0`, `timeout_lines=600`
- Impact:
  - this is a strong, valid run showing TX-path activity + watchdog, but still no observed router-originated frames on host.

## Latest run added (2026-05-25 v6 bridgehold, complete)
- Run: `picocom-20260525-174217.log` + `pkt-watchdog10half-bridgehold-v6.txt`.
- This is the first recent bridgehold run that completed all markers:
  - `pre -> phase1 (1..6) -> post1 -> post2 -> done`
  - no manual `^C` in serial log.
- Setup checks passed:
  - host route pinned to test NIC,
  - static neighbor points to current OpenWrt MAC `86:97:3f:c0:4d:6a`,
  - host NIC forced to `10 Mbps Half Duplex`.
- Capture still one-way:
  - `dir_tx=1525`, `dir_rx=0`
  - `to_owrt=1525`, `from_owrt=0`
  - `icmp_echo_req=1202`, `icmp_echo_rep=0`
- OpenWrt counters stayed flat during the whole run:
  - pre/post1/post2 TX all `3715 bytes / 10 pkts / 9 err`
  - RX stayed hard zero.
- Watchdog was not reproduced in this completed run window (`dmesg` watchdog count `0`).
- Impact:
  - run quality is good, but phase1 stress appears ineffective on this image (no TX growth).

## Latest run added (2026-05-25 v5 bridgehold, incomplete)
- Run: `picocom-20260525-140510.log` + `pkt-watchdog10half-bridgehold-v5.txt`.
- Setup checks passed:
  - host route pinned to test NIC,
  - static neighbor points to OpenWrt MAC `32:85:9a:5d:b3:cc`,
  - host NIC forced to `10 Mbps Half Duplex`.
- Capture still one-way:
  - `dir_tx=1241`, `dir_rx=0`
  - `to_owrt=1241`, `from_owrt=0`
  - `icmp_echo_req=962`, `icmp_echo_rep=0`
- Serial shows strong watchdog storm (`NETDEV WATCHDOG` line count: `352`).
- Test-quality issue:
  - manual `^C` during phase1,
  - only rounds `1/12` and `2/12` reached,
  - `post1/post2/done` markers missing.
- Impact:
  - host PowerShell ending automatically is expected (`capture_seconds=720`),
  - v5 remains an incomplete run because OpenWrt script was interrupted.

## Latest run added (2026-05-25 v4 bridgehold, incomplete)
- Run: `picocom-20260525-121047.log` + `pkt-watchdog10half-bridgehold-v4.txt`.
- Setup checks passed:
  - host route pinned to test NIC,
  - static neighbor points to OpenWrt MAC `32:85:9a:5d:b3:cc`,
  - host NIC forced to `10 Mbps Half Duplex`.
- Capture still one-way:
  - `dir_tx=1517`, `dir_rx=0`
  - `to_owrt=1517`, `from_owrt=0`
  - `icmp_echo_req=1202`, `icmp_echo_rep=0`
- Serial still shows repeated `NETDEV WATCHDOG`.
- Test-quality issue:
  - manual `^C` during phase1,
  - `post1/post2/done` markers missing.
- Impact:
  - v4 confirms the persistent one-way symptom, but is not a valid full checkpoint run because it did not complete.

## Latest run added (22:09 watchdog+10half)
- Run: `picocom-20260524-220912.log` + `pkt-watchdog10half.txt`.
- New positive signal:
  - TX counters moved under forced `10/half` + static neighbor:
    - pre: `44695 bytes / 473 pkts / 19 err`
    - post1/post2: `104279 bytes / 1081 pkts / 22 err / 3 drop`
- Watchdog reproduced again (3 unique timeout events at ~`8198.937`, `8202.868`, `8489.907`).
- Host still saw no router-sourced frames:
  - `dir_tx=349`, `dir_rx=0`
  - `to_owrt=349`, `from_owrt=0`
  - `icmp_echo_req=120`, `icmp_echo_rep=0`

## What is proven so far
- Host path setup is valid during test windows:
  - static neighbor points `192.168.77.1 -> 16:d8:10:6e:9d:33`
  - route to `192.168.77.0/24` pinned to the Realtek interface
- Host transmits many directed unicast frames to router MAC:
  - repeated `BC-EC-A0-2D-6C-9B > 16-D8-10-6E-9D-33` in pktmon captures
- Router sees stable pinned neighbor and ARP (`PERMANENT`, ARP flags `0x6`) in split runs.
- Link mismatch hypothesis was tested:
  - mismatch run (`host 100/full`, router `10/half`) failed
  - matched `10/half` run also failed identically

## Persistent failure signature (all recent runs)
- Host captures:
  - `Direction Tx` present
  - `Direction Rx = 0`
  - no `16-D8-10-6E-9D-33 > BC-EC-A0-2D-6C-9B` frames
  - no ICMP echo replies
- Router `eth0` counters:
  - RX stays `0`
  - TX counters stay flat in split runs
- Driver debug:
  - `tc7200u tx submit` logs progress (`free_now` decreases)
  - no corresponding successful traffic observations on host
- IRQ64 increments; IRQ66 stays `0`.
- Probed MMIO values at:
  - `0x12c03804`, `0x12c03808`, `0x12c03c44`, `0x12c02c44`
  - stayed `0x00000001` across checkpoints

## New test-quality issue identified
- During the latest run, `eth0` drifted back to `master br-lan` between pre and post snapshots.
- The host capture window was too short for this long watchdog run:
  - host capture starts around `22:10:16` and ends around `22:14:04` (~3m48s)
  - router phase1 spans ~`8194 -> 8623` seconds in dmesg (~7 minutes)
- Result: current host artifacts do not fully overlap intended phase2 window.

## Hypotheses already ruled out
- Wrong host pktmon OWRT MAC filter
- Missing host static neighbor/route for the target subnet
- ARP-only host traffic artifact
- Link-mode mismatch as primary cause

## Current leading hypothesis
- Router-side TX completion/egress path is stalled or not committing, while submit path continues.
- Router RX path also remains non-functional from netdev perspective.

## Next discriminating test (prepared)
- OpenWrt:
  - `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v11.txt`
- Windows:
  - `/home/mgta29/tc7200u-research/scripts/tftp/send-next-host-watchdog-fill-10half-bridgehold-v11.ps1.txt`
- Goal:
  - keep `eth0` detached from `br-lan` for the full run,
  - keep low-level OpenWrt RX counters at checkpoints,
  - remove router-side TX stress (RX-only observation window),
  - determine whether RX can increment when TX/watchdog pressure is absent.
  - guarantee `pre/post1/post2/done` checkpoints for valid comparison.

## Related notes (same day)
- `2026-05-24-rx-window-arp-only-204855.md`
- `2026-05-24-split-run-211146-analysis.md`
- `2026-05-24-split-run-213235-analysis.md`
- `2026-05-24-link100-run-214125-analysis.md`
- `2026-05-24-link10half-run-215536-analysis.md`
- `2026-05-24-watchdog10half-run-220912-analysis.md`
- `2026-05-25-watchdog10half-bridgehold-v4-analysis.md`
- `2026-05-25-watchdog10half-bridgehold-v5-analysis.md`
- `2026-05-25-watchdog10half-bridgehold-v6-analysis.md`
- `2026-05-25-watchdog10half-bridgehold-v7-analysis.md`
- `2026-05-25-watchdog10half-bridgehold-v8-analysis.md`
- `2026-05-25-watchdog10half-bridgehold-v9-analysis.md`
- `2026-05-25-watchdog10half-bridgehold-v10-analysis.md`
