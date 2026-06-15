# GENET GMAC 0x12000238 candidate write negative

Date: 2026-05-18

## Context

The vendor-disabled BCM3383 GMAC init block contains candidate writes to
`0x12000238` and `0x120005a0`. This test changed only `0x12000238`, leaving
`0x120005a0` untouched, then replayed ring0.

## Test

Baseline:

- `0x12000238 = 0x00000132`
- `0x120005a0 = 0x005f2faa`
- TX MIB counters were reset and read as `0x00000001`.

Write:

- `0x12000238 = 0x00000170`
- Readback confirmed `0x00000170`.

Ring0 replay used the canonical compact status-first descriptor:

- `0x12c03000 = 0x000e009a`
- `0x12c03004 = 0x00080000`
- `0x12c03008 = 0x00000000`
- `0x12c0300c = 0x00000000`

The test restored `0x12000238` to `0x00000132` after the replay.

## Result

After replay:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000000`
- `0x12c03808 = 0x00000001`
- `0x12c03820 = 0x00000000`
- `0x12c03c48 = 0x00000000`
- TX MIB counters stayed unchanged at `0x00000001`.

## Conclusion

The isolated vendor candidate write `0x12000238=0x170` does not make ring0
retire descriptors or transmit. Keep it classified as negative when tested
alone.

The next narrow branch is the sibling vendor candidate `0x120005a0=0x000fffff`,
tested alone and restored afterward.
