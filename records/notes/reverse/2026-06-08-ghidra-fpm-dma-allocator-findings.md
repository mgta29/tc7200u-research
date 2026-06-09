# Ghidra FPM/DMA allocator findings - 2026-06-08-140718

## Scope
TC7200U `image.raw` Ghidra reverse-engineering session focused on static DMA/FPM allocator object `0x81848740` and missing writer for `object+0x0c` / `0x8184874c`.

## Current target
Next target after this log: `FUN_8009f940`, assembly range `0x8009f940 - 0x8009f9c0`.

## Key object layout confirmed so far
- Static allocator/control object base: `0x81848740`.
- `object+0x00`: FPM/index/hardware base pointer used by token paths.
- `object+0x08`: initialized size/count field, seen as `0x800` from `FUN_8009cf58`.
- `object+0x0c`: backing/base address field, static address `0x8184874c`; many functions read it, writer still not found.
- `object+0x10`: object/control substructure used by `fn_obj_get_flagged_value_or_fallback` / `FUN_8002c290`.
- `object+0x34`: allocator offset/limit/base-offset field, read by `FUN_8009f728` and allocation paths.
- `object+0x38..0x44`: slot/config values used by token/high-bit paths.
- `object+0x48`: high-address-bit table, static address `0x81848788`, indexed by token/index.

## Function findings
- `fn_dma_addr_alloc_core` lazily initializes static object at `0x81848740` via `FUN_8009cf58`; returns object base. It does not itself establish `object+0x0c` backing base in the inspected path.
- `FUN_8009cf58` initializes object header: `+0x00=0`, `+0x04=6`, `+0x08=0x800`, `+0x0c=0`, then initializes `+0x10...` via `FUN_804ec310`.
- `fn_dma_addr_alloc_wrapper_a` calls core then `fn_dma_translate_or_get_flag2_value`; consumer of `object+0x0c`, not writer.
- `fn_dma_addr_alloc_wrapper_sized` calls core, then `FUN_8009de50(base, size16)`; uses `object+0x10` flag/value path, not direct address allocation.
- `FUN_8009de50` selector wrapper around `FUN_8002c290(param_1+0x10, flag)`, flag `2` when size is zero, else `0x20`.
- `fn_dma_translate_or_get_flag2_value` reads `object+0x0c`; if nonzero, computes `base_offset + backing_base + index*0x100`, and writes high bits to `object+0x48+index*4`. If backing base is zero, fallback/error-report path returns zero.
- `fn_dma_lookup_token_or_flag2_value` reads object fields `+0x00`, `+0x28`, `+0x2c`, `+0x30`; writes only high-bit table `object+0x48+index*4`; no `object+0x0c` write.
- `fn_dma_alloc_token_to_buffer_ptr_candidate` allocates/gets FPM token and translates using `fn_dma_translate_or_get_flag2_value`; requires `object+0x0c` already configured.
- `FUN_8009e168` / `fn_dma_free_token_to_fpm_candidate` frees token path; reads `object+0x0c`, writes high-bit table and token back to `*(object+0x00)+0x200`; no `object+0x0c` write.
- `fn_dma_buffer_ptr_to_token_candidate` converts buffer pointer to token. It reads `object+0x0c` and `object+0x48`; returns `0x80000000 | (index<<12) | (high_bits<<28)`. No `object+0x0c` write.
- `FUN_8009dc4c` / `fn_fpm_read_7bit_token_field_candidate` reads FPM hardware registers around `0xb2204000/0xb2204004`; ignores allocator object for writes; no `object+0x0c` write.
- `FUN_8009dcc0` / candidate `fn_fpm_set_token_multicast_count_candidate` validates token/count and writes modified token/count to `*(object+0x00)+0x224`; no `object+0x0c` write.
- `FUN_8009de2c` reads `object+0x48+index*4`, maps through `object+0x38+highbits*4`; reader only.
- `FUN_8009f728` returns allocator field `object+0x34` (`0x81848774` for static object); reader only.
- `FUN_8009f78c` wrapper around free-token path: core -> `FUN_8009e168`; consumer only.
- `FUN_8009f7e4` wrapper: core -> `fn_dma_alloc_token_to_buffer_ptr_candidate`; consumer only.
- `FUN_8009f814` diagnostic/config dump wrapper: core -> `FUN_8009e284(obj,1)`; consumer only.
- `FUN_8009e284` is diagnostic print/report function for Free Pool Manager configuration; calls snapshot helper then prints.
- `fn_dma_fpm_snapshot_config_and_counters` reads allocator/FPM registers and fills output arrays; no `object+0x0c` write.
- `FUN_8009f86c` wrapper: core -> `fn_dma_buffer_ptr_to_token_candidate` -> `FUN_8009dc4c`; consumer only.
- `FUN_8009f8cc` wrapper: core -> `fn_dma_buffer_ptr_to_token_candidate` -> `FUN_8009dcc0`; consumer only.

## Ghidra repair notes
- Many false splits were caused by callees incorrectly marked no-return / call-return flow overrides.
- Keep shared epilogues such as `LAB_8009e158` as labels, not functions.
- Preferred cleanup: change wrong call flow back to Default, press `D` on bytes after calls, delete false function headers only when they are real function objects; do not clear bytes unless needed.

## Current conclusion
`0x8184874c` / `object+0x0c` is confirmed as the FPM backing/base address used for token-to-buffer and buffer-to-token translation. Multiple consumers/readers confirmed. The writer/initializer for this field remains unfound.
