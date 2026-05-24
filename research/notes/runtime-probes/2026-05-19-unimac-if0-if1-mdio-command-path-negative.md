# 2026-05-19 - UNIMAC IF0/IF1 MDIO command path negative

## Summary

Additional runtime probes were run on the two UNIMAC interface windows:

- IF0 base: `0x12c00600`
- IF1 base: `0x12c02600`

The goal was to verify whether either interface exposes a usable upstream-style
`UMAC_MDIO_CMD` command engine.

## Result

Identity and core state:

- `0x12c00000 = 0x000012aa`
- `0x12c00004 = 0x000001ff`
- `0x12c00600 = 0x00000c01`
- `0x12c02600 = 0x00000c01`
- `0x12c00814 = 0x000005ee`
- `0x12c02814 = 0x00000000`

Config latching:

- IF0 config (`0x12c00618`) is writable and latches test values.
- IF1 config (`0x12c02618`) is writable and latches test values.
- The two config registers are independent (not mirrored):
  - IF0 held `0x000001a1` while IF1 held `0x000002b1`.

Command behavior:

- IF0 command writes retain only partial bits and remain in a busy-like state:
  - `0x28000000 -> 0x28000000`
  - `0x28010000 -> 0x28010000`
  - `0x28020000` and `0x28030000` paths did not yield data/status movement.
- IF1 command write `0x28020000` read back as `0x28000000`.
- Nearby status/data candidates did not change:
  - IF0 `+0x10=0x000005ee`, `+0x14=0x00000000`, `+0x1c=0x00000000`
  - IF1 `+0x10=0x000005ee`, `+0x14=0x00000000`, `+0x1c=0x00000000`

Ring/IRQ state remained the same:

- `0x12c03800=0x00010003`
- `0x12c03804=0x00000028`
- `0x12c03808=0x00010000`
- `0x12c0380c=0x00000000`
- `0x12c03c40=0x00000001`
- `0x12c03c44=0x00000001`
- `0x12c03c48=0x00000001`
- `/proc/interrupts`: hwirq `64` increments; hwirq `66` stays `0`.

## Interpretation

Neither IF0 nor IF1 behaves like a working upstream `mdio-bcm-unimac`
command/data path on this target.

The MDIO reverse-engineering branch should be treated as exhausted for now.
Further progress is more likely in kernel-side TDMA/ring setup changes than in
additional raw MDIO command pokes.

## Next action

Use a kernel-side test branch:

- keep current V1 offsets
- set `GENET_V1` `words_per_bd` from `2` to `3` (temporary test)
- boot and check whether TDMA consumer/ring movement changes from the known
  stuck signature.
