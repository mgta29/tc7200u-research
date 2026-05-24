# 2026-05-19 - `0x12c02c0c/0x12c03c0c` pointer is not descriptor-window alias

## Setup

- OpenWrt `eth0`: `192.168.77.1/24`
- Test traffic: `ping -c 3 -W 1 192.168.77.2`
- Captured:
  - `P0=devmem(0x12c02c0c)`, `P1=devmem(0x12c03c0c)`
  - descriptor window `0x12c03000..0x12c0300c`
  - `devmem` dereference at `P0`, `P0+4`, `P0+8`, `P0+12`
  - IRQ and link stats.

## Observed

- `P0=0x06e76d40`
- `P1=0x06e76d40` (same value from both windows)
- Descriptor window remained:
  - `0x12c03000=0x000de37a`
  - `0x12c03004=0x00085f4d`
  - `0x12c03008=0x000b30b5`
  - `0x12c0300c=0x000f190a`
- Dereferencing `P0` did **not** match descriptor words:
  - `devmem 0x06e76d40 = 0xffffffff`
  - `devmem 0x06e76d44 = 0xfffdffff`
  - `devmem 0x06e76d48 = 0xffffffff`
  - `devmem 0x06e76d4c = 0xffffffff`
- IRQ/stats unchanged failure pattern:
  - hwirq `64` increments, hwirq `66=0`
  - RX `0`, TX errors present.

## Interpretation

`0x12c02c0c`/`0x12c03c0c` should not be treated as a CPU-readable alias of the
descriptor window at `0x12c03000`. It behaves like a pointer/bus address field
that does not resolve to valid CPU-visible memory through direct `devmem`.
The stuck data-path diagnosis remains unchanged.
