# 2026-06-28 - DQM Slot-Region, Request-Engine, and CP2 Event-Drain Findings

## Metadata

| Field | Value |
|---|---|
| Project | `tc7200u-research` |
| Target | Technicolor TC7200U / BCM3383 stage1 firmware |
| Architecture | `MIPS:BE:32:default` |
| Ghidra image base | `0x80004000` |
| Work area | DQM / CP2 / FPM event path |
| Record date | `2026-06-28` |
| Output file | `2026-06-28-dqm-slot-region-cp2-event-drain.md` |
| Intended repo target | `u:\home\mgta29\tc7200u-research\records\reverse\` |

## Scope of this log

This record covers the Ghidra reverse-engineering work performed around the DQM slot-region programming path, the DQM request-engine chunked submit helper, CP2 event-drain handling, FPM token-return behavior, volatile datatype cleanup, runtime memory-block handling, and a newly mapped candidate MMIO/table block at `b4c000c0`.

Main functions covered:

```text
80061020  fn_dqm_read_slot_region_word_80061020_candidate
80c7990c  fn_dqm_write_slot_region_word_80c7990c_candidate
80c7aca0  fn_dqm_select_free_region_and_program_context_80c7aca0_candidate
80c7b700  fn_dqm_hw_region_submit_wait_chunked_80c7b700_candidate
80c79950  fn_dqm_submit_region_20bytes_with_0530_0538_masked_80c79950_candidate
80c79ba0  fn_dqm_cp2_event_drain_and_fpm_token_service_80c79ba0_candidate
```

---

# 1. Volatile datatype cleanup

## 1.1 Key rule confirmed

Do **not** make base `uint32_t` volatile globally.

Only the project-specific MMIO/runtime aliases should be volatile:

```c
typedef volatile unsigned char      vuint8_t;
typedef volatile unsigned short     vuint16_t;
typedef volatile unsigned int       vuint32_t;
typedef volatile unsigned long long vuint64_t;
```

Correct category:

```text
/tc7200u/mmio
```

Correct application pattern:

```text
/tc7200u/mmio/vuint32_t
/tc7200u/mmio/vuint16_t
/tc7200u/mmio/vuint8_t
```

Avoid applying pointer forms unless the actual object is a pointer:

```text
vuint32_t      correct for MMIO/runtime words
vuint32_t *    only correct for pointer variables such as 80007040/80007050/80007054
```

## 1.2 Ghidra typedef creation issue

Ghidra's **Create TypeDef** dialog does not accept C declarations such as:

```c
volatile unsigned int
```

Instead, create the typedef from an existing base type such as `uint32_t` or `uint`, then set the typedef's **Mutability** setting to `volatile`.

Correct process:

```text
Create TypeDef:
  Name:      vuint32_t
  Data type: uint32_t
  Category:  /tc7200u/mmio

Then:
  Right click vuint32_t
  Settings / Default Settings
  Mutability = volatile
  Use Default unchecked
```

## 1.3 Runtime words requiring volatile data

```text
80007040  DQM_CMD_ENGINE_DESCRIPTOR_WORD_PTR_80007040_candidate     vuint32_t *
80007048  DQM_ACTIVE_SLOT_MASK_80007048_candidate                   vuint32_t
80007050  DQM_CP2_EVENT_COUNTERS_PTR_80007050_candidate             vuint32_t *
80007054  DQM_CP2_EVENT_TOKEN_DEFER_TABLE_PTR_80007054_candidate    vuint32_t *
80007058  DQM_CP2_SELECTOR_DEFER_MASK_80007058_candidate            vuint32_t
80007060  DQM_SLOT_SERVICE_COUNT_SLOT0_80007060_candidate           vuint32_t
80007064  DQM_SLOT_SERVICE_HIGHWATER_SLOT0_80007064_candidate       vuint32_t
80007068  DQM_SLOT_ASSIGNED_QUOTA_SLOT0_80007068_candidate          vuint32_t
8000706c  DQM_SLOT_QUOTA_EXCEEDED_COUNT_SLOT0_8000706C_candidate    vuint32_t
8000718c  DQM_CP2_DIRECT_FPM_RETURN_COUNT_8000718C_candidate        vuint32_t
80008008  DQM_CP2_F800_PENDING_STATUS_80008008_candidate            vuint32_t
80008060  DQM_CP2_REINJECT_OR_RETURN_MODE_80008060_candidate        vuint32_t
80008098  DQM_SLOT_SERVICE_RESULT_INDEX_80008098_candidate          vuint32_t
800080a0  DQM_SLOT_SERVICE_WAIT_STATUS_800080A0_candidate           vuint32_t
800080a4  DQM_SLOT_SERVICE_RESULT_STATUS_800080A4_candidate         vuint32_t
800080a8  DQM_RESULT_ACK_WAIT_STATUS_800080A8_candidate             vuint32_t
800080b0  DQM_RESULT_SERVICE_WAIT_STATUS_800080B0_candidate         vuint32_t
800080b4  DQM_SLOT_SERVICE_ACK_SOURCE_800080B4_candidate            vuint32_t
800080b8  DQM_SLOT_CTRL180_BUSY_STATE_800080B8_candidate            vuint32_t
800080c4  DQM_RUNTIME_EVENT07_SKIP_PULL_MASK_800080C4_candidate     vuint32_t
800080d0  DQM_SLOT_SERVICE_MODE_FLAGS_800080D0_candidate            vuint32_t
800080d4  DQM_SLOT_SELECTOR_BUSY_STATUS_800080D4_candidate          vuint32_t
800080e4  DQM_CP2_SERVICE_DRAIN_STATUS_800080E4_candidate           vuint32_t
800080e8  DQM_CP2_SPECIAL_EVENT_STATUS_800080E8_candidate           vuint32_t
800080ec  DQM_SLOT_CTRLCC_MODE_FLAGS_800080EC_candidate             vuint32_t
```

---

# 2. Memory block findings and changes

## 2.1 Runtime RAM blocks

The `80007xxx` and `80008xxx` regions contain runtime state words that Ghidra may initially treat as loaded code bytes or constants. This causes decompiler symptoms such as:

```text
WARNING: Read-only address (ram,0x80007048) is written
WARNING: Read-only address (ram,0x80007058) is written
WARNING: Read-only address (ram,0x8000718c) is written
WARNING: Removing unreachable block ...
```

Correct handling:

```text
80007000..80007fff  runtime mutable state, rw, volatile=true, execute=false
80008000..800081ff  runtime mutable state, rw, volatile=true, execute=false
80008200..8183ff07  normal loaded image/code/data, volatile=false
```

Do **not** make the whole `ram` block volatile.

## 2.2 Newly mapped candidate MMIO/table block

A small candidate runtime block was added because the CP2 event drain function constructs `b4c000c0` and `b4c000e2`, but those addresses were not mapped in the current Ghidra image.

Block:

```text
Name:       MMIO_B4C000C0_candidate
Start:      b4c000c0
End:        b4c000e3
Length:     0x24
Type:       Uninitialized
Read:       true
Write:      true
Execute:    false
Volatile:   true
```

Layout:

```text
b4c000c0  vuint16_t[16]  DQM_CMD_DC_LOW14_MATCH_TABLE_B4C000C0_candidate
b4c000e0  undefined      padding/reserved
b4c000e1  undefined      padding/reserved
b4c000e2  vuint16_t      DQM_CMD_DC_LOW14_ACTIVE_MASK_B4C000E2_candidate
```

Observed XREFs for the mask word:

```text
b4c000e2  DQM_CMD_DC_LOW14_ACTIVE_MASK_B4C000E2_candidate
  80c7a218(R)
  80c7a220(W)
  FUN_80c86dd8:80c86f70(R)
  FUN_80c86dd8:80c86f78(W)
```

Important constraint:

```text
Do not create a large b4c00000 block yet.
Only the small b4c000c0..b4c000e3 block is justified by current xrefs.
```

---

# 3. Datatypes and structures

## 3.1 `dqm_slot_region20_entry_candidate`

Category:

```text
/tc7200u/mmio
```

Structure:

```c
struct dqm_slot_region20_entry_candidate {
    vuint32_t word_00;
    vuint32_t word_04;
    vuint32_t word_08;
    vuint32_t word_0c;
    vuint32_t word_10;
    vuint32_t word_14;
    vuint32_t word_18;
    vuint32_t word_1c;
};
```

Length:

```text
0x20 bytes
```

Applied as an array:

```text
b6041000  dqm_slot_region20_entry_candidate[16]  DQM_SLOT_REGION20_BASE_16041000_candidate
```

Reason:

```text
Each DQM slot-region entry is 0x20 bytes.
Pointer arithmetic on DQM_SLOT_REGION20_BASE_16041000_candidate + index must scale by 0x20, not by 4.
```

## 3.2 `dqm_slot_program_context_30_candidate`

Category:

```text
/tc7200u/dqm
```

Candidate structure:

```c
struct dqm_slot_program_context_30_candidate {
    uint32_t request_word_00;                     // ctrl580 input; low20 copied to slot word +0x00
    uint32_t slot_word0c_mid5_04_candidate;       // low5 -> slot word +0x0c bits 20..16
    uint32_t slot_word0c_high5_08_candidate;      // low5 -> slot word +0x0c bits 25..21
    uint32_t slot_word04_0c_candidate;            // copied to slot word +0x04
    uint32_t field_10_unknown;
    uint32_t selector_mode_flag_14_candidate;     // 0 -> selector mode uses 0x200, nonzero -> 0x300
    uint32_t optional_high16_enable_18_candidate; // if == 1, uses +0x1c low16 in selector word
    uint16_t optional_high16_value_1c_candidate;  // shifted into selector bits 31..16
    uint16_t pad_or_field_1e_candidate;
    uint32_t field_20_unknown;
    uint32_t slot_word08_count_24_candidate;      // (value - 1) low7 -> slot word +0x08 bits 30..24
    uint32_t selected_slot_index_28;              // output on success
    uint32_t status_code_2c;                      // output on failure
};
```

## 3.3 `dqm_cp2_b604_selector_program_block_candidate`

The `b6040400` block was refined. Important fields:

```c
struct dqm_cp2_b604_selector_program_block_candidate {
    uint8_t   reserved_000_100[0x100];       // b6040400..b60404ff
    vuint32_t region_slot_alloc_bitmap_100;  // b6040500, low16 used-slot bitmap
    uint8_t   reserved_104_110[0x0c];        // b6040504..b604050f
    vuint32_t selector_program_mask_110;     // b6040510

    uint8_t   reserved_114_130[0x1c];        // b6040514..b604052f
    vuint32_t region_access_ctrl_130;        // b6040530
    vuint32_t region_access_mask_134;        // b6040534
    vuint32_t region_access_ctrl_138;        // b6040538
    vuint32_t region_access_mask_13c;        // b604053c
    uint8_t   reserved_140_164[0x24];        // b6040540..b6040563

    vuint32_t selector_a_164;                // b6040564
    vuint32_t selector_b_168;                // b6040568
    uint8_t   reserved_16c_1c0[0x54];
    vuint32_t selector_a_1c0;                // b60405c0
    vuint32_t selector_b_1c4;                // b60405c4
};
```

Key correction:

```text
b6040530..b604053c are not anonymous reserved slice fields.
They are access-control/mask words used by read/write/submit helpers around the b6041000 slot-region window.
```

## 3.4 `fpm_endpoint_block_20_candidate`

Existing interpretation retained:

```c
struct fpm_endpoint_block_20_candidate {
    vuint32_t endpoint_800_00;
    vuint32_t reserved_04;
    vuint32_t endpoint_400_08;
    vuint32_t reserved_0c;
    vuint32_t endpoint_200_10;
    vuint32_t reserved_14;
    vuint32_t endpoint_100_18;
    vuint32_t reserved_1c;
};
```

Applied at:

```text
b2200200  FPM_ENDPOINTS_B2200200_candidate
```

Important conclusion:

```text
Writes to b2200200 in the analyzed DQM/CP2 path are FPM token/data return paths.
They are not GENET TDMA descriptor writes.
```

---

# 4. Function findings

## 4.1 `fn_dqm_read_slot_region_word_80061020_candidate`

Address:

```text
80061020
```

Signature:

```c
uint32_t fn_dqm_read_slot_region_word_80061020_candidate(uint32_t slot_index, uint32_t field_offset)
```

Behavior:

```text
- computes read address:
    b6041000 + slot_index * 0x20 + (field_offset & ~3)
- saves b6040530 and b6040538
- writes b6040534 = 0xffffffff
- writes b604053c = 0xffffffff
- reads one 32-bit word from the computed slot-region address
- restores b6040530 and b6040538
- returns the read word
```

Current interpretation:

```text
Read-side helper for the DQM per-slot 0x20-byte region at b6041000.
The temporary writes to b6040534/b604053c look like access-mask or selector-window overrides.
```

Status:

```text
Done.
```

## 4.2 `fn_dqm_write_slot_region_word_80c7990c_candidate`

Address:

```text
80c7990c
```

Signature:

```c
void fn_dqm_write_slot_region_word_80c7990c_candidate(
    uint32_t slot_index,
    uint32_t field_offset,
    uint32_t value)
```

Behavior:

```text
- computes write address:
    b6041000 + slot_index * 0x20 + (field_offset & ~3)
- saves b6040530 and b6040538
- writes b6040534 = 0xffffffff
- writes b604053c = 0xffffffff
- writes value to the computed slot-region address
- restores b6040530 and b6040538
- returns
```

Status:

```text
Done.
```

## 4.3 `fn_dqm_select_free_region_and_program_context_80c7aca0_candidate`

Address:

```text
80c7aca0
```

Signature:

```c
uint32_t fn_dqm_select_free_region_and_program_context_80c7aca0_candidate(
    dqm_slot_program_context_30_candidate *region_ctx)
```

Confirmed behavior:

```text
- submits ctrl580 using region_ctx->request_word_00
- ctrl580 result 0:
    region_ctx->status_code_2c = 0
    return 0
- ctrl580 result 2:
    region_ctx->status_code_2c = 1
    return 0
- reads b6040500 low16 region-slot allocation bitmap
- scans low 16 bits for the first clear slot bit
- if all low16 bits are set:
    region_ctx->status_code_2c = 2
    return 0
- initializes/submits several per-slot hardware/state regions:
    b6040700 + slot*4,    length 0x04
    b6041000 + slot*0x20, length 0x20 through 80c79950
    b6042000 + slot*0x40, length 0x40
    b6046000 + slot*0x10, length 0x10
    b6043000 + slot*0x40, length 0x40
- programs slot-region words at b6041000 + slot*0x20
- writes final selector mode to b604008c
- calls quota rebalance/program helper
- stores selected slot index to region_ctx->selected_slot_index_28
- returns 1 on success
```

Failure/status outputs:

```text
region_ctx +0x2c = 0  ctrl580 result 0 or later hardware-region submit failed
region_ctx +0x2c = 1  ctrl580 result 2
region_ctx +0x2c = 2  no free low16 slot bit in b6040500
```

Success output:

```text
region_ctx +0x28 = selected slot index
return 1
```

Slot-region programming:

```text
slot +0x00 = region_ctx->request_word_00 & 0x000fffff
slot +0x04 = region_ctx->slot_word04_0c
slot +0x08 = ((region_ctx->slot_word08_count_24 - 1) & 0x7f) << 24
slot +0x0c = ((region_ctx->slot_word0c_high5_08 & 0x1f) << 21) |
             ((region_ctx->slot_word0c_mid5_04  & 0x1f) << 16)
slot +0x14 = 1000
```

Final selector mode:

```c
selector_mode = selected_slot_index | 0x80;

if (region_ctx->optional_high16_enable_18 == 1) {
    selector_mode |= region_ctx->optional_high16_value_1c << 16;
}

if (region_ctx->selector_mode_flag_14 == 0) {
    final_ctrl = selector_mode | 0x200;
} else {
    final_ctrl = selector_mode | 0x300;
}

DQM_SLOT_SELECTOR_MODE_B604008C_candidate = final_ctrl;
```

Status:

```text
Done for this pass.
```

## 4.4 `fn_dqm_hw_region_submit_wait_chunked_80c7b700_candidate`

Address:

```text
80c7b700
```

Signature:

```c
uint32_t fn_dqm_hw_region_submit_wait_chunked_80c7b700_candidate(
    uint32_t region_base,
    uint32_t region_size)
```

Important decompiler correction:

```text
The decompiler may show:
  DQM_REQUEST_ENGINE_WORD2_ZERO_16001308_candidate = 0x8c620334;
  _DAT_8c620334 = 0x80000fc;

This is wrong.

Assembly proves:
  descriptor_word_ptr = *(vuint32_t **)0x80007040;
  *(vuint32_t **)0xb6001308 = descriptor_word_ptr;
  descriptor_word_ptr[0] = 0x080000fc;
```

Correct label/type:

```text
80007040  DQM_CMD_ENGINE_DESCRIPTOR_WORD_PTR_80007040_candidate  vuint32_t *
b6001308  DQM_REQUEST_ENGINE_DESCRIPTOR_PTR_16001308_candidate   vuint32_t
```

Behavior:

```text
- converts region_base to a low 29-bit bus/physical address:
    current_chunk_bus_addr = region_base & 0x1fffffff
- loads descriptor_word_ptr from 80007040
- writes descriptor_word_ptr to b6001308
- writes descriptor_word_ptr[0] = 0x080000fc for full 0xfc-byte chunks
- submits full chunks while the engine accepts them:
    b6001304 = current_chunk_bus_addr
    b600130c = 0x00010000
    current_chunk_bus_addr += 0xfc
    region_size -= 0xfc
- tracks submitted-but-not-completed chunks with inflight_chunk_count
- uses b6001044 bit1 as submit-blocked / queue-full candidate
- uses b6001044 bit2 as completion/result-not-ready candidate
- reads b600131c when a completion/result is available
- if a short remainder remains:
    descriptor_word_ptr[0] = 0x08000000 | region_size
    submits the final short chunk through b6001304/b600130c
    waits for completion
    reads b600131c
- returns 1 after all chunks complete
```

Useful labels:

```text
b6001044  DQM_CMD_ENGINE_STATUS_16001044_candidate
b6001304  DQM_REQUEST_ENGINE_REGION_BASE_OR_TOKEN_16001304_candidate
b6001308  DQM_REQUEST_ENGINE_DESCRIPTOR_PTR_16001308_candidate
b600130c  DQM_REQUEST_ENGINE_SUBMIT_TRIGGER_1600130C_candidate
b600131c  DQM_REQUEST_ENGINE_RESULT_LOW12_1600131C_candidate
```

Status:

```text
Done after fixing 80007040 datatype.
```

## 4.5 `fn_dqm_submit_region_20bytes_with_0530_0538_masked_80c79950_candidate`

Address:

```text
80c79950
```

Signature:

```c
uint32_t fn_dqm_submit_region_20bytes_with_0530_0538_masked_80c79950_candidate(
    uint32_t region_index)
```

Important correction:

```text
This function returns the result from 80c7b700.
It should not be void.
```

Behavior:

```text
- computes region base:
    b6041000 + region_index * 0x20
- saves b6040530 and b6040538
- writes b6040534 = 0xffffffff
- writes b604053c = 0xffffffff
- submits 0x20 bytes through:
    fn_dqm_hw_region_submit_wait_chunked_80c7b700_candidate(region_base, 0x20)
- restores b6040530 and b6040538
- returns the submit helper result
```

Status:

```text
Done.
```

## 4.6 `fn_dqm_cp2_event_drain_and_fpm_token_service_80c79ba0_candidate`

Address:

```text
80c79ba0
```

Signature:

```c
uint32_t fn_dqm_cp2_event_drain_and_fpm_token_service_80c79ba0_candidate(void)
```

Return:

```text
returns 1 on normal drain/stop condition
```

Current interpretation:

```text
IRQ-side DQM event drain helper. It bridges CP2 event pulls, slot-service trigger/result handling, per-slot runtime accounting, FPM token/data return, CP2 reinjection, and internal DQM command emission.
```

Event source selection:

```text
If b6001820 bit 0x08000000 is set:
  pull event words from CP2 e004/e005/e006

Else:
  check 80008008 sign bit
  if pending, pull event words from CP2 f800/f800/f800
```

If no event is available:

```text
return 1
```

Event class decode:

```c
event_class = event_word0 & 0xfc000000;
```

Known classes:

```text
0x0c000000  main DQM/FPM token/event path
0x10000000  command/event path, may emit 0xdc
0x14000000  command/event path, emits 0xdd
other       stop and return 1
```

### Class `0x0c000000`

Main DQM/FPM token/event path:

```text
- validates event_word1_or_token low12 size field against 0x600
- if too large, emits cmd06(0xe2)
- if event_word2 has bits 0x06000000 set:
    writes event words to b6040100/b6040104/b6040108
    triggers slot service with b6040120 = 0x10
    waits on 800080a0 bit 0x10
    reads service status from 800080a4
    reads selected slot index from 80008098 low4
    may call fn_dqm_slot_service_finalize_and_bump_counter_80c7b534_candidate
    updates per-slot accounting at 80007060..8000706c
    may ack through b604012c/b6040128
    may drain ctrl180/token state through fn_dqm_drain_slot_ctrl180_and_return_token_80c7a3a4_candidate
- if not a slot-service event:
    either returns event_word1_or_token to FPM endpoint b2200200
    or reinjects it through CP2 e000/e001 depending on runtime mode/state
```

### Class `0x10000000`

Command/event path:

```text
- checks b6001094 and selector bits from event_word0
- may search the b4c000c0 16-bit low14 match table
- may clear one bit from b4c000e2
- emits command 0xdc through b6001d20/b6001d24
```

Low14 table behavior:

```text
search for:
  event_word0 & 0x3fff

inside:
  b4c000c0 + index*2, index 0..15

if matched:
  b4c000e2 &= ~(1 << index)
```

### Class `0x14000000`

Command/event path:

```text
b6001d20 = 0xdd
b6001d24 = event_word0
```

### FPM endpoint conclusion

All observed writes to:

```text
b2200200 / FPM_ENDPOINTS_B2200200_candidate.endpoint_800_00
```

in this function are token/data returns, not GENET TDMA descriptor writes.

Status:

```text
Semantically done enough for this pass.
Decompiler still removes blocks because of runtime RAM folding; assembly-level interpretation is reliable.
```

---

# 5. Important labels added or refined

## 5.1 DQM command/request engine

```text
80007040  DQM_CMD_ENGINE_DESCRIPTOR_WORD_PTR_80007040_candidate
b6001044  DQM_CMD_ENGINE_STATUS_16001044_candidate
b6001304  DQM_REQUEST_ENGINE_REGION_BASE_OR_TOKEN_16001304_candidate
b6001308  DQM_REQUEST_ENGINE_DESCRIPTOR_PTR_16001308_candidate
b600130c  DQM_REQUEST_ENGINE_SUBMIT_TRIGGER_1600130C_candidate
b600131c  DQM_REQUEST_ENGINE_RESULT_LOW12_1600131C_candidate
```

## 5.2 DQM selector / slot programming

```text
b604008c  DQM_SLOT_SELECTOR_MODE_B604008C_candidate
b6040500  DQM_REGION_SLOT_ALLOC_BITMAP_B6040500_candidate
b6040530  DQM_REGION_ACCESS_CTRL_0530_16040530_candidate
b6040534  DQM_REGION_ACCESS_MASK_0534_16040534_candidate
b6040538  DQM_REGION_ACCESS_CTRL_0538_16040538_candidate
b604053c  DQM_REGION_ACCESS_MASK_053C_1604053C_candidate
b6040700  DQM_REGION_SUBMIT_WORD_B6040700_candidate
b6041000  DQM_SLOT_REGION20_BASE_16041000_candidate
b6042000  DQM_SLOT_RUNTIME40_BASE_B6042000_candidate
b6043000  DQM_SLOT_REGION40_BASE_B6043000_candidate
b6046000  DQM_SLOT_REGION10_BASE_B6046000_candidate
```

## 5.3 DQM slot-service words

```text
b6040100  DQM_SLOT_SERVICE_WORD0_B6040100_candidate
b6040104  DQM_SLOT_SERVICE_WORD1_B6040104_candidate
b6040108  DQM_SLOT_SERVICE_WORD2_B6040108_candidate
b6040120  DQM_EVENT_SERVICE_TRIGGER_16040120_candidate
b6040128  DQM_RESULT_ACK_TRIGGER_16040128_candidate
b604012c  DQM_RESULT_ACK_VALUE_1604012C_candidate
b6040130  DQM_RESULT_SERVICE_TRIGGER_16040130_candidate
```

## 5.4 DQM command/event

```text
b6001094  DQM_CMD_EVENT_GATE_STATUS_B6001094_candidate
b6001d20  DQM_COMMAND_WORD_16001D20_candidate
b6001d24  DQM_COMMAND_ARG_OR_RETURN_PC_16001D24_candidate
b4c000c0  DQM_CMD_DC_LOW14_MATCH_TABLE_B4C000C0_candidate
b4c000e2  DQM_CMD_DC_LOW14_ACTIVE_MASK_B4C000E2_candidate
```

## 5.5 FPM

```text
b2200200  FPM_ENDPOINTS_B2200200_candidate
```

---

# 6. Tables and maps

## 6.1 DQM slot-region table

Base:

```text
b6041000
```

Type:

```c
dqm_slot_region20_entry_candidate[16]
```

Entry stride:

```text
0x20
```

Fields:

```text
+0x00  word_00  caller-built descriptor/control word
+0x04  word_04  copied from slot program context +0x0c
+0x08  word_08  high7 count/span field at bits 30..24
+0x0c  word_0c  two 5-bit fields at bits 25..21 and 20..16
+0x10  word_10  not yet named
+0x14  word_14  programmed as fixed value 1000 in 80c7aca0
+0x18  word_18  used by quota/rebalance path
+0x1c  word_1c  used by quota/rebalance path
```

## 6.2 DQM command low14 match table

Base:

```text
b4c000c0
```

Type:

```c
vuint16_t[16]
```

Mask word:

```text
b4c000e2  vuint16_t
```

Behavior:

```text
The 0x10000000 CP2 command/event path compares event_word0 low14 against the 16-entry table.
If a match is found, it clears the matching bit in b4c000e2 before emitting command 0xdc.
```

## 6.3 DQM slot runtime/accounting table

Candidate base:

```text
80007060 + slot_index * 0x10
```

Candidate layout:

```text
+0x00  DQM_SLOT_SERVICE_COUNT_SLOT0_80007060_candidate
+0x04  DQM_SLOT_SERVICE_HIGHWATER_SLOT0_80007064_candidate
+0x08  DQM_SLOT_ASSIGNED_QUOTA_SLOT0_80007068_candidate
+0x0c  DQM_SLOT_QUOTA_EXCEEDED_COUNT_SLOT0_8000706C_candidate
```

Use `vuint32_t` for the base words.

---

# 7. Decompiler issues and interpretation policy

## 7.1 Removed-unreachable blocks in `80c79ba0`

Warnings remain expected until all runtime `80007xxx/80008xxx` words and affected blocks are correctly treated as mutable volatile state:

```text
WARNING: Removing unreachable block ...
WARNING: Globals starting with '_' overlap smaller symbols at the same address
```

For this pass, do not fight every warning. The assembly-level interpretation is complete enough.

## 7.2 Fake constants from runtime RAM

Examples seen:

```text
1051000e
40f809
24680008
3442ffff
afb00000
8c620334
```

These are not semantic constants in the firmware logic. They are stale loaded image bytes or decompiler folding artifacts caused by runtime words initially being interpreted as code/data constants.

## 7.3 Function splitting caution

The following labels inside `80c79ba0` are internal control-flow labels/tails, not independent functions unless future xrefs prove otherwise:

```text
80c7a044
80c7a0e8
80c7a1c0
```

Do not split `80c79ba0`.

---

# 8. Results

## 8.1 Completed in this pass

```text
80061020  DQM slot-region read helper identified and documented
80c7990c  DQM slot-region write helper identified and documented
80c7aca0  DQM slot allocation/programming helper identified and documented
80c7b700  DQM request-engine chunked submit/wait helper identified and documented
80c79950  DQM 0x20-byte slot-region submit wrapper identified and documented
80c79ba0  DQM CP2 event drain / FPM token service helper semantically documented
```

## 8.2 Major confirmed conclusions

```text
- b6041000 is a 16-entry slot-region table with 0x20-byte entries.
- b6040530/0534/0538/053c are access-control/mask words used around b6041000 slot-region access.
- b6040500 low16 is a slot allocation/occupied bitmap in the allocation path.
- 80007040 is a runtime descriptor-word pointer used by the DQM request engine.
- b6001308 receives the descriptor pointer, not a literal value.
- b4c000c0/b4c000e2 form a small candidate command-event low14 table/mask block.
- b2200200 writes in this DQM/CP2 path are FPM token/data returns, not GENET TDMA descriptor writes.
```

## 8.3 Pending / next target

Recommended next function:

```text
80c7a3a4
fn_dqm_drain_slot_ctrl180_and_return_token_80c7a3a4_candidate
```

Why:

```text
It is reached from 80c79ba0 after slot-service/result handling and likely explains the ctrl180 drain path plus final FPM token return behavior.
```

---

# 9. Suggested Ghidra cleanup checklist

```text
[ ] Ensure /tc7200u/mmio/vuint32_t has Mutability=volatile.
[ ] Ensure base uint32_t is not volatile.
[ ] Ensure b6041000 is dqm_slot_region20_entry_candidate[16].
[ ] Ensure b4c000c0 is vuint16_t[16].
[ ] Ensure b4c000e2 is vuint16_t.
[ ] Ensure 80007040 is vuint32_t *.
[ ] Ensure 80007050 and 80007054 are vuint32_t *.
[ ] Ensure runtime words in 80007000..800081ff are vuint32_t, not pointers unless listed as pointer.
[ ] Keep MMIO_B4C000C0_candidate small: b4c000c0..b4c000e3 only.
[ ] Do not split 80c79ba0 based on Ghidra's fake unreachable blocks.
```

---

# 10. Commands to archive this record

## 10.1 Windows download location

Download this file from ChatGPT, then save/copy it to:

```text
C:\Users\mgta29\Downloads\2026-06-28-dqm-slot-region-cp2-event-drain.md
```

## 10.2 Move into WSL repo target

From WSL:

```bash
mkdir -p ~/tc7200u-research/records/reverse
cp /mnt/c/Users/mgta29/Downloads/2026-06-28-dqm-slot-region-cp2-event-drain.md ~/tc7200u-research/records/reverse/
```

Alternative if using the `u:` mount directly from Windows:

```powershell
Copy-Item "C:\Users\mgta29\Downloads\2026-06-28-dqm-slot-region-cp2-event-drain.md" "U:\home\mgta29\tc7200u-research\records\reverse\2026-06-28-dqm-slot-region-cp2-event-drain.md"
```

## 10.3 Git commit and push

From WSL:

```bash
cd ~/tc7200u-research
git status --short
git add records/reverse/2026-06-28-dqm-slot-region-cp2-event-drain.md
git commit -m "records: add 2026-06-28 DQM slot-region CP2 event-drain log"
git push
git status --short
```

Expected result:

```text
records/reverse/2026-06-28-dqm-slot-region-cp2-event-drain.md tracked and pushed to the main repository.
```

---

# 11. Notes

This log intentionally keeps `_candidate` suffixes on hardware names, structure names, and interpretation-heavy fields where the hardware semantics are still not fully proven.

The analysis remains consistent with the current broader Ethernet/DQM/FPM hypothesis:

```text
OEM path uses VENET/FPM/DQM/SEGDMA/UNIMAC/IOP-style infrastructure.
The analyzed DQM/FPM token returns are not upstream GENET TDMA descriptor writes.
```
