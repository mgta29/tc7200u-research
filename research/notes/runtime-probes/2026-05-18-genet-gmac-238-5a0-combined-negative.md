# GENET GMAC 0x12000238 and 0x120005a0 combined negative

Date: 2026-05-18

## Context

The isolated vendor-disabled BCM3383 GMAC candidate writes
`0x12000238=0x00000170` and `0x120005a0=0x000fffff` both failed separately.
This test applied both writes together, then replayed ring0.

## Test

Baseline:

- `0x12000238 = 0x00000132`
- `0x120005a0 = 0x005f2faa`
- TX MIB counters were reset and read as `0x00000001`.

Writes:

- `0x12000238 = 0x00000170`
- `0x120005a0 = 0x000fffff`
- Readback confirmed both values.

Ring0 replay used the canonical compact status-first descriptor:

- `0x12c03000 = 0x000e009a`
- `0x12c03004 = 0x00080000`
- `0x12c03008 = 0x00000000`
- `0x12c0300c = 0x00000000`

The test restored both registers afterward:

- `0x12000238 = 0x00000132`
- `0x120005a0 = 0x005f2faa`

## Result

After replay:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000000`
- `0x12c03808 = 0x00000001`
- `0x12c03820 = 0x00000000`
- `0x12c03c48 = 0x00000000`
- TX MIB counters stayed unchanged at `0x00000001`.

## Conclusion

Applying both local GMAC candidate writes together does not make ring0 retire
descriptors or transmit. The branch is negative.

The remaining vendor-disabled GMAC init candidates are GPIO/pinmux-style writes
at `0x14e001c4` and `0x14e001c8`, plus broader clock/reset and interrupt-mask
writes. Keep testing narrow and avoid parent interrupt-mask writes.
