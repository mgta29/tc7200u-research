# 2026-05-24 link10half run (`picocom-20260524-215536.log` + `pkt-link10half.txt`)

## Findings
- Link mode was matched on both sides at `10 Mbps / Half Duplex`:
  - Router `ethtool`: `Speed 10Mb/s`, `Duplex Half`, `Auto-negotiation off`.
  - Host proof shows `LinkSpeed 10 Mbps`, `Speed & Duplex 10 Mbps Half Duplex`.

- Router counters still did not move:
  - pre/post1/post2 RX: always `0`
  - pre/post1/post2 TX: always `44695 bytes / 473 packets / 19 errors`

- Neighbor and ARP remained valid/permanent on router:
  - `192.168.77.2 lladdr bc:ec:a0:2d:6c:9b PERMANENT`
  - `/proc/net/arp` flags `0x6`.

- Host capture stayed one-way:
  - `dir_tx=285`, `dir_rx=0`
  - `to_owrt=285`, `from_owrt=0`
  - `icmp_req=90`, `icmp_reply=0`
  - no ARP frames.

## Interpretation
- Link-mode mismatch is no longer a candidate root cause.
- Strongest remaining hypothesis is stalled TX completion / blocked egress path on router side (submit path active, completion/counter path inactive), plus no observable RX.

## Next test
- OpenWrt: `/home/mgta29/send-next-watchdog-fill-10half-v1.txt`
- Windows: `/home/mgta29/send-next-host-watchdog-fill-10half-v1.ps1.txt`

Goal:
- Fill TX ring intentionally under known-good neighbor/link settings and capture watchdog/ring status summary to characterize completion failure mode.
