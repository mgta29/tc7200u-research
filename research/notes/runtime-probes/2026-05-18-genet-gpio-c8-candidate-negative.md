# GENET GPIO C8 candidate write negative

Date: 2026-05-18

## Context

The vendor-disabled BCM3383 GMAC init block contains GPIO/pinmux-style writes
around `0x14e001c4` and `0x14e001c8`. This test changed only the C8 candidate
state, then replayed ring0.

## Test

Baseline:

- `0x14e001c4 = 0xda492010`
- `0x14e001c8 = 0x00824936`
- `0x12000238 = 0x00000132`
- `0x120005a0 = 0x005f2faa`
- TX MIB counters were reset and read as `0x00000001`.

Write:

- `0x14e001c8 = 0x04824936`
- Readback confirmed `0x04824936`.

Ring0 replay used the canonical compact status-first descriptor:

- `0x12c03000 = 0x000e009a`
- `0x12c03004 = 0x00080000`
- `0x12c03008 = 0x00000000`
- `0x12c0300c = 0x00000000`

The test restored `0x14e001c8` to `0x00824936` after the replay.

## Result

After replay:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000000`
- `0x12c03808 = 0x00000001`
- `0x12c03820 = 0x00000000`
- `0x12c03c48 = 0x00000000`
- TX MIB counters stayed unchanged at `0x00000001`.

## Conclusion

The isolated GPIO C8 vendor candidate write does not make ring0 retire
descriptors or transmit. Keep it classified as negative when tested alone.

The next narrow branch is to apply all non-clock, non-parent-interrupt vendor
GMAC init candidates together, then restore them.
