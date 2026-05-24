# 2026-05-19 - reinit changes pointer field, traffic does not

## Setup

- OpenWrt `eth0`: `192.168.77.1/24`
- Three phases:
  - `CYCLE1`: down/flush/up/add/sleep
  - `CYCLE2`: down/flush/up/add/sleep
  - `TRAFFIC`: `ping -c 3 -W 1 192.168.77.2`, then sleep
- Sampled each phase:
  - `0x12c02c0c`, `0x12c03c0c`
  - `0x12c03000..0x12c0300c`
  - IRQ and netdev stats at end.

## Observed

- Pointer-like field changed across reinit cycles:
  - `CYCLE1`: `0x12c02c0c=0x06f197c0`, `0x12c03c0c=0x06f197c0`
  - `CYCLE2`: `0x12c02c0c=0x06e73dc0`, `0x12c03c0c=0x06e73dc0`
- During traffic phase, pointer-like field stayed at CYCLE2 value:
  - `0x12c02c0c=0x06e73dc0`, `0x12c03c0c=0x06e73dc0`
- Descriptor window remained constant in all phases:
  - `0x12c03000=0x000de37a`
  - `0x12c03004=0x00085f4d`
  - `0x12c03008=0x000b30b5`
  - `0x12c0300c=0x000f190a`
- End-state failure unchanged:
  - IRQ `64` increments, IRQ `66=0`
  - RX `0`, TX unchanged (`3715/10`, errors `9`).

## Interpretation

`0x12c02c0c/0x12c03c0c` behaves like a reinit-dependent base/pointer field, not
like a per-packet progress indicator. Traffic does not move this field, and
descriptor words in the sampled window remain static. This supports ending
runtime register pokes and focusing on kernel-side descriptor ownership/format
and DMA-path logic.
