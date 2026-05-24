# 2026-05-24 - flood run: no watchdog in window, still no RX

## Setup

- OpenWrt th0: 192.168.77.3/24
- Peer target: 192.168.77.2
- Bridge detached (th0 nomaster, r-lan down/flush)
- Static neighbor set for peer MAC c:ec:a0:2d:6c:9b
- Test command:
  - ping -I eth0 -f -c 400 192.168.77.2 >/dev/null 2>&1 || ping -I eth0 -c 120 -W 1 192.168.77.2 >/dev/null

## Observed

- Link stayed UP,LOWER_UP on th0.
- RX stayed zero before/after the run.
- TX counters were unchanged in sampled pre/post snapshot (29723 bytes, 293 packets, 18 errors).
- Interrupt pattern remained one-sided:
  - hwirq 64 increased (17333 -> 17861)
  - hwirq 66 remained 
