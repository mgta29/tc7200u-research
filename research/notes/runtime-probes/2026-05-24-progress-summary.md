# 2026-05-24 Ethernet Debug Progress Summary

## Short answer
- Not running in circles. Multiple hypotheses were eliminated with targeted experiments.

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
  - `/home/mgta29/send-next-watchdog-fill-10half-v1.txt`
- Windows:
  - `/home/mgta29/send-next-host-watchdog-fill-10half-v1.ps1.txt`
- Goal:
  - intentionally fill TX ring under known-good neighbor + matched link mode
  - capture watchdog/ring status summary and correlate with host capture directionality

## Related notes (same day)
- `2026-05-24-rx-window-arp-only-204855.md`
- `2026-05-24-split-run-211146-analysis.md`
- `2026-05-24-split-run-213235-analysis.md`
- `2026-05-24-link100-run-214125-analysis.md`
- `2026-05-24-link10half-run-215536-analysis.md`
