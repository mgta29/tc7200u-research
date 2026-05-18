# 2026-05-18 - GENET mdio@600 divider bits do not latch

## Context

The first `mdio@600` raw probe showed a live register window, but MDIO reads
stayed busy. This follow-up tried to program a nonzero MDIO clock divider and
use the two-step command/start sequence from the upstream UniMAC MDIO driver.

## Result

Attempted config:

```text
write 0x12c00604 = 0x000013f1
read  0x12c00604 = 0x00000001
```

Only clause-22 bit 0 latched. The divider and preamble-support bits did not.

Two-step PHY0 reg2 read:

```text
write 0x12c00600 = 0x08020000
read  0x12c00600 = 0x08000000
write 0x12c00600 = 0x28020000
read  0x12c00600 = 0x28000000
read  0x12c00600 = 0x28000000
```

The register-address bits were not retained, and the busy/start bit remained
set after two seconds.

## Interpretation

`0x12c00600` and `0x12c00604` are live, but this block is not behaving like the
upstream `mdio-bcm-unimac` `MDIO_CMD`/`MDIO_CFG` layout. The BCM3384 header
names `0x12c00600..0x12c00710` as `UNIMAC_INTERFACE0`, not a standalone MDIO
controller.

Do not keep writing assumed UniMAC MDIO command words into this window until the
interface register layout is mapped.

## Next direction

Dump the whole `UNIMAC_INTERFACE0` range in three states:

- `eth0` down, GPIO14 low/restored
- `eth0` up
- `eth0` down with GPIO14 high

Compare which offsets change. The correct MDIO command/config registers, if
present in this block, should show recognizable state transitions instead of
silently dropping divider and register-address bits.
