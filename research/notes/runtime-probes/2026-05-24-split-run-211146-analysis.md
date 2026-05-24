# 2026-05-24 run (`picocom-20260524-211146.log` + host proofs + `pkt-next.txt`)

## What is now proven
- Host L2 path to router MAC is working:
  - `pkt-next.txt` has many `BC-EC-A0-2D-6C-9B > 16-D8-10-6E-9D-33` frames.
  - Count in this run: `to_owrt=547`.
- Host-side setup was correct in-run:
  - `host-neigh-proof.txt`: `192.168.77.1 -> 16-d8-10-6e-9d-33` permanent.
  - `host-route-proof.txt`: `192.168.77.0/24` pinned on interface index `3`.

## What still fails
- Router never receives packets at netdev level:
  - OpenWrt `eth0 RX` stayed `0 -> 0 -> 0` (pre/post1/post2).
  - OpenWrt ARP remained unresolved; post2 shows `192.168.77.2 FAILED`.
- Host never receives any frame sourced by router MAC:
  - `from_owrt=0`.
  - `Direction Rx=0` in `pkt-next.txt`.
- Router TX control still only showed `tc7200u tx submit` attempts; `eth0 TX` counters stayed unchanged (`301/301/301` packets in pre/post1/post2).
- Relevant devmem probes remained unchanged and equal to `0x00000001`:
  - `0x12c03804`, `0x12c03808`, `0x12c03c44`, `0x12c02c44`.

## Interpretation
- This result rules out the earlier host-filter-mismatch hypothesis.
- Current strongest hypothesis: router-side MAC/PHY data path is not exchanging payload traffic despite link-up and interrupt activity.

## Next split test
- OpenWrt script: `/home/mgta29/send-next-tx-static-neigh-rx-window-v1.txt`
- Windows script: `/home/mgta29/send-next-host-txrx-split-v1.ps1.txt`

Purpose:
1) Force OpenWrt TX as unicast (static neighbor on router) to test egress visibility on host without ARP dependency.
2) Then run host->router probe window to retest router RX in same capture.
