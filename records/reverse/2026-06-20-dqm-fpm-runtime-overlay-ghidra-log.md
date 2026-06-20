# 2026-06-20 DQM/FPM Runtime Overlay and Ghidra Cleanup Log
## Metadata
| Field | Value |
|---|---|
| Date | 2026-06-20 |
| Project | TC7200U / BCM3383 Ghidra reverse engineering |
| Program | `image.raw` |
| Output filename | `2026-06-20-dqm-fpm-runtime-overlay-ghidra-log.md` |
| Input labels file | `labels.json`, 1328 labels, SHA256 `6789cba97bf7880c3e2e15abfd0896b246c412450130cbe84cb27319e2fa3b1b` |
| Input structures file | `structures.h`, 63 structures, SHA256 `3bc1a12e348a846b77a6650507781ec75a67f165d0bd22fda9e1aa40ec82479f` |
| Target repo path | `records/reverse/2026-06-20-dqm-fpm-runtime-overlay-ghidra-log.md` |

## Executive summary
This pass turned the noisy `80c74cdc` DQM decompile from a misleading infinite loop with dozens of `Removing unreachable block` and `Read-only address is written` warnings into a usable DQM/FPM runtime-overlay analysis view. The main conclusion is that the `0x40000000` value seen in the DQM paths is a DQM/FPM token flag, not proven peripheral IRQ bit30. The pass also confirmed the FPM endpoint map at `0xb2200200+` / `0x12200200+`, separated the `B4E00118` ENET pinmux/control word from IRQ status/mask work, and preserved the unresolved IRQ13 task as a separate GENET/peripheral interrupt problem.

Major result: the cleaned decompile now has a real service-exit return path and repeatedly re-reads `DQM_EVENT_FIFO_PENDING_FLAGS_80008120_candidate` while draining `DQM_QUEUE_EVENT_FIFO_16045740_candidate`. The previous warning flood was a Ghidra modeling conflict: the static image starts at `0x80004000`, but the DQM runtime reuses part of `0x80004000/0x80008000` as writable state. The correct approach is to keep the main Ghidra program preserving boot code and use a separate runtime-overlay analysis copy for the volatile DQM state model.

## Provenance and working inputs
- `labels.json` now contains the carried label/comment set exported from Ghidra. It includes the new DQM runtime-state labels, FPM endpoint labels, PERIPH IRQ candidate labels, and DQM/FPM function names.
- `structures.h` contains the carried datatype work. The current relevant structures are `dqm_runtime_state_80004000_candidate`, `dqm_runtime_event_state_80008000_candidate`, `tc7200_fpm_endpoint_registers_candidate`, `tc7200_fpm_allocator`, `tc7200_fpm_packet_allocator`, `tc7200_fpm_packet_inner_header`, and `tc7200_fpm_packet_header`.
- Ghidra project context: keep the live static image program intact; perform runtime overlay cleanup only in the copied runtime-analysis program.

## Label/category counts from current export
| Category search | Count in current labels export |
|---|---:|
| `DQM_EVENT1800008` | 15 |
| `DQM_EVENT_FIFO` | 2 |
| `DQM_RUNTIME` | 33 |
| `DQM_CP2` | 100 |
| `FPM_ENDPOINT` | 33 |
| `PERIPH_IRQ` | 4 |
| `PERIPH_CTRL` | 1 |

## Memory block and region status
| Region/block | Range | Result / meaning |
|---|---:|---|
| `MMIO_FPM_PHYS_12200000` | `12200000-12200fff` | physical FPM window |
| `MMIO_FPM_KSEG1_B2200000` | `b2200000-b2200fff` | KSEG1 FPM MMIO alias; current block may be named MMIO_FPM_GMAC0_KSEG1_B2200000_candidate |
| `MMIO_GENET_PHYS_12C00000` | `12c00000-12c03fff` | physical GENET/GMAC candidate window |
| `MMIO_GENET_KSEG1_B2C00000` | `b2c00000-b2c03fff` | KSEG1 GENET/GMAC candidate window |
| `MMIO_PERIPH_INTC_PHYS_14E00000` | `14e00000-14e00fff` | physical peripheral IRQ/control window |
| `MMIO_PERIPH_INTC_KSEG1_B4E00000 split` | `b4e00000-b4e00117 and b4e0011c-b4e00fff` | split around existing B4E00118 word |
| `MMIO_PERIPH_CTRL_REG_B4E00118_candidate` | `b4e00118-b4e0011b` | existing ENET pinmux/control word; keep separate from IRQ status/mask |

Notes:
- `B2200000-B2200FFF` already existed as the FPM KSEG1 block. Do not recreate it. Rename to `MMIO_FPM_KSEG1_B2200000` when convenient, because the current `FPM_GMAC0` wording can mix FPM and GMAC semantics.
- `B4E00118-B4E0011B` already existed as a 4-byte block. It has ENET init xrefs and should remain separate. The full `B4E00000` KSEG1 periph window must be split around that word if modeled.
- Physical `14E00048/14E0004C` and KSEG1 `B4E00048/B4E0004C` are still IRQ status/mask candidates only. Do not convert them into final semantics until OEM write sites prove status/mask/ack behavior.

## FPM endpoint map confirmed
| Pool/request size | Physical address | KSEG1 address | Label family |
|---:|---:|---:|---|
| `0x800` | `12200200` | `B2200200` | `FPM_ENDPOINT_800` |
| `0x400` | `12200208` | `B2200208` | `FPM_ENDPOINT_400` |
| `0x200` | `12200210` | `B2200210` | `FPM_ENDPOINT_200` |
| `0x100` | `12200218` | `B2200218` | `FPM_ENDPOINT_100` |

Interpretation:
- `B2200200` is the common visible endpoint used by several token return paths.
- `B2200208/B2200210/B2200218` are additional pool-class endpoints selected by `fn_dma_get_hw_alloc_free_addr_by_pool_size_8009de50`.
- `FPM_ENDPOINT_*` writes are token/data return paths, not normal descriptor-ring writes.
- Avoid `POOL0` wording unless pool numbering is later proven; `800/400/200/100` is safer because it follows the endpoint/request size mapping.

## Runtime overlay cleanup result
### Before
- `fn_dqm_event1800008_service_loop_and_fpm_dispatch_80c74cdc_candidate` decompiled as a damaged `do { ... } while(true)` with no meaningful exit.
- Ghidra removed many reachable blocks as unreachable.
- Ghidra printed repeated `Read-only address is written` warnings for addresses such as `0x8000404a`, `0x800041e8`, `0x800041ec`, `0x80004218`, and `0x8000421c`.
- `8000811c/80008120` initially appeared as function/code-style state, producing bad expressions such as `FUN_8000811c & 0x3f0000`.

### Fix
- Created or used a copied Ghidra program for runtime DQM overlay analysis.
- Cleared the runtime-overlaid `0x80004000-0x800081ff` range in the copied program only.
- Applied volatile/runtime datatypes and labels to DQM runtime state at `0x80004000/0x80008000`.
- Preserved the main Ghidra program with the original static boot/code bytes intact.

### After
- The unreachable-block and read-only-write warning flood is gone in the cleaned paste.
- `DQM_EVENT_FIFO_PENDING_FLAGS_80008120_candidate` is recognized and re-read during the FIFO drain.
- A real return path is visible through the `bVar4` service gate.
- Remaining `uRam*`, `iRam*`, `cRam*`, and `sRam*` forms are now ordinary cleanup targets, not a structural decompiler failure.

## Runtime labels applied / to preserve
| Address | Type | Label |
|---:|---|---|
| `80004041` | `byte` | `DQM_RUNTIME_ENABLE_OR_ACTIVE_BYTE_80004041_candidate` |
| `80004042` | `byte` | `DQM_RUNTIME_TRACE_DISABLE_BYTE_80004042_candidate` |
| `8000404a` | `vuint16_t` | `DQM_CP2_POOL_CLASS_DEBUG_8000404A_candidate` |
| `80004050` | `vuint32_t` | `DQM_RUNTIME_TRACE_QUEUE_MASK_80004050_candidate` |
| `80004068` | `vuint32_t` | `DQM_RUNTIME_SERVICE_MASK_80004068_candidate` |
| `800040b4` | `vuint32_t` | `DQM_RUNTIME_SPECIAL_SERVICE_MASK_800040B4_candidate` |
| `800040bc` | `vuint32_t` | `DQM_RUNTIME_ACTIVE_QUEUE_MASK_800040BC_candidate` |
| `800040c0` | `vuint32_t` | `DQM_RUNTIME_EVENT1800008_MASK_800040C0_candidate` |
| `800040c4` | `vuint32_t` | `DQM_RUNTIME_EVENT07_PULL_QUEUE_MASK_800040C4_candidate` |
| `800041e8` | `vuint32_t` | `DQM_CP2_TRACE_OR_CMD_COUNT_800041E8_candidate` |
| `800041ec` | `vuint32_t` | `DQM_CP2_TRACE_OR_CMD_SIZE_800041EC_candidate` |
| `800041f8` | `vuint32_t` | `DQM_QUEUE_TOKEN_OR_CMD_REJECT_COUNT_800041f8_candidate` |
| `800041fc` | `vuint32_t` | `DQM_QUEUE_TOKEN_WORD_NOT_VALID_COUNT_800041fc_candidate` |
| `80004200` | `vuint32_t` | `DQM_QUEUE_TOKEN_NONZERO_LOW12_COUNT_80004200_candidate` |
| `80004208` | `vuint32_t` | `DQM_QUEUE_TOKEN_ZERO_LOW12_COUNT_80004208_candidate` |
| `80004210` | `vuint32_t` | `DQM_CP2_SUBMIT_TIMEOUT_COUNT_80004210_candidate` |
| `80004218` | `vuint32_t` | `DQM_QUEUE_ERROR_CODE_80004218_candidate` |
| `8000421c` | `vuint32_t` | `DQM_CP2_ERROR_DEBUG_8000421C_candidate` |
| `800050c8` | `vuint32_t` | `DQM_CP2_QUEUE_AUX_800050C8_candidate` |
| `800050cc` | `vuint32_t` | `DQM_CP2_QUEUE_TABLE_WORD_800050CC_candidate` |
| `80008000` | `vuint32_t` | `DQM_RUNTIME_SELECTOR_ACTIVE_MASK_80008000_candidate` |
| `8000800c` | `vuint32_t` | `DQM_EVENT1800008_PENDING_STATUS_8000800C_candidate` |
| `80008094` | `vuint32_t` | `DQM_CP2_SUBMIT_BUSY_OR_LOCK_80008094_candidate` |
| `8000809c` | `vuint32_t` | `DQM_CP2_RETURN_TOKEN_8000809C_candidate` |
| `80008120` | `vuint32_t` | `DQM_EVENT_FIFO_PENDING_FLAGS_80008120_candidate` |
| `800081c0` | `vuint32_t` | `DQM_RUNTIME_EVENT07_SKIP_PULL_MASK_800081C0_candidate` |

Important caveat: in the main static image program, `0x80004040` is real decoded boot code. Do not clear or retype that range in the main program. Runtime DQM state is modeled in the copied overlay-analysis program only.

## Datatypes and structures
The following structures are the current high-value datatype state. Keep `_candidate` on incomplete/provisional structures. Field names that are now clear can be used in comments and decompiles, but do not mass-remove `_candidate` from the structures.

### `dqm_runtime_state_80004000_candidate`
```c
struct dqm_runtime_state_80004000_candidate {
    uint8_t reserved_00[65];
    uint8_t runtime_enable_or_active_byte_41_candidate;
    uint8_t trace_disable_byte_42_candidate;
    uint8_t reserved_43[7];
    vuint16_t cp2_pool_class_debug_4a_candidate;
    uint8_t reserved_4c[4];
    vuint32_t trace_queue_mask_50_candidate;
    uint8_t reserved_54[20];
    vuint32_t service_mask_68_candidate;
    uint8_t reserved_6c[72];
    vuint32_t special_service_mask_b4_candidate;
    uint8_t reserved_b8[4];
    vuint32_t active_queue_mask_bc_candidate;
    vuint32_t event1800008_mask_c0_candidate;
    vuint32_t event07_pull_queue_mask_c4_candidate;
};
```

### `dqm_runtime_event_state_80008000_candidate`
```c
struct dqm_runtime_event_state_80008000_candidate {
    vuint32_t selector_active_mask_00_candidate;
    uint8_t reserved_04[8];
    vuint32_t event1800008_pending_status_0c_candidate;
    uint8_t reserved_10[132];
    vuint32_t cp2_submit_busy_or_lock_94_candidate;
    uint8_t reserved_98[4];
    vuint32_t cp2_return_token_9c_candidate;
    uint8_t reserved_a0[128];
    vuint32_t event_fifo_pending_flags_120_candidate;
    uint8_t reserved_124[156];
    vuint32_t event07_skip_pull_mask_1c0_candidate;
};
```

### `tc7200_fpm_endpoint_registers_candidate`
```c
struct tc7200_fpm_endpoint_registers_candidate {
    uint32_t endpoint_800_200_candidate;
    uint32_t reserved_204_candidate;
    uint32_t endpoint_400_208_candidate;
    uint32_t reserved_20c_candidate;
    uint32_t endpoint_200_210_candidate;
    uint32_t reserved_214_candidate;
    uint32_t endpoint_100_218_candidate;
};
```

### `tc7200_fpm_allocator`
```c
struct tc7200_fpm_allocator {
    uint32_t fpm_hw_base_kseg1_00_00; /* +0x00 */
    uint32_t board_or_buffer_class; /* +0x04 */
    uint32_t largest_default_pool_size; /* +0x08 */
    uint32_t fpm_backing_base_aligned; /* +0x0c */
    uint8_t embedded_flag_log_object[24]; /* +0x10..+0x27 */
    uint8_t pool_size_shift_bits; /* +0x28 */
    uint8_t pad_29[3]; /* +0x29..+0x2b */
    uint32_t pool_class_lookup_table_ptr; /* +0x2c */
    uint32_t max_largest_request_state; /* +0x30 */
    uint32_t fpm_extra_base_offset_or_headroom_candidate; /* +0x34, Extra base/headroom offset used in FPM token-to-buffer translation.    Used as:      data_addr = allocator->fpm_backing_base_aligned                + fpm_extra_base_offset_or_headroom_candidate                + token_index * 0x100 */
    uint32_t pool_size_table[4]; /* +0x38 */
    uint32_t token_highbits_table[32768]; /* +0x48 */
};
```

### `tc7200_fpm_packet_allocator`
```c
struct tc7200_fpm_packet_allocator {
    uint8_t embedded_flag_log_object[24]; /* +0x00..+0x17 */
    uint32_t packet_header_slot_size; /* +0x18 */
    uint32_t packet_header_arena_aligned; /* +0x1c */
    uint32_t main_fpm_allocator_ptr; /* +0x20 */
};
```

### `tc7200_fpm_packet_inner_header`
```c
struct tc7200_fpm_packet_inner_header {
    uint32_t data_addr; /* +0x00 */
    uint32_t requested_payload_len; /* +0x04 */
    uint8_t unknown_08[16]; /* +0x08..+0x1f */
    void *ptr_or_list_18; /* +0x18 */
    uint8_t unknown_1c[4]; /* +0x1c..+0x1f */
    uint16_t flags_20; /* +0x20 */
    uint8_t unknown_22[10]; /* +0x22..+0x2b */
    uint32_t fpm_extra_base_offset_saved; /* +0x2c */
};
```

### `tc7200_fpm_packet_header`
```c
struct tc7200_fpm_packet_header {
    void *free_callback; /* +0x00 */
    struct tc7200_fpm_packet_inner_header *inner_header; /* +0x04 */
    void *list_or_inner_ptr_a; /* +0x08 */
    uint32_t active_or_refcount; /* +0x0c */
    uint8_t unknown_10[16]; /* +0x10..+0x1f */
    struct tc7200_fpm_packet_inner_header embedded_inner; /* +0x20..+0x4f */
    uint8_t unknown_50[144]; /* +0x50..+0xdf */
};
```

### `tc7200_periph_irq_bank_candidate`
```c
struct tc7200_periph_irq_bank_candidate {
    uint32_t status_48_candidate;
    uint32_t mask_4c_candidate;
};
```

## Function labeling and signature changes
| Address | Function label | Current interpretation |
|---:|---|---|
| `80c74cdc` | `fn_dqm_event1800008_service_loop_and_fpm_dispatch_80c74cdc_candidate` | DQM event1800008 service loop; drains B6045740 FIFO, handles classes 7 and 0x0c, writes selected negative/token words to B2200200, now has visible return path after runtime overlay cleanup. |
| `80c73a3c` | `fn_dqm_event_fifo_class16_or_negative_token_to_fpm_endpoint800_80c73a3c_candidate` | DQM event FIFO class16/17 or negative-token helper; strips DQM token flag 0x40000000 when present, emits trace record 0x6c, writes cleaned token to FPM endpoint B2200200. |
| `80c73d54` | `FUN_80c73d54` | Common DQM trace/error record sink; next target to decode record ids 0x6c and 0x76. |
| `80c79ac0` | `fn_dqm_drain_cp2_f800_events_or_requeue_80c79ac0_candidate` | CP2 f800 event drain/requeue helper; event class 0x0c000000 can return event_token_or_data to FPM endpoint B2200200. |
| `80c79ba0` | `fn_dqm_cp2_event_drain_and_fpm_token_service_80c79ba0_candidate` | DQM IRQ-side CP2 event drain/FPM token service helper called by DQM IRQ/mailbox handler. |
| `8005fae8` | `fn_dqm_irq12_mailbox_event_handler_8005fae8_candidate` | Primary DQM IRQ/mailbox event handler; services queue/event status and calls 80c79ba0; not the GENET IRQ13 clear path. |
| `8005fa08` | `fn_dqm_event_mask_enable_disable_8005fa08_candidate` | DQM event/mask enable-disable helper for 0xb6001000. |
| `8009d0a0` | `fn_dma_fpm_driver_hw_init_8009d0a0` | DMA/FPM runtime hardware init; writes FPM HW base, allocates aligned backing storage, computes pool-class routing. |
| `8009f6a8` | `fn_dma_fpm_driver_hw_init_wrapper_8009f6a8` | Wrapper that calls hardware init with requested FPM buffer size and FPM HW base; runtime caller passes size 0x100 and base 0xb2200000. |
| `8002a7ec` | `fn_dma_fpm_alloc_token_for_size_8002a7ec` | Allocates/reads an FPM token using pool-class endpoint FPM_HW_BASE+0x200+pool_class*8. |
| `8009de50` | `fn_dma_get_hw_alloc_free_addr_by_pool_size_8009de50` | Endpoint selector; maps pool size to B2200200/B2200208/B2200210/B2200218 via pool class. |
| `8009e168` | `fn_dma_fpm_free_token_to_hw_8009e168` | Returns/free an FPM token to common endpoint allocator->fpm_hw_base+0x200, physical 0x12200200. |
| `803a8790` | `fn_enet_gmac_mbdma_global_init` | High-value GMAC MBDMA bridge init; writes FPM endpoint addresses into MBDMA/GENET-side registers. |
| `803ae840` | `fn_enet_unimac_mbdma_phy_init_803ae840_candidate` | Main ENET UNIMAC/MBDMA/PHY init body; touches B4E00118 ENET pinmux/control and calls GMAC/MBDMA global init; not the IRQ13 status/mask path. |

### Primary function comment to keep for `80c74cdc`
Paste in Ghidra as a plain function comment, without wrapping `/* */` into the comment field.

```text
DQM event1800008 service loop with FPM endpoint dispatch.

Behavior:
  - reads DQM global IRQ/status at b6001014
  - checks DQM_EVENT1800008_PENDING_STATUS_8000800C_candidate
  - services DQM_QUEUE_EVENT_STATUS at b6045a80
  - drains DQM_QUEUE_EVENT_FIFO at b6045740 while 80008120 has pending bits
  - parses event class from fifo_word0 >> 26
  - handles class 7 queue/event records
  - handles class 0x0c command-trigger records through b6045a20/b6045a24
  - forwards selected negative/token words to FPM endpoint b2200200
  - updates DQM runtime stats/counters in the 0x80004000/0x80008000 runtime-state overlay

Important:
  0x40000000 here is a DQM/FPM token flag, not proven periph IRQ13 bit30.

calls {@symbol fn_dqm_event_fifo_class16_or_negative_token_to_fpm_endpoint800_80c73a3c_candidate}
```

## Key behavior findings
### `0x40000000` classification
- In `80c73a3c` and the cleaned `80c74cdc` service loop, `0x40000000` is a DQM/FPM token flag.
- When set on a negative token/FIFO word, the code clears it with `& 0xbfffffff`, emits a DQM trace/error record (`0x6c` or `0x76` depending on path), and then writes the cleaned token/data to `B2200200`.
- This is not the same as the runtime OpenWrt IRQ13 guard value `periph_stat=0x40000004`. Do not label DQM token bit30 as peripheral IRQ bit30.

### DQM/FPM event loop
- The service loop reads `DQM_EVENT1800008_PENDING_STATUS_8000800C_candidate` and checks service bits such as `0x40000000`, `0x02000000`, `0x04000000`, and `0x08000000`.
- It drains `DQM_QUEUE_EVENT_FIFO_16045740_candidate` while `DQM_EVENT_FIFO_PENDING_FLAGS_80008120_candidate & 0x003f0000` is nonzero.
- Event class `7` is the main queue/event record path.
- Event class `0x0c` is the command-trigger path using `B6045A20/B6045A24`.
- Classes `0x16/0x17` dispatch to `fn_dqm_event_fifo_class16_or_negative_token_to_fpm_endpoint800_80c73a3c_candidate`.
- Class `0x18` dispatches to `FUN_80c73b10`; other classes dispatch to `FUN_80c73c04`.

### FPM allocator and packet lifecycle
- `fn_dma_fpm_driver_hw_init_8009d0a0` initializes the main FPM allocator, stores FPM KSEG1 base, allocates aligned backing memory, and builds the pool-class lookup table.
- `fn_dma_fpm_alloc_token_for_size_8002a7ec` reads an FPM token from `fpm_hw_base + 0x200 + pool_class * 8`.
- `fn_dma_fpm_token_to_backing_buffer_addr_8009dfec` converts token index to backing address: `backing_base + extra_base_offset + token_index * 0x100`.
- `fn_dma_fpm_backing_buffer_addr_to_token_8009e0a4` performs the reverse conversion and restores saved high bits.
- `fn_dma_fpm_free_token_to_hw_8009e168` writes valid tokens back to the common endpoint `B2200200`.
- The secondary packet allocator at `0x8187bc70` uses a slot size of `0xe0`, an aligned header arena, and a link to the main FPM allocator.

### ENET/GMAC relationship
- `B4E00118` has ENET init xrefs and is better treated as `PERIPH_CTRL_REG_B4E00118_candidate` / ENET pinmux/control, not IRQ status.
- `fn_enet_unimac_mbdma_phy_init_803ae840_candidate` touches `B4E00118` and calls the GMAC/MBDMA global init path.
- `fn_enet_gmac_mbdma_global_init` uses the FPM endpoint wrappers and writes FPM endpoint addresses into GMAC/MBDMA/GENET-side registers.
- This strengthens the OEM path hypothesis: vendor Ethernet traffic uses DQM/FPM/UNIMAC/MBDMA plumbing, not only upstream direct `bcmgenet` TDMA.

## IRQ13 / periph interrupt status separation
Keep these as separate unresolved work:

```text
B4E00048  PERIPH_IRQ_STATUS_B4E00048_candidate
B4E0004C  PERIPH_IRQ_MASK_B4E0004C_candidate
14E00048  PERIPH_IRQ_STATUS_14E00048_candidate
14E0004C  PERIPH_IRQ_MASK_14E0004C_candidate
B2C0xxxx  GENET/GMAC ISR/status/ack candidates, not yet mapped
```

Do not combine the DQM/FPM `0x40000000` token flag with the OpenWrt IRQ13 guard observation. The IRQ13 runtime clue remains: Linux IRQ13 reaches `bcmgenet_isr0()`, but the current upstream-style clear path probably does not clear the true BCM3383 source. Find OEM status/ack/mask writes for the `B4E00048/B4E0004C` path before changing OpenWrt assumptions.

## Ghidra cleanup decisions made
- Do not clear `0x80004000-0x800081ff` in the main program; that would destroy useful static boot-code analysis.
- Use `tc7200u-runtime-dqm-overlay-analysis` or equivalent copied program for runtime-state decompilation cleanup.
- Remove/avoid false child functions inside parent DQM service loops when they are only labels and use parent stack/register state.
- Keep `_candidate` on functions/structures where behavior is clear enough to use but not fully vendor-confirmed.
- Do not rename raw registers or decompiler temporaries; only rename real symbols, globals, functions, fields, structures, and decompiler-visible variables where useful.
- Keep comments in Ghidra annotation style with `{@symbol ...}` and `{@address ...}` when referencing known functions/addresses.

## Remaining cleanup targets
1. Decode `FUN_80c73d54`, the common DQM trace/error record sink, to explain record IDs `0x6c` and `0x76`.
2. Continue cleaning `uRam*/iRam*/cRam*/sRam*` auto globals in the runtime overlay copy only.
3. Inspect `FUN_80c73b10` and `FUN_80c73c04` for other event classes from the DQM FIFO.
4. Continue DQM CP2 event service helpers: `80c79ac0`, `80c79ba0`, `80c7a3a4`, `80c7d618`, `80c7d99c`.
5. For IRQ13, search writes/xrefs to `B4E00048/B4E0004C` and GENET/GMAC ISR status/ack offsets; do not use the DQM/FPM token flag as proof.
6. Clean duplicate function comments in exported labels where both plate and function comments were copied twice.

## Suggested repo commit
Target location:

```text
records/reverse/2026-06-20-dqm-fpm-runtime-overlay-ghidra-log.md
```

Commit message:

```text
reverse: record DQM FPM runtime overlay cleanup
```

WSL one-liner after downloading/copying this file into the repo:

```sh
cd ~/tc7200u-research; mkdir -p records/reverse; cp -av /mnt/c/Users/mgta29/Downloads/2026-06-20-dqm-fpm-runtime-overlay-ghidra-log.md records/reverse/2026-06-20-dqm-fpm-runtime-overlay-ghidra-log.md; git status --short; git add records/reverse/2026-06-20-dqm-fpm-runtime-overlay-ghidra-log.md; git diff --cached --stat; git commit -m "reverse: record DQM FPM runtime overlay cleanup"
```

If the browser saves the file somewhere else, replace the `cp -av` source path only. Do not delete or overwrite existing logs.

## Bottom line
The current Ghidra pass converted DQM/FPM runtime state from decompiler noise into a usable model. The confirmed path is DQM event/status handling, FIFO draining, token classification, and FPM endpoint writes at `B2200200+`. The confirmed non-result is equally important: this does not solve GENET IRQ13. The next reverse-engineering fork should decode the DQM trace sink and continue DQM/FPM service helpers, while the IRQ13 work remains focused on OEM periph IRQ and GENET/GMAC status/ack/mask write sequences.
