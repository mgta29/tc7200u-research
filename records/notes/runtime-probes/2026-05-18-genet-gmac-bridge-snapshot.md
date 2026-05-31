# GENET GMAC and bridge snapshot

Date: 2026-05-18

## Context

After descriptor word-order and RBUF/TBUF tests failed, this snapshot compared
candidate GMAC clock/reset, GPIO, GENET bridge, and EXT registers with `eth0`
down and after fixed-link GENET link-up.

The test was intentionally read-only apart from `ip link set eth0 up/down`.

## Result

GMAC and platform registers were stable across link down/up:

- `ClkCtrlLow` at `0x14e00004`: `0x960f6fc3`
- `ClkCtrlHigh` at `0x14e00008`: `0xfffff9ff`
- `ClkCtrlUBus` at `0x14e0000c`: `0xffffffff`
- `SoftResetBHigh` at `0x14e00090`: `0x00000020`
- `GPIO 0x14e001c4`: `0xda492010`
- `GPIO 0x14e001c8`: `0x00824936`
- `0x12000238`: `0x00000132`
- `0x120005a0`: `0x005f2faa`

GENET bridge registers were also unchanged:

- `0x12c00040 = 0x00000000`
- `0x12c00044 = 0x04040404`
- `0x12c00048 = 0x00000000`
- `0x12c0004c = 0x00000000`
- `0x12c00050 = 0x00000000`
- `0x12c00054 = 0x00000000`
- `0x12c00058 = 0x00000000`
- `0x12c0005c = 0x80402010`

Sampled EXT registers were unchanged:

- `0x12c00080 = 0x00000001`
- `0x12c0008c = 0x00000001`
- `0x12c00090 = 0x00000001`
- `0x12c0009c = 0x00000001`

Interrupts:

- hwirq `64` counted (`7213` at snapshot time).
- hwirq `66` remained `0`.

## Conclusion

GENET fixed-link up does not change the sampled GMAC clock/reset, GPIO,
bridge, or EXT state. The bridge block has nonzero defaults, but no link-up
transition points at an automatic DMA window setup.

The next useful branch is a controlled replay of the vendor-disabled GMAC init
candidate bits from the `#if 0` block, one narrow write set at a time, then the
same ring0/MIB replay. Start with candidate GMAC registers `0x12000238` and
`0x120005a0`, because they are local to the GMAC/GENET candidate block and do
not touch the parent interrupt mask.
