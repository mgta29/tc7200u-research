# 2026-06-14 — Stage1 readyq / owner-list / wakeup-chain reverse log

## Scope

This record documents the Stage1 scheduler, ready queue, owner-list, wait queue, and wakeup-chain work performed in Ghidra.

Focus area:

- Stage1 scheduler ready queue bitmap/table
- Stage1 context embedded list node at `context + 0x18`
- `owner_list_head_ref_28` ownership model
- Readyq add/remove/select helpers
- Generic owner-list insert/unlink/pop helpers
- Wake-all success helper
- Priority ordering conclusion
- Data type and structure corrections
- Function rename decisions and remaining `_candidate` items

No Git operations were performed or requested.

---

## High-level result

The Stage1 ready/wait ownership model is now substantially closed.

The confirmed chain is:

```text
wait/object blocking path
-> fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c
   -> inserts context->readyq_node_18 into an owner/wait list
   -> stores owner_list_head_ref into context->owner_list_head_ref_28

wake/unblock path
-> fn_stage1_context_unlink_from_owner_list_80e97634
   or fn_stage1_context_owner_list_pop_front_clear_owner_80e975e4
   -> removes context->readyq_node_18 from the owner/wait list
   -> clears context->owner_list_head_ref_28

make-runnable path
-> fn_stage1_context_make_runnable_80e96154
   -> clears low context_flags_50 bits
   -> returns context to scheduler readyq

readyq path
-> fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130
   -> inserts context into readyq bucket
   -> calls preempt/dispatch-needed marker

scheduler path
-> fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294
   -> sets global dispatch-needed flag when new context outranks current context

dispatch path
-> fn_stage1_scheduler_unlock_or_dispatch_loop_80e976a8
   -> selects lowest-numbered non-empty readyq bucket
   -> context switches when needed
Priority conclusion is now confirmed:

lower context->readyq_bucket_20 value = higher Stage1 scheduler priority
Confirmed structures and data types
stage1_readyq_node_candidate

Embedded circular doubly-linked list node.

typedef struct stage1_readyq_node_candidate {
    struct stage1_readyq_node_candidate *next_00;
    struct stage1_readyq_node_candidate *prev_04;
} stage1_readyq_node_candidate; // size 0x08

Usage:

Embedded at stage1_context_candidate + 0x18
Used both for scheduler readyq buckets and owner/wait lists
Removed nodes are left/restored self-linked:
node->next_00 = node
node->prev_04 = node
stage1_readyq_table_candidate

Confirmed layout:

typedef struct stage1_readyq_table_candidate {
    uint nonempty_bucket_bitmap_00;
    stage1_readyq_node_candidate *bucket_heads_04[32];
} stage1_readyq_table_candidate; // size 0x84

Important global:

g_stage1_scheduler_readyq_table_819dcc5c

Important fields:

+0x00 nonempty_bucket_bitmap_00
+0x04 bucket_heads_04[0]
...
+0x80 bucket_heads_04[31]

The readyq table is not a pointer at 819dcc5c; it is the table object itself.

stage1_context_candidate fields used in this pass

Important fields confirmed or reinforced:

typedef struct stage1_context_candidate {
    /* ... */
    stage1_readyq_node_candidate readyq_node_18;         // +0x18
    uint readyq_bucket_20;                               // +0x20
    stage1_readyq_node_candidate **owner_list_head_ref_28; // +0x28
    uint scheduler_callback_block_count_2c_candidate;    // +0x2c
    uint pending_callback_flag_30;                       // +0x30
    void *pending_callback_arg_34;                       // +0x34
    uint context_flags_50;                               // +0x50
    ushort context_trace_id_60;                          // +0x60
    uint wait_state_98;                                  // +0x98
    uint resume_status_9c;                               // +0x9c
    struct stage1_thread_record_candidate *thread_record_ac_candidate; // +0xac
    /* ... */
} stage1_context_candidate;

Key field interpretation:

owner_list_head_ref_28 is not an owner object.
owner_list_head_ref_28 is a pointer to the list-head variable that currently owns context->readyq_node_18.

This allows generic unlink/make-runnable logic to remove a context from whatever wait/owner list owns it without knowing the concrete wait-object type.

Scheduler global cluster

Important Stage1 software-runtime globals:

819dcc4c  g_stage1_scheduler_unlock_callback_list_head_819dcc4c
819dcc50  g_stage1_scheduler_timeslice_or_budget_reload_819dcc50
819dcc54  g_stage1_current_context_819dcc54
819dcc58  g_stage1_scheduler_dispatch_needed_flag_819dcc58
819dcc5c  g_stage1_scheduler_readyq_table_819dcc5c
819dcce0  g_stage1_context_switch_counter_819dcce0

Important correction:

g_stage1_current_context_819dcc54 is a stage1_context_candidate * pointer.
It is not an inline stage1_context_candidate struct.

Incorrectly typing it as a full struct causes overlap with:

819dcc58 g_stage1_scheduler_dispatch_needed_flag_819dcc58
819dcc5c g_stage1_scheduler_readyq_table_819dcc5c
De Bruijn LSB index table

Confirmed symbol:

byte g_stage1_debruijn_lsb_index_table_8146c418[64];

Range:

8146c418 - 8146c457

The next object starts at:

8146c458 s_%u.%u.%u.%u

The table must not be extended past 8146c457.

Purpose:

Maps De Bruijn hash result to lowest-set-bit index.
Used by fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748.
Function results
fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748

Previous name:

fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748_candidate

Final name:

fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748

Signature:

int fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748(uint bitmap)

Confirmed decompile:

int fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748(uint bitmap)

{
  return (int)g_stage1_debruijn_lsb_index_table_8146c418
              [(bitmap & -bitmap) * 0x450fbaf >> 0x1a];
}

Behavior:

Isolates least significant set bit:
bitmap & -bitmap
Multiplies by De Bruijn-style constant:
0x0450fbaf
Shifts by 26:
>> 0x1a
Indexes a 64-entry byte table.
Returns the lowest-numbered set-bit index.

Important:

bitmap == 0 hashes/indexes table[0].
table[0] is expected invalid marker 0xff / 255.
Normal readyq scheduler callers should only pass nonzero readyq bitmaps.

Scheduler meaning:

readyq nonempty bitmap -> lowest set bit -> selected bucket index

Priority conclusion:

lower readyq_bucket_20 value = higher scheduler priority
fn_stage1_scheduler_readyq_select_context_80e970f4

Previous name:

fn_stage1_scheduler_readyq_select_context_80e970f4_candidate

Final name:

fn_stage1_scheduler_readyq_select_context_80e970f4

Purpose:

Selects the highest-priority runnable context from a readyq table.
Uses the nonempty-bucket bitmap to find the lowest-numbered non-empty bucket.
Converts the selected bucket head node back to a context by subtracting 0x18.

Clean target form:

stage1_context_candidate *
fn_stage1_scheduler_readyq_select_context_80e970f4(stage1_readyq_table_candidate *readyq_table)
{
  uint readyq_bucket_index;
  stage1_readyq_node_candidate *readyq_node;

  readyq_bucket_index =
     fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748
        (readyq_table->nonempty_bucket_bitmap_00);

  readyq_node = readyq_table->bucket_heads_04[readyq_bucket_index];
  if (readyq_node == NULL) {
    return NULL;
  }

  return (stage1_context_candidate *)((byte *)readyq_node - 0x18);
}

Decompiler note:

Ghidra may show readyq_node + -3 because:
  readyq_node_18 offset = 0x18
  sizeof(stage1_readyq_node_candidate) = 0x08
  0x18 / 0x08 = 3
fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130

Previous name:

fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130_candidate

Final name:

fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130

Signature:

void fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130
        (stage1_readyq_table_candidate *readyq_table,
         stage1_context_candidate *context)

Behavior:

Reads bucket index from:
context->readyq_bucket_20
Gets bucket head slot:
&readyq_table->bucket_heads_04[bucket_index]
If context->owner_list_head_ref_28 is non-NULL, detaches context from its current owner list through:
fn_stage1_context_unlink_from_owner_list_80e97634
If target bucket was empty, sets the matching bit in:
readyq_table->nonempty_bucket_bitmap_00
Inserts context->readyq_node_18 into the target bucket.
Calls:
fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294(context)

Important list behavior:

Non-empty bucket path inserts the new node before the current head using head->prev as old tail.
Empty bucket path stores the node as bucket head.
Empty-bucket insertion expects the node to already be self-linked.
The remove helpers leave/restore removed nodes in self-linked state.

Important correction:

The call at:

80e971c4

targets:

fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294

not:

fn_stage1_scheduler_readyq_remove_context_80e971e8

Decompiler artifact:

if (context != NULL) node = &context->readyq_node_18;

is fake as a real API condition, because the function dereferences context earlier through:

context->readyq_bucket_20

Real callers must pass non-NULL context.

fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294

Previous name:

fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294_candidate

Final name:

fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294

Signature:

void fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294
        (stage1_context_candidate *context)

Confirmed behavior:

void fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294
        (stage1_context_candidate *context)

{
  if (((int)context->readyq_bucket_20 <
       (int)g_stage1_current_context_819dcc54->readyq_bucket_20) ||
      (g_stage1_current_context_819dcc54->context_flags_50 != 0)) {
    g_stage1_scheduler_dispatch_needed_flag_819dcc58 = 1;
  }
}

Meaning:

Sets:

g_stage1_scheduler_dispatch_needed_flag_819dcc58 = 1;

when either:

The newly-ready context has numerically lower readyq_bucket_20 than the current context.
The current context has nonzero context_flags_50.

Priority conclusion reinforced:

lower readyq_bucket_20 = higher scheduler priority

This helper does not dispatch directly. It only requests dispatch/preemption at the next allowed scheduler/unlock point.

fn_stage1_scheduler_readyq_remove_context_80e971e8

Previous name:

fn_stage1_scheduler_readyq_remove_context_80e971e8_candidate

Final name:

fn_stage1_scheduler_readyq_remove_context_80e971e8

Signature:

void fn_stage1_scheduler_readyq_remove_context_80e971e8
        (stage1_readyq_table_candidate *readyq_table,
         stage1_context_candidate *context)

Purpose:

Removes a context from the scheduler readyq bucket selected by:
context->readyq_bucket_20

Behavior:

Reads bucket_index from context->readyq_bucket_20.
Gets the bucket head slot:
&readyq_table->bucket_heads_04[bucket_index]
Removes:
context->readyq_node_18

from that bucket’s circular doubly-linked list.

If the context node is the bucket head:
Advances the bucket head to node->next_00
Or clears the head to NULL if this was the only node.
If context node was not the head:
Unlinks it from its current list position.
Leaves or restores context->readyq_node_18 self-linked.
If bucket becomes empty, clears the matching bit in:
readyq_table->nonempty_bucket_bitmap_00

Important wording:

The single-node path does not explicitly rewrite node->next/node->prev.
It relies on the node already being self-linked.

This confirmed the earlier add-helper question:

Empty readyq bucket insertion can simply set the head because the node is expected to already be self-linked.
fn_stage1_context_unlink_from_owner_list_80e97634

Previous name:

fn_stage1_context_unlink_from_owner_list_80e97634_candidate

Final name:

fn_stage1_context_unlink_from_owner_list_80e97634

Signature:

void fn_stage1_context_unlink_from_owner_list_80e97634
        (stage1_readyq_node_candidate **owner_list_head_ref,
         stage1_context_candidate *context)

Purpose:

Generic owner-list unlink helper.

Behavior:

Clears:
context->owner_list_head_ref_28 = NULL;
Unlinks:
context->readyq_node_18

from the circular doubly-linked list whose head pointer is referenced by:

owner_list_head_ref
If the node is the list head:
Updates *owner_list_head_ref to node->next_00
Or NULL if this was the only node.
If the node is not the list head:
Unlinks it from its current list position.
Leaves/restores node self-linking.

Important model:

context->owner_list_head_ref_28 is not an owner object.
It is a pointer to the list-head variable currently owning context->readyq_node_18.

This helper is generic. Do not narrow it to waitq, timer, semaphore, or owned-wait object ownership until callers prove the concrete owner type.

Decompiler artifact:

The late NULL-looking path is fake because the function already dereferences context at entry.

fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c

Previous name:

fn_stage1_waitq_push_back_80e9747c_candidate

Final name:

fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c

Signature:

void fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c
        (stage1_readyq_node_candidate **owner_list_head_ref,
         stage1_context_candidate *context)

Purpose:

Generic context owner-list / wait-list insert helper.

Confirmed core behavior:

Reads current list head from:
*owner_list_head_ref
Inserts:
context->readyq_node_18

into the circular doubly-linked owner/wait list.

Uses:
context->readyq_bucket_20

as an ordering / priority key.

May update:
*owner_list_head_ref

if the inserted context becomes the new head.

Stores:
context->owner_list_head_ref_28 = owner_list_head_ref;

Ownership result:

context->owner_list_head_ref_28 is the exact external list-head slot that later lets
fn_stage1_context_unlink_from_owner_list_80e97634 unlink the context without knowing the owner object.

Decompiler issue:

Ghidra shows container-of artifacts such as:

psVar3 + -3
psVar2[4].next_00
psVar2[3].next_00
psVar2[3].prev_04

These are not real arrays.

They result from:

readyq_node_18 offset = 0x18
sizeof(stage1_readyq_node_candidate) = 0x08
0x18 / 0x08 = 3

So:

psVar3 + -3

means:

(stage1_context_candidate *)((byte *)head_node - 0x18)

And expressions like:

psVar2[4].next_00

are artifacts for fields such as:

context->readyq_bucket_20

Final safe ordering statement:

The list is ordered by context->readyq_bucket_20.
Lower bucket values are higher priority.
The helper may replace *owner_list_head_ref when inserted context becomes the new head/highest-priority context.

Avoid over-describing every branch until assembly is manually checked.

fn_stage1_context_owner_list_pop_front_clear_owner_80e975e4

Previous name:

fn_stage1_waitq_pop_front_80e975e4_candidate

Final name:

fn_stage1_context_owner_list_pop_front_clear_owner_80e975e4

Corrected signature:

stage1_context_candidate *
fn_stage1_context_owner_list_pop_front_clear_owner_80e975e4
        (stage1_readyq_node_candidate **owner_list_head_ref)

Important correction:

The old Ghidra signature showed void, but callers use the returned context.

Behavior:

Reads:
head_node = *owner_list_head_ref;
If empty:
Returns NULL.
If one node:
Clears:
*owner_list_head_ref = NULL;
If multiple nodes:
Advances head to:
head_node->next_00
Unlinks old head.
Restores old head self-linking.
Converts head node back to owning context:
(stage1_context_candidate *)((byte *)head_node - 0x18)
Clears:
popped_context->owner_list_head_ref_28 = NULL;
Returns popped context.

Key decompiler arithmetic:

piVar2 = piVar1 + -6;

means:

popped_context = (stage1_context_candidate *)((byte *)head_node - 0x18);

because piVar1 is an int *:

0x18 / 4 = 6

And:

piVar2[10] = 0;

means:

popped_context->owner_list_head_ref_28 = NULL;

because:

10 * 4 = 40 = 0x28

This is the pop-side counterpart to:

fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c
fn_stage1_wait_object_wake_all_success_80e98cd0

Previous name:

fn_stage1_wait_object_wake_all_success_80e98cd0_candidate

Final name:

fn_stage1_wait_object_wake_all_success_80e98cd0

Signature:

void fn_stage1_wait_object_wake_all_success_80e98cd0
        (stage1_condition_object_candidate *wait_object)

Behavior:

Operates on a wait object whose wait queue head is at object +0x04:
wait_object->waitq_04
Enters scheduler defer/nesting section:
stage1_dispatch_defer_or_running_flag_candidate++;
While wait queue is non-empty:
Pops one waiting context:
fn_stage1_context_owner_list_pop_front_clear_owner_80e975e4(&wait_object->waitq_04)
Clears:
context->wait_state_98 = 0;
Sets:
context->resume_status_9c = 7;
Calls:
fn_stage1_context_make_runnable_80e96154(context);
Leaves scheduler defer/nesting section.
If outermost scheduler section, reaches:
fn_stage1_scheduler_unlock_or_dispatch_loop_80e976a8

Interpretation:

resume_status_9c = 7 appears to be normal success/wake status.

Contrast still pending:

fn_stage1_wait_object_wake_all_status5_80e9801c_candidate

appears to wake waiters with:

resume_status_9c = 5

likely cancelled/destroyed/failure-like, but keep _candidate until opened and confirmed.

Important note:

This helper does not directly set context_flags_50 bit1 / 0x2.

Runnable transition cleanup happens through:

fn_stage1_context_make_runnable_80e96154

which clears low context_flags_50 bits 0x3.

Ghidra stale-register artifacts:

in_a1
in_a2
in_a3

are not meaningful wake parameters here. They appear because of the current scheduler unlock/dispatch helper signature and should not be documented as real wake arguments.

fn_stage1_context_make_runnable_80e96154

Previous name:

fn_stage1_context_make_runnable_80e96154_candidate

Final name:

fn_stage1_context_make_runnable_80e96154

Purpose:

Makes a blocked/non-ready context runnable again.

Confirmed behavior from this pass and prior pass:

Enters scheduler defer/nesting section.
If context->context_flags_50 & 0x3:
Clears low bits:
context->context_flags_50 &= ~0x3;
If context->owner_list_head_ref_28 is nonzero:
Calls:
fn_stage1_context_unlink_from_owner_list_80e97634(context->owner_list_head_ref_28, context);
- Clears ownership.
If flags now zero:
Adds context to readyq:
fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130(
    &g_stage1_scheduler_readyq_table_819dcc5c,
    context
);
Leaves scheduler defer/nesting section.
If outermost, reaches scheduler unlock/dispatch loop.

Important role:

This is the wake/unblock -> readyq transition helper.
fn_stage1_scheduler_unlock_or_dispatch_loop_80e976a8

Final name already used:

fn_stage1_scheduler_unlock_or_dispatch_loop_80e976a8

Purpose:

Central scheduler drain/unlock/dispatch point.

Important behavior relevant to this pass:

Checks scheduler defer/running state.
If dispatch is allowed and either:
current context has nonzero context_flags_50, or
g_stage1_scheduler_dispatch_needed_flag_819dcc58 is set,
then:
selects next context with:
fn_stage1_scheduler_readyq_select_context_80e970f4
performs context switch if selected context differs.
Clears dispatch-needed flag after dispatch handling.
Reloads scheduler budget/timeslice:
g_stage1_scheduler_timeslice_or_budget_reload_819dcc50 = 50000;

Important relation:

fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294
only sets the flag.
This dispatch loop consumes it.
Function rename summary

Renamed / finalized during this work:

fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748_candidate
-> fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748

fn_stage1_scheduler_readyq_select_context_80e970f4_candidate
-> fn_stage1_scheduler_readyq_select_context_80e970f4

fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130_candidate
-> fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130

fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294_candidate
-> fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294

fn_stage1_scheduler_readyq_remove_context_80e971e8_candidate
-> fn_stage1_scheduler_readyq_remove_context_80e971e8

fn_stage1_context_unlink_from_owner_list_80e97634_candidate
-> fn_stage1_context_unlink_from_owner_list_80e97634

fn_stage1_waitq_push_back_80e9747c_candidate
-> fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c

fn_stage1_waitq_pop_front_80e975e4_candidate
-> fn_stage1_context_owner_list_pop_front_clear_owner_80e975e4

fn_stage1_wait_object_wake_all_success_80e98cd0_candidate
-> fn_stage1_wait_object_wake_all_success_80e98cd0

Already finalized in earlier work and reinforced here:

fn_stage1_context_make_runnable_80e96154
fn_stage1_scheduler_unlock_or_dispatch_loop_80e976a8

Still candidate / pending:

fn_stage1_wait_object_wake_all_status5_80e9801c_candidate
fn_stage1_owned_wait_object_acquire_blocking_80e98770_candidate
stage1_condition_object_candidate
stage1_thread_record_candidate partial fields
some context_flags_50 bit meanings
exact resume_status_9c enum names
Datatype and symbol corrections to keep
Use pointer type for owner-list head references

Use:

stage1_readyq_node_candidate **owner_list_head_ref;

not a concrete owner object pointer.

Rationale:

The same helper is used for generic owner/wait lists.
The context stores a pointer to the head slot, not the owning object.
Use table type for readyq helpers

For readyq add/remove/select, use:

stage1_readyq_table_candidate *readyq_table;

not:

uint *readyq_table;
Use correct return type for pop-front helper

Use:

stage1_context_candidate *
fn_stage1_context_owner_list_pop_front_clear_owner_80e975e4(...)

not:

void

because wake helpers consume the returned context.

Keep owner_list_head_ref_28 as field name

Do not rename it to just owner object or wait object.

Correct meaning:

field +0x28 = pointer to external owner-list head slot

Good field name:

owner_list_head_ref_28
Avoid over-narrowing owner-list helpers

The owner-list helpers are generic.

Do not name them as only:

semaphore queue
timer queue
condition queue
event queue

until specific callers prove concrete owner type.

Ghidra decompiler artifact notes
Fake NULL paths

Several helpers show late NULL checks like:

if (context != NULL) node = &context->readyq_node_18;

These are artifacts when the same function already dereferences context earlier.

Do not model these functions as NULL-safe unless assembly and caller behavior prove it.

Affected helpers:

fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130
fn_stage1_scheduler_readyq_remove_context_80e971e8
fn_stage1_context_unlink_from_owner_list_80e97634
fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c
Container-of artifacts

Ghidra may display:

node + -3

or:

piVar1 + -6

depending on pointer type.

Meaning:

node + -3 with stage1_readyq_node_candidate *:
  subtracts 3 * 8 = 0x18

piVar1 + -6 with int *:
  subtracts 6 * 4 = 0x18

Both mean:

(stage1_context_candidate *)((byte *)node - 0x18)

because:

context->readyq_node_18 is embedded at context + 0x18
Array-looking field artifacts

Expressions like:

psVar2[4].next_00
psVar2[3].next_00
psVar2[3].prev_04

inside fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c are not real arrays.

They are Ghidra’s wrong typed view of:

stage1_context_candidate fields reached after container_of(node - 0x18)

Do not create fake array fields or dummy structs for these artifacts.

Status of scheduler priority model

Confirmed:

lower readyq_bucket_20 = higher priority

Evidence chain:

fn_stage1_readyq_bitmap_lowest_set_bucket_index_80ea3748
-> returns lowest set bit from readyq nonempty bitmap

fn_stage1_scheduler_readyq_select_context_80e970f4
-> selects bucket_heads_04[lowest_set_bit]

fn_stage1_scheduler_mark_dispatch_needed_if_preempt_needed_80e97294
-> marks dispatch needed if new_context->readyq_bucket_20 < current_context->readyq_bucket_20

fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c
-> uses readyq_bucket_20 as owner/wait-list ordering key
Status of owner-list model

Confirmed:

context->owner_list_head_ref_28

is:

stage1_readyq_node_candidate **owner_list_head_ref;

Meaning:

pointer to the external list-head variable that currently owns context->readyq_node_18

Install:

fn_stage1_context_owner_list_insert_by_priority_set_owner_80e9747c

Pop head and clear:

fn_stage1_context_owner_list_pop_front_clear_owner_80e975e4

Unlink arbitrary context and clear:

fn_stage1_context_unlink_from_owner_list_80e97634

Readyq add detaches if needed:

fn_stage1_scheduler_readyq_add_context_maybe_dispatch_80e97130

Make runnable detaches if still owner-linked:

fn_stage1_context_make_runnable_80e96154
Status of wait-object wake-all success path

Confirmed:

wait_object + 0x04 = waitq head

Wake-all success path:

fn_stage1_wait_object_wake_all_success_80e98cd0
-> pop waiting contexts from wait_object->waitq_04
-> wait_state_98 = 0
-> resume_status_9c = 7
-> make runnable
-> readyq add
-> dispatch-needed check
-> scheduler unlock/dispatch loop

Interpretation:

resume_status_9c = 7 = normal success/wake status

Still pending:

resume_status_9c = 5 in fn_stage1_wait_object_wake_all_status5_80e9801c_candidate

Likely cancelled/destroyed/failure-like release, but not finalized.

Recommended next targets
1. Open status5 wake helper
fn_stage1_wait_object_wake_all_status5_80e9801c_candidate

Goal:

Confirm same wake-all pattern as success wake helper.
Confirm it sets:
context->resume_status_9c = 5;
Decide final name, likely:
fn_stage1_wait_object_wake_all_status5_80e9801c

or, if caller context proves destroy/cancel:

fn_stage1_wait_object_wake_all_cancelled_or_destroyed_80e9801c

Do not remove _candidate from semantic destroy/cancel wording until callers prove it.

2. Open blocking acquire helper
fn_stage1_owned_wait_object_acquire_blocking_80e98770_candidate

Reason:

Scalar/xref search showed writes at:

80e987b4  sw s0,0x28(param_1)
80e98878  sw zero,0x28(param_1)

Likely meaning:

sets and clears context->owner_list_head_ref_28 in a higher-level blocking acquire path

Goal:

Identify concrete owner object layout.
Confirm how blocking path transitions current context from readyq into owner/wait list.
Confirm context_flags_50 bit meanings.
3. Trace writes to context_flags_50

Goal:

Confirm bit0 / bit1 exact meanings.
Current known behavior:
fn_stage1_context_make_runnable_80e96154 clears low bits 0x3.
Readyq dispatch marker checks if current context has nonzero context_flags_50.
Still pending:
exact names for bit0 and bit1.
4. Define resume status enum later

Current observed values:

resume_status_9c = 7  normal success/wake
resume_status_9c = 5  likely cancelled/destroyed/failure-like

Do not create final enum names until more callers are reviewed.

Potential future type:

typedef enum stage1_resume_status_candidate {
    STAGE1_RESUME_STATUS_5_CANDIDATE = 5,
    STAGE1_RESUME_STATUS_SUCCESS_7 = 7,
} stage1_resume_status_candidate;

Keep candidate on enum until more statuses are known.

Current confidence

High confidence:

readyq table layout
readyq node layout
readyq select/add/remove behavior
De Bruijn bitmap helper
priority rule: lower bucket = higher priority
owner_list_head_ref_28 pointer-to-head-slot model
generic owner-list insert/unlink/pop behavior
success wake-all path with resume_status_9c = 7

Medium confidence:

owner-list insertion exact sorted traversal branch details
resume_status_9c value names
context_flags_50 bit names
concrete owner object types for all wait queues

Low / not finalized:

status5 wake helper semantic name
owned wait object concrete struct layout
full scheduler wait/blocking object taxonomy
Final working chain summary
1. Context blocks / waits:
   - readyq remove path removes context from runnable bucket
   - owner-list insert path adds context->readyq_node_18 to wait/owner list
   - context->owner_list_head_ref_28 records the exact list-head slot

2. Context is woken:
   - wake helper pops from wait_object->waitq_04
   - pop helper clears context->owner_list_head_ref_28
   - wake helper sets wait_state_98 = 0
   - wake helper sets resume_status_9c = 7 for success

3. Context becomes runnable:
   - make-runnable clears low context_flags_50 bits
   - detaches owner-list state if still linked
   - adds context to readyq bucket selected by readyq_bucket_20

4. Scheduler checks preemption:
   - dispatch-needed flag set if new context bucket is numerically lower than current context bucket
   - or if current context has nonzero context_flags_50

5. Scheduler dispatch:
   - dispatch loop selects lowest-numbered non-empty readyq bucket
   - selected node is converted back to context by subtracting 0x18
   - context switch runs if selected context differs from current context
Record end

Created for continued TC7200U Stage1 Ghidra reverse-engineering work.
