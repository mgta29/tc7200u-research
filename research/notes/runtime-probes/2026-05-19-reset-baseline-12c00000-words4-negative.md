# 2026-05-19 - reset baseline at 0x12c00000 after bad 0x12c02600 branch (negative)

## Context

A prior test image incorrectly moved the GENET instance to `0x12c02600`, which
produced clearly invalid register interpretations and unusable TX state.

This run restores a clean baseline boot where the driver binds again at:

- `bcmgenet 12c00000.ethernet`

## Key readback

- `0x12c00000 = 0x000012aa`
- `0x12c00004 = 0x00000003`
- `0x12c02600 = 0x00000c01`
- `0x12c02604 = 0x00000000`

After `eth0 up`, `192.168.77.1/24`, and ping to `192.168.77.2`:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000014`
- `0x12c03808 = 0x010000d8`
- `0x12c0380c = 0x00000000`
- `0x12c03c40 = 0x00010000`
- `0x12c03c44 = 0x00020001`
- `0x12c03c48 = 0x00000000`

Counters/interrupts:

- `ip -s link` showed RX `0`, TX `0`, TX errors `18`
- `/proc/interrupts`: hwirq `64` increments, hwirq `66` remains `0`

## Interpretation

The reset baseline is valid again (`12c00000` binding), but packet flow is
still broken. This run is negative for the current descriptor-width variant.

The earlier full-base remap to `0x12c02600` should remain discarded.

## Next step

Stop full-base remap attempts. Move to a split-map kernel branch:

- keep DMA/ring/global accesses on `0x12c00000`
- test selected UMAC path accesses through a separate window (`0x12c02600`)
  only where needed.
