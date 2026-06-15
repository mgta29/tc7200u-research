# 2026-05-24 - pktmon shows peer ARP only, no OpenWrt egress frames

## Inputs

- Serial log:
  - `records/logs/serial/picocom-20260524-195459.log`
- Host packet trace text:
  - `C:/tftp/pkt.txt`

## Setup seen in serial log

- Interface prepared on OpenWrt:
  - `eth0` up, static `192.168.77.3/24`
  - static neighbor `192.168.77.2 -> bc:ec:a0:2d:6c:9b`
- Stress command:
  - `ping -I eth0 -f -c 2000 192.168.77.2 >/dev/null 2>&1 || ping -I eth0 -c 400 -W 1 192.168.77.2 >/dev/null`

## Serial-side observations

- `eth0` stayed `UP,LOWER_UP`.
- Random MAC in this boot: `16:d8:10:6e:9d:33`.
- RX remained zero.
- TX rose from `1699 bytes / 9 pkts / 9 errors` to
  `30167 bytes / 301 pkts / 18 errors`.
- IRQ pattern remained one-sided:
  - hwirq `64`: `503 -> 1212`
  - hwirq `66`: `0 -> 0`
  - `ERR`: `11550 -> 16123`
- `NETDEV WATCHDOG` repeated multiple times.
- In this run, no `Ring 0 queue 0 status summary` lines were emitted.

## Host-side pktmon observations

- Trace contains repeated peer ARP requests:
  - `BC-EC-A0-2D-6C-9B > FF-FF-FF-FF-FF-FF`
  - `who-has 192.168.77.1 tell 192.168.77.2`
- Counts in this capture:
  - peer-source MAC lines: `288`
  - `who-has 192.168.77.1 tell 192.168.77.2`: `280`
- No frames matched the OpenWrt MAC from this boot (`16:d8:10:6e:9d:33`).
- No `192.168.77.3` references were present.

## Interpretation

This run confirms that traffic is still not leaving OpenWrt onto the wire in a
usable way, even while the driver reports continuous TX submission and TX
counters increase. The host saw only peer-side ARP retries and no ARP replies
from OpenWrt.
