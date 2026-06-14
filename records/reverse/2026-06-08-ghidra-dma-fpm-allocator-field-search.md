# 2026-06-08 Ghidra DMA/FPM allocator field-search findings

## Scope
Detailed Ghidra notes for TC7200U DMA/FPM allocator reverse-engineering. Goal was to find a nonzero writer for allocator object fields, especially static allocator base `0x81848740`, suspected backing/base field `+0x0c` / `0x8184874c`, high-bit table near `+0x48` / `0x81848788`, and embedded object fields used by `FUN_8002c290` / `fn_obj_get_flagged_value_or_fallback`.

## Direct address/reference result
No direct constant-address stores or references were found for `0x81848740`, `0x8184874c`, or `0x81848788`. Therefore the writer is not an obvious `lui/addiu/sw` constant-address store in the searched code.

## Allocator +0x0c candidates checked and ruled out
- `FUN_8002a568` / `fn_dma_alloc_descriptor_from_token_candidate`: `8002a600 sw v0,0xc(s1)` writes `descriptor+0x0c = 1`. `s1 = pool_base + token_index * descriptor_size`, not allocator base.
- `FUN_8002aa58` / `fn_dma_init_descriptor_from_token_candidate`: `8002aae4 sw v0,0xc(param_2)` writes `descriptor+0x0c = 1`, not allocator base.
- `FUN_8002ab08` / `fn_dma_init_descriptor_from_context_candidate`: `8002ab7c sw v0,0xc(a2)` writes `descriptor+0x0c = 1`, not allocator base.
- `8009c9a8` trace/ring copy cluster: `8009c9c4`, `8009ca80`, `8009cb24`, `8009cbec`, `8009cc98` are all 16-byte copy-loop `dst+0x0c` writes inside 0x60-byte trace/ring records. They are not allocator writes. The block uses stack-source records and destination write pointer/counter fields around `s0+0x14`, `s0+0x18`, and `s0+0x24`. Strings observed include `addi.ret (np), zero, %d`, `ExitFilterAccept:`, and `addi (np), zero, %d`.
- `FUN_804ec580`: `804ec580 sw t3,0xc(v1)` is a table/string copy loop copying 16-byte records such as `Fatal Errors`, `Errors`, `Warnings`, `Initialization`, `Function Entry/Exit`, `Informational`; not allocator inner `+0x0c`.

## Confirmed allocator header initializer
- `FUN_8009cf58` renamed/candidate: `fn_dma_allocator_header_init_candidate`.
- It initializes allocator object header: `+0x00 = 0`, `+0x04 = 6`, `+0x08 = 0x800`, `+0x0c = 0`.
- It then calls `FUN_804ec310(param_1 + 4, 0, NULL, ...)`, meaning embedded object begins at allocator `+0x10`.
- `8009cf7c sw zero,0xc(a0)` is zero-init only. It is not a nonzero backing-base setup for `0x8184874c`.

## Embedded object / inner-field candidates checked and ruled out
`FUN_8002c290(obj, flag)` style logic appears to use embedded object fields equivalent to allocator `+0x1c` and `+0x24` when called on `allocator+0x10`. Searches for `+0x0c`, `+0x14`, `+0x1c`, and `+0x24` stores found several candidates; inspected results:

- `FUN_8002a280`: generic heap/free-list routine, likely `fn_heap_free_block_candidate`. Stores at `8002a34c`, `8002a358`, and `8002a430` update global heap accounting at `DAT_81470a00`, including `DAT_81470a14--` and `DAT_81470a10++`. Not allocator inner fields.
- `FUN_8002af18`: interrupt/status dispatcher, likely `fn_irq_dispatch_status_mask_candidate`. `DAT_8173facc = 0xb8601800`; `8002afd8 sw s0,0x14(v0)` writes MMIO/status mask at `0xb8601814`, not allocator inner `+0x14`. Flow after `FUN_8003d184` was repaired; `FUN_8003d184` returns.
- `FUN_8009dc00`: false split inside FPM interrupt handler path. `8009dc14 sw s1,0x14(s2)` is FPM interrupt status write/ack, not allocator inner `+0x14`. It follows the `FPM_INT: Allocation FIFO full.` print path.
- `fn_dma_fpm_snapshot_config_and_counters` stores are report/snapshot output fields, not allocator setup.

## Ghidra repair notes
- Accidental rerun of `tc7200u_fix_mips32.java` did not appear to destroy the key allocator labels at checked locations.
- False function wrappers in the trace/ring cluster were checked and removed/avoided. Script result confirmed no functions at `0x8009c9a8`, `0x8009c9e4`, `0x8009ca2c`, or `0x8009cad8`.
- Flow overrides/no-return issues were repaired or identified for `FUN_80e93bf0`, `FUN_80e99988`, `FUN_80f0f55c`, and `FUN_8003d184` where they caused valid post-call code to appear as `??` bytes.

## Current conclusion
No nonzero writer has been found for allocator `+0x0c` / `0x8184874c`, allocator inner `+0x0c`, or allocator inner `+0x14` in the inspected allocator/FPM ranges. The only confirmed allocator `+0x0c` write is the zero initialization in `FUN_8009cf58`. Many apparent `+0x0c` / `+0x14` hits were descriptor constructors, trace/ring copy loops, heap counters, MMIO/status registers, or FPM interrupt acknowledge writes.

## Next suggested work
Continue from actual users of `fn_dma_addr_alloc_core`, `FUN_8002c290`, and `fn_obj_get_flagged_value_or_fallback`, not from blind `+0x0c` searches. If the backing value exists, it may be supplied through runtime initialization, embedded object state, or non-obvious pointer-based setup rather than a direct static write to `0x8184874c`.
