# TC7200U reverse notes: DMA FPM packet allocator and token path

## Summary
Reverse work confirms that the vendor Ethernet DMA path is tied to Broadcom FPM allocator hardware, not only normal GENET descriptor rings. Board FPM init uses requested FPM buffer size 0x100 and FPM HW MMIO base 0xb2200000, physical 0x12200000. This strengthens the interpretation that the MBDMA global values at 0x12c0004c, 0x12c00050, 0x12c00054, 0x12c00058, and 0x12c00008 are FPM hardware alloc/free addresses, not ordinary descriptor-ring bases.

## Main DMA FPM allocator object
Static object: 0x81848740. Init latch: 0x81848738. Header init only clears/defaults fields; runtime hardware init fills the important fields.
Fields now mapped:
- +0x00: FPM HW MMIO base, board value 0xb2200000, physical 0x12200000
- +0x04: encoded FPM buffer-size class
- +0x08: requested FPM buffer size, board value 0x100
- +0x0c: aligned DDR backing/FPM pool base from heap allocation
- +0x28: computed pool-size shift byte
- +0x2c: heap-allocated pool-class lookup table pointer
- +0x30: largest pool/request size
- +0x34: overhead/reserve field used by packet allocation path
- +0x38..+0x44: pool size/default table copy
- +0x48 + index*4: token high-bits table

## Board and hardware init path
fn_platform_or_board_fpm_driver_init_80143088_candidate proves fixed board constants: requested_fpm_buffer_size = 0x100 and fpm_hw_regs_base = 0xb2200000. It calls fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate, which gets the static allocator through fn_dma_addr_alloc_core and then calls fn_dma_fpm_driver_hw_init_8009d0a0_candidate.
fn_dma_fpm_driver_hw_init_8009d0a0_candidate stores allocator +0x00 = fpm_hw_regs_base, initializes FPM hardware registers, allocates aligned DDR backing memory, stores it at allocator +0x0c, writes low bus-visible backing base bits to FPM HW +0x44, computes allocator +0x28 shift, and allocates/fills allocator +0x2c lookup table.

## FPM hardware registers observed
- FPM HW +0x10: interrupt/control enable mask candidate
- FPM HW +0x14: interrupt pending/status and ack/clear register candidate
- FPM HW +0x44: low bus-visible backing DDR base bits
- FPM HW +0x200: token free/deallocation register
- FPM HW +0x200 + pool_class*8: sized pool alloc/free endpoint used by MBDMA global init

## FPM interrupt handler
fn_dma_fpm_interrupt_status_handler_8009d8bc_candidate reads handled bits as status at FPM HW +0x14 AND mask/control at FPM HW +0x10. It logs bits 0x1000 through 0x1, has fatal handling for invalid token free bit 0x8, disables bit 0x4 after repeated usage-index-pool-full events, and writes handled bits back to FPM HW +0x14 as ack/clear.

## Secondary packet allocator object
Static object: 0x8187bc70. Init latch: 0x8187bc68. Getter: fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate.
Fields now mapped:
- +0x18: 0xe0, packet header slot size or max/header unit value
- +0x1c: 16-byte-aligned packet header buffer base from heap allocation size 0x700010
- +0x20: pointer to main DMA/FPM allocator object 0x81848740
Allocation relation: 0xe0 << 0xf = 0x700000, with 0x10 bytes alignment slack.

## Packet allocation path
FUN_8002a54c should be named fn_dma_fpm_packet_alloc_from_size_8002a54c_candidate. It gets a token through fn_dma_lookup_token_or_flag2_value using the main allocator at packet_alloc_object +0x20 and requested size plus allocator overhead. Token index bits 12..27 select the packet header slot: header_base + token_index * slot_size. It clears the slot, sets packet header internal pointers, stores a free/release callback at packet header +0x00, stores requested payload length in the inner header, translates the FPM token to backing/data address through fn_dma_translate_or_get_flag2_value, and stores that translated address at inner header +0x00.

## Packet free path
FUN_8002a4ac should be named fn_dma_fpm_packet_free_callback_8002a4ac_candidate. It gets the secondary packet allocator object and calls FUN_8002a658 with release flag 1.
FUN_8002a658 should be named fn_dma_fpm_packet_release_to_fpm_8002a658_candidate. It reconstructs the FPM token from the inner header data address using fn_dma_buffer_ptr_to_token_candidate, then returns the token to hardware through fn_dma_free_token_to_fpm_candidate.

## Token format
Token format is now supported by both pointer-to-token and free-token helpers:
- bit31: valid token marker
- bits28..29: high bits or pool selector from allocator +0x48 table
- bits12..27: token index
- token index byte offset: index * 0x100
- bits0..11: low token field not used by the inspected pointer-to-token/free helpers

## Free helper behavior
fn_dma_buffer_ptr_to_token_candidate requires allocator +0x0c backing base. It computes index from low bus-visible buffer address minus backing base minus extra offset, shifted by 8, then rebuilds a valid token using bit31, high bits from allocator +0x48+index*4, and index shifted by 12.
fn_dma_free_token_to_fpm_candidate validates bit31, extracts token index, reconstructs backing buffer address from allocator +0x0c plus extra offset plus index*0x100, updates allocator +0x48+index*4 with token high bits, performs a cache/memory operation through FUN_8002a034, then writes the token to FPM HW base +0x200.

## Ethernet implication
For OpenWrt bring-up, this reverse evidence supports focusing on GENET DMA address/window/FPM semantics rather than only upstream bcmgenet TDMA descriptor format. Vendor code appears to integrate GENET or MBDMA with FPM token hardware and FPM alloc/free endpoints. Current TDMA consumer-index-stuck behavior may be caused by an address/window/ownership model mismatch against this vendor FPM path.

## Next reverse targets
- FUN_8002a034: determine exact cache or memory sync modes, especially mode 1 and mode 3
- fn_dma_lookup_token_or_flag2_value: prove token allocation register read path and pool class selection
- MBDMA global init: annotate 0x12c00008 and 0x12c0004c..0x58 as FPM endpoint writes, not ring base writes
- OpenWrt diff: compare descriptor buffer address representation against vendor token/backing address model
