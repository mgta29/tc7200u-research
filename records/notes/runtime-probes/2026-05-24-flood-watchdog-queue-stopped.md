# 2026-05-24 - flood run: watchdog reproduced with queue-stop snapshot

## Setup

- OpenWrt eth0: 192.168.77.3/24
- Peer target: 192.168.77.2
- Bridge detached (eth0 nomaster, br-lan down/flush)
- Static neighbor set for peer MAC bc:ec:a0:2d:6c:9b
- Test command:
  - ping -I eth0 -f -c 2000 192.168.77.2 >/dev/null 2>&1 || ping -I eth0 -c 400 -W 1 192.168.77.2 >/dev/null

## Observed

- Link stayed UP,LOWER_UP on eth0.
- RX stayed zero before/after the run.
- TX rose substantially during the run:
  - pre: 29723 bytes, 293 packets, 18 errors
  - post: 77611 bytes, 777 packets, 22 errors
- Interrupt pattern remained one-sided:
  - hwirq 64 increased (21102 -> 22890)
  - hwirq 66 remained 0
  - ERR increased (76325 -> 83687)
- NETDEV WATCHDOG reproduced multiple times and included a clear ring summary:
  - t=4913.926: `TX queue status: stopped, interrupts: enabled`
  - `(sw)free_bds: 18 (sw)size: 256`
  - `(sw)p_index: 246 (hw)p_index: 72`
  - `(sw)c_index: 8 (hw)c_index: 0`
  - `(sw)clean_p: 8 (sw)write_p: 246`
- Additional timeouts followed (for example at ~5167, ~5169, ~5172) with
  `hw)c_index: 0` still stuck.
- After timeout handling, tx-submit accounting jumped beyond ring size
  (`free_now=266`, later `free_now=273` while ring size is 256).

## Interpretation

This run strengthens the same failure mode: hardware completion does not move
(`hw c_index` remains 0) while software indices change and watchdog recovery
mutates software free-descriptor accounting into impossible values (> ring
size). That points to a broken completion/reclaim path on top of the underlying
no-completion condition.
