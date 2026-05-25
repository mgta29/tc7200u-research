# 2026-05-24 watchdog+10half run (`picocom-20260524-220912.log` + `pkt-watchdog10half.txt`)

## Findings
- Router link mode was forced and verified at start:
  - `Speed: 10Mb/s`
  - `Duplex: Half`
  - `Auto-negotiation: off`

- Router counters:
  - pre:
    - RX: `0 bytes / 0 packets`
    - TX: `44695 bytes / 473 packets / 19 errors / 0 dropped`
  - post1:
    - RX: still `0 / 0`
    - TX: `104279 bytes / 1081 packets / 22 errors / 3 dropped`
  - post2:
    - RX: still `0 / 0`
    - TX unchanged from post1 (`104279 / 1081 / 22 / 3`)

- Interrupt/error counters:
  - IRQ64: `80012 -> 80989 -> 81707`
  - IRQ66: always `0`
  - ERR: `231966 -> 246563 -> 248514`

- Watchdog evidence:
  - 3 unique timeout events:
    - `[8198.937192] ... timed out 2010 ms`
    - `[8202.868614] ... timed out 2680 ms`
    - `[8489.907897] ... timed out 2650 ms`

- Host-side proof files remained valid:
  - static neighbor present (`192.168.77.1 -> 16-d8-10-6e-9d-33`)
  - route pinned to `192.168.77.0/24`
  - host NIC forced to `10 Mbps Half Duplex`

- Host pktmon capture (`pkt-watchdog10half.txt`):
  - `dir_tx=349`
  - `dir_rx=0`
  - `to_owrt=349`
  - `from_owrt=0`
  - `icmp_echo_req=120`
  - `icmp_echo_rep=0`
  - `arp_req=0`, `arp_rep=0`

## New quality/synchronization issue
- Interface ownership drifted on router:
  - pre snapshot: `eth0` standalone
  - post1/post2 snapshots: `eth0 ... master br-lan`
- Host capture duration does not cover full router timeline:
  - host capture begins around `22:10:16` and ends around `22:14:04` (~3m48s)
  - router phase1 spans about `8194 -> 8623` in dmesg (~7 minutes)
- Therefore this artifact set is still valid for "no host-observed router egress in captured window", but does not fully overlap intended phase2 window.

## Interpretation
- Progress was made:
  - watchdog + TX growth reproduced under forced `10/half` and static neighbor.
- Core failure remains:
  - no host-observed frames sourced by router MAC.
  - router RX remains hard zero.
- Next test must remove timing/ownership drift to avoid false negatives from partial overlap.

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v2.txt`
- Windows: `/home/mgta29/send-next-host-watchdog-fill-10half-bridgehold-v2.ps1.txt`

Goal:
- keep `eth0` detached from `br-lan` for the full run and extend host capture window to full watchdog duration.
