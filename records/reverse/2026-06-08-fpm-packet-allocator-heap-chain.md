# FPM packet allocator and heap allocator chain findings

## Scope

This note records additive reverse-engineering findings made after the previous detailed FPM/MBDMA caller-chain log. Preserve old logs and notes. Do not delete or overwrite prior evidence.

The previous log established the main FPM hardware allocator path:

```text
fn_platform_or_board_fpm_driver_init_80143088_candidate
  -> fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate(0x100, 0xb2200000, ...)
  -> fn_dma_fpm_driver_hw_init_8009d0a0_candidate
```

It also established the derived GMAC MBDMA FPM hardware alloc/free register values:

```text
0x12c0004c = 0x12200218
0x12c00050 = 0x12200210
0x12c00054 = 0x12200208
0x12c00058 = 0x12200200
0x12c00008 = 0x12200200
0x12c00010 = aligned_fpm_ddr_backing_base & 0x1fffffff
```

This new note covers the secondary packet-allocation object path and the generic heap allocator/free-list routines discovered from it.

## Platform FPM init secondary call

The platform FPM init function also calls:

```text
fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate(0x100, 0xb2200000, fpm_context_or_config_ptr, param_4)
```

Then it calls:

```text
fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate(returned_object)
```

This secondary path is separate from the main FPM hardware/backing-memory setup. It creates and initializes a packet-allocation object and a packet header buffer.

## Packet allocation object lazy getter

Function:

```text
fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate
```

Confirmed behavior:

```text
init latch:  0x8187bc68
object base: 0x8187bc70
```

On first call:

```text
fn_dma_fpm_packet_alloc_object_init_800b6acc_candidate(&0x8187bc70, param_2, param_3, param_4)
g_dma_fpm_packet_alloc_init_done_8187bc68_candidate = 1
register cleanup callback fn_dma_fpm_packet_alloc_shutdown_or_cleanup_800b6d30_candidate
return &g_dma_fpm_packet_alloc_object_8187bc70_candidate
```

Important argument note:

```text
param_1 = requested FPM size 0x100, ignored by this getter
param_2 = FPM HW register base 0xb2200000, passed through but not used by the visible object initializer
param_3 = context/config pointer, passed through but not used by the visible object initializer
param_4 = caller arg, used by object init helpers
```

## Packet allocation object initializer

Function:

```text
fn_dma_fpm_packet_alloc_object_init_800b6acc_candidate
```

Confirmed role:

```text
secondary FPM packet-allocation object initializer
```

Visible behavior:

```text
fn_obj_flags_init_804ec310_candidate(param_1, 0, NULL, param_4)
fn_obj_set_name_804ec4d4_candidate(param_1, "BcmBfcPacketAlloc")
fn_obj_finalize_or_register_804ed178_candidate(param_1, name, 0, param_4)
```

The string display in Ghidra may show a pointer two bytes into a larger/odd label, but the intended runtime object name is:

```text
BcmBfcPacketAlloc
```

This function is object/log/config setup only. It does not perform the main FPM HW register setup, DDR backing allocation, pool table construction, or MBDMA register derivation.

Suggested labels:

```text
FUN_8002a4f8 -> fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate
FUN_800b6acc -> fn_dma_fpm_packet_alloc_object_init_800b6acc_candidate
DAT_8187bc68 -> g_dma_fpm_packet_alloc_init_done_8187bc68_candidate
0x8187bc70   -> g_dma_fpm_packet_alloc_object_8187bc70_candidate
FUN_800b6d30 -> fn_dma_fpm_packet_alloc_shutdown_or_cleanup_800b6d30_candidate
```

## Packet header-buffer initializer

Function:

```text
fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate
```

Input:

```text
packet_alloc_object = 0x8187bc70
```

Confirmed fields set:

```text
packet_alloc_object +0x18 = 0xe0
packet_alloc_object +0x1c = 16-byte-aligned heap allocation from fn_heap_alloc_wrapper_800049b4_candidate(0x700010)
packet_alloc_object +0x20 = main DMA/FPM allocator object from fn_dma_addr_alloc_core, normally 0x81848740
```

The buffer size relationship is:

```text
0xe0 << 0xf = 0x700000
requested heap allocation = 0x700000 + 0x10 = 0x700010
caller alignment = (heap_payload_ptr + 0xf) & 0xfffffff0
```

Therefore:

```text
+0x18 is a count or max-buffer-size-like value, not direct byte length
+0x1c is the packet header-buffer base after 16-byte alignment
+0x20 links this packet allocator object to the main DMA/FPM allocator object at 0x81848740
```

Normal path final link:

```text
packet_alloc_object +0x20 = fn_dma_addr_alloc_core(...) = 0x81848740
return 1
```

## Debug branch helper

Function:

```text
fn_dma_fpm_packet_alloc_debug_finish_or_link_800b6c98_candidate
```

This helper is called only after the verbose/debug log path for a successful packet header-buffer allocation.

Confirmed behavior:

```text
FUN_80f94244(log_builder, FUN_804e6850, debug_log_flag, log_context)
main_dma_allocator_object = fn_dma_addr_alloc_core(log_builder, FUN_804e6850, debug_log_flag, log_context)
*(packet_alloc_object_unaff_s0 + 0x20) = main_dma_allocator_object
return 1
```

Important Ghidra note:

```text
unaff_s0 is inherited preserved register state. In the caller, s0 is the packet_alloc_object, normally 0x8187bc70.
```

Conclusion:

```text
The verbose/debug branch does not skip packet allocator linking. It still stores 0x81848740 at packet_alloc_object +0x20 and returns success.
```

## Packet allocator chain now confirmed

```text
fn_platform_or_board_fpm_driver_init_80143088_candidate
  -> fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate
      -> fn_dma_fpm_packet_alloc_object_init_800b6acc_candidate
      -> returns 0x8187bc70
  -> fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate
      -> allocates 0x700010 packet header-buffer request
      -> aligns object +0x1c to 16 bytes
      -> stores object +0x20 = 0x81848740
```

## Packet allocator cleanup wrapper

Function:

```text
fn_dma_fpm_packet_alloc_shutdown_or_cleanup_800b6d30_candidate
```

Confirmed behavior:

```text
ignores callback arguments
calls fn_dma_fpm_packet_alloc_object_cleanup_800b6b10_candidate(&g_dma_fpm_packet_alloc_object_8187bc70_candidate, ...)
```

Function:

```text
fn_dma_fpm_packet_alloc_object_cleanup_800b6b10_candidate
```

Confirmed behavior:

```text
calls fn_obj_base_destructor_or_reset_804ec3d4_candidate(packet_alloc_object, ...)
```

## Generic object destructor/reset

Function:

```text
fn_obj_base_destructor_or_reset_804ec3d4_candidate
```

Confirmed behavior:

```text
object[0] = &PTR_FUN_8180d6f0
object[3] = 0
if object[2] != 0:
    FUN_80f08cdc(object[2], cleanup_arg_or_context, cleanup_flags, cleanup_arg3)
    object[2] = 0
object[1] = 0
object[5] = 0
fn_heap_free_if_nonnull_80f08cbc_candidate(object, cleanup_arg_or_context, cleanup_flags, cleanup_arg3)
```

This is generic object cleanup/reset, not packet/FPM-specific cleanup.

Visible field impact:

```text
object +0x00 reset to base vtable/type pointer
object +0x04 cleared
object +0x08 optional owned subresource cleaned and cleared
object +0x0c cleared
object +0x14 cleared
```

Not directly visible here:

```text
packet_alloc_object +0x1c header-buffer free
packet_alloc_object +0x20 allocator-link clear
```

## Heap free wrappers

Function:

```text
fn_heap_free_if_nonnull_80f08cbc_candidate
```

Behavior:

```text
if ptr != 0:
    fn_heap_free_wrapper_800049d0_candidate(ptr, ...)
```

Function:

```text
fn_heap_free_wrapper_800049d0_candidate
```

Behavior:

```text
fn_heap_free_list_block_8002a2xx_candidate(ptr, ...)
```

This proves the object cleanup chain reaches a real heap-free routine.

## Generic heap free-list free routine

Function:

```text
fn_heap_free_list_block_8002a2xx_candidate
```

Confirmed role:

```text
real heap/free-list free routine
```

It expects:

```text
heap_payload_ptr = pointer returned by heap allocation
block_header     = heap_payload_ptr - 0x0c
```

Heap block header layout:

```text
block_header +0x00 = next/list link
block_header +0x04 = previous/backlink pointer
block_header +0x08 = total block size
payload            = block_header +0x0c
```

The free routine:

```text
checks heap initialized state
validates/debug-checks the block header
unlinks the block from allocated list
adds the block size back to heap free bytes/counters
inserts the block into g_heap_free_list_head_814709ec_candidate in address order
coalesces adjacent free blocks
updates global heap status/statistics
```

Suggested global labels:

```text
DAT_814709e8 -> g_heap_initialized_or_state_814709e8_candidate
DAT_814709ec -> g_heap_free_list_head_814709ec_candidate
DAT_814709f0 -> g_heap_allocated_list_head_814709f0_candidate
DAT_814709f4 -> g_heap_error_or_status_814709f4_candidate
DAT_81470a00 -> g_heap_stats_base_81470a00_candidate
DAT_81470a04 -> g_heap_free_bytes_or_total_81470a04_candidate
DAT_81470a08 -> g_heap_low_watermark_or_min_free_bytes_81470a08_candidate
DAT_81470a10 -> g_heap_free_block_count_81470a10_candidate
DAT_81470a14 -> g_heap_alloc_block_count_81470a14_candidate
DAT_81470a18 -> g_heap_alloc_failure_count_81470a18_candidate
```

## Heap allocation wrapper

Function:

```text
fn_heap_alloc_wrapper_800049b4_candidate
```

Correct return type:

```text
undefined4 fn_heap_alloc_wrapper_800049b4_candidate(int alloc_size)
```

Confirmed behavior:

```text
return fn_heap_alloc_list_block_8002a090_candidate(alloc_size)
```

Important Ghidra repair note:

```text
This wrapper must not be typed as void. Callers consume the return value for the FPM DDR backing allocation and packet header-buffer allocation.
```

## Generic heap allocation routine

Function:

```text
fn_heap_alloc_list_block_8002a090_candidate
```

Confirmed role:

```text
generic heap/free-list allocation routine
```

It computes:

```text
requested_total_block_size = (requested_payload_size + 0x0f) & ~3
```

It returns:

```text
returned_payload_ptr = selected_block_header + 0x0c
```

This confirms the allocation/free pair:

```text
alloc returns block_header + 0x0c
free expects payload_ptr - 0x0c
```

Allocator behavior:

```text
checks heap initialized state
rejects requested size 0
searches free list for exact match or smallest sufficient block
splits larger blocks when possible
removes exact/full selected block from free list
updates free bytes and low watermark
inserts allocated block into g_heap_allocated_list_head_814709f0_candidate
increments allocated block count
returns payload pointer
```

## Confirmed allocation sizes in FPM path

Main FPM DDR backing allocation:

```text
requested_fpm_buffer_size = 0x100
caller requested payload  = 0x100 * 0x8000 + 0x100 = 0x800100
heap total block size     = (0x800100 + 0x0f) & ~3 = 0x80010c
returned payload          = block_header + 0x0c
FPM code alignment        = (payload + 0xff) & 0xffffff00
```

Packet header-buffer allocation:

```text
caller requested payload  = 0x700010
heap total block size     = (0x700010 + 0x0f) & ~3 = 0x70001c
returned payload          = block_header + 0x0c
packet code alignment     = (payload + 0x0f) & 0xfffffff0
```

## Cleanup status and unresolved lifetime question

Confirmed cleanup chain:

```text
fn_dma_fpm_packet_alloc_shutdown_or_cleanup_800b6d30_candidate
  -> fn_dma_fpm_packet_alloc_object_cleanup_800b6b10_candidate
    -> fn_obj_base_destructor_or_reset_804ec3d4_candidate
      -> fn_heap_free_if_nonnull_80f08cbc_candidate(object)
        -> fn_heap_free_wrapper_800049d0_candidate(object)
          -> fn_heap_free_list_block_8002a2xx_candidate(object)
```

This confirms:

```text
object base free path: visible and real
```

Still not directly visible:

```text
packet header buffer at object +0x1c being freed
main allocator link at object +0x20 being cleared
```

Important unresolved point:

```text
0x8187bc70 is used as a fixed global/static-looking packet allocator object address by the getter.
However, the cleanup path reaches a real heap free routine that expects a valid heap header at 0x8187bc70 - 0x0c = 0x8187bc64.
```

Safe current wording:

```text
0x8187bc70 is a fixed/static-looking packet allocator object with a heap-free cleanup path. Lifetime classification is unresolved until 0x8187bc64 and memory ownership are verified.
```

Do not yet call it:

```text
definite static BSS
definite heap object
definite leak
definite invalid free
```

## Next Ghidra checks

Check:

```text
ram:8187bc64
```

Look for a valid heap header immediately before the packet allocator object:

```text
0x8187bc64 = next/list link or zero
0x8187bc68 = previous/backlink pointer or init latch conflict candidate
0x8187bc6c = total heap block size
0x8187bc70 = payload/object base
```

Note the possible conflict:

```text
0x8187bc68 was also identified as the packet allocator init latch.
```

If 0x8187bc68 is truly the init latch, then 0x8187bc64..0x8187bc6f may not be a normal heap header for object 0x8187bc70. That would strengthen the lifetime ambiguity and may indicate a generic destructor path that is not safe or not used for this static object in normal operation.

## Current OpenWrt implication

The secondary packet allocator path adds a separate RAM-backed packet header buffer requirement:

```text
packet header-buffer request = 0x700010
packet header-buffer base stored at 0x8187bc70 +0x1c after 16-byte alignment
packet allocator object links to main DMA/FPM allocator object through 0x8187bc70 +0x20 = 0x81848740
```

This is separate from the main FPM HW setup and does not change the previously derived GMAC MBDMA values. It may still matter if reproducing vendor init behavior beyond basic FPM HW register programming.
