# 2026-05-19 - inbound 192.168.77.x test: no RX, irq64-only activity

## Setup

- OpenWrt: `192.168.77.1/24` on `eth0`
- Laptop: `192.168.77.2` (expected ping source)
- OpenWrt loop sampled once per second:
  - `ip -s link show dev eth0` RX/TX counters
  - `/proc/interrupts` lines for hwirq `64` and `66`

## Observed

- RX remained zero for the entire observation window.
- TX stayed flat during the loop (`11495 bytes`, `113 packets`, `8 errors`).
- hwirq `64` continued to increment steadily.
- hwirq `66` remained zero.

## Interpretation

Even with correct L3 addressing and interface up, there is no observable RX
path activity. The interrupt pattern remains one-sided (`64` only) and does not
correlate with packet receive completion.

This further supports moving from runtime pokes to kernel-side GENET DMA /
descriptor-path changes.
