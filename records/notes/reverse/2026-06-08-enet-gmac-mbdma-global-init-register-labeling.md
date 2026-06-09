# 2026-06-08 ENET/GMAC/MBDMA global init and Ghidra register-labeling repair

## Scope

This note records the current reverse-engineering findings for the TC7200.U / BCM3383 ENET/GMAC/MBDMA path. This is additive evidence only. Do not delete or overwrite old logs/notes.

## Current high-value function

Function analyzed:

- `fn_enet_gmac_mbdma_global_init`

Classification:

- Direct GENET/GMAC/MBDMA register initialization.
- Highly relevant to the current OpenWrt TDMA/MBDMA blocker.
- This function writes the `0xb2c000xx` KSEG1/uncached register view, corresponding to the hardware/register region normally discussed as `0x12c000xx`.

## Important address convention

Ghidra decompiler/listing shows:

- `0xb2c00000` style names, e.g. `Ramb2c00004`, `DAT_b2c00120`.

For notes and hardware comparison, treat these as uncached/register aliases for:

- `0x12c00000` hardware/register region.

Example:

- Ghidra address `0xb2c00004` = hardware/register `0x12c00004`.

## MBDMA-visible address setup

The function calls DMA address/allocation wrappers and masks returned values with `0x1fffffff` before writing them to MBDMA global registers.

Observed sequence:

- `fn_dma_addr_alloc_wrapper_a(0,0,...)` -> masked with `0x1fffffff` -> `GENET_MBDMA_GLOBAL_12c00010`.
- `fn_dma_addr_alloc_wrapper_sized(0x100,0,...)` -> masked -> `GENET_MBDMA_GLOBAL_12c0004c`.
- `fn_dma_addr_alloc_wrapper_sized(0x200,0,...)` -> masked -> `GENET_MBDMA_GLOBAL_12c00050`.
- `fn_dma_addr_alloc_wrapper_sized(0x400,0,...)` -> masked -> `GENET_MBDMA_GLOBAL_12c00054`.
- `fn_dma_addr_alloc_wrapper_sized(0x800,0,...)` -> masked -> `GENET_MBDMA_GLOBAL_12c00058`.
- `fn_dma_addr_alloc_wrapper_sized(0x800,0,...)` -> masked -> `GENET_MBDMA_GLOBAL_12c00008`.

Interpretation:

- The `& 0x1fffffff` mask strips CPU/KSEG-style upper bits and leaves MBDMA-visible physical-ish addresses.
- Earlier note still applies: `fn_dma_addr_alloc_core` was observed to return a static allocator/control object base around `0x81848740`; wrapper output must be analyzed before calling these direct descriptor/data-buffer bases.

## Global MBDMA control

Observed:

- `GENET_MBDMA_GLOBAL_CTRL_12c0000c = unaff_s3 | 0x800000`.
- Then `GENET_MBDMA_GLOBAL_CTRL_12c0000c = (old & 0xff7ff000) | 0xc41`.

Important caution:

- `unaff_s3` is still an unresolved preserved-register/decompiler artifact.
- Do not treat `unaff_s3` as a normal a0-a3 argument.
- The second write forces low bits to include `0xc41` while preserving selected high/mid bits from the previous value.

## Token control and common channel setup

Observed:

- `Ramb2c00004 = (old & 0xffffe000) | 0x9010`.
- `Ramb2c00044 = 0x02020202`.
- `Ramb2c00048 = 0x0000000f`.

Suggested labels:

- `Ramb2c00004` -> `GENET_MBDMA_TOKEN_CTRL_12c00004_candidate`.
- `Ramb2c00044` -> `GENET_MBDMA_CHANNEL_WEIGHT_12c00044_candidate`.
- `Ramb2c00048` -> `GENET_MBDMA_CHANNEL_ENABLE_MASK_12c00048_candidate`.

These are likely important comparison points against OpenWrt because TDMA/MBDMA descriptor consumption is currently blocked.

## Core/interface 0 channel programming

When `g_enet_gmac_core_or_iface_index_81840024_candidate == 0`, function programs:

- `Ramb2c00100` with multiple mask/OR steps:
  - set `0x04000000` using `old & 0xe00fffff | 0x4000000`.
  - clear field with `old & 0xfffc0fff`.
  - clear field with `old & 0xfffff0ff`.
  - set low bits with `old & 0xfffffff8 | 5`.
- `Ramb2c00104 = 0x13601c10`.
- `Ramb2c00140` with multiple mask/OR steps:
  - set `0x04000000`.
  - set `0x200` using `old & 0xffffc0ff | 0x200`.
  - clear field with `old & 0xffffff0f`.
  - set low bits with `old & 0xfffffff0 | 4`.
  - set low bits with `old & 0xfffffff8 | 5`.
- `Ramb2c00144 = 0x13601c10`.

Suggested labels:

- `Ramb2c00100` -> `GENET_MBDMA_CORE0_TX_CH0_CTRL_12c00100_candidate`.
- `Ramb2c00104` -> `GENET_MBDMA_CORE0_TX_CH0_BASE_OR_SIZE_12c00104_candidate`.
- `Ramb2c00140` -> `GENET_MBDMA_CORE0_RX_CH0_CTRL_12c00140_candidate`.
- `Ramb2c00144` -> `GENET_MBDMA_CORE0_RX_CH0_BASE_OR_SIZE_12c00144_candidate`.

Keep `_candidate` because exact TX/RX direction and field names still need confirmation.

## Core/interface nonzero channel programming

When `g_enet_gmac_core_or_iface_index_81840024_candidate != 0`, function programs:

- `DAT_b2c00120` with the same pattern as `Ramb2c00100`.
- `DAT_b2c00124 = 0x13601c10`.
- `DAT_b2c00180` with the same pattern as `Ramb2c00140`.
- `DAT_b2c00184 = 0x13601c10`.

Suggested labels:

- `DAT_b2c00120` -> `GENET_MBDMA_CORE1_TX_CH0_CTRL_12c00120_candidate`.
- `DAT_b2c00124` -> `GENET_MBDMA_CORE1_TX_CH0_BASE_OR_SIZE_12c00124_candidate`.
- `DAT_b2c00180` -> `GENET_MBDMA_CORE1_RX_CH0_CTRL_12c00180_candidate`.
- `DAT_b2c00184` -> `GENET_MBDMA_CORE1_RX_CH0_BASE_OR_SIZE_12c00184_candidate`.

## Status / interrupt / ack setup

Observed:

- `DAT_b2c00000 = 0xffffffff`.
- `DAT_b2c00040 = DAT_b2c00000 | 0xdea9`.

Because `DAT_b2c00000` is first written as `0xffffffff`, the decompiled expression implies `DAT_b2c00040` receives `0xffffffff`, unless readback has side effects.

Suggested labels:

- `DAT_b2c00000` -> `GENET_MBDMA_STATUS_OR_INTR_12c00000_candidate`.
- `DAT_b2c00040` -> `GENET_MBDMA_STATUS_ACK_OR_MASK_12c00040_candidate`.

## Ghidra repair / labeling workflow learned

Problem observed:

- `Ramb2c00004`, `Ramb2c00044`, `Ramb2c00048`, `Ramb2c00100`, etc. appeared red in the decompiler.
- Creating a new memory block failed because block already existed: conflict `[b2c00000, b2c001ff]`.

Conclusion:

- The register block already exists as `GENET_MMIO_KSEG1` covering `ram:b2c00000-ram:b2c02fff`.
- Do not add another block.
- The issue is that individual register addresses are raw bytes or not yet defined/labeled.

Correct workflow:

1. Go to the existing address, e.g. `ram:0xb2c00004` or `0xb2c00004`.
2. If the address shows `??`, define it as a DWORD / `undefined4` first.
3. Then press `L` and apply the final label.
4. Repeat for each register.

Example performed:

- At `0xb2c00004`, raw bytes were converted to `ddw` / DWORD.
- Next action is to press `L` on `0xb2c00004` and label it `GENET_MBDMA_TOKEN_CTRL_12c00004_candidate`.

## Current Ghidra register labeling todo

Define DWORD if needed, then label:

- `0xb2c00004` -> `GENET_MBDMA_TOKEN_CTRL_12c00004_candidate`.
- `0xb2c00044` -> `GENET_MBDMA_CHANNEL_WEIGHT_12c00044_candidate`.
- `0xb2c00048` -> `GENET_MBDMA_CHANNEL_ENABLE_MASK_12c00048_candidate`.
- `0xb2c00100` -> `GENET_MBDMA_CORE0_TX_CH0_CTRL_12c00100_candidate`.
- `0xb2c00104` -> `GENET_MBDMA_CORE0_TX_CH0_BASE_OR_SIZE_12c00104_candidate`.
- `0xb2c00140` -> `GENET_MBDMA_CORE0_RX_CH0_CTRL_12c00140_candidate`.
- `0xb2c00144` -> `GENET_MBDMA_CORE0_RX_CH0_BASE_OR_SIZE_12c00144_candidate`.
- `0xb2c00120` -> `GENET_MBDMA_CORE1_TX_CH0_CTRL_12c00120_candidate`.
- `0xb2c00124` -> `GENET_MBDMA_CORE1_TX_CH0_BASE_OR_SIZE_12c00124_candidate`.
- `0xb2c00180` -> `GENET_MBDMA_CORE1_RX_CH0_CTRL_12c00180_candidate`.
- `0xb2c00184` -> `GENET_MBDMA_CORE1_RX_CH0_BASE_OR_SIZE_12c00184_candidate`.
- `0xb2c00000` -> already labeled `GENET_MBDMA_STATUS_OR_INTR_12c00000_candidate`.
- `0xb2c00040` -> `GENET_MBDMA_STATUS_ACK_OR_MASK_12c00040_candidate`.

## Why this matters for OpenWrt

The current OpenWrt bring-up problem is that the MAC can probe and link can appear, but TX/RX descriptor consumption remains broken. This vendor function provides concrete MBDMA setup values and register order for the `0x12c00000` region. The following values are especially important to compare against OpenWrt runtime devmem traces:

- `0x12c00004 = (old & 0xffffe000) | 0x9010` token control.
- `0x12c00044 = 0x02020202` channel weights.
- `0x12c00048 = 0x0000000f` channel enable mask.
- `0x12c00100/120` TX-like channel control paths.
- `0x12c00140/180` RX-like channel control paths.
- `0x12c00104/124/144/184 = 0x13601c10`.
- `0x12c0000c` final low field `0xc41` with preserved high/mid bits.

## Next reverse targets

1. `fn_dma_addr_alloc_wrapper_a`.
2. `fn_dma_addr_alloc_wrapper_sized`.
3. Underlying allocator/core helper behind those wrappers.
4. Continue labeling `0xb2c000xx` registers as DWORD + label.
5. Compare this vendor MBDMA init sequence to OpenWrt register dumps around `0x12c00000`, `0x12c00004`, `0x12c00008`, `0x12c0000c`, `0x12c00010`, `0x12c00040`, `0x12c00044`, `0x12c00048`, `0x12c00100`, `0x12c00140`, and corresponding core1 offsets.
