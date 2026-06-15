# GENET safe vendor combined write negative

Date: 2026-05-18

## Context

This branch kept GPIO14 high and applied the remaining safe vendor-side GMAC
initialization writes together. It excluded the broad clock writes, parent
interrupt-mask write, and UART-area write.

## Writes

Confirmed readback:

- `GPIO_PER_DIR_LO = 0x00004000`
- `GPIO_PER_DATA_LO = 0x00004000`
- `0x14e001c4 = 0xda49201a`
- `0x14e001c8 = 0x04824936`
- `0x12000238 = 0x00000170`
- `0x120005a0 = 0x000fffff`

## Ring0 result

After the canonical ring0 replay:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000000`
- `0x12c03808 = 0x00000001`
- `0x12c03820 = 0x00000000`
- `0x12c03c48 = 0x00000000`

TX MIB post-read capture was interrupted, but the first two counters were
unchanged:

- `0x12c004a8 = 0x00000001`
- `0x12c004e8 = 0x00000001`

## Conclusion

The safe combined vendor-side writes did not make TDMA retire the descriptor or
produce a visible TX MIB increment. Stop manual descriptor replay for now.

The next branch is MDIO/B53 visibility with GPIO14 high, using Linux MDIO sysfs
first and raw UniMAC MDIO reads second.
