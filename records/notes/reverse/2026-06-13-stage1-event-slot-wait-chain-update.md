# 2026-06-13 - Stage1 event-slot wait/clear chain update

## Scope

This note extends the Host-DQM / MSP comms guarded-enable-path reverse log with the later Stage1 event-slot wait, clear, test, and blocking-wait cleanup.

This remains a reverse-engineering note. All function and data names keep `_candidate` unless fully proven.

---

## Updated overall status

| Area | Status | Progress |
|---|---:|---:|
| Host-DQM dispatch table producer/consumer chain | Mostly closed | 96% |
| Stage1 event-slot raise / wake path | Mostly closed | 90-92% |
| Stage1 event-slot wait / clear path | Mostly closed | 92-94% |
| Stage1 event-slot immediate wait-mask test | Closed | 99% |
| Stage1 blocking wait implementation | Mostly closed | 92-94% |
| Stage1 timed/deadline wait implementation | Candidate but understood at high level | 78-82% |
| NATP no-match RX Host-DQM wake path | Mostly closed | 88-90% |
| Full NATP packet worker internals | Partially closed | 65-70% |

---

## Stage1 event-slot structs

```c
typedef struct stage1_event_slot_candidate {
    uint pending_mask_00;   /* +0x00 accumulated/raised event bits */
    int waitq_04;           /* +0x04 wait queue/list head */
} stage1_event_slot_candidate;

typedef struct stage1_event_wait_condition_candidate {
    uint require_all_mask_00;       /* +0x00 all bits required if nonzero */
    uint require_any_mask_04;       /* +0x04 any matching bit wakes */
    uint observed_pending_mask_08;  /* +0x08 receives slot->pending_mask_00 */
    uint clear_slot_on_wake_0c;     /* +0x0c clear slot pending mask after wake if nonzero */
} stage1_event_wait_condition_candidate;
Current context fragment:

typedef struct stage1_context_candidate {
    undefined1 pad_00[0x5c];
    stage1_event_wait_condition_candidate *wait_condition_5c;
    undefined1 pad_60[0x38];
    uint wait_state_98;
    uint resume_status_9c;
} stage1_context_candidate;

Confirmed globals:

g_stage1_event_slot_table_base_81909698_candidate
stage1_dispatch_defer_or_running_flag_candidate
g_stage1_current_context_819dcc54_candidate

Important type correction:

stage1_dispatch_defer_or_running_flag_candidate must be uint/int, not a pointer.
Stage1 event-slot id bridge

Function:

fn_host_dqm_dispatch_table_entry_bridge_8002ad7c_candidate

Better semantic meaning:

1-based stage1 event-slot id -> slot pointer -> raise bits bridge

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

This bridge has multiple non-Host-DQM callers. It is generic Stage1 event-slot infrastructure, not Host-DQM-only.

Status:

95% closed
Stage1 event-slot wait and clear wrapper

Function:

fn_stage1_event_slot_wait_mask_clear_8002ac7c_candidate

Prototype:

undefined4 fn_stage1_event_slot_wait_mask_clear_8002ac7c_candidate
        (uint wait_mask,
         uint *out_observed_mask,
         int timeout_or_delay,
         uint slot_id);

Confirmed behavior:

slot_id is 1-based.
slot = g_stage1_event_slot_table_base_81909698_candidate + (slot_id - 1) * 8

timeout_or_delay == 0:
    blocking wait
    if no bits returned:
        *out_observed_mask = 0
        return -1

timeout_or_delay != 0:
    timed/deadline wait
    timeout_or_delay is converted through /10 with minimum 1
    if no bits returned:
        *out_observed_mask = 0
        return 0

on observed bits:
    *out_observed_mask = observed_bits
    clear observed bits through:
        slot->pending_mask_00 &= ~observed_bits
    return 0

slot_id == 0:
    return 1

Important assembly detail:

0xcccccccd multiply pattern confirms fast /10 conversion.

Status:

94% closed

Remaining uncertainty:

Exact unit of timeout_or_delay; likely converted to 10 ms style ticks, but keep candidate.
Stage1 event-slot clear wrapper

Function:

fn_stage1_event_slot_clear_observed_mask_80e959e8_candidate

Behavior:

Thin wrapper around fn_stage1_event_slot_apply_pending_clear_mask_80e980bc_candidate.

Prototype:

void fn_stage1_event_slot_clear_observed_mask_80e959e8_candidate
        (stage1_event_slot_candidate *slot,
         uint clear_mask,
         undefined4 passthrough_a2,
         undefined4 passthrough_a3);

Status:

100% wrapper
Stage1 event-slot clear implementation

Function:

fn_stage1_event_slot_apply_pending_clear_mask_80e980bc_candidate

Prototype:

void fn_stage1_event_slot_apply_pending_clear_mask_80e980bc_candidate
        (stage1_event_slot_candidate *slot,
         uint clear_mask,
         undefined4 passthrough_a2,
         undefined4 passthrough_a3);

Confirmed effect:

slot->pending_mask_00 &= clear_mask;

Wait-side caller passes:

clear_mask = ~observed_mask;

So the actual wait-side clear is:

slot->pending_mask_00 &= ~observed_mask;

Also confirmed:

The helper increments stage1_dispatch_defer_or_running_flag_candidate before update.
If this was the outermost update, it calls stage1_scheduler_unlock_or_dispatch_80e976a8_candidate.
Otherwise it decrements/stores the nesting counter.

Status:

98-100% closed
Stage1 event-slot immediate wait-mask test

Function:

fn_stage1_event_slot_test_wait_mask_80e985d4_candidate

Prototype:

uint fn_stage1_event_slot_test_wait_mask_80e985d4_candidate
        (stage1_event_slot_candidate *slot,
         uint wait_mask,
         uint wait_mode,
         undefined4 passthrough_a3);

Confirmed mode behavior:

wait_mode bit 1 / 0x2 clear:
    ALL mode; satisfied only if all wait_mask bits are present.

wait_mode bit 1 / 0x2 set:
    ANY mode; satisfied if any wait_mask bit is present.

wait_mode bit 0 / 0x1 set:
    if condition is satisfied, clear slot->pending_mask_00 to zero.

Return value:

Full slot->pending_mask_00 snapshot if satisfied.
0 if not satisfied.

Important correction:

The function returns the full pending-mask snapshot, not only slot->pending_mask_00 & wait_mask.

Status:

99% closed

Clean local names:

uVar2 -> observed_pending_snapshot
iVar1 -> new_dispatch_depth
Checked blocking wait wrapper

Function:

fn_stage1_event_slot_wait_mask_blocking_80e95a04_candidate

Prototype:

uint fn_stage1_event_slot_wait_mask_blocking_80e95a04_candidate
        (stage1_event_slot_candidate *slot,
         uint wait_mask,
         uint wait_mode,
         undefined4 passthrough_a3);

Behavior:

if wait_mask == 0:
    return 0

if wait_mode has bits outside 0x03:
    return 0

otherwise:
    return fn_stage1_event_slot_wait_mask_blocking_impl_80e98258_candidate(
        slot,
        wait_mask,
        wait_mode & 0xff,
        passthrough_a3
    )

Status:

98% closed
Real blocking wait implementation

Function:

fn_stage1_event_slot_wait_mask_blocking_impl_80e98258_candidate

Prototype:

uint fn_stage1_event_slot_wait_mask_blocking_impl_80e98258_candidate
        (stage1_event_slot_candidate *slot,
         uint wait_mask,
         uint wait_mode,
         undefined4 passthrough_a3);

Confirmed flow:

1. wait_mode_low = wait_mode & 0xff
2. increment stage1_dispatch_defer_or_running_flag_candidate
3. immediately test slot->pending_mask_00 using:
       fn_stage1_event_slot_test_wait_mask_80e985d4_candidate
4. if already satisfied:
       return observed pending snapshot
5. otherwise:
       build stage1_event_wait_condition_candidate on stack
       current_context->wait_condition_5c = &wait_condition
       mark current_context +0x98 / +0x9c
       push current_context into slot->waitq_04
       call stage1_scheduler_unlock_or_dispatch_80e976a8_candidate
       resume when wake path makes context runnable
6. return wait_condition.observed_pending_mask_08

Wait-condition mode behavior:

wait_mode & 0x2 == 0:
    require_all_mask_00 = wait_mask
    require_any_mask_04 = 0

wait_mode & 0x2 != 0:
    require_all_mask_00 = 0
    require_any_mask_04 = wait_mask

clear_slot_on_wake_0c = wait_mode & 0x1

Current Host-DQM wait path uses:

wait_mode = 2

So:

ANY-bit wait
do not auto-clear in wake helper
outer wait function clears with:
    slot->pending_mask_00 &= ~observed_mask

Status:

92-94% closed

Remaining candidates:

FUN_80e960d0
FUN_80e96428
stage1_scheduler_unlock_or_dispatch_80e976a8_candidate argument semantics
context +0x98 exact state name
context +0x9c exact resume/status enum
Timed/deadline wait implementation

Function:

fn_stage1_event_slot_wait_mask_until_deadline_impl_80e983d0_candidate

Prototype still shown as normal 4-arg call by Ghidra:

uint fn_stage1_event_slot_wait_mask_until_deadline_impl_80e983d0_candidate
        (stage1_event_slot_candidate *slot,
         uint wait_mask,
         uint wait_mode,
         undefined4 passthrough_a3);

Important calling convention note:

t0/t1 carry the absolute deadline or deadline-like 64-bit value.
Ghidra may hide these register-carried args from the C prototype.

Confirmed high-level behavior:

Same immediate test and wait-condition layout as blocking implementation.
If not already satisfied:
    stores wait_condition pointer at current_context +0x5c
    marks current_context wait state
    calls FUN_80e94ce8 with current_context +0x68 and t0/t1 deadline data
    may push current context into slot->waitq_04
    loops until observed_pending_mask_08 is set, timeout occurs, or scheduler status stops retry.

Status:

78-82% closed

Remaining target:

FUN_80e94ce8
Stage1 event-slot raise/wake implementation

Function:

fn_stage1_event_slot_raise_mask_wake_waiters_80e98110_candidate

Prototype:

void fn_stage1_event_slot_raise_mask_wake_waiters_80e98110_candidate
        (stage1_event_slot_candidate *slot,
         uint raise_mask,
         undefined4 passthrough_a2,
         undefined4 passthrough_a3);

Confirmed behavior:

slot->pending_mask_00 |= raise_mask

while slot->waitq_04 != 0:
    context = pop_front(slot->waitq_04)
    wait_condition = context->wait_condition_5c

    if wait_condition.require_all_mask_00 != 0:
        wake when all required bits are present
        if not satisfied, fall back to require_any_mask_04

    if any-mode condition is satisfied:
        context->wait_state_98 = 0
        context->resume_status_9c = 7
        make context runnable
        wait_condition.observed_pending_mask_08 = slot->pending_mask_00

        if wait_condition.clear_slot_on_wake_0c != 0:
            slot->pending_mask_00 = 0
    else:
        move context to temporary local wait queue

move non-ready temporary waiters back to slot->waitq_04

if dispatch nesting counter reaches outermost level:
    call scheduler unlock/dispatch helper

Status:

90-92% closed

Remaining candidates:

exact resume_status_9c value 7 meaning
exact waitq helper internals
exact context state naming
Updated Host-DQM / Stage1 chain

Current confirmed chain:

Host-DQM selector pending bit
    -> selector-specific pending-bit dispatcher
    -> table_index = selector * 0x20 + bit_index
    -> g_host_dqm_dispatch_table_a_81916fd8_candidate[table_index] = raise_mask
    -> g_host_dqm_dispatch_table_b_819172d8_candidate[table_index] = 1-based slot_id
    -> fn_host_dqm_dispatch_table_entry_bridge_8002ad7c_candidate
    -> slot = g_stage1_event_slot_table_base_81909698_candidate + (slot_id - 1) * 8
    -> fn_stage1_event_slot_raise_mask_wake_waiters_80e98110_candidate
    -> slot->pending_mask_00 |= raise_mask
    -> wake matching contexts from slot->waitq_04

Wait side:

worker calls fn_stage1_event_slot_wait_mask_clear_8002ac7c_candidate(
    wait_mask,
    out_observed_mask,
    timeout_or_delay,
    slot_id
)

blocking/timed wait observes slot->pending_mask_00
wake path stores full pending snapshot into observed_pending_mask_08
outer wait clears:
    slot->pending_mask_00 &= ~observed_mask

This confirms the bridge between Host-DQM pending bits and worker wakeups.

NATP no-match RX path relevance

Function:

fn_natp_nomatch_rx_token_worker_80846164_candidate

Confirmed Host-DQM/event-slot part:

creates Host-DQM channel object:
    queue_index_a_08 = 0xff
    channel_index    = 0x0c
    init_flag        = 0
    selector         = g_natp_nomatch_rx_host_dqm_selector_81917634_candidate

registers channel to event-slot:
    raise_mask = g_natp_nomatch_rx_event_raise_mask_8191761c_candidate
    slot_id    = g_natp_nomatch_rx_event_slot_id_81917618_candidate

wait loop:
    wait_mask = g_natp_nomatch_rx_event_raise_mask_8191761c_candidate
    slot_id   = g_natp_nomatch_rx_event_slot_id_81917618_candidate

Status:

Host-DQM wake part: 88-90% closed
full packet/FPM path: 65-70% closed
Remaining high-priority targets
1. FUN_80e94ce8
   Timed/deadline wait helper used by fn_stage1_event_slot_wait_mask_until_deadline_impl_80e983d0_candidate.

2. FUN_80e960d0
   Scheduler/context wait-state helper.

3. FUN_80e96428
   Scheduler/context status handler, reached when resume_status_9c == 6.

4. stage1_scheduler_unlock_or_dispatch_80e976a8_candidate
   Needs argument semantics.

5. fn_stage1_waitq_push_back_80e9747c_candidate
   Waitq push helper.

6. fn_stage1_waitq_pop_front_80e975e4_candidate
   Waitq pop helper.

7. g_host_dqm_dispatch_table_a/b writer
   Already identified as fn_host_dqm_register_channel_event_slot_80844950_candidate in later cleanup; keep confirming all callers.
Current function names to keep
fn_stage1_event_slot_wait_mask_clear_8002ac7c_candidate
fn_stage1_event_slot_clear_observed_mask_80e959e8_candidate
fn_stage1_event_slot_apply_pending_clear_mask_80e980bc_candidate
fn_stage1_event_slot_test_wait_mask_80e985d4_candidate
fn_stage1_event_slot_wait_mask_blocking_80e95a04_candidate
fn_stage1_event_slot_wait_mask_blocking_impl_80e98258_candidate
fn_stage1_event_slot_wait_mask_until_deadline_impl_80e983d0_candidate
fn_stage1_event_slot_raise_mask_wake_waiters_80e98110_candidate
fn_stage1_event_slot_dispatch_wrapper_80e959cc_candidate

fn_host_dqm_dispatch_table_entry_bridge_8002ad7c_candidate
fn_host_dqm_register_channel_event_slot_80844950_candidate
fn_host_dqm_register_event_slot_reorder_args_80844f10_candidate

fn_natp_nomatch_rx_token_worker_80846164_candidate
Result summary

The Stage1 event-slot wait/raise/clear chain is now mostly closed.

Strong result:

Host-DQM pending-bit dispatch does not directly call arbitrary worker code.
It raises a mask into a 1-based Stage1 event slot.
Workers block on that slot/mask pair.
The wake path writes the full slot pending snapshot into the waiter condition.
The outer wait wrapper then clears the observed bits.

For the NATP no-match RX worker:

Host-DQM registration:
    table A = NATP no-match raise_mask
    table B = NATP no-match 1-based slot_id

Runtime wake:
    selector dispatcher raises table A into table B slot
    NATP worker wakes from fn_stage1_event_slot_wait_mask_clear_8002ac7c_candidate
    worker drains Host-DQM/NATP RX tokens

This closes the event bridge enough to stop treating Host-DQM dispatch as an unknown callback model.
