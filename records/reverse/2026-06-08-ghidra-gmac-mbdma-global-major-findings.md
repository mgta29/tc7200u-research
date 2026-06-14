# Ghidra GMAC MBDMA global major findings

## Major find

`FUN_803a8790 @ 803a8790` is confirmed as GMAC MBDMA global setup. Rename suggestion: `fn_enet_gmac_mbdma_global_init`.

Evidence string: `GMAC_MBDMA_Global: 0x%x`.

## GENET/MBDMA registers written

The function writes KSEG1 GENET registers in the `0xb2c00000` window, physical `0x12c00000` range:

- `b2c00008 -> phys 12c00008`
- `b2c0000c -> phys 12c0000c`
- `b2c00010 -> phys 12c00010`
- `b2c0004c -> phys 12c0004c`
- `b2c00050 -> phys 12c00050`
- `b2c00054 -> phys 12c00054`
- `b2c00058 -> phys 12c00058`

Recommended conservative Ghidra labels:

- `GENET_MBDMA_GLOBAL_12c00008`
- `GENET_MBDMA_GLOBAL_CTRL_12c0000c`
- `GENET_MBDMA_GLOBAL_12c00010`
- `GENET_MBDMA_GLOBAL_12c0004c`
- `GENET_MBDMA_GLOBAL_12c00050`
- `GENET_MBDMA_GLOBAL_12c00054`
- `GENET_MBDMA_GLOBAL_12c00058`

## Behavior

The function writes DMA-visible physical addresses masked with `0x1fffffff`:

- `Ramb2c00010 = FUN_8009f6e8(...) & 0x1fffffff`
- `Ramb2c0004c = FUN_8009f83c(0x100, ...) & 0x1fffffff`
- `Ramb2c00050 = FUN_8009f83c(0x200, ...) & 0x1fffffff`
- `Ramb2c00054 = FUN_8009f83c(0x400, ...) & 0x1fffffff`
- `Ramb2c00058 = FUN_8009f83c(0x800, ...) & 0x1fffffff`
- `Ramb2c00008 = FUN_8009f83c(0x800, ...) & 0x1fffffff`

The `0x1fffffff` mask strips MIPS cached/uncached high bits and leaves a physical/bus address.

The control register at `b2c0000c / phys 12c0000c` is then configured:

- sets `0x800000` first from `unaff_s3 | 0x800000`
- later applies `(old & 0xff7ff000) | 0x0c41`
- this clears bit `0x00800000`, clears low `0xfff`, and sets low bits `0x0c41`

## Relevance

This is directly relevant to the OpenWrt GMAC DMA/RX/TX blocker. It identifies a non-MDIO GENET MBDMA global init path and several DMA/global registers in the `0x12c00000` GENET window.

## Search context

Found via Ghidra Scalar Search for decimal `45760`, hex `0xb2c0`, which finds `lui ...,0xb2c0` GENET KSEG1 address construction. Search showed 24 hits. Known MDIO and `GENET_REG_12c00070` hits were filtered out; `803a8790` was the first new high-value GENET/MBDMA hit.

## Next targets

Follow helper functions used by `fn_enet_gmac_mbdma_global_init`:

- `8009f6e8`
- `8009f83c`

Also continue scalar hits after known MDIO hits:

- `80c7c8a0`
- `80c7c8e0`
- `80c7c904`
- `80c7c91c`
- `80c7cebc`
- `80c7cec8`
- `80c8970c`
- `80c89748`
- `80c89760`
- `80c89d00`
- `80c89d0c`

## Preservation

Created as a new timestamped reverse note. No old logs or records were deleted.
