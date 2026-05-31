# GENET GPIO14 high ring0 partial movement

Date: 2026-05-18

## Context

The OEM firmware log says `Powering UP switch. PIN = 14`. Local BCM3384 headers
identify GPIO14 as bit `0x00004000` in:

- `0x14e00100` (`GPIO_PER_DIR_LO`)
- `0x14e0012c` (`GPIO_PER_DATA_LO`)

This probe forced GPIO14 high, then replayed the canonical ring0 descriptor.

## Baseline

Before the write:

- `GPIO_PER_DIR_LO = 0x00004000`
- `GPIO_PER_DATA_LO = 0x00000000`

GPIO14 was already configured as an output, but its data bit was low.

TX MIB counters were reset with `0x12c00580=7` then `0`, and read as
`0x00000001`.

## Write

The test wrote:

- `GPIO_PER_DATA_LO = 0x00004000`
- `GPIO_PER_DIR_LO = 0x00004000`

Readback confirmed both as `0x00004000`.

## Ring0 replay

Ring0 was reset and replayed with:

- `0x12c03800 = 0x00000000`
- `0x12c03804 = 0x00000000`
- `0x12c03808 = 0x00000000`
- `0x12c0380c = 0x01000800`
- `0x12c03810 = 0x00000000`
- `0x12c03814 = 0x000002ff`
- `0x12c03818 = 0x00000001`
- `0x12c0381c = 0x00000000`
- `0x12c03820 = 0x00000000`
- `0x12c03000 = 0x000e009a`
- `0x12c03004 = 0x00080000`
- `0x12c03008 = 0x00000000`
- `0x12c0300c = 0x00000000`
- `0x12c03c40 = 0x00000001`
- `0x12c03c44 = 0x00000003`
- `0x12c03808 = 0x00000001`

## Result

After replay:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000028`
- `0x12c03808 = 0x00000001`
- `0x12c03820 = 0x00000000`
- `0x12c03c48 = 0x00000000`
- TX MIB counters stayed at `0x00000001`.

The test restored:

- `GPIO_PER_DATA_LO = 0x00000000`
- `GPIO_PER_DIR_LO = 0x00004000`

## Conclusion

Forcing GPIO14 high changed ring0 state compared with the latest controlled
low-result runs: consumer moved to `0x28`. This is a partial signal, not a
working transmit path, because TX MIB counters did not increment and the write
pointer stayed zero.

The next probe should compare GPIO14 low and high in one boot with identical
ring reset/replay steps, to verify that `cons=0x28` is caused by GPIO14 high.
