# 2026-05-24 run (`picocom-20260524-204855.log` + `C:\tftp\pkt.txt`)

## Evidence
- OpenWrt pre/post link stats unchanged for RX:
  - pre RX: `0 bytes / 0 packets`
  - post RX: `0 bytes / 0 packets`
- OpenWrt TX unchanged in this window:
  - pre TX: `30167 bytes / 301 packets / 18 errors`
  - post TX: `30167 bytes / 301 packets / 18 errors`
- IRQ deltas:
  - IRQ64: `16613 -> 17162` (`+549`)
  - IRQ66: `0 -> 0`
- OpenWrt ARP table remained empty (header only in `/proc/net/arp`).

- Host packet capture (`pkt.txt`) remained ARP-broadcast-only:
  - `who-has` lines: `58`
  - ARP replies: `0`
  - ICMP echo lines: `0`
  - router MAC `16-D8-10-6E-9D-33`: `0` occurrences
  - peer MAC `BC-EC-A0-2D-6C-9B`: `58` occurrences
  - `Direction Tx`: `58`
  - `Direction Rx`: `0`

## Interpretation
- This run still does not prove host unicast-to-router traffic in the measured window.
- Current evidence remains consistent with host path not delivering frames to router RX path.

## Next test pair
- OpenWrt side: `/home/mgta29/send-next-rx-plus-tx-control-v2.txt`
- Windows side: `/home/mgta29/send-next-host-verified-unicast-v3.ps1.txt`

Goal of this pair:
- Phase 1: prove (or falsify) host unicast delivery toward router.
- Phase 2: inject router->host TX control traffic in the same contiguous capture window.
