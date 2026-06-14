# DMA/FPM allocator and GMAC MBDMA findings

## Scope

This note records additive reverse-engineering findings for the TC7200.U / BCM3383 GMAC MBDMA path. Preserve old logs and notes. Do not delete or overwrite prior evidence.

## Current focus

The current reverse target is the vendor ENET/GMAC MBDMA initialization path, especially how the firmware derives the values written into the GENET/MBDMA register block at KSEG1 `0xb2c000xx`, equivalent to hardware/register view `0x12c000xx`.

## Confirmed MBDMA global init role

Function:

- `fn_enet_gmac_mbdma_global_init`

Classification:

- Direct GMAC/MBDMA global and per-channel register initialization.
- Relevant to the OpenWrt blocker where eth0/link may exist but TDMA/MBDMA descriptor consumption does not progress.

Important register writes:

- `0x12c00010 = fn_dma_addr_alloc_wrapper_a(0,0,...) & 0x1fffffff`.
- `0x12c0004c = fn_dma_addr_alloc_wrapper_sized(0x100,...) & 0x1fffffff`.
- `0x12c00050 = fn_dma_addr_alloc_wrapper_sized(0x200,...) & 0x1fffffff`.
- `0x12c00054 = fn_dma_addr_alloc_wrapper_sized(0x400,...) & 0x1fffffff`.
- `0x12c00058 = fn_dma_addr_alloc_wrapper_sized(0x800,...) & 0x1fffffff`.
- `0x12c00008 = fn_dma_addr_alloc_wrapper_sized(0x800,...) & 0x1fffffff`.
- `0x12c0000c = (old_or_unaff_s3_derived & 0xff7ff000) | 0x0c41` after an earlier `| 0x800000` write.
- `0x12c00004 = (old & 0xffffe000) | 0x9010`.
- `0x12c00044 = 0x02020202`.
- `0x12c00048 = 0x0000000f`.

Per-core channel pattern:

- Core/interface 0 path uses `0x12c00100`, `0x12c00104`, `0x12c00140`, `0x12c00144`.
- Core/interface nonzero path uses `0x12c00120`, `0x12c00124`, `0x12c00180`, `0x12c00184`.
- Base/size-like words are written as `0x13601c10`.
- TX-like control path ends with low bits `| 5`.
- RX-like control path sets `0x04000000`, sets `0x200`, clears fields, applies `| 4`, then ends with low bits `| 5`.

Candidate labels applied or recommended:

- `GENET_MBDMA_TOKEN_CTRL_12c00004_candidate`.
- `GENET_MBDMA_CHANNEL_WEIGHT_12c00044_candidate`.
- `GENET_MBDMA_CHANNEL_ENABLE_MASK_12c00048_candidate`.
- `GENET_MBDMA_CORE0_TX_CH0_CTRL_12c00100_candidate`.
- `GENET_MBDMA_CORE0_TX_CH0_BASE_OR_SIZE_12c00104_candidate`.
- `GENET_MBDMA_CORE0_RX_CH0_CTRL_12c00140_candidate`.
- `GENET_MBDMA_CORE0_RX_CH0_BASE_OR_SIZE_12c00144_candidate`.
- `GENET_MBDMA_CORE1_TX_CH0_CTRL_12c00120_candidate`.
- `GENET_MBDMA_CORE1_TX_CH0_BASE_OR_SIZE_12c00124_candidate`.
- `GENET_MBDMA_CORE1_RX_CH0_CTRL_12c00180_candidate`.
- `GENET_MBDMA_CORE1_RX_CH0_BASE_OR_SIZE_12c00184_candidate`.
- `GENET_MBDMA_STATUS_OR_INTR_12c00000_candidate`.
- `GENET_MBDMA_STATUS_ACK_OR_MASK_12c00040_candidate`.

Keep the TX/RX names as `_candidate` until direction is confirmed by runtime behavior or register documentation.

## Wrapper A correction

Function:

- `fn_dma_addr_alloc_wrapper_a`

Listing proved this is not a direct return of `fn_dma_addr_alloc_core`. Real flow:

```text
core_base = fn_dma_addr_alloc_core(...)
return fn_dma_translate_or_get_flag2_value(core_base, original_param_1, original_param_2)
```

For GMAC MBDMA global init, the call is `fn_dma_addr_alloc_wrapper_a(0,0,...)`, therefore:

```text
0x12c00010 = fn_dma_translate_or_get_flag2_value(0x81848740, 0, 0) & 0x1fffffff
```

When allocator object field `+0x0c` is configured, this becomes:

```text
0x12c00010 = allocator_object[+0x0c] & 0x1fffffff
```

This is the allocator backing base, not the allocator object address itself.

## Sized wrapper confirmation

Function:

- `fn_dma_addr_alloc_wrapper_sized`

Confirmed flow:

```text
core_base = fn_dma_addr_alloc_core(...)
size16 = requested_size & 0xffff
return fn_dma_get_hw_alloc_free_addr_by_pool_size_8009de50_candidate(core_base, size16)
```

For GMAC MBDMA global init:

```text
0x12c0004c = hw_alloc_free_addr(size 0x100) & 0x1fffffff
0x12c00050 = hw_alloc_free_addr(size 0x200) & 0x1fffffff
0x12c00054 = hw_alloc_free_addr(size 0x400) & 0x1fffffff
0x12c00058 = hw_alloc_free_addr(size 0x800) & 0x1fffffff
0x12c00008 = hw_alloc_free_addr(size 0x800) & 0x1fffffff
```

`0x12c00058` and `0x12c00008` should normally match because both use size `0x800`, unless allocator state changes between calls.

## Address translator helper

Function:

- `fn_dma_translate_or_get_flag2_value`

Behavior:

```text
param_1 = allocator object base
param_2 = input address or token-like value
param_3 = extra offset
```

If `*(param_1 + 0x0c)` is nonzero, treat it as backing base:

```text
index = (param_2 >> 12) & 0xffff
high_bit_table[index] = (param_2 >> 28) & 3
return param_3 + backing_base + index * 0x100
```

For the static allocator base `0x81848740`:

```text
backing base field = 0x8184874c
high-bit table starts at 0x81848788
```

If backing base is zero, the helper checks object `+0x10` with flag `2`; if flag path is active it reports `FPM Pool Base Address not configured`; return remains `0`.

## HW alloc/free address selector

Function renamed:

- `FUN_8009de50` -> `fn_dma_get_hw_alloc_free_addr_by_pool_size_8009de50_candidate`

Behavior for nonzero pool size:

```text
pool_size_u16 = pool_size & 0xffff
allocator_shift = *(u8 *)(allocator_object_base + 0x28) & 0x1f
pool_table = *(int *)(allocator_object_base + 0x2c)
pool_index = (pool_size_u16 - 1) >> allocator_shift
pool_class = *(u8 *)(pool_table + pool_index)
hw_alloc_free_addr = *(int *)(allocator_object_base + 0x00) + 0x200 + pool_class * 8
```

This means the sized MBDMA registers are not independent allocations. They are pool-class HW alloc/free control addresses derived from the allocator object table.

Strings observed in this helper confirm meaning:

- `GetFpmHwAllocDeallocAddress`.
- `fpmPoolSize:`.
- `FPM_HW_Alloc/Free_Address:`.
- `Fpm pool bucket selected:`.

## Allocator core

Function:

- `fn_dma_addr_alloc_core`

Confirmed role:

- Lazy initializer/getter for static DMA/FPM allocator object.
- Init latch at `0x81848738`.
- Object base at `0x81848740`.
- Always returns `0x81848740`.
- Does not directly return a DMA buffer or final MBDMA address.

Clean interpretation:

```text
if g_dma_allocator_init_done_81848738_candidate == 0:
    fn_dma_allocator_header_init_candidate(0x81848740, ...)
    g_dma_allocator_init_done_81848738_candidate = 1
    register cleanup callback FUN_8009f648
return 0x81848740
```

Suggested labels:

- `DAT_81848738` -> `g_dma_allocator_init_done_81848738_candidate`.
- `0x81848740` -> `g_dma_allocator_object_81848740_candidate`.
- `FUN_8009f648` -> `fn_dma_allocator_shutdown_or_callback_8009f648_candidate`.
- `FUN_80e99004` -> `fn_register_shutdown_or_cleanup_callback_80e99004_candidate`.

## Allocator object layout currently inferred

For allocator object base `0x81848740`:

```text
+0x00 = allocator/FPM HW base used by pool-size address formula
+0x04 = 6
+0x08 = 0x800
+0x0c = backing base for token/buffer translation
+0x10 = flag/config object initialized by FUN_804ec310
+0x28 = pool-size bucket shift
+0x2c = byte lookup table pointer
+0x30 = max/request limit
+0x34 = timer/counter/value read by fn_get_tick_or_timer_value_8009f728_candidate
+0x48 = high-bit table for translated token/buffer pointers
```

Header initializer still needs inspection to prove exact runtime values for `+0x00`, `+0x0c`, `+0x28`, `+0x2c`, `+0x30`, and `+0x34`.

## Ghidra memory block issue

Problem observed:

- `Go To DAT_81848738` produced no result.
- `Go To 0x81848740` produced no result.

Explanation:

- `DAT_81848738` is currently a decompiler-generated name, not necessarily a real Listing symbol.
- `0x81848740` may not be covered by a mapped RAM block in the Ghidra project.

Recommended repair:

1. Try `G -> ram:81848740`.
2. Try `G -> 81848740`.
3. If both fail, create a RAM block.

Suggested block:

```text
Name: dma_allocator_state_81848700
Start: ram:81848700
Length: 0x200
Initialized: false
Read: yes
Write: yes
Execute: no
Volatile: no
```

If Ghidra reports a block conflict, cancel. That means the block already exists.

After block creation, label:

```text
0x81848738 -> g_dma_allocator_init_done_81848738_candidate
0x81848740 -> g_dma_allocator_object_81848740_candidate
0x8184874c -> g_dma_allocator_backing_base_8184874c_candidate
0x81848768 -> g_dma_allocator_pool_shift_81848768_candidate
0x8184876c -> g_dma_allocator_pool_table_ptr_8184876c_candidate
0x81848770 -> g_dma_allocator_max_request_81848770_candidate
0x81848774 -> g_dma_allocator_timer_or_counter_81848774_candidate
0x81848788 -> g_dma_allocator_high_bits_table_81848788_candidate
```

## Ghidra analysis repair warnings

Several functions still show bad `CALL_TERMINATOR` flow overrides. These are caused by callees incorrectly treated as no-return. Bytes after calls are valid MIPS code, not data.

Known returning functions that should not be no-return:

- `fn_dma_addr_alloc_core`.
- `fn_obj_get_flagged_value_or_fallback`.
- log/builder functions such as `FUN_80f95470`, `FUN_80f94244`, and related print-chain helpers unless proven otherwise.

Repair pattern:

```text
Open called function -> Edit Function -> uncheck No Return
Then return to first ?? byte after the call -> press D to disassemble
```

Do not create new functions at those undefined tail bytes.

## OpenWrt compare targets

The highest-value runtime comparison points are:

```text
0x12c00004 token control
0x12c0000c global control
0x12c00010 allocator backing base-derived value
0x12c00044 channel weight
0x12c00048 channel enable mask
0x12c0004c size 0x100 HW alloc/free address
0x12c00050 size 0x200 HW alloc/free address
0x12c00054 size 0x400 HW alloc/free address
0x12c00058 size 0x800 HW alloc/free address
0x12c00008 size 0x800 HW alloc/free address
0x12c00100 core0 TX-like control
0x12c00104 core0 TX-like base/size word
0x12c00140 core0 RX-like control
0x12c00144 core0 RX-like base/size word
0x12c00120 core1 TX-like control
0x12c00124 core1 TX-like base/size word
0x12c00180 core1 RX-like control
0x12c00184 core1 RX-like base/size word
```

If OpenWrt does not reproduce the vendor token-control, channel-enable, allocator-derived address registers, or channel-control sequence, that is a strong lead for the descriptor-consumption failure.

## Next reverse target

Inspect and paste:

```text
fn_dma_allocator_header_init_candidate
```

This should reveal how the allocator object fields are initialized and may identify the actual pool table, shift, max request, backing base, and FPM HW base values used before GMAC MBDMA init.
