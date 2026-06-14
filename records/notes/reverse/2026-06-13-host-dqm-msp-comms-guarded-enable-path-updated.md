# 2026-06-13 - Host DQM / MSP comms guarded enable path - updated reverse log

## Scope

This note updates the earlier Host-DQM / MSP comms guarded-enable-path log with the later Ghidra cleanup and corrected dispatch-path findings.

Covered areas:

- MSP comms init and guarded enable path.
- Generic Host-DQM channel object allocation/base initialization.
- Host-DQM selector/register-block mapping.
- Queue-index-A and channel-index-B setup helpers.
- Host-DQM selector dispatch registration.
- Selector pending-bit dispatchers for MSG_PROC and MSP.
- Host-DQM dispatch table A/B meaning.
- Stage1 event-slot bridge and event-slot waiter wakeup path.
- Ghidra MMIO block mapping and struct cleanup.

This is still a reverse-engineering note. All names keep `_candidate` unless the function/data semantics are fully closed.

---

## Updated overall status

Approximate closure for the Host-DQM/MSP comms path: **90%**

| Area | Status | Progress |
|---|---:|---:|
| Ghidra cleanup and function-boundary repair | Clean enough | 95% |
| MSP init wrapper `800b1500` | Confirmed | 92% |
| MSP guarded enable path `800b1584` | Confirmed high level | 94% |
| Host-DQM object allocation wrapper `80844dac` | Confirmed | 90% |
| Host-DQM base initializer `80843cd8` | Mostly closed | 98% |
| Queue-index-A setup `80844568` | Closed enough | 92% |
| Channel-index-B setup `808445bc` | Closed enough | 97% |
| Host-DQM selector registration `80843c28` | Closed enough | 92% |
| Host-DQM dispatch table A/B meaning | Confirmed read-side meaning | 90% |
| Stage1 event-slot wake path | Confirmed structure | 90% |
| Table writer / registration source | Still missing | 35% |
| Connection to OpenWrt DQM/GENET bring-up | Directionally useful, not final | 55% |

---

## Major correction retained

Earlier working assumption was that the MSP comms path used Host-DQM selector `1`, mapping to:

```text
0xb8200000 / 0xb8201800
That is wrong for the specific MSP comms channel object created by:

fn_msp_comms_channel_init_800b1500_candidate

The MSP comms init wrapper passes:

a0 = 0x1e
a1 = 0x1f
a2 = 0
a3 = 0x3
t0 = 0x80fa6bc0

Therefore the object stored in:

g_msp_comms_channel_obj_8146ffd8_candidate

is initialized as:

queue_index_a_08 = 0x1e
channel_index    = 0x1f
init_flag        = 0
selector         = 3
host_dqm_base    = 0xb8600000
register_block   = 0xb8601800

Selector 3 is the MSG_PROC Host-DQM selector.

Concrete bit for the MSP comms channel object:

channel_index = 0x1f
bit mask      = 1 << 31 = 0x80000000
Current selector mapping

Confirmed in:

fn_host_dqm_channel_obj_base_init_80843cd8_candidate
Selector	Role	Event/status code	Host-DQM base	Register block
0	UTP	0x88	0xb8000000	0xb8001800
1	MSP	0x7e	0xb8200000	0xb8201800
2	FAP	0x74	0xb8400000	0xb8401800
3	MSG_PROC	0x6a	0xb8600000	0xb8601800
4	MPEG_PROC	0x60	0xb8a00000	0xb8a01800
5	PMC	0x56	0xb8800000	0xb8801800

Important distinction:

Selector 1 / MSP register block      = 0xb8201800
MSP comms channel object in this path = selector 3 / MSG_PROC = 0xb8601800
MSP comms init path

Function:

fn_msp_comms_channel_init_800b1500_candidate

Confirmed behavior:

if g_msp_comms_channel_initialized_8146ffdc_candidate == 0:
    obj = fn_host_dqm_channel_obj_alloc_init_80844dac_candidate(
        0x1e,
        0x1f,
        0,
        3
    )

    g_msp_comms_channel_obj_8146ffd8_candidate = obj

    if obj == NULL:
        log "Error - failed to create MSP com..."
    else:
        fn_stage1_guarded_context_lock_alloc_init_store_8072ab9c_candidate(
            &g_stage1_msp_comms_guard_lock_ptr_8187bc54_candidate
        )
        g_msp_comms_channel_initialized_8146ffdc_candidate = 1

return g_msp_comms_channel_initialized_8146ffdc_candidate

Confirmed globals:

g_msp_comms_channel_obj_8146ffd8_candidate
g_msp_comms_channel_initialized_8146ffdc_candidate
g_msp_comms_channel_enabled_8146ffe0_candidate
g_stage1_msp_comms_guard_lock_ptr_8187bc54_candidate
MSP comms guarded enable path

Function:

fn_msp_comms_channel_enable_800b1584_candidate

High-level behavior:

if initialized:
    acquire guarded-context lock

    if enable != 0:
        wait for register_block +0x20 bit[channel_index] to clear
        set register_block +0x18 bit[channel_index]
        set register_block +0x14 bit[channel_index]

    g_msp_comms_channel_enabled_8146ffe0_candidate = enable != 0

    release guarded-context lock
    wake waiter if required
    return 1
else:
    g_msp_comms_channel_enabled_8146ffe0_candidate = 0
    log "Error - MspComms Channel not Init"
    return 0

For the confirmed object:

register_block = 0xb8601800
channel_index  = 0x1f
bit            = 0x80000000

So enable path does:

wait until 0xb8601820 bit31 clears
set        0xb8601818 bit31
set        0xb8601814 bit31
Host-DQM object allocation wrapper

Function:

fn_host_dqm_channel_obj_alloc_init_80844dac_candidate

Current prototype:

host_dqm_channel_obj_candidate *
fn_host_dqm_channel_obj_alloc_init_80844dac_candidate
        (uint queue_index_a_08,
         uint channel_index,
         uint init_flag,
         uint host_dqm_selector);

Important calling convention note:

a3 carries host_dqm_selector.
incoming caller t0 is preserved and passed into the base initializer as the name/object string pointer.
Do not add fake C arguments for t0/t1.

Behavior:

allocates 0x5c bytes
normalizes init_flag to boolean
calls fn_host_dqm_channel_obj_base_init_80843cd8_candidate(...)
returns allocated object pointer
Host-DQM channel object base initializer

Function:

fn_host_dqm_channel_obj_base_init_80843cd8_candidate

Current prototype:

void fn_host_dqm_channel_obj_base_init_80843cd8_candidate
        (host_dqm_channel_obj_candidate *obj,
         uint queue_index_a_08,
         uint channel_index,
         uint init_flag_byte);

Register-carried inputs:

t0 = host_dqm_selector
t1 = object/name string pointer

Confirmed behavior:

- installs base ops table PTR_FUN_81826978
- disables interrupts by clearing CP0 Status.IE while static/global state is updated
- one-time clears Host-DQM dispatch tables:
    0x81916fd8
    0x819172d8
- stores selector from t0
- stores queue_index_a_08, channel_index, init_flag_byte
- maps selector to base/register block
- performs one-time selector dispatch registration
- calls queue-index-A setup if queue_index_a_08 != 0xff
- calls channel-index-B setup if channel_index != 0xff
- allocates/copies name string from register-carried t1
- zeroes +0x48..+0x58 state/stat fields
- stores DMA/FPM allocator at +0x1c
- registers object in object list at 0x819175d8
- restores CP0 Status

Closure:

~98%

Remaining candidates:

exact object-list helper semantics
exact fallback/static-state helper naming
exact allocator call argument semantics
Host-DQM object struct

Current cleaned layout:

typedef struct host_dqm_channel_obj_candidate {
    undefined4 *ops_table;                          /* +0x00 base ops table */
    char *name_copy_04;                             /* +0x04 allocated/copy of t1 string */
    uint queue_index_a_08;                          /* +0x08 queue index A */
    uint channel_index;                             /* +0x0c channel/bit index */
    uint init_flag_byte_10;                         /* +0x10 low byte init flag */
    uint queue_or_expected_index_14;                /* +0x14 queue/backlog expected index */
    uint queue_a_initial_index_18;                  /* +0x18 high16 from queue-A +0x1a08 */
    void *fpm_allocator_1c;                         /* +0x1c FPM allocator pointer */
    uint record_word_count_or_limit;                /* +0x20 record/payload word count */
    uint host_dqm_selector;                         /* +0x24 selector from t0 */
    uint host_dqm_base;                             /* +0x28 selector MMIO base */
    host_dqm_register_block_1800_candidate *register_block; /* +0x2c */
    undefined4 *queue_a_window_1a00_30;             /* +0x30 base + queue_index_a*0x10 + 0x1a00 */
    undefined4 *queue_b_window_1a00_34;             /* +0x34 base + channel_index*0x10 + 0x1a00 */
    undefined4 *record_words;                       /* +0x38 base + channel_index*0x10 + 0x1c00 */
    undefined4 *queue_a_window_1c00_3c;             /* +0x3c base + queue_index_a*0x10 + 0x1c00 */
    uint *queue_a_cursor_or_index_ptr_40;           /* +0x40 base + queue_index_a*4 + 0x1f00 */
    uint *queue_index_or_cursor_ptr_44;             /* +0x44 base + channel_index*4 + 0x1f00 */
    undefined4 field_48_unknown;                    /* +0x48 zeroed */
    undefined4 field_4c_unknown;                    /* +0x4c zeroed */
    uint ready_copy_count_50;                       /* +0x50 successful ready payload copy counter */
    undefined4 field_54_unknown;                    /* +0x54 zeroed */
    uint queue_delta_high_water_58;                 /* +0x58 queue/backlog high-water stat */
} host_dqm_channel_obj_candidate;

Allocation size:

0x5c
Generic Host-DQM register block struct

Use generic field names, not MSP-specific names, because the same layout is applied to all selector register blocks.

typedef struct host_dqm_register_block_1800_candidate {
    byte pad_00[0x14];                    /* +0x00..+0x13 */
    uint reg14_status_current_bits;       /* +0x14 */
    uint reg18_enabled_pending_mask;      /* +0x18 */
    uint reg1c_queue_bit_or_ack;          /* +0x1c */
    uint reg20_channel_status_or_busy;    /* +0x20 */
} host_dqm_register_block_1800_candidate;

Known instances in Ghidra:

0xb8201800 = g_host_dqm_msp_register_block_0xb8201800_candidate
0xb8601800 = g_host_dqm_msg_proc_register_block_0xb8601800_candidate

Ghidra MMIO analysis targets:

b8201814 / b8201818 / b8201820 = selector 1 / MSP register fields
b8601814 / b8601818 / b8601820 = selector 3 / MSG_PROC register fields
Queue-index-A setup helper

Function:

fn_host_dqm_setup_queue_index_a_windows_80844568_candidate

Behavior:

queue_index = obj->queue_index_a_08
queue_window_base = obj->host_dqm_base + queue_index * 0x10

obj->queue_a_window_1c00_3c       = queue_window_base + 0x1c00
obj->queue_a_window_1a00_30       = queue_window_base + 0x1a00
obj->queue_a_cursor_or_index_ptr_40 = obj->host_dqm_base + 0x1f00 + queue_index * 4
obj->queue_a_initial_index_18     = *(queue_window_base + 0x1a08) >> 16

obj->register_block->reg1c_queue_bit_or_ack = 1 << queue_index
return 0

Closure:

~92%
Channel-index-B / record-window setup helper

Function:

fn_host_dqm_setup_channel_index_b_record_windows_808445bc_candidate

Behavior:

queue_window_base = obj->host_dqm_base + obj->channel_index * 0x10

obj->queue_b_window_1a00_34       = queue_window_base + 0x1a00
obj->record_words                 = queue_window_base + 0x1c00
obj->queue_index_or_cursor_ptr_44 = obj->host_dqm_base + obj->channel_index * 4 + 0x1f00
obj->queue_or_expected_index_14   = *(queue_window_base + 0x1a08) >> 16
obj->record_word_count_or_limit   = (*(queue_window_base + 0x1a00) & 3) + 1

waits for reg20 channel bit to clear
sets reg18 channel bit
return 0

This proves:

+0x38 record_words
+0x44 queue_index_or_cursor_ptr_44
+0x20 record_word_count_or_limit
+0x14 queue_or_expected_index_14

Closure:

~97%
Host-DQM selector dispatch registration

Function:

fn_host_dqm_register_selector_dispatch_80843c28_candidate

Prototype:

void fn_host_dqm_register_selector_dispatch_80843c28_candidate
        (uint event_or_status_code,
         undefined4 dispatch_callback,
         uint host_dqm_base,
         char *manager_name_or_log_string);

Behavior:

- derives register block at host_dqm_base + 0x1800
- derives control/status block at host_dqm_base + 0x1000
- clears register_block +0x14
- performs fallback/event cleanup for event_or_status_code
- registers dispatch_callback for event_or_status_code
- sets bit 3 in control/status block +0x08
- calls fn_enet_return_or_status_8003d184_candidate(event_or_status_code)
- logs manager/debug string
- dumps first 8 words from host_dqm_base + 0x1000

Closure:

~92%
Host-DQM global/static-state helper

Function:

fn_host_dqm_global_static_state_enable_disable_80843b7c_candidate

Behavior:

enable == 1 and selector_or_all == 0xffff:
    FUN_80f06430(0x81916fd4)

enable == 0 and selector_or_all == 0xffff:
    fn_static_state_release_or_unregister_ref_80f06474_candidate(0x81916fd4)

Wrappers:

fn_host_dqm_global_static_state_enable_wrapper_80843be8_candidate
fn_host_dqm_global_static_state_disable_wrapper_80843c08_candidate

Function boundary cleanup completed:

80843be8 is the real enable wrapper start.
80843bf0 is not a function start.
80843c1c is not a function start; it is the disable wrapper epilogue.
Host-DQM global flags and tables

One-time flags:

g_host_dqm_global_tables_initialized_8173fac0_candidate
g_host_dqm_utp_dispatch_registered_8173fac1_candidate
g_host_dqm_msp_dispatch_registered_8173fac2_candidate
g_host_dqm_fap_dispatch_registered_8173fac3_candidate
g_host_dqm_mpeg_proc_dispatch_registered_8173fac4_candidate
g_host_dqm_msg_proc_dispatch_registered_8173fac5_candidate
g_host_dqm_pmc_dispatch_registered_8173fac6_candidate

Global tables:

0x81916fd8 -> g_host_dqm_dispatch_table_a_81916fd8_candidate
0x819172d8 -> g_host_dqm_dispatch_table_b_819172d8_candidate
0x819175d8 -> g_host_dqm_object_list_819175d8_candidate

Table size:

0xc0 entries each
0x300 bytes each
undefined4[192]

Selector table layout:

selector 0 UTP       entries 0x00..0x1f
selector 1 MSP       entries 0x20..0x3f
selector 2 FAP       entries 0x40..0x5f
selector 3 MSG_PROC  entries 0x60..0x7f
selector 4 MPEG_PROC entries 0x80..0x9f
selector 5 PMC       entries 0xa0..0xbf

Meaning from read-side dispatchers:

table A entry = raise_mask / event bits
table B entry = 1-based stage1 event-slot id

Table writer is not yet found.

Search results:

Direct xrefs to table A/B currently show reads only.
Scalar searches for full table base addresses found no useful non-clear writer:
  2173792216  / -2121175080  = 0x81916fd8
  2173792984  / -2121174312  = 0x819172d8
  2173793752  / -2121173544  = 0x819175d8
Stage1 event-slot id bridge

Current function name in Ghidra:

fn_host_dqm_dispatch_table_entry_bridge_8002ad7c_candidate

Better semantic meaning:

generic 1-based stage1 event-slot id -> slot pointer -> raise bits bridge

Behavior:

if slot_id != 0:
    slot = g_stage1_event_slot_table_base_81909698_candidate + (slot_id - 1) * 8
    fn_stage1_event_slot_dispatch_wrapper_80e959cc_candidate(
        slot,
        raise_mask,
        passthrough_a2,
        passthrough_a3
    )

return slot_id == 0

Important correction:

This function has many callers outside Host-DQM. It is not strictly Host-DQM-only.

Stage1 event slot structs

Slot entry:

typedef struct stage1_event_slot_candidate {
    uint pending_mask_00;   /* +0x00 accumulated/raised event bits */
    int waitq_04;          /* +0x04 wait queue/list head */
} stage1_event_slot_candidate;

Wait condition:

typedef struct stage1_event_wait_condition_candidate {
    uint require_all_mask_00;       /* +0x00 all bits required if nonzero */
    uint require_any_mask_04;       /* +0x04 any matching bit wakes */
    uint observed_pending_mask_08;  /* +0x08 receives slot->pending_mask_00 */
    uint clear_slot_on_wake_0c;     /* +0x0c clear slot pending mask after wake if nonzero */
} stage1_event_wait_condition_candidate;

Global slot-table base:

g_stage1_event_slot_table_base_81909698_candidate

This needed a small RAM global block in Ghidra because address 0x81909698 was not initially mapped.

Stage1 event-slot dispatcher wrapper

Function:

fn_stage1_event_slot_dispatch_wrapper_80e959cc_candidate

Behavior:

thin wrapper around fn_stage1_event_slot_raise_mask_wake_waiters_80e98110_candidate
Stage1 event-slot raise/wake dispatcher

Function:

fn_stage1_event_slot_raise_mask_wake_waiters_80e98110_candidate

Behavior:

slot->pending_mask_00 |= raise_mask

while slot->waitq_04 != 0:
    context = pop_front(slot->waitq_04)
    wait_condition = *(context + 0x5c)

    if wait_condition.require_all_mask_00 is nonzero:
        wake when all required bits are present
        if not satisfied, fallback to require_any_mask_04

    if require_any condition is satisfied:
        clear context +0x98
        set context +0x9c = 7
        make context runnable
        wait_condition.observed_pending_mask_08 = slot->pending_mask_00
        if wait_condition.clear_slot_on_wake_0c != 0:
            slot->pending_mask_00 = 0
    else:
        move context to temporary wait queue

move non-ready temporary waiters back to slot->waitq_04

if event-dispatch nesting counter drops to zero:
    call stage1 scheduler unlock/dispatch helper

Closure:

~90%

Remaining candidates:

exact context struct fields at +0x5c, +0x98, +0x9c
exact waitq helper internals
exact meaning of runnable-state value 7
Selector-3 / MSG_PROC pending-bit dispatcher

Function:

fn_host_dqm_msg_proc_pending_bit_dispatch_8002af18_candidate

Registered by base initializer as selector 3 callback:

event/status code = 0x6a
register block    = 0xb8601800
table index base  = 0x60

Registers used:

+0x14 = current/status/pending bits
+0x18 = enabled mask

Behavior:

pending_bits = reg18 & reg14

for each set bit N:
    table_index = 0x60 + N
    clear bit N from local reg14 copy
    if table_a[table_index] and table_b[table_index] are nonzero:
        raise table_a[table_index] into stage1 event slot table_b[table_index]

recompute pending bits after each handled bit
write updated reg14 back to MMIO +0x14
call fn_enet_return_or_status_8003d184_candidate(0x6a)
return 1

Closure:

~97%
Selector-1 / MSP pending-bit dispatcher

Function:

fn_host_dqm_msp_pending_bit_dispatch_8002b0fc_candidate

Registered by base initializer as selector 1 callback:

event/status code = 0x7e
register block    = 0xb8201800
table index base  = 0x20

Registers used:

+0x14 = current/status bits
+0x20 = channel status/busy/ready bits

Dispatch cases:

bit 19 / 0x00080000 -> table index 0x33
bit 18 / 0x00040000 -> table index 0x32
aggregate mask 0x13f3ffff -> table index 0x20

Behavior:

reg20 = *(0xb8201820)
reg14 = *(0xb8201814)

if bit19 is present in both reg20 and reg14:
    dispatch table[0x33]
    clear bit19 from local reg14 copy

if bit18 is present in both reg20 and reg14:
    dispatch table[0x32]
    clear bit18 from local reg14 copy

if any reg20 & reg14 & 0x13f3ffff bit is set:
    reg14 &= 0xec0c0000
    dispatch table[0x20]

write updated reg14 back to 0xb8201814
call fn_enet_return_or_status_8003d184_candidate(0x7e)
return 1

Closure:

~90%

Remaining candidates:

exact reason selector-1 path logs DTP_ISR
exact semantic meaning of bit18, bit19, aggregate mask
PMC pending-bit dispatcher retained

Function:

fn_host_dqm_pmc_pending_bit_dispatch_80844bd4_candidate

Current interpretation:

selector 5 / PMC
register block = 0xb8801800
event/status code = 0x56
table base index = 0xa0

Behavior pattern matches generic pending-bit dispatch:

pending = reg14 & reg18
for each pending bit:
    table_index = 0xa0 + bit_index
    if table A/B entries nonzero:
        raise table A into stage1 event slot table B
clear handled bits from local reg14
write updated reg14 back to +0x14
call status helper with 0x56
return 1

Still candidate until cleaned again with the updated table/slot terminology.

Current dispatch chain

For selector 3 / MSG_PROC:

0xb8601814 / 0xb8601818 pending bit
    -> fn_host_dqm_msg_proc_pending_bit_dispatch_8002af18_candidate
    -> table_index = 0x60 + bit_index
    -> table_a[index] = raise_mask
    -> table_b[index] = 1-based stage1 event-slot id
    -> fn_host_dqm_dispatch_table_entry_bridge_8002ad7c_candidate
    -> fn_stage1_event_slot_dispatch_wrapper_80e959cc_candidate
    -> fn_stage1_event_slot_raise_mask_wake_waiters_80e98110_candidate
    -> slot->pending_mask_00 |= raise_mask
    -> wake matching waiters

This replaces the earlier vague “callback dispatch” model with:

Host-DQM pending bit -> dispatch table lookup -> stage1 event-slot raise/wakeup
Ghidra cleanup completed in this update

Function-boundary and MMIO cleanup:

80843be8 is the real Host-DQM global static-state enable wrapper.
80843bf0 is not a function start.
80843c08 includes the disable wrapper epilogue.
80843c1c is not a function start.
80843c28 is the selector dispatch registration helper.
80843cd8 is the Host-DQM base initializer.
80844568 is queue-index-A setup.
808445bc is channel-index-B / record-window setup.
8002af18 is selector-3 / MSG_PROC pending-bit dispatcher.
8002b0fc is selector-1 / MSP pending-bit dispatcher.

MMIO blocks created/used in Ghidra:

MMIO_HOST_DQM_MSP_0xb8200000_candidate
MMIO_HOST_DQM_MSG_PROC_0xb8600000_candidate

Register struct applied at:

0xb8201800
0xb8601800

Register struct fields were changed to generic names so the same type can be used for all selectors.

OpenWrt relevance

This note remains Ghidra-first. Runtime probing is a later step.

Current Ghidra-derived comparison targets for the OpenWrt DQM/GENET bring-up investigation:

MSG_PROC selector-3 block:
  0xb8601814
  0xb8601818
  0xb8601820

MSP comms object bit:
  bit31 / 0x80000000

Why this matters:

The MSP comms init path creates a Host-DQM object with selector 3 / MSG_PROC,
queue_index_a_08 = 0x1e,
channel_index = 0x1f.

The guarded enable path waits for reg20 bit31 clear, then sets reg18 bit31 and reg14 bit31.

This is not yet proof that these registers cause the OpenWrt TX/RX stall. It is a concrete OEM Host-DQM synchronization path that should be kept visible while comparing OEM behavior to OpenWrt behavior.

Do not jump back to broad switch/MDIO work from this alone.

Remaining high-priority unknowns
Find the writer/registration function for:
g_host_dqm_dispatch_table_a_81916fd8_candidate
g_host_dqm_dispatch_table_b_819172d8_candidate

Goal:

prove selector + bit_index -> raise_mask + stage1 event-slot id
Clean remaining selector dispatchers:
8002b000  selector 0 / UTP candidate
8002b240  selector 2 / FAP candidate
8002b328  selector 4 / MPEG_PROC candidate
80844bd4  selector 5 / PMC candidate
Clean stage1 waitq helpers:
fn_stage1_waitq_pop_front_80e975e4_candidate
fn_stage1_waitq_push_back_80e9747c_candidate
fn_stage1_context_make_runnable_80e96154_candidate
fn_stage1_waitq_cleanup_or_assert_empty_80f8997c_candidate
Clean static-state helpers:
FUN_80f06430
fn_static_state_release_or_unregister_ref_80f06474_candidate
Clean Host-DQM/FPM allocator call path enough to avoid over-interpreting decompiler artifact arguments.
Current function names to keep
fn_msp_comms_channel_init_800b1500_candidate
fn_msp_comms_channel_enable_800b1584_candidate

fn_host_dqm_channel_obj_alloc_init_80844dac_candidate
fn_host_dqm_channel_obj_base_init_80843cd8_candidate

fn_host_dqm_setup_queue_index_a_windows_80844568_candidate
fn_host_dqm_setup_channel_index_b_record_windows_808445bc_candidate

fn_host_dqm_register_selector_dispatch_80843c28_candidate

fn_host_dqm_global_static_state_enable_disable_80843b7c_candidate
fn_host_dqm_global_static_state_enable_wrapper_80843be8_candidate
fn_host_dqm_global_static_state_disable_wrapper_80843c08_candidate

fn_comms_wait_reg20_bit_clear_80844aa0_candidate
fn_comms_set_reg14_reg18_channel_bit_8002b7e0_candidate
fn_host_dqm_wait_reg20_bit_set_then_call_8002b998_80844b38_candidate

fn_host_dqm_msg_proc_pending_bit_dispatch_8002af18_candidate
fn_host_dqm_msp_pending_bit_dispatch_8002b0fc_candidate
fn_host_dqm_pmc_pending_bit_dispatch_80844bd4_candidate

fn_host_dqm_dispatch_table_entry_bridge_8002ad7c_candidate
fn_stage1_event_slot_dispatch_wrapper_80e959cc_candidate
fn_stage1_event_slot_raise_mask_wake_waiters_80e98110_candidate

fn_stage1_guarded_context_lock_alloc_init_store_8072ab9c_candidate

Keep _candidate on all names.

Result summary

The earlier log’s core result is preserved but refined.

The MSP comms path resolves to:

MSP init:
  create generic Host-DQM channel object
  queue_index_a_08 = 0x1e
  channel_index = 0x1f
  selector = 3 / MSG_PROC
  register_block = 0xb8601800
  store object in g_msp_comms_channel_obj_8146ffd8_candidate
  allocate/store guarded lock at g_stage1_msp_comms_guard_lock_ptr_8187bc54_candidate
  set initialized flag

MSP enable:
  acquire guarded-context lock
  wait for 0xb8601820 bit31 clear
  set 0xb8601818 bit31
  set 0xb8601814 bit31
  set enabled flag
  release guarded-context lock

The Host-DQM dispatch side now resolves to:

selector pending bit
  -> selector-specific table index
  -> table A raise_mask
  -> table B 1-based stage1 event-slot id
  -> event-slot pending_mask OR
  -> waiter wakeup path

This is the current strongest Host-DQM reverse-engineering result from the 2026-06-13 cleanup pass.
