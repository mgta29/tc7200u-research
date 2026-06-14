# TC7200U reverse notes: GMAC MBDMA FPM endpoint reinterpretation

## Summary
This note updates the reverse interpretation of fn_enet_gmac_mbdma_global_init after completing the DMA/FPM allocator, packet allocator, token allocation, token free, and cache helper analysis. The MBDMA global registers at 0x12c0004c, 0x12c00050, 0x12c00054, 0x12c00058, and 0x12c00008 are now strongly identified as FPM hardware token allocation/free endpoint addresses, not normal descriptor-ring bases.

## Repository context
The current Ethernet blocker is still GENET DMA/window/descriptor behavior: bcmgenet queues TX descriptors, TDMA stays enabled, but the hardware consumer index does not advance and packets do not pass. This reverse evidence supports continuing DMA address/window/FPM-token work instead of MDIO or switch wiring work.

## Function updated
Function: fn_enet_gmac_mbdma_global_init

Role: GMAC MBDMA global bridge setup between GENET/MBDMA and Broadcom FPM token hardware.

## Obsolete prior uncertainty
Older notes said the allocator wrapper outputs were not fully proven and that fn_dma_addr_alloc_wrapper_a / fn_dma_addr_alloc_wrapper_sized still needed analysis. That is now obsolete.

Completed proof chain:
- Board FPM init proves FPM HW base 0xb2200000 KSEG1 / 0x12200000 physical.
- fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate passes requested size and FPM base to runtime init.
- fn_dma_fpm_driver_hw_init_8009d0a0_candidate stores FPM base at main allocator +0x00 and creates backing memory, shift, and lookup table fields.
- fn_dma_fpm_alloc_token_for_size_candidate reads tokens from FPM_HW_BASE +0x200 + pool_class*8.
- fn_dma_free_token_to_fpm_candidate writes returned tokens to FPM_HW_BASE +0x200.
- fn_dma_addr_alloc_wrapper_sized(size,...) resolves to FPM_HW_BASE +0x200 + pool_class*8.

## Main DMA/FPM allocator object
Static main allocator object: 0x81848740.

Mapped fields used by MBDMA/FPM bridge:
- +0x00: FPM HW MMIO base, board value 0xb2200000, physical 0x12200000
- +0x0c: aligned DDR/FPM backing pool base from heap allocation
- +0x28: computed pool-size shift
- +0x2c: pool-class lookup table pointer
- +0x30: max/request limit
- +0x38..+0x44: pool size/default table
- +0x48 + token_index*4: token high bits / pool selector table

## MBDMA global register writes now interpreted
In fn_enet_gmac_mbdma_global_init:

GENET_MBDMA_GLOBAL_12c00010:
- value source: fn_dma_addr_alloc_wrapper_a(0,0,...)
- now interpreted as allocator +0x0c backing/FPM pool base masked with 0x1fffffff
- meaning: low 29-bit bus-visible FPM backing pool base

GENET_MBDMA_GLOBAL_12c0004c:
- value source: fn_dma_addr_alloc_wrapper_sized(0x100,...)
- expected value: 0x12200218
- meaning: FPM endpoint for 0x100-size allocation class, not descriptor ring base

GENET_MBDMA_GLOBAL_12c00050:
- value source: fn_dma_addr_alloc_wrapper_sized(0x200,...)
- expected value: 0x12200210
- meaning: FPM endpoint for 0x200-size allocation class, not descriptor ring base

GENET_MBDMA_GLOBAL_12c00054:
- value source: fn_dma_addr_alloc_wrapper_sized(0x400,...)
- expected value: 0x12200208
- meaning: FPM endpoint for 0x400-size allocation class, not descriptor ring base

GENET_MBDMA_GLOBAL_12c00058:
- value source: fn_dma_addr_alloc_wrapper_sized(0x800,...)
- expected value: 0x12200200
- meaning: FPM endpoint for 0x800-size/class0 allocation endpoint

GENET_MBDMA_GLOBAL_12c00008:
- value source: fn_dma_addr_alloc_wrapper_sized(0x800,...)
- expected value: 0x12200200
- meaning: same class0 endpoint; also matches FPM token free/deallocation register base offset +0x200

## FPM endpoint derivation
Board FPM HW base:
- KSEG1: 0xb2200000
- physical: 0x12200000

Endpoint formula:
- endpoint = FPM_HW_BASE + 0x200 + pool_class * 8

Expected physical endpoint values:
- pool class 0: 0x12200200
- pool class 1: 0x12200208
- pool class 2: 0x12200210
- pool class 3: 0x12200218

Expected size mapping from current table logic:
- size 0x100 -> pool class 3 -> 0x12200218
- size 0x200 -> pool class 2 -> 0x12200210
- size 0x400 -> pool class 1 -> 0x12200208
- size 0x800 -> pool class 0 -> 0x12200200

## Token allocation/free model
Allocation helper now proven:
- pool_index = (requested_size - 1) >> allocator_shift
- pool_class = lookup_table[pool_index]
- token = *(FPM_HW_BASE + 0x200 + pool_class*8)
- valid token requires bit31 set
- token high bits are saved to allocator +0x48 + token_index*4
- requested size low 12 bits are ORed into token

Free helper now proven:
- token must have bit31 set
- token_index = (token >> 12) & 0xffff
- backing buffer address = extra_offset + allocator +0x0c + token_index*0x100
- cache maintenance is done through fn_mips_dcache_range_op_8002a034_candidate
- token is written to FPM_HW_BASE +0x200

Token format:
- bit31: valid token marker
- bits28..29: high bits / pool selector
- bits12..27: token index
- bits0..11: requested allocation size low bits on allocation path

## MBDMA control writes still separate
The following are still control/config values, not FPM endpoint outputs:
- GENET_MBDMA_GLOBAL_CTRL_12c0000c: global control RMW; unaff_s3 likely decompiler artifact around first RMW
- GENET_MBDMA_TOKEN_CTRL_12c00004: forced to preserved upper bits plus 0x9010
- GENET_MBDMA_CHANNEL_WEIGHT_12c00044: 0x2020202
- GENET_MBDMA_CHANNEL_ENABLE_MASK_12c00048: 0xf
- GENET_MBDMA_STATUS_OR_INTR_12c00000: status/intr clear or ack source
- GENET_MBDMA_STATUS_ACK_OR_MASK_12c00040: status/mask written with status | 0xdea9

## Channel bank writes
The function selects core0 or core1 channel register bank based on g_enet_gmac_core_or_iface_index_81840024_candidate.

Core0 registers:
- TX ctrl: 0x12c00100
- TX base/size-like: 0x12c00104 = 0x13601c10
- RX ctrl: 0x12c00140
- RX base/size-like: 0x12c00144 = 0x13601c10

Core1 registers:
- TX ctrl: 0x12c00120
- TX base/size-like: 0x12c00124 = 0x13601c10
- RX ctrl: 0x12c00180
- RX base/size-like: 0x12c00184 = 0x13601c10

The constant 0x13601c10 remains unresolved. It is address-shaped and likely channel/window/base/size related, but current FPM endpoint evidence does not prove its exact role. Keep labels as BASE_OR_SIZE candidates until runtime evidence or xrefs prove the field.

## Suggested Ghidra plate comment update
Use this function-level summary in fn_enet_gmac_mbdma_global_init:

GMAC MBDMA global init bridges GENET/MBDMA to Broadcom FPM token hardware. The sized wrapper writes at 0x12c0004c..0x12c00058 and 0x12c00008 are FPM hardware token allocation/free endpoint addresses derived from FPM_HW_BASE +0x200 + pool_class*8, not normal descriptor ring bases. 0x12c00010 receives allocator +0x0c backing/FPM pool base masked to low 29-bit bus-visible form. The 0x13601c10 channel constant remains unresolved.

## Suggested EOL comments
GENET_MBDMA_GLOBAL_12c00010:
MBDMA receives allocator +0x0c backing/FPM pool base masked to low 29-bit bus address

GENET_MBDMA_GLOBAL_12c0004c:
MBDMA FPM endpoint for size 0x100: expected 0x12200218, not descriptor ring base

GENET_MBDMA_GLOBAL_12c00050:
MBDMA FPM endpoint for size 0x200: expected 0x12200210, not descriptor ring base

GENET_MBDMA_GLOBAL_12c00054:
MBDMA FPM endpoint for size 0x400: expected 0x12200208, not descriptor ring base

GENET_MBDMA_GLOBAL_12c00058:
MBDMA FPM endpoint for size 0x800: expected 0x12200200, class0 alloc/free endpoint

GENET_MBDMA_GLOBAL_12c00008:
MBDMA FPM endpoint for size 0x800: expected 0x12200200; same HW offset used for token free writes

0x13601c10 channel writes:
constant 0x13601c10; address-shaped, verify exact channel base/size/window role separately

## OpenWrt bring-up implication
The vendor path is not a plain upstream bcmgenet TDMA descriptor-only setup. It programs MBDMA global registers with FPM token hardware endpoints and FPM backing pool state. The OpenWrt failure mode where TDMA is enabled but consumer index does not advance may be caused by missing BCM3383-specific MBDMA/FPM endpoint programming, DMA window setup, or address/token representation expected by this SoC.

## Next targets
- Search/xref constant 0x13601c10 to determine whether it is channel base, descriptor window, packet memory, or size encoding.
- Compare OpenWrt bcmgenet TX descriptor buffer-address fields against vendor token/backing/FPM endpoint model.
- Inspect any runtime register dumps for 0x12c00008, 0x12c0004c..0x12c00058, and 0x12c00104/144/124/184 after OpenWrt init.
- Keep 0x12c0004c..58 and 0x12c00008 annotated as FPM endpoint registers unless contradicted by hardware evidence.
