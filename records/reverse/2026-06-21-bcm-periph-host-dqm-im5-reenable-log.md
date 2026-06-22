# 2026-06-21 BCM peripheral IM5 / Host-DQM IRQ path reverse log

## Metadata

- **Date:** 2026-06-21
- **Program:** `image.raw`
- **Architecture/import:** `MIPS:BE:32:default`
- **Image base:** `0x80004000`
- **Work area:** TC7200U / BCM3383 stage1 Ghidra reverse engineering
- **Primary target:** BCM peripheral interrupt parent/child dispatch, Host-DQM selector handlers, and IRQ return/re-enable path
- **Repository destination:** `u:\home\mgta29\tc7200u-research\records\reverse\`
- **Suggested filename:** `2026-06-21-bcm-periph-host-dqm-im5-reenable-log.md`

## Executive summary

This session completed the main OEM interrupt path from the CP0 IM5 parent dispatcher through the BCM peripheral child-bank dispatcher, Host-DQM selector pending-bit handlers, stage1 event-slot bridge, and final IRQ return/re-enable helper.

The strongest confirmed model is:

```text
CP0 Status IM5
  -> fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate
  -> parent active = b4e00050 & b4e00054
  -> fn_bcm_periph_irq_child_bank_dispatch_8002ae48_candidate(parent_bit_index)
  -> child active = child_bank+0x08 & child_bank+0x0c
  -> child_bank+0x08 &= ~child_bit before registered handler call
  -> Host-DQM selector pending-bit handler
  -> Host-DQM dispatch table bridge to stage1 event-slot raise
  -> fn_bcm_irq_return_reenable_8003d184_candidate(encoded_irq_id)
  -> child_bank+0x08 |= child_bit after work drain
```

Key corrections from this session:

- `child_bank +0x08` is **mask/control/enable latch**, not pending/status.
- `child_bank +0x0c` is **status/pending source**.
- Host-DQM dispatch tables at `81916fd8` and `819172d8` are **not callback pointers**:
  - `81916fd8[index]` = event raise mask
  - `819172d8[index]` = 1-based stage1 event-slot id
- `fn_bcm_irq_return_reenable_8003d184_candidate` is the return/re-enable helper for decoded IRQ groups, including groups `0x23..0x28`.
- Five Host-DQM selector handlers use a simple scan-loop pattern: UTP, FAP, MSG_PROC, MPEG_PROC, PMC.
- MSP uses a special DTP/MSP path with explicit bit cases and aggregate mask `0x13f3ffff`.
- Host-DQM MMIO blocks already existed; duplicate blocks must not be created. Existing blocks were renamed/verified.

## Runtime/OpenWrt relation

Previous runtime clue:

```text
Linux irq=13
periph_stat = 0x40000004
periph_mask = 0x00002000
```

Current reverse-engineering result does **not** prove that OEM encoded group `0x30` is involved in this Host-DQM IM5 path. The OEM path mapped here accepts and dispatches groups `0x23..0x28` through the child-bank machinery and table rooted around `81745514`.

Safe runtime implication:

- Linux IRQ13 reaches a BCM peripheral/IM5-level parent source.
- The OEM equivalent path masks/clears a child latch in `child_bank +0x08` before handler execution.
- The handler drains selector work and then calls the return/re-enable helper, which sets `child_bank +0x08` again.
- Do not add blind ack/clear writes in OpenWrt based only on this path. Snapshot parent/child status and mask words before writing.

Recommended OpenWrt probe snapshot points remain:

```text
b4e00050  parent IM5 mask/enable candidate
b4e00054  parent IM5 status/pending candidate
child_bank+0x08  child mask/control/enable latch
child_bank+0x0c  child status/pending source
GENET INTRL2 stat/mask saved once before printk
```

## Parent IM5 dispatcher

### Function

```c
void fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate(void);
```

### Address

```text
8002adbc
```

### Behavior

```text
mask_or_enable = *(volatile uint32_t *)b4e00050
status_pending = *(volatile uint32_t *)b4e00054
active = mask_or_enable & status_pending

while active != 0:
    parent_bit_index = 31 - clz(active)
    active &= ~(1 << parent_bit_index)
    fn_bcm_periph_irq_child_bank_dispatch_8002ae48_candidate(parent_bit_index)

CP0 Status |= 0x100 << 5
```

### Labels

```text
b4e00050  PERIPH_IRQ_IM5_MASK_OR_ENABLE_B4E00050_candidate
b4e00054  PERIPH_IRQ_IM5_STATUS_OR_PENDING_B4E00054_candidate
```

### Datatype

```c
typedef struct tc7200_periph_irq_im5_parent_bank_candidate {
    vuint32_t mask_or_enable_00;
    vuint32_t status_or_pending_04;
} tc7200_periph_irq_im5_parent_bank_candidate;
```

Apply at:

```text
b4e00050
```

## Child-bank dispatcher

### Function

```c
void fn_bcm_periph_irq_child_bank_dispatch_8002ae48_candidate(uint32_t parent_bit_index);
```

### Address

```text
8002ae48
```

### Confirmed logic

```text
handler_table = 81745514 + parent_bit_index * 0x100
child_bank = g_bcm_periph_irq_child_bank_base_table_81745B14_candidate[parent_bit_index] | 0x1000

active = *(child_bank + 0x08) & *(child_bank + 0x0c)

while active != 0:
    child_bit = 31 - clz(active)
    bit_mask = 1 << child_bit
    active &= ~bit_mask
    *(child_bank + 0x08) &= ~bit_mask
    entry = handler_table + child_bit * 8
    if entry->handler_00 != NULL:
        entry->handler_00(entry->handler_arg_04)
```

### Correct child-bank register meaning

```text
+0x08  child_mask_or_enable_08
+0x0c  child_status_or_pending_0c
```

This was a corrected reversal. Earlier wording that treated `+0x08` as pending/status and `+0x0c` as mask/enable is wrong.

### Datatype

```c
typedef struct bcm_periph_irq_child_bank_regs_candidate {
    vuint32_t field_00_unknown;
    vuint32_t field_04_unknown;
    vuint32_t child_mask_or_enable_08;
    vuint32_t child_status_or_pending_0c;
} bcm_periph_irq_child_bank_regs_candidate;
```

Apply at:

```text
b3001000
b3201000
b4201000
b3601000
b3401000
b3e01000
```

### Child-bank base table

```c
uint32_t g_bcm_periph_irq_child_bank_base_table_81745B14_candidate[6];
```

Entries:

```text
parent_bit 0 / group 0x23 -> b3000000
parent_bit 1 / group 0x24 -> b3200000
parent_bit 2 / group 0x25 -> b4200000
parent_bit 3 / group 0x26 -> b3600000
parent_bit 4 / group 0x27 -> b3400000
parent_bit 5 / group 0x28 -> b3e00000
```

### Child-bank labels

```text
B3001008  BCM_CHILD_IRQ_G23_MASK_OR_ENABLE_B3001008_candidate
B300100C  BCM_CHILD_IRQ_G23_STATUS_OR_PENDING_B300100C_candidate

B3201008  BCM_CHILD_IRQ_G24_MASK_OR_ENABLE_B3201008_candidate
B320100C  BCM_CHILD_IRQ_G24_STATUS_OR_PENDING_B320100C_candidate

B4201008  BCM_CHILD_IRQ_G25_MASK_OR_ENABLE_B4201008_candidate
B420100C  BCM_CHILD_IRQ_G25_STATUS_OR_PENDING_B420100C_candidate

B3601008  BCM_CHILD_IRQ_G26_MASK_OR_ENABLE_B3601008_candidate
B360100C  BCM_CHILD_IRQ_G26_STATUS_OR_PENDING_B360100C_candidate

B3401008  BCM_CHILD_IRQ_G27_MASK_OR_ENABLE_B3401008_candidate
B340100C  BCM_CHILD_IRQ_G27_STATUS_OR_PENDING_B340100C_candidate

B3E01008  BCM_CHILD_IRQ_G28_MASK_OR_ENABLE_B3E01008_candidate
B3E0100C  BCM_CHILD_IRQ_G28_STATUS_OR_PENDING_B3E0100C_candidate
```

## IRQ return / re-enable helper

### Function

```c
void fn_bcm_irq_return_reenable_8003d184_candidate(uint32_t encoded_irq_id);
```

### Address

```text
8003d184
```

### Confirmed behavior

The helper decodes `encoded_irq_id` through:

```c
fn_bcm_irq_decode_encoded_irq_id_8003d32c_candidate(encoded_irq_id, &group_id, &child_id);
```

Then enters a protected/critical section through:

```text
FUN_80e950a4
```

and exits through:

```text
FUN_80e950bc
```

Group behavior:

```text
group 0x1f:
  b4e0006c |= 1 << (child_id + 0x0c)

group 0:
  child 0 -> b4e000c2 |= 0x01
  child 1 -> b4e000c2 |= 0x02
  child 2 -> b4e000c2 |= 0x04

group 0x21:
  CP0 Status |= 0x100 << child_id

group 0x22:
  b4e00024 |= 1 << child_id

group 0x23..0x28:
  child_bank = g_bcm_periph_irq_child_bank_base_table_81745B14_candidate[group_id - 0x23] | 0x1000
  *(child_bank + 0x08) |= 1 << child_id

other group, except 0xff:
  b4e00040 |= 1 << (group_id & 0x1f)
```

### MMIO labels

```text
b4e00024  PERIPH_IRQ_GROUP22_RETURN_ENABLE_B4E00024_candidate
b4e00040  PERIPH_IRQ_MISC_GROUP_RETURN_ENABLE_B4E00040_candidate
b4e0006c  PERIPH_IRQ_ROUTE_OR_MISC_CFG_B4E0006C_candidate
b4e000c2  PERIPH_IRQ_GROUP0_RETURN_ENABLE_BYTE_B4E000C2_candidate
```

### Datatypes

```text
b4e00024  vuint32_t
b4e00040  vuint32_t
b4e0006c  vuint32_t
b4e000c2  vuint8_t / volatile uint8_t
```

### False function fix

Ghidra split an inline block incorrectly:

```text
FUN_8003d1b8
```

Action:

```text
Delete function definition only.
Keep bytes.
Apply label:
8003d1b8  LAB_bcm_irq_return_group1f_route_set_8003d1b8
```

## Encoded IRQ decode table

### Function

```c
void fn_bcm_irq_decode_encoded_irq_id_8003d32c_candidate(
    uint32_t encoded_irq_id,
    uint8_t *out_group_id,
    uint8_t *out_child_id
);
```

### Decode entry datatype

```c
typedef struct bcm_irq_encoded_id_decode_entry_candidate {
    uint16_t encoded_irq_id_00;
    uint8_t group_id_02;
    uint8_t child_id_03;
} bcm_irq_encoded_id_decode_entry_candidate;
```

### Array

```c
bcm_irq_encoded_id_decode_entry_candidate
g_bcm_irq_encoded_id_decode_table_81745B2C_candidate[132];
```

### Important correction

`81745b48` is not a child-bank base table entry. It is decode-table entry `[7]`.

The child-bank base table is only:

```text
81745b14..81745b2b
```

The decode table starts at:

```text
81745b2c
```

## Peripheral IRQ registration helper

### Function

```c
uint32_t fn_bcm_irq_register_handler_808601ac_candidate(
    bcm_periph_irq_handler_fn_candidate *handler,
    uint32_t handler_arg,
    uint32_t encoded_irq_id
);
```

### Correct argument order

The helper is:

```text
handler, handler_arg, encoded_irq_id
```

not a direct `(group, child, handler, arg)` API.

### Handler entry datatype

```c
typedef struct bcm_periph_irq_handler_entry_candidate {
    bcm_periph_irq_handler_fn_candidate *handler_00;
    uint32_t handler_arg_04;
} bcm_periph_irq_handler_entry_candidate;
```

### Handler table

```c
bcm_periph_irq_handler_entry_candidate
g_bcm_periph_irq_handler_table_group23_to_28_81745514_candidate[192];
```

Group ranges:

```text
0x23 parent 0 -> 81745514..81745613
0x24 parent 1 -> 81745614..81745713
0x25 parent 2 -> 81745714..81745813
0x26 parent 3 -> 81745814..81745913
0x27 parent 4 -> 81745914..81745a13
0x28 parent 5 -> 81745a14..81745b13
```

## Host-DQM dispatch-table bridge

### Function

```c
bool fn_host_dqm_dispatch_table_entry_bridge_8002ad7c_candidate(
    uint32_t raise_mask,
    uint32_t slot_id,
    uint32_t passthrough_a2,
    uint32_t passthrough_a3
);
```

### Behavior

```text
if slot_id == 0:
    return true

slot = g_stage1_event_slot_table_base_81909698_candidate + ((slot_id - 1) * 8)
fn_stage1_event_slot_dispatch_wrapper_80e959cc_candidate(slot, raise_mask)
return false
```

### Table meanings

```text
81916fd8[index] = raise_mask / event bits
819172d8[index] = 1-based stage1 event-slot id
```

### Correct labels

```text
81916fd8  g_host_dqm_pending_bit_raise_mask_table_81916FD8_candidate
819172d8  g_host_dqm_pending_bit_event_slot_id_table_819172D8_candidate
81909698  g_stage1_event_slot_table_base_81909698_candidate
```

### Datatypes

```c
uint32_t g_host_dqm_pending_bit_raise_mask_table_81916FD8_candidate[192];
uint32_t g_host_dqm_pending_bit_event_slot_id_table_819172D8_candidate[192];
void *g_stage1_event_slot_table_base_81909698_candidate;
```

Later, after `80e959cc` is fully decoded, upgrade to:

```c
stage1_event_slot_candidate *g_stage1_event_slot_table_base_81909698_candidate;
```

## Host-DQM selector registration map

The six Host-DQM selector IRQs are now mapped:

| Selector | Name | Encoded IRQ | Decode | Runtime slot | Host-DQM block | Child bank | Re-enable |
|---:|---|---:|---|---|---|---|---|
| 0 | UTP | `0x88` | group `0x23`, child `3` | `8174552c` | `b8001800` | `b3001000` | `b3001008 |= 0x8` |
| 1 | MSP | `0x7e` | group `0x24`, child `3` | `8174562c` | `b8201800` | `b3201000` | `b3201008 |= 0x8` |
| 2 | FAP | `0x74` | group `0x27`, child `3` | `8174592c` | `b8401800` | `b3401000` | `b3401008 |= 0x8` |
| 3 | MSG_PROC | `0x6a` | group `0x26`, child `3` | `8174582c` | `b8601800` | `b3601000` | `b3601008 |= 0x8` |
| 4 | MPEG_PROC | `0x60` | group `0x25`, child `3` | `8174572c` | `b8a01800` | `b4201000` | `b4201008 |= 0x8` |
| 5 | PMC | `0x56` | group `0x28`, child `3` | `81745a2c` | `b8801800` | `b3e01000` | `b3e01008 |= 0x8` |

## Host-DQM selector registration function

### Function

```c
void fn_host_dqm_register_selector_dispatch_80843c28_candidate(
    uint32_t encoded_irq_id,
    bcm_periph_irq_handler_fn_candidate *dispatch_callback,
    uint32_t host_dqm_base,
    char *manager_name_or_log_string
);
```

### Behavior

```text
register_block = host_dqm_base + 0x1800
control_block = host_dqm_base | 0x1000

clear register_block +0x14
call cleanup for encoded IRQ
register callback through fn_bcm_irq_register_handler_noarg_808603ec_candidate(callback, encoded_irq_id)
set bit 3 in control_block +0x08
call fn_bcm_irq_return_reenable_8003d184_candidate(encoded_irq_id)
log manager string and first 8 control-block words
```

## Host-DQM register-block datatype

Use the longer `+0x20` block, not the shorter selector-only struct.

```c
typedef struct host_dqm_register_block_1800_candidate {
    byte pad_00[20];
    vuint32_t reg14_channel_status_or_current;
    vuint32_t reg18_channel_enable_or_pending;
    undefined4 reg1c_queue_bit_or_ack;
    vuint32_t reg20_channel_status_or_busy;
} host_dqm_register_block_1800_candidate;
```

Apply at:

```text
b8001800
b8201800
b8401800
b8601800
b8801800
b8a01800
```

### Pointer globals

```text
8173fadc  g_host_dqm_utp_register_block_ptr_8173FADC_candidate
8173fad8  g_host_dqm_msp_register_block_ptr_8173FAD8_candidate
8173fad4  g_host_dqm_fap_register_block_ptr_8173FAD4_candidate
8173facc  g_host_dqm_msg_proc_register_block_ptr_8173FACC_candidate
8173fac8  g_host_dqm_mpeg_proc_register_block_ptr_8173FAC8_candidate
8173fad0  g_host_dqm_pmc_register_block_ptr_8173FAD0_candidate
```

Datatype for each:

```c
host_dqm_register_block_1800_candidate *
```

## Host-DQM pending-bit handlers

### Pattern classification

| Selector | Handler | Pattern | Table base |
|---:|---|---|---:|
| 0 | `fn_host_dqm_utp_pending_bit_dispatch_8002b000_candidate` | simple loop | `0x00` |
| 1 | `fn_host_dqm_msp_pending_bit_dispatch_8002b0fc_candidate` | special MSP/DTP | mixed |
| 2 | `fn_host_dqm_fap_pending_bit_dispatch_8002b240_candidate` | simple loop | `0x40` |
| 3 | `fn_host_dqm_msg_proc_pending_bit_dispatch_8002af18_candidate` | simple loop | `0x60` |
| 4 | `fn_host_dqm_mpeg_proc_pending_bit_dispatch_8002b328_candidate` | simple loop | `0x80` |
| 5 | `fn_host_dqm_pmc_pending_bit_dispatch_80844bd4_candidate` | simple loop | `0xa0` |

### Simple loop behavior

The simple loop handlers use:

```text
active = reg18_channel_enable_or_pending & reg14_channel_status_or_current
```

For each active bit:

```text
index = selector_id * 32 + pending_bit_index
raise_mask = g_host_dqm_pending_bit_raise_mask_table_81916FD8_candidate[index]
slot_id    = g_host_dqm_pending_bit_event_slot_id_table_819172D8_candidate[index]

if raise_mask != 0 and slot_id != 0:
    fn_host_dqm_dispatch_table_entry_bridge_8002ad7c_candidate(raise_mask, slot_id, in_a2, in_a3)

reg14_local &= ~(1 << pending_bit_index)
```

Exit:

```text
register_block->reg14_channel_status_or_current = reg14_local
fn_bcm_irq_return_reenable_8003d184_candidate(encoded_irq_id)
return 1
```

### UTP

```c
uint32_t fn_host_dqm_utp_pending_bit_dispatch_8002b000_candidate(uint32_t handler_arg);
```

Mapping:

```text
selector 0
encoded IRQ 0x88
group 0x23 child 3
register block b8001800
table index 0x00..0x1f
child re-enable b3001008 |= 0x8
```

### MSG_PROC

```c
uint32_t fn_host_dqm_msg_proc_pending_bit_dispatch_8002af18_candidate(uint32_t handler_arg);
```

Mapping:

```text
selector 3
encoded IRQ 0x6a
group 0x26 child 3
register block b8601800
table index 0x60..0x7f
child re-enable b3601008 |= 0x8
```

### MSP special handler

```c
uint32_t fn_host_dqm_msp_pending_bit_dispatch_8002b0fc_candidate(uint32_t handler_arg);
```

MSP is not a simple scan loop.

Registers:

```text
+0x14  reg14_channel_status_or_current
+0x18  read once, likely volatile side-effect / consistency read
+0x20  reg20_channel_status_or_busy
```

Core active source:

```text
active = reg20 & reg14
```

Confirmed cases:

```text
bit 19 / 0x00080000:
  condition: reg20 & reg14 & 0x00080000
  table index 51 = selector 1 * 32 + 19
  raise_mask 819170a4
  slot_id    819173a4
  after dispatch: reg14 &= ~0x00080000

bit 18 / 0x00040000:
  condition: reg20 & reg14 & 0x00040000
  table index 50 = selector 1 * 32 + 18
  raise_mask 819170a0
  slot_id    819173a0
  after dispatch: reg14 &= ~0x00040000

aggregate mask 0x13f3ffff:
  condition: reg20 & reg14 & 0x13f3ffff
  table index 32 = selector 1 * 32 + 0
  raise_mask 81917058
  slot_id    81917358
  after dispatch: reg14 &= 0xec0c0000
```

Missing aggregate table entry logs a DTP ISR error.

### FAP

```c
uint32_t fn_host_dqm_fap_pending_bit_dispatch_8002b240_candidate(uint32_t handler_arg);
```

Mapping:

```text
selector 2
encoded IRQ 0x74
group 0x27 child 3
register block b8401800
table index 0x40..0x5f
child re-enable b3401008 |= 0x8
```

### MPEG_PROC

```c
uint32_t fn_host_dqm_mpeg_proc_pending_bit_dispatch_8002b328_candidate(uint32_t handler_arg);
```

Mapping:

```text
selector 4
encoded IRQ 0x60
group 0x25 child 3
register block b8a01800
table index 0x80..0x9f
child re-enable b4201008 |= 0x8
```

### PMC

```c
uint32_t fn_host_dqm_pmc_pending_bit_dispatch_80844bd4_candidate(uint32_t handler_arg);
```

Important correction: this function returns `1`. The decompiler may show `void`, but assembly sets `v0 = 1` before return.

Mapping:

```text
selector 5
encoded IRQ 0x56
group 0x28 child 3
register block b8801800
table index 0xa0..0xbf
child re-enable b3e01008 |= 0x8
```

## Host-DQM MMIO memory blocks

The six Host-DQM blocks already existed. Creating new blocks caused overlap/conflict dialogs and should not be repeated.

Verified/expected blocks:

```text
b8000000..b8001fff  MMIO_HOST_DQM_UTP_B8000000_candidate
b8200000..b8201fff  MMIO_HOST_DQM_MSP_B8200000_candidate
b8400000..b8401fff  MMIO_HOST_DQM_FAP_B8400000_candidate
b8600000..b8601fff  MMIO_HOST_DQM_MSG_PROC_B8600000_candidate
b8800000..b8801fff  MMIO_HOST_DQM_PMC_B8800000_candidate
b8a00000..b8a01fff  MMIO_HOST_DQM_MPEG_PROC_B8A00000_candidate
```

Settings:

```text
Read: yes
Write: yes
Execute: no
Volatile: yes
Initialized: no
Overlay: no
Artificial: no
```

## Child IRQ bank memory blocks

Verified/expected child-bank blocks:

```text
b3000000..b3001fff  MMIO_CHILD_IRQ_BANK_B3000000_candidate
b3200000..b3201fff  MMIO_CHILD_IRQ_BANK_B3200000_candidate
b3400000..b340ffff  MMIO_CHILD_IRQ_BANK_B3400000_candidate
b3600000..b3601fff  MMIO_CHILD_IRQ_BANK_B3600000_candidate
b3e00000..b3e01fff  MMIO_CHILD_IRQ_BANK_B3E00000_candidate
b4200000..b420ffff  MMIO_CHILD_IRQ_BANK_B4200000_candidate
```

`b340` and `b420` being `0x10000` blocks is acceptable because they cover the required `+0x1000` child-bank registers.

## Host-DQM channel object datatype note

There are two similar datatypes in the export:

```text
host_dqm_channel_obj_candidate
host_dqm_channel_object_candidate
```

Use:

```text
host_dqm_channel_obj_candidate
```

going forward. It is the richer type and already contains field names like:

```text
record_word_count_or_limit
host_dqm_selector
host_dqm_base
register_block
ready_copy_count_50
queue_delta_high_water_58
```

Do not delete the older duplicate yet. Stop applying it.

## Current corrections / cleanup still pending

1. Clean duplicate comment formatting where comments contain `plate: /*` or duplicated `function: /*`.
2. Update `fn_host_dqm_pmc_pending_bit_dispatch_80844bd4_candidate` from `void` to `uint32_t`.
3. Ensure all Host-DQM register block pointer globals use `_ptr_` naming.
4. Apply `host_dqm_register_block_1800_candidate` at all six `b8*1800` register blocks.
5. Keep `host_dqm_selector_register_block_candidate` only if needed historically; prefer `host_dqm_register_block_1800_candidate`.
6. Do not create overlapping MMIO blocks.

## High-value next target

Find the table population path for:

```text
81916fd8  g_host_dqm_pending_bit_raise_mask_table_81916FD8_candidate
819172d8  g_host_dqm_pending_bit_event_slot_id_table_819172D8_candidate
```

Search xrefs/writes to:

```text
81916fd8
819172d8
```

Goal:

```text
Identify which Host-DQM selector pending bits map to which raise masks and stage1 event slots.
```

This will connect hardware selector pending bits to the software wait/wake path.

## Suggested Ghidra comments

### Child-bank dispatcher

```c
/* BCM peripheral interrupt child-bank dispatcher.

   Arguments:
     parent_bit_index = active parent bit selected by
       {@symbol fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate}

   Flow:
     - computes child handler-table base:
         {@address 81745514} + parent_bit_index * 0x100
     - loads child MMIO bank base from:
         {@address 81745b14} + parent_bit_index * 4
     - ORs selected base with 0x1000 before register access
     - reads:
         child_base + 0x08 = child mask/control/enable latch
         child_base + 0x0c = child pending/status source
     - active = +0x08 & +0x0c
     - scans active child bits from highest to lowest using clz
     - for each active child bit:
         clears that bit from local active mask
         clears that bit from child_base +0x08
         looks up handler entry:
           handler_table[parent_bit_index][child_bit]
         if handler is non-NULL:
           calls handler(handler_arg)

   Important:
     The child-bank dispatcher clears/disables the child bit in +0x08 before
     calling the registered handler. Handler-side completion/re-enable is done
     later through {@symbol fn_bcm_irq_return_reenable_8003d184_candidate}.
*/
```

### IRQ return helper

```c
/* BCM IRQ return / re-enable helper.

   Arguments:
     encoded_irq_id = encoded IRQ id decoded through
       {@symbol fn_bcm_irq_decode_encoded_irq_id_8003d32c_candidate}

   Flow:
     - decodes encoded_irq_id into group_id and child_id
     - enters protected/critical section through {@symbol FUN_80e950a4}
     - re-enables or returns the interrupt source according to group_id
     - leaves protected/critical section through {@symbol FUN_80e950bc}

   For group 0x23..0x28:
     child_bank = {@address 81745b14}[group_id - 0x23] | 0x1000
     *(uint32_t *)(child_bank + 0x08) |= 1 << child_id

   Important:
     For the BCM peripheral IM5 child-bank path, this function re-enables the
     child bit in child_bank +0x08 after the registered handler drains work.
*/
```

### Dispatch table bridge

```c
/* Host-DQM pending-bit table entry bridge.

   Arguments:
     raise_mask = event bits to OR/raise into the selected stage1 event slot
     slot_id    = 1-based stage1 event-slot id; 0 means no slot dispatch

   Behavior:
     - if slot_id == 0:
         returns true
     - else:
         slot = *(uint32_t *){@address 81909698} + ((slot_id - 1) * 8)
         calls {@symbol fn_stage1_event_slot_dispatch_wrapper_80e959cc_candidate}
           with:
             a0 = slot
             a1 = raise_mask
         returns false

   Host-DQM pending-bit handlers call this with:
     raise_mask = {@address 81916fd8}[selector_id * 32 + pending_bit]
     slot_id    = {@address 819172d8}[selector_id * 32 + pending_bit]
*/
```

## Suggested WSL move + commit commands

After downloading this file to:

```text
c:\Users\mgta29\Downloads\2026-06-21-bcm-periph-host-dqm-im5-reenable-log.md
```

move it into the repository and commit:

```bash
cd ~/tc7200u-research; mkdir -p records/reverse; cp -av /mnt/c/Users/mgta29/Downloads/2026-06-21-bcm-periph-host-dqm-im5-reenable-log.md records/reverse/
```

```bash
cd ~/tc7200u-research; git status --short --branch
```

```bash
cd ~/tc7200u-research; git add records/reverse/2026-06-21-bcm-periph-host-dqm-im5-reenable-log.md; git diff --cached --name-status
```

```bash
cd ~/tc7200u-research; git commit -m "reverse: document BCM IM5 Host-DQM IRQ path"
```

```bash
cd ~/tc7200u-research; git status --short --branch; git log --oneline --decorate -3
```

## Notes

- No old logs or records should be deleted.
- Keep all previous reverse logs as evidence.
- This log records the corrected Host-DQM/BCM IM5 path state as of 2026-06-21.
