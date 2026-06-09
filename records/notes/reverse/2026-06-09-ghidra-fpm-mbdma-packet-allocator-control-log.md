# TC7200U Ghidra FPM/MBDMA/packet allocator control log

## Scope

Detailed reverse log for the current Ghidra pass covering ENET/GMAC step2, MBDMA global init, FPM hardware init, FPM snapshot/dump path, and secondary packet allocator object work.

## Ghidra labeling/state

- GENET/MBDMA MMIO labels were added for the 0xb2c0xxxx KSEG1 register block.
- FPM MMIO labels were added for the 0xb220xxxx KSEG1 register block.
- Main DMA/FPM allocator struct was applied at 0x81848740 as tc7200_fpm_allocator.
- Secondary packet allocator struct target is 0x8187bc70 as tc7200_fpm_packet_allocator.
- A direct references query for FPM_PACKET_ALLOC_OBJECT_8187bc70 returned 0 locations. This is not proof that the object is unused; code reaches it through lazy getter/init functions and pointer/register flows rather than absolute references to the data label.

## Corrected GENET mode/control register 0x12c00070

Function: fn_enet_gmac_init_step2_core_cmd_bits_candidate

Confirmed behavior:
- OEM KSEG1 register: 0xb2c00070
- Physical register: 0x12c00070
- Gated by _DAT_8184006c > 0xaf
- core/interface 0 sets 0x00000001 then 0x00000002, effective mask 0x00000003
- nonzero core/interface sets 0x00010000 then 0x00020000, effective mask 0x00030000
- previous 0x00003000 interpretation is superseded by 0x00030000 unless another confirmed writer is found

Disable helper: fn_enet_gmac_disable_step2
- param_1 == 0 clears low pair 0x00000003
- param_1 != 0 clears high pair 0x00030000
- main wrapper passes (g_enet_gmac_core_or_iface_index == 0), so it enables selected core bits and clears the opposite core bit-pair

## MBDMA global init

Function: fn_enet_gmac_mbdma_global_init

Confirmed behavior:
- Uses main DMA/FPM allocator object through fn_dma_addr_alloc_wrapper_a() and fn_dma_addr_alloc_wrapper_sized().
- 0x12c00010 receives fn_dma_translate_or_get_flag2_value(allocator,0,0) & 0x1fffffff, which resolves to allocator +0x0c masked to bus-visible low 29 bits.
- 0x12c0004c receives FPM endpoint for 0x100 buffers, expected 0x12200218.
- 0x12c00050 receives FPM endpoint for 0x200 buffers, expected 0x12200210.
- 0x12c00054 receives FPM endpoint for 0x400 buffers, expected 0x12200208.
- 0x12c00058 receives FPM endpoint for 0x800 buffers, expected 0x12200200.
- 0x12c00008 receives a second 0x800 endpoint, expected 0x12200200.
- 0x12c0000c first strobes bit 23 with 0x00800000, then clears it through mask 0xff7ff000 and sets final low field 0x0c41.
- 0x12c00004 token control becomes (old & 0xffffe000) | 0x9010.
- 0x12c00044 channel weights are set to 0x02020202.
- 0x12c00048 channel enable mask is set to 0x0000000f.
- 0x12c00040 receives status/ack/mask value status | 0xdea9.

Core bank selection:
- core0 TX control/base-like registers: 0x12c00100 / 0x12c00104
- core0 RX control/base-like registers: 0x12c00140 / 0x12c00144
- core1 TX control/base-like registers: 0x12c00120 / 0x12c00124
- core1 RX control/base-like registers: 0x12c00180 / 0x12c00184
- selected TX/RX base-or-size-like registers receive 0x13601c10; keep semantic meaning unresolved

## Main DMA/FPM allocator object

Object base: 0x81848740

Confirmed struct fields:
- +0x00 fpm_hw_base_kseg1
- +0x04 board_or_buffer_class
- +0x08 largest_default_pool_size / requested FPM buffer size
- +0x0c fpm_backing_base_aligned
- +0x10 embedded flag/log object
- +0x28 pool_size_shift_bits
- +0x2c pool_class_lookup_table_ptr
- +0x30 max/largest request size
- +0x34 timer/counter/state
- +0x38..+0x44 copied default pool-size values
- +0x48 token high-bits table base

## Board-level FPM init

Function: fn_platform_or_board_fpm_driver_init_80143088_candidate

Confirmed board constants:
- requested_fpm_buffer_size = 0x100
- fpm_hw_regs_base = 0xb2200000 KSEG1
- physical FPM base = 0x12200000
- calls fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate(0x100, 0xb2200000, ...)
- calls fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate with same FPM base
- then calls fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate

## FPM hardware init wrapper

Function: fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate

Confirmed:
- calls fn_dma_fpm_allocator_get_or_init_8009xxxx_candidate first to get allocator object 0x81848740
- calls fn_dma_fpm_driver_hw_init_8009d0a0_candidate with allocator object, requested FPM buffer size, FPM HW register base, and inherited context
- wrapper proves hardware init receives the real allocator object, not a raw address

## FPM hardware runtime init

Function: fn_dma_fpm_driver_hw_init_8009d0a0_candidate

Confirmed writes and behavior:
- allocator +0x00 receives FPM HW base 0xb2200000
- allocator +0x08 receives requested FPM buffer size
- for requested size 0x100, allocator +0x04 class becomes 7
- FPM +0x40 bits 26:24 receive allocator +0x04 class value
- heap allocation length is requested_size * 0x8000 + 0x100
- for requested size 0x100, allocation length is 0x00800100
- allocator +0x0c receives (allocated_ptr + 0xff) & 0xffffff00
- FPM +0x44 receives (allocated_ptr + 0xff) & 0x1fffff00
- D-cache range op is applied over allocator +0x0c and requested_size * 0x8000
- FPM control/status setup writes include offsets +0xc0 and +0x10
- allocator +0x28 is adjusted as pool-size shift bits
- allocator +0x2c is allocated and filled as pool-class lookup table
- allocator +0x30 tracks largest pool/request size
- FPM base register bit 0x10000 is set before calling the dump helper

Important conclusion:
- allocator +0x0c is the real source for MBDMA 0x12c00010
- FPM +0x44 is the hardware low bus-visible backing-base field
- OpenWrt must compare FPM side 0x12200040/0x12200044 before assuming MBDMA init is correct

## FPM endpoint selector

Function: fn_dma_get_hw_alloc_free_addr_by_pool_size_8009de50

Confirmed formula:
- pool_index = (pool_size - 1) >> (allocator->pool_size_shift_bits & 0x1f)
- pool_class = *(u8 *)(allocator->pool_class_lookup_table_ptr + pool_index)
- endpoint = allocator->fpm_hw_base_kseg1 + 0x200 + pool_class * 8

Expected endpoint map after current table model:
- 0x100 -> class 3 -> 0xb2200218 -> physical 0x12200218
- 0x200 -> class 2 -> 0xb2200210 -> physical 0x12200210
- 0x400 -> class 1 -> 0xb2200208 -> physical 0x12200208
- 0x800 -> class 0 -> 0xb2200200 -> physical 0x12200200

## Token/backing translation helper

Function: fn_dma_translate_or_get_flag2_value

Confirmed behavior:
- if allocator +0x0c is nonzero, treat it as backing base
- token/index field is (param_2 >> 12) & 0xffff
- highbits table at allocator +0x48 receives (param_2 >> 28) & 3
- return param_3 + allocator->fpm_backing_base_aligned + token_index * 0x100
- for wrapper_a(0,0), return allocator +0x0c directly
- therefore MBDMA 0x12c00010 = allocator +0x0c masked by 0x1fffffff

## FPM dump and snapshot helpers

Function renamed: fn_fpm_dump_config_and_counters_8009e284_candidate

Correction:
- this is not an enable/start function
- it runs after FPM init and after FPM base register bit 0x10000 is set
- it calls fn_dma_fpm_snapshot_config_and_counters and prints config/status/counters
- if dump_interrupt_counters != 0, it prints interrupt status counters; main init path passes 0

Function: fn_dma_fpm_snapshot_config_and_counters

Confirmed read map:
- reads allocator->fpm_hw_base_kseg1
- reads FPM +0x44 as low backing-base field
- reads FPM +0x50 as overflow/underflow count register
- reads FPM +0x54 as FIFO/token status register
- reads FPM +0x58 as invalid token free count
- reads FPM +0x5c as invalid token multifree count
- calls endpoint selector with pool size 0x800 to report 0x800 endpoint
- copies software counters DAT_8146ff0c..DAT_8146ff50 into interrupt counter output array

Extra FPM labels added/recommended:
- 0xb2200050 = FPM_OVER_UNDERFLOW_COUNT_12200050
- 0xb2200054 = FPM_FIFO_TOKEN_STATUS_12200054
- 0xb2200058 = FPM_INVALID_TOKEN_FREE_COUNT_12200058
- 0xb220005c = FPM_INVALID_TOKEN_MULTIFREE_COUNT_1220005c

## Secondary packet allocator

Object/latch:
- 0x8187bc68 = FPM_PACKET_ALLOC_INIT_DONE_8187bc68
- 0x8187bc70 = FPM_PACKET_ALLOC_OBJECT_8187bc70

Getter: fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate
- lazy initializes secondary packet allocator object
- on first call initializes object through fn_dma_fpm_packet_alloc_object_init_800b6acc_candidate
- passes FPM HW base/context through but object init does not use them
- sets init latch 0x8187bc68
- registers shutdown/cleanup callback
- always returns object base 0x8187bc70

Object init: fn_dma_fpm_packet_alloc_object_init_800b6acc_candidate
- initializes embedded flag/log header
- sets object name to BcmBfcPacketAlloc
- finalizes/registers object
- does not configure FPM MMIO
- does not allocate packet header arena
- does not write token hardware

Header-buffer init: fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate
- packet_alloc +0x18 = 0xe0 packet-header slot size
- packet_alloc +0x1c = 16-byte aligned heap allocation from raw allocation size 0x700010
- packet_alloc +0x20 = main DMA/FPM allocator object, normally 0x81848740
- size relation: 0xe0 << 15 = 0x700000, plus 0x10 alignment slack gives 0x700010
- this is separate from main FPM data-buffer backing memory initialized at 8009d0a0

Caution:
- current decompile of the verbose/debug flag 0x80000000 path may show an early return before storing +0x20
- treat that branch as unresolved until assembly/tail path is verified
- normal non-debug path stores the main FPM allocator pointer at packet_alloc +0x20

## OpenWrt control implications

OpenWrt bring-up must not treat MBDMA registers 0x12c0004c/50/54/58/08 as normal descriptor ring bases. They are FPM hardware endpoint addresses derived from FPM HW base +0x200 + class*8.

Critical control questions:
- does OpenWrt initialize FPM HW base 0x12200000
- does OpenWrt program FPM 0x12200040 bits 26:24 with class 7 for 0x100 board buffer size
- does OpenWrt allocate/setup FPM backing memory equivalent to 0x00800100 bytes
- does OpenWrt program FPM 0x12200044 with low bus-visible backing base
- does OpenWrt program MBDMA 0x12c00010 from the same backing base
- does OpenWrt program MBDMA endpoint registers with 0x12200218/210/208/200
- does OpenWrt account for token-backed data buffers instead of plain linear descriptor-owned buffers

## High-value OpenWrt compare list

FPM side:
- 0x12200040
- 0x12200044
- 0x12200050
- 0x12200054
- 0x12200058
- 0x1220005c
- 0x12200200
- 0x12200208
- 0x12200210
- 0x12200218

GENET/MBDMA side:
- 0x12c00004
- 0x12c00008
- 0x12c0000c
- 0x12c00010
- 0x12c00040
- 0x12c00044
- 0x12c00048
- 0x12c0004c
- 0x12c00050
- 0x12c00054
- 0x12c00058
- 0x12c00070

## Next reverse targets

- Verify assembly/tail behavior in fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate for debug flag 0x80000000 branch.
- Search callers of packet allocator functions, not direct data references to 0x8187bc70, because direct references may be optimized through lazy getter and pointer flow.
- Reverse packet-header/token allocation and translation functions that consume packet_alloc +0x18/+0x1c/+0x20.
- Continue from token paths involving valid bit 0x80000000, index mask 0x0ffff000, and stride 0x100.

## Preservation

Created as a new dated reverse note. No old logs or notes were edited or deleted.
