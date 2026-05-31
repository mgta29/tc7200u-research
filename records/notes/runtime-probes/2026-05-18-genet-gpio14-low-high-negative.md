# GENET GPIO14 low/high comparison negative

Date: 2026-05-18

## Context

A previous single GPIO14-high replay showed ring0 consumer movement to
`0x00000028`, but no TX MIB increment. This run compared GPIO14 low and high in
the same boot with the same ring reset and replay sequence.

## Baseline

Initial GPIO state:

- `GPIO_PER_DIR_LO = 0x00004000`
- `GPIO_PER_DATA_LO = 0x00000000`

GPIO14 was already configured as output and low.

## Low Pass

GPIO14 was forced low:

- `GPIO_PER_DIR_LO = 0x00004000`
- `GPIO_PER_DATA_LO = 0x00000000`

After ring0 replay:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000000`
- `0x12c03808 = 0x00000001`
- `0x12c03820 = 0x00000000`
- TX MIB counters stayed `0x00000001`.

## High Pass

GPIO14 was forced high:

- `GPIO_PER_DIR_LO = 0x00004000`
- `GPIO_PER_DATA_LO = 0x00004000`

After the same ring0 reset and replay:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000000`
- `0x12c03808 = 0x00000001`
- `0x12c03820 = 0x00000000`
- TX MIB counters stayed `0x00000001`.

The test restored GPIO14 low.

## Conclusion

GPIO14-high alone did not reproduce the earlier consumer movement and did not
make TDMA retire descriptors or increment TX MIB counters. Treat the earlier
`cons=0x00000028` observation as stale or unstable until reproduced.

The next branch is to keep GPIO14 high while applying the remaining safe
vendor-side GMAC writes together, excluding broad clock writes, parent interrupt
mask writes, and UART-area writes.
