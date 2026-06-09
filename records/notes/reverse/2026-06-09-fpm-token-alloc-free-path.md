# TC7200U reverse notes: FPM token allocation/free path and packet allocator

## Summary
This note records the completed reverse pass for the Broadcom DMA/FPM allocator, packet allocator, token allocation, token free, and cache-maintenance helpers. The evidence shows that the vendor Ethernet path depends on FPM token hardware and FPM alloc/free endpoints, not just ordinary GENET descriptor-ring base programming.

## Repository context
Ethernet remains blocked because GENET queues TX descriptors but TDMA does not consume them. This reverse evidence supports continuing DMA/window/address-representation work rather than MDIO or switch probing.

## Main DMA/FPM allocator object
Static object: 0x81848740. Init latch: 0x81848738.

Mapped fields:
- +0x00: FPM HW MMIO base, board value 0xb2200000, physical 0x12200000
- +0x04: encoded FPM buffer-size class
- +0x08: requested FPM buffer size, board value 0x100
- +0x0c: aligned DDR backing/FPM pool base from heap allocation
- +0x28: computed pool-size shift byte
- +0x2c: heap-allocated pool-class lookup table pointer
- +0x30: largest allowed request size
- +0x34: overhead/reserve field used by packet allocation path
- +0x38..+0x44: pool size/default table copy
- +0x48 + token_index*4: token high-bits / pool selector table

## Board FPM init constants
fn_platform_or_board_fpm_driver_init_80143088_candidate proves:
- requested_fpm_buffer_size = 0x100
- fpm_hw_regs_base = 0xb2200000
- physical FPM base = 0x12200000

The wrapper fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate gets the static main allocator through fn_dma_addr_alloc_core and calls fn_dma_fpm_driver_hw_init_8009d0a0_candidate with allocator_object, requested_fpm_buffer_size, fpm_hw_regs_base, and context.

## FPM hardware init behavior
fn_dma_fpm_driver_hw_init_8009d0a0_candidate:
- stores allocator +0x00 = fpm_hw_regs_base
- initializes FPM hardware register ranges
- allocates aligned DDR/FPM backing memory
- stores aligned backing base at allocator +0x0c
- writes low bus-visible backing base bits to FPM HW +0x44
- computes allocator +0x28 pool-size shift
- allocates and fills allocator +0x2c pool-class lookup table
- sets interrupt/control bits at FPM HW +0x10 and related registers

## FPM interrupt handler
fn_dma_fpm_interrupt_status_handler_8009d8bc_candidate:
- gets main allocator through fn_dma_addr_alloc_core
- fpm_hw_base = allocator +0x00
- handled bits = *(fpm_hw_base +0x14) & *(fpm_hw_base +0x10)
- logs bits 0x1000, 0x800, 0x400, 0x200, 0x100, 0x80, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x1
- bit 0x8 invalid token free enters fatal/debug dump path
- repeated bit 0x4 usage-index-pool-full disables bit 0x4 in FPM HW +0x10
- writes handled bits back to FPM HW +0x14 as ack/clear candidate

## Secondary packet allocator object
Static object: 0x8187bc70. Init latch: 0x8187bc68.

fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate lazily initializes and returns 0x8187bc70.

Mapped fields:
- +0x18: 0xe0, packet header slot size or max/header unit value
- +0x1c: 16-byte-aligned packet header buffer base
- +0x20: pointer to main DMA/FPM allocator object, normally 0x81848740

fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate allocates 0x700010 bytes. Relation: 0xe0 << 0xf = 0x700000, plus 0x10 alignment slack. Debug helper fn_dma_fpm_packet_alloc_debug_finish_or_link_800b6c98_candidate also links packet allocator +0x20 to the main allocator, so the verbose path does not skip linkage.

## Packet allocation path
FUN_8002a54c should be named fn_dma_fpm_packet_alloc_from_size_8002a54c_candidate.

Flow:
- uses packet_alloc_object +0x20 to get the main allocator
- requests an FPM token using requested size plus allocator overhead/reserve
- token index bits 12..27 select the packet header slot: header_base + token_index * slot_size
- clears the selected packet header slot
- sets packet header pointers at +0x04, +0x08, and +0x38
- stores free/release callback fn_dma_fpm_packet_free_callback_8002a4ac_candidate at packet header +0x00
- stores requested payload length in inner header +0x04
- translates the FPM token to backing/data address through fn_dma_translate_or_get_flag2_value
- stores translated backing/data address at inner header +0x00

## Packet free path
FUN_8002a4ac should be named fn_dma_fpm_packet_free_callback_8002a4ac_candidate. It gets the secondary packet allocator object and calls FUN_8002a658 with release flag 1.

FUN_8002a658 should be named fn_dma_fpm_packet_release_to_fpm_8002a658_candidate. It:
- reads main allocator from packet_alloc_object +0x20
- reads inner packet header pointer from packet_header +0x04
- reconstructs FPM token from inner header data address with fn_dma_buffer_ptr_to_token_candidate
- frees token through fn_dma_free_token_to_fpm_candidate
- logs PacketFree failure if the FPM token free returns zero

## Pointer-to-token helper
fn_dma_buffer_ptr_to_token_candidate converts backing/data pointer back into an FPM token.

Formula:
index = ((buffer_ptr & 0x1fffffff) - (allocator +0x0c & 0x1fffffff) - extra_base_offset) >> 8

token = 0x80000000 | (high_bits_table[index] << 28) | (index << 12)

Requires allocator +0x0c backing base to be configured. Uses allocator +0x48 + index*4 as the high-bits table.

## FPM token allocation helper
fn_dma_lookup_token_or_flag2_value should be renamed fn_dma_fpm_alloc_token_for_size_candidate.

Allocation flow:
- rejects requested_alloc_size if it exceeds allocator +0x30
- pool_index = (requested_alloc_size - 1) >> allocator_shift
- pool_class = lookup_table[pool_index]
- token_word = *(FPM_HW_BASE + 0x200 + pool_class*8)
- valid token requires bit31 set
- stores token high bits into allocator +0x48 + token_index*4
- preserves token bits31..12 and stores requested size low 12 bits in token

## Token free helper
fn_dma_free_token_to_fpm_candidate:
- requires token bit31 set
- extracts token_index = (token >> 12) & 0xffff
- token_byte_offset = token_index * 0x100
- reconstructs backing_buffer_addr = extra_base_offset + allocator +0x0c + token_index*0x100
- stores token high bits into allocator +0x48 + token_index*4
- runs cache helper before freeing token
- writes token to FPM HW base +0x200

## Token format
- bit31: valid token marker
- bits28..29: high bits / pool selector
- bits12..27: token index
- bits0..11: requested allocation size low bits on alloc path

## FPM hardware alloc/free endpoints
With FPM HW base 0xb2200000 / physical 0x12200000:
- free register: FPM_HW +0x200 = 0xb2200200 / 0x12200200
- pool class 0 endpoint: 0x12200200
- pool class 1 endpoint: 0x12200208
- pool class 2 endpoint: 0x12200210
- pool class 3 endpoint: 0x12200218

This matches the MBDMA global init values and supports interpreting 0x12c00008 and 0x12c0004c..0x12c00058 as FPM alloc/free endpoint registers, not descriptor-ring bases.

## Cache helper
FUN_8002a034 should be named fn_mips_dcache_range_op_8002a034_candidate.

It aligns start down and end up to 16-byte cache lines, then runs MIPS cache operations:
- mode 1: cacheOp(0x19), D-cache hit writeback / clean candidate
- mode 2: cacheOp(0x11), D-cache hit invalidate candidate
- other/default: cacheOp(0x15), D-cache hit writeback+invalidate candidate

Known FPM usage:
- mode 1 before returning/freeing an FPM token
- mode 3/default during FPM backing-memory setup

## Ethernet implication
Vendor code integrates GENET/MBDMA with Broadcom FPM token hardware and FPM alloc/free endpoints. OpenWrt bcmgenet direct descriptor behavior may be missing BCM3383-specific FPM/DMA address representation, window setup, ownership semantics, or token-backed buffer model. This is directly relevant to TDMA enabled but consumer index not advancing.

## Next reverse targets
- Revisit fn_enet_gmac_mbdma_global_init and mark 0x12c00008 and 0x12c0004c..0x12c00058 as FPM endpoint writes
- Verify fn_dma_translate_or_get_flag2_value against the allocation/free token model
- Inspect any functions reading packet allocator +0x18/+0x1c/+0x20 in ENET call paths
- Compare OpenWrt TX buffer address representation against vendor token/backing address conversion
