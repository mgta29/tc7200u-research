# 2026-05-24 - flood run: no watchdog in window, still no RX

## Setup

- OpenWrt eth0: 192.168.77.3/24
- Peer target: 192.168.77.2
- Bridge detached (eth0 nomaster, br-lan down/flush)
- Static neighbor set for peer MAC bc:ec:a0:2d:6c:9b
- Test command:
  - ping -I eth0 -f -c 400 192.168.77.2 >/dev/null 2>&1 || ping -I eth0 -c 120 -W 1 192.168.77.2 >/dev/null

## Observed

- Link stayed UP,LOWER_UP on eth0.
- RX stayed zero before/after the run.
- TX counters were unchanged in sampled pre/post snapshot (29723 bytes, 293 packets, 18 errors).
- Interrupt pattern remained one-sided:
  - hwirq 64 increased (17333 -> 17861)
  - hwirq 66 remained 0
  - ERR increased (66990 -> 69150)
- No NETDEV WATCHDOG lines were emitted in this capture window.
- tc7200u tx submit lines continued throughout with the known signature:
  - hw_before(p=0 c=8)
  - hw_after(p=1 c=...)
  - free_now monotonically decreased during the sampled window (for example 244 -> 125).

## Interpretation

This run did not produce a timeout during the sampled interval, but the data path
is still non-functional: no RX completions, no successful reachability, and the
same one-sided IRQ behavior (64 active, 66 idle). The TX submit trace still
shows the same TC7200U v1 ring behavior pattern without restoring packet flow.
