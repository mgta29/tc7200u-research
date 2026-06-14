# 2026-06-14 - Stage1 PI / owned-wait-object scheduler chain

## Scope

This record captures the Stage1 scheduler / priority-inheritance / owned-wait-object work completed in Ghidra during this pass.

Main focus:

- readyq-node based context references
- owned wait object acquisition/release behavior
- priority-inheritance boost handoff
- priority-inheritance recompute/restore
- owned PI object list add/remove helpers
- context priority update with readyq or wait-list requeue
- datatype and field-name cleanup
- function renames where behavior is now clear enough

Repository policy for this record:

- No old logs deleted.
- Existing malformed/broken copy was preserved as a dated `before-repair` file if it existed.
- This file is a dated reverse-engineering record.
- No git command was run or required for this note.
- Correct output directory: `~/tc7200u-research/records/reverse/`.

## High-level result

The owned-wait-object priority-inheritance chain is now mostly closed.

Confirmed chain:

~~~text
owned wait object acquire
-> if PI mode is enabled:
     owner gets boost pressure from waiter context

owned wait object release
-> pop one waiter
-> if more waiters remain:
     transfer/continue PI pressure onto popped waiter
-> wake popped waiter with resume_status_9c = 7
-> remove released object from old owner's owned-PI list
-> recompute/restore old owner's inherited priority
~~~

The important structural model is:

~~~text
context->{@field readyq_node_18}
  is an embedded scheduler/list node

helpers often receive:
  &context->{@field readyq_node_18}

to recover context:
  context = readyq_node - 0x18
~~~

This explains many apparent `param_1 + offset` accesses in the decompiler.

## Major confirmed scheduler model

Lower readyq bucket values mean higher scheduler priority.

Confirmed fields:

~~~text
context->{@field readyq_bucket_20}
  current/effective readyq bucket

context->{@field base_readyq_bucket_48_candidate}
  base/requested bucket while PI is active

context->{@field priority_inheritance_active_4c_candidate}
  nonzero when PI inheritance is currently active

context->{@field owned_pi_object_list_head_3c_candidate}
  singly-linked list of PI-capable wait objects owned by this context

owned_object->{@field next_owned_pi_object_0c_candidate}
  next pointer in owner_context owned-PI-object list

owned_object->{@field waitq_08}
  queue/list of contexts waiting on this owned object
~~~

## Naming policy applied in this pass

Function names with clear behavior were changed from `_candidate` to final names.

Structures remain `_candidate` for now because the full layouts still contain provisional fields. Individual fields with clear semantics can be renamed or cleaned even when the structure name remains candidate.

Rule applied:

~~~text
Clear function role + clear argument model + clear side effects
-> remove _candidate from function name

Struct still has unknown fields
-> keep struct name with _candidate

Field now proven by xrefs and behavior
-> field name may be cleaned
~~~

## Field rename performed

At `stage1_context_candidate + 0x48`:

Old name:

~~~c
saved_base_readyq_bucket_48_candidate
~~~

New name:

~~~c
base_readyq_bucket_48_candidate
~~~

Reason:

- The PI boost helper saves the prior effective bucket there when PI starts.
- The priority update helper writes the requested/base bucket there while PI remains active.
- The recompute/restore helper reads it to restore the context toward its base bucket.

Therefore the field is not only a one-shot saved value. It is the tracked base/requested bucket during PI mode.

## Function renames completed or recommended as completed

~~~text
fn_stage1_waitq_if_more_waiters_transfer_pi_boost_80e9798c
fn_stage1_context_node_apply_priority_inheritance_boost_80e97930
fn_stage1_context_update_priority_requeue_80e965e8
fn_stage1_pi_recompute_restore_wrapper_80e97b24
fn_stage1_context_node_recompute_priority_inheritance_80e979b8
fn_stage1_context_node_remove_owned_pi_object_80e97a9c
fn_stage1_context_node_add_owned_pi_object_80e97a8c
~~~

The deeper semantics are clear enough for these function identities. Remaining uncertainty is limited to minor detail such as exact waiter scan selection in the recompute helper.


---

# Structures and datatypes

## `stage1_readyq_node_candidate`

Confirmed embedded list node:

~~~c
typedef struct stage1_readyq_node_candidate {
    struct stage1_readyq_node_candidate *next_00;
    struct stage1_readyq_node_candidate *prev_04;
} stage1_readyq_node_candidate; // size 0x08
~~~

Used by:

- scheduler ready queues
- blocked/wait queues
- owner/wait ordered lists
- context embedded node at `context->{@field readyq_node_18}`

Important pattern:

~~~text
readyq_node pointer = context + 0x18
context pointer     = readyq_node - 0x18
~~~

## `stage1_readyq_table_candidate`

Confirmed readyq table shape:

~~~c
typedef struct stage1_readyq_table_candidate {
    uint nonempty_bucket_bitmap_00;
    stage1_readyq_node_candidate *bucket_heads_04[32];
} stage1_readyq_table_candidate; // size 0x84
~~~

Global object:

~~~c
g_stage1_scheduler_readyq_table_819dcc5c
~~~

This is an inline global table object, not a pointer.

## Scheduler global cluster

Known scheduler cluster:

~~~text
819dcc4c  g_stage1_scheduler_unlock_callback_list_head_819dcc4c
819dcc50  g_stage1_scheduler_timeslice_or_budget_reload_819dcc50
819dcc54  g_stage1_current_context_819dcc54
819dcc58  g_stage1_scheduler_dispatch_needed_flag_819dcc58
819dcc5c  g_stage1_scheduler_readyq_table_819dcc5c
819dcce0  g_stage1_context_switch_counter_819dcce0
~~~

Typing rule:

~~~c
g_stage1_current_context_819dcc54
~~~

must be typed as:

~~~c
stage1_context_candidate *
~~~

not as an inline `stage1_context_candidate` object.

If typed as a full object, it overlaps:

~~~text
g_stage1_scheduler_dispatch_needed_flag_819dcc58
g_stage1_scheduler_readyq_table_819dcc5c
~~~

## `stage1_context_candidate` relevant field block

Relevant field map after this pass:

~~~c
typedef struct stage1_context_candidate {
    undefined1 pad_00[0x0c];                                           // +0x00
    undefined1 context_switch_state_0c[0x0c];                          // +0x0c

    stage1_readyq_node_candidate readyq_node_18;                       // +0x18
    uint readyq_bucket_20;                                             // +0x20
    undefined4 field_24;                                               // +0x24

    stage1_readyq_node_candidate **owner_list_head_ref_28;             // +0x28
    uint scheduler_callback_block_count_2c_candidate;                  // +0x2c
    uint pending_callback_flag_30;                                     // +0x30
    undefined4 pending_callback_arg_34;                                // +0x34

    uint owned_pi_object_count_38_candidate;                           // +0x38
    stage1_owned_wait_object_candidate *owned_pi_object_list_head_3c_candidate; // +0x3c
    stage1_owned_wait_object_candidate *current_owned_wait_object_acquire_candidate; // +0x40
    undefined4 field_44;                                               // +0x44

    uint base_readyq_bucket_48_candidate;                              // +0x48
    uint priority_inheritance_active_4c_candidate;                     // +0x4c

    uint context_flags_50;                                             // +0x50
    uint context_activation_hold_count_54_candidate;                   // +0x54
    undefined4 *field_58;                                              // +0x58
    stage1_event_wait_condition_candidate *wait_condition_5c;          // +0x5c
    ushort context_trace_id_60;                                        // +0x60
    undefined1 pad_62[6];                                              // +0x62

    undefined1 timeout_list_object_68_candidate[0x30];                 // +0x68
    uint wait_state_98;                                                // +0x98
    uint resume_status_9c;                                             // +0x9c

    undefined4 extended_zero_area_a0_candidate[3];                     // +0xa0
    stage1_thread_record_candidate *thread_record_ac_candidate;        // +0xac

    undefined4 extended_zero_area_b0_candidate[12];                    // +0xb0
    stage1_context_cleanup_callback_pair_candidate cleanup_callback_pairs_e0_candidate[8]; // +0xe0

    undefined4 field_120_candidate;                                    // +0x120
    stage1_context_candidate *next_registered_context_124_candidate;   // +0x124
} stage1_context_candidate;
~~~

## Important context corrections

### `owner_list_head_ref_28`

Correct type:

~~~c
stage1_readyq_node_candidate **owner_list_head_ref_28;
~~~

This is a pointer to the external head slot that owns `context->{@field readyq_node_18}`.

It is not:

~~~c
stage1_readyq_node_candidate *owner_list_head_ref_28;
~~~

Reason:

- owner-list insert stores the list-head reference in the context
- owner-list unlink uses the reference to update the external head pointer
- make-runnable and priority-requeue use it to remove/reinsert blocked contexts while preserving ordering

### `base_readyq_bucket_48_candidate`

Correct current name:

~~~c
uint base_readyq_bucket_48_candidate;
~~~

Meaning:

- base/requested readyq bucket while PI is active
- restore target when no remaining PI donor pressure exists
- updated by priority update helper while PI-active flag is nonzero

### `priority_inheritance_active_4c_candidate`

Correct current name:

~~~c
uint priority_inheritance_active_4c_candidate;
~~~

Meaning:

- nonzero when current effective priority is under PI management
- temporarily cleared during priority update/recompute to avoid recursive base/boost confusion
- set again if donor pressure remains

## `stage1_owned_wait_object_candidate`

Confirmed owned wait object layout:

~~~c
typedef struct stage1_owned_wait_object_candidate {
    byte active_or_locked_00;                         // +0x00
    byte pad_01[3];                                   // +0x01
    stage1_context_candidate *owner_context_04;       // +0x04
    stage1_readyq_node_candidate *waitq_08;           // +0x08
    struct stage1_owned_wait_object_candidate *next_owned_pi_object_0c_candidate; // +0x0c
    uint ownership_pi_mode_10;                        // +0x10
} stage1_owned_wait_object_candidate;                 // size 0x14
~~~

Confirmed field meanings:

~~~text
active_or_locked_00
  object is currently owned/locked

owner_context_04
  current owner context

waitq_08
  queue of contexts waiting for this object

next_owned_pi_object_0c_candidate
  singly-linked next pointer in owner_context owned-PI-object list

ownership_pi_mode_10
  nonzero enables owned-object PI accounting
  value 1 selects full priority-inheritance behavior
~~~

## `stage1_condition_object_candidate`

Current known condition object layout remains:

~~~c
typedef struct stage1_condition_object_candidate {
    stage1_owned_wait_object_candidate *associated_owned_wait_object_00_candidate; // +0x00
    stage1_readyq_node_candidate *waitq_04;                                       // +0x04
    uint field_08_candidate;                                                     // +0x08
} stage1_condition_object_candidate; // size 0x0c
~~~

Do not replace this with a dummy/minimal structure. It already carries useful known fields.

## Context flags

Current confirmed flag model:

~~~c
#define STAGE1_CONTEXT_FLAG_NONREADY_01  0x00000001
#define STAGE1_CONTEXT_FLAG_LOWBIT_02    0x00000002
#define STAGE1_CONTEXT_FLAG_DEAD_10      0x00000010
~~~

Known behavior:

~~~text
0x01
  set by {@symbol fn_stage1_current_context_mark_nonready_remove_readyq_80e960d0}
  cleared by {@symbol fn_stage1_context_make_runnable_80e96154}
  means non-ready / blocked / removed from readyq

0x02
  cleared together with bit0 by {@symbol fn_stage1_context_make_runnable_80e96154}
  setter not yet confirmed

0x10
  written by {@symbol fn_stage1_current_context_cleanup_mark_dead_80e96428}
  terminal/dead/cleanup-marked state
~~~

## Wait and resume fields

Known wait/resume fields:

~~~c
uint wait_state_98;
uint resume_status_9c;
~~~

Known values:

~~~text
wait_state_98 = 1
  waiting for owned wait object / mutex-like acquire path

wait_state_98 = 3
  condition/timed condition wait path

resume_status_9c = 0
  no result yet / still waiting

resume_status_9c = 7
  normal wake/success-style resume from owned wait object release or wake-all success

resume_status_9c = 3,4,5
  failure/cancel/timeout-like result in condition wait path

resume_status_9c = 6
  cleanup/dead path
~~~

Keep exact enum names provisional until broader xrefs are decoded.


---

# Function findings and signatures

## `fn_stage1_waitq_if_more_waiters_transfer_pi_boost_80e9798c`

Old name:

~~~c
fn_stage1_waitq_if_more_waiters_transfer_pi_boost_80e9798c_candidate
~~~

Final name:

~~~c
fn_stage1_waitq_if_more_waiters_transfer_pi_boost_80e9798c
~~~

Recommended signature:

~~~c
void fn_stage1_waitq_if_more_waiters_transfer_pi_boost_80e9798c
        (stage1_readyq_node_candidate *woken_context_node,
         stage1_context_candidate *old_owner_context,
         stage1_readyq_node_candidate **remaining_waitq_head_ref)
~~~

Known caller:

~~~c
{@symbol fn_stage1_owned_wait_object_release_wake_one_80e989dc}
~~~

Call position:

~~~text
after one waiter is popped from wait_object->{@field waitq_08}
before the popped waiter is made runnable
only when wait_object->{@field ownership_pi_mode_10} == 1
~~~

Confirmed behavior:

~~~c
if (*remaining_waitq_head_ref != NULL) {
    fn_stage1_context_node_apply_priority_inheritance_boost_80e97930
        (woken_context_node, old_owner_context->readyq_bucket_20);
}
~~~

Meaning:

~~~text
If the owned object still has waiters after one waiter was popped,
continue/transfer PI pressure to the popped waiter by applying the old owner's
effective readyq bucket to that waiter.
~~~

Important note:

This helper does not inspect the remaining waiter directly. It only checks whether at least one waiter remains, then applies `old_owner_context->{@field readyq_bucket_20}` to `woken_context_node`.

## `fn_stage1_context_node_apply_priority_inheritance_boost_80e97930`

Old name:

~~~c
fn_stage1_context_node_apply_priority_inheritance_boost_80e97930_candidate
~~~

Final name:

~~~c
fn_stage1_context_node_apply_priority_inheritance_boost_80e97930
~~~

Recommended signature:

~~~c
void fn_stage1_context_node_apply_priority_inheritance_boost_80e97930
        (stage1_readyq_node_candidate *context_readyq_node,
         int inherited_readyq_bucket)
~~~

Argument model:

~~~text
context_readyq_node = &context->{@field readyq_node_18}
inherited_readyq_bucket = donor/inherited bucket
~~~

Offset decoding:

~~~text
context_readyq_node + 0x08  -> context->{@field readyq_bucket_20}
context_readyq_node + 0x30  -> context->{@field base_readyq_bucket_48_candidate}
context_readyq_node + 0x34  -> context->{@field priority_inheritance_active_4c_candidate}
context_readyq_node - 0x18  -> context
~~~

Confirmed behavior:

~~~text
if inherited bucket numerically outranks current effective bucket:
  save old PI-active marker
  temporarily clear PI-active marker
  update/requeue context to inherited bucket
  if PI was not already active:
      save previous effective bucket into base_readyq_bucket_48_candidate
  set PI-active marker
~~~

This helper does not touch `context_flags_50` directly.

## `fn_stage1_context_update_priority_requeue_80e965e8`

Old name:

~~~c
fn_stage1_context_update_priority_requeue_80e965e8_candidate
~~~

Final name:

~~~c
fn_stage1_context_update_priority_requeue_80e965e8
~~~

Recommended signature:

~~~c
void fn_stage1_context_update_priority_requeue_80e965e8
        (stage1_context_candidate *context,
         int requested_readyq_bucket)
~~~

Do not keep stale decompiler artifacts as semantic parameters:

~~~c
undefined4 param_3
undefined4 param_4
~~~

Confirmed behavior:

~~~text
enter scheduler defer/nesting

if context_flags_50 == 0:
  remove context from global readyq table

else if context_flags_50 bit0 is set and owner_list_head_ref_28 is non-NULL:
  unlink context from current owner/wait list
  clear owner_list_head_ref_28

update priority fields:
  if PI is not active:
      readyq_bucket_20 = requested_readyq_bucket
  else:
      base_readyq_bucket_48_candidate = requested_readyq_bucket
      if requested bucket outranks current effective bucket:
          readyq_bucket_20 = requested_readyq_bucket

if context was runnable:
  reinsert into global readyq table

else if context was blocked on owner/wait list:
  reinsert into that owner/wait list

mark dispatch needed:
  direct flag if current context
  otherwise preemption check helper

leave scheduler defer/nesting
dispatch if outermost
~~~

Important side effect:

The function preserves list membership while changing priority. It removes and reinserts the context so readyq or wait-owner list ordering stays valid.

## `fn_stage1_pi_recompute_restore_wrapper_80e97b24`

Old name:

~~~c
fn_stage1_pi_recompute_restore_wrapper_80e97b24_candidate
~~~

Final name:

~~~c
fn_stage1_pi_recompute_restore_wrapper_80e97b24
~~~

Recommended signature:

~~~c
void fn_stage1_pi_recompute_restore_wrapper_80e97b24
        (stage1_readyq_node_candidate *context_readyq_node)
~~~

Confirmed behavior:

~~~c
fn_stage1_context_node_recompute_priority_inheritance_80e979b8
    (context_readyq_node);
~~~

This wrapper has no independent scheduler behavior.

## `fn_stage1_context_node_recompute_priority_inheritance_80e979b8`

Old name:

~~~c
fn_stage1_context_node_recompute_priority_inheritance_80e979b8_candidate
~~~

Final name:

~~~c
fn_stage1_context_node_recompute_priority_inheritance_80e979b8
~~~

Recommended signature:

~~~c
void fn_stage1_context_node_recompute_priority_inheritance_80e979b8
        (stage1_readyq_node_candidate *owner_context_readyq_node)
~~~

Argument model:

~~~text
owner_context_readyq_node = &owner_context->{@field readyq_node_18}
~~~

Offset decoding:

~~~text
owner_context_readyq_node - 0x18  -> owner_context
owner_context_readyq_node + 0x08  -> owner_context->{@field readyq_bucket_20}
owner_context_readyq_node + 0x24  -> owner_context->{@field owned_pi_object_list_head_3c_candidate}
owner_context_readyq_node + 0x30  -> owner_context->{@field base_readyq_bucket_48_candidate}
owner_context_readyq_node + 0x34  -> owner_context->{@field priority_inheritance_active_4c_candidate}
~~~

Confirmed behavior:

~~~text
if PI active:
  read owner_context owned-PI-object list
  read base bucket
  clear PI-active marker

  if current effective bucket outranks base bucket:
      restore/requeue toward base bucket

  scan remaining owned PI objects and their waitq_08 lists

  if remaining candidate donor bucket outranks current effective bucket:
      update/requeue to inherited bucket
      mark PI active again
~~~

Caution:

The decompiler traversal currently overwrites the candidate bucket while scanning wait queues. It does not cleanly prove whether the selected donor is first waiter, last waiter, or best/numerically lowest bucket waiter. Do not finalize that detail until waitq ordering and assembly are checked.

## `fn_stage1_context_node_remove_owned_pi_object_80e97a9c`

Old name:

~~~c
fn_stage1_context_node_remove_owned_pi_object_80e97a9c_candidate
~~~

Final name:

~~~c
fn_stage1_context_node_remove_owned_pi_object_80e97a9c
~~~

Recommended signature:

~~~c
void fn_stage1_context_node_remove_owned_pi_object_80e97a9c
        (stage1_readyq_node_candidate *owner_context_readyq_node,
         stage1_owned_wait_object_candidate *owned_pi_object)
~~~

Confirmed behavior:

~~~text
link_ref = &owner_context->owned_pi_object_list_head_3c_candidate

if object is head:
  update head to object->next

else:
  walk singly-linked list until current->next == object
  update current->next to object->next

clear object->next_owned_pi_object_0c_candidate
~~~

This helper does not directly change readyq membership, wait state, resume status, context flags, or priority fields.

## `fn_stage1_context_node_add_owned_pi_object_80e97a8c`

Old name:

~~~c
fn_stage1_context_node_add_owned_pi_object_80e97a8c_candidate
~~~

Final name:

~~~c
fn_stage1_context_node_add_owned_pi_object_80e97a8c
~~~

Recommended signature:

~~~c
void fn_stage1_context_node_add_owned_pi_object_80e97a8c
        (stage1_readyq_node_candidate *owner_context_readyq_node,
         stage1_owned_wait_object_candidate *owned_pi_object)
~~~

Confirmed behavior:

~~~c
owned_pi_object->next_owned_pi_object_0c_candidate =
    owner_context->owned_pi_object_list_head_3c_candidate;

owner_context->owned_pi_object_list_head_3c_candidate =
    owned_pi_object;
~~~

Meaning:

~~~text
Push object at head of owner_context owned-PI-object singly-linked list.
~~~

This helper does not directly change readyq membership, wait state, resume status, context flags, or priority fields.

## Owned PI list pair now closed

~~~text
add:
  {@symbol fn_stage1_context_node_add_owned_pi_object_80e97a8c}
  -> push owned object at owner_context->{@field owned_pi_object_list_head_3c_candidate}

remove:
  {@symbol fn_stage1_context_node_remove_owned_pi_object_80e97a9c}
  -> unlink owned object from owner_context->{@field owned_pi_object_list_head_3c_candidate}
  -> clear owned_object->{@field next_owned_pi_object_0c_candidate}
~~~


---

# Final result of this pass

## PI boost and restore model

The Stage1 owned-wait-object PI model now looks like this:

~~~text
1. A context waits on a PI-capable owned wait object.

2. If the wait object is already owned:
   - waiting context is inserted into object->{@field waitq_08}
   - owner may receive inherited priority pressure

3. If owner is boosted:
   - owner_context->{@field priority_inheritance_active_4c_candidate} becomes nonzero
   - owner_context->{@field readyq_bucket_20} becomes the inherited/effective bucket
   - owner_context->{@field base_readyq_bucket_48_candidate} tracks the base/requested bucket

4. When owner releases the object:
   - one waiter is popped
   - if more waiters remain, the popped waiter receives PI handoff pressure
   - old owner removes the object from owned_pi_object_list_head_3c_candidate
   - old owner's PI is recomputed/restored

5. If no owned object still has waiters:
   - old owner is restored toward base_readyq_bucket_48_candidate
   - priority_inheritance_active_4c_candidate remains cleared
~~~

## Release-side chain

Confirmed release-side call chain:

~~~text
{@symbol fn_stage1_owned_wait_object_release_wake_one_80e989dc}
  -> pop waiter from wait_object->{@field waitq_08}

  if wait_object->{@field ownership_pi_mode_10} == 1:
    -> {@symbol fn_stage1_waitq_transfer_pi_boost_wrapper_80e97b08}
       -> {@symbol fn_stage1_waitq_if_more_waiters_transfer_pi_boost_80e9798c}
          -> {@symbol fn_stage1_context_node_apply_priority_inheritance_boost_80e97930}

  -> set popped_context->{@field wait_state_98} = 0
  -> set popped_context->{@field resume_status_9c} = 7
  -> {@symbol fn_stage1_context_make_runnable_80e96154}

  if PI mode:
    -> decrement old_owner_context->{@field owned_pi_object_count_38_candidate}
    -> {@symbol fn_stage1_context_node_remove_owned_pi_object_80e97a9c}
    -> {@symbol fn_stage1_pi_recompute_restore_wrapper_80e97b24}
       -> {@symbol fn_stage1_context_node_recompute_priority_inheritance_80e979b8}

  -> clear wait_object ownership state
~~~

## Acquire-side relationship

Previously connected acquire-side behavior remains consistent with this pass:

~~~text
{@symbol fn_stage1_owned_wait_object_acquire_blocking_80e98770}
  - waits while object is locked
  - inserts current context into object->{@field waitq_08}
  - applies owner PI boost when ownership_pi_mode_10 == 1
  - on successful acquisition:
      object->{@field active_or_locked_00} = 1
      object->{@field owner_context_04} = current_context
      if PI mode:
        add object to current_context->{@field owned_pi_object_list_head_3c_candidate}
~~~

This matches the add/remove list helper behavior.

## Names now safe to use without `_candidate`

~~~text
fn_stage1_waitq_if_more_waiters_transfer_pi_boost_80e9798c
fn_stage1_context_node_apply_priority_inheritance_boost_80e97930
fn_stage1_context_update_priority_requeue_80e965e8
fn_stage1_pi_recompute_restore_wrapper_80e97b24
fn_stage1_context_node_recompute_priority_inheritance_80e979b8
fn_stage1_context_node_remove_owned_pi_object_80e97a9c
fn_stage1_context_node_add_owned_pi_object_80e97a8c
~~~

## Names still intentionally provisional

Keep `_candidate` or unresolved status for these until opened/decoded:

~~~text
FUN_80e9730c
FUN_80e97304
FUN_80e98754
fn_stage1_wait_object_wake_all_status5_80e9801c_candidate
fn_stage1_context_wake_if_waiting_make_runnable_80e963a0_candidate
~~~

Reason:

- some may be lock/interrupt/scheduler bookkeeping helpers
- exact status enum names are not fully proven
- one helper may be an initializer/reset helper but body has not been decoded in this pass

## Datatype cleanup checklist

In Ghidra, confirm these types and fields:

~~~text
stage1_context_candidate +0x18
  stage1_readyq_node_candidate readyq_node_18

stage1_context_candidate +0x20
  uint readyq_bucket_20

stage1_context_candidate +0x28
  stage1_readyq_node_candidate **owner_list_head_ref_28

stage1_context_candidate +0x38
  uint owned_pi_object_count_38_candidate

stage1_context_candidate +0x3c
  stage1_owned_wait_object_candidate *owned_pi_object_list_head_3c_candidate

stage1_context_candidate +0x40
  stage1_owned_wait_object_candidate *current_owned_wait_object_acquire_candidate

stage1_context_candidate +0x48
  uint base_readyq_bucket_48_candidate

stage1_context_candidate +0x4c
  uint priority_inheritance_active_4c_candidate

stage1_owned_wait_object_candidate +0x04
  stage1_context_candidate *owner_context_04

stage1_owned_wait_object_candidate +0x08
  stage1_readyq_node_candidate *waitq_08

stage1_owned_wait_object_candidate +0x0c
  stage1_owned_wait_object_candidate *next_owned_pi_object_0c_candidate

stage1_owned_wait_object_candidate +0x10
  uint ownership_pi_mode_10
~~~

## Comment cleanup checklist

Search old comments and replace this obsolete field name:

~~~text
saved_base_readyq_bucket_48_candidate
~~~

with:

~~~text
base_readyq_bucket_48_candidate
~~~

Search and fix typo:

~~~text
next_owned_pi_object_0c_candidate_candidate
~~~

to:

~~~text
next_owned_pi_object_0c_candidate
~~~

## Ghidra calling convention cleanup

For any decoded helper showing:

~~~c
/* WARNING: Unknown calling convention -- yet parameter storage is locked */
~~~

repair with:

~~~text
Edit Function Signature
-> set calling convention to default or __stdcall
-> uncheck Use Custom Storage
-> remove stale extra parameters
-> keep only semantic parameters
~~~

Do not manually force register storage unless there is a specific reason.

## Known open cautions

### Waitq scan selection in recompute helper

The recompute helper scans owned objects and waiter queues. The current decompiler output does not cleanly prove whether it selects:

~~~text
first waiter
last waiter
best-priority waiter
~~~

Do not write final comments claiming minimum-priority selection until assembly/list ordering confirms it.

### `FUN_80e9730c` and `FUN_80e97304`

These are called around the priority-field write inside:

~~~c
{@symbol fn_stage1_context_update_priority_requeue_80e965e8}
~~~

They are likely scheduler/interrupt/lock bookkeeping, but do not name them until opened.

### Status values

`resume_status_9c = 7` is strongly success-style wake.

Status values `3`, `4`, `5`, and `6` need more enum work before final naming.

## Recommended next target

Open next:

~~~c
FUN_80e98754
~~~

Expected reason:

~~~text
Likely owned-wait-object initializer/reset helper.
~~~

After that, useful follow-up targets:

~~~text
FUN_80e9730c
FUN_80e97304
fn_stage1_wait_object_wake_all_status5_80e9801c_candidate
fn_stage1_context_wake_if_waiting_make_runnable_80e963a0_candidate
~~~

## Do not do next

Do not:

~~~text
- mass-remove _candidate from all structures
- invent missing fields
- create dummy placeholder functions
- rename fields without updating comments/xrefs
- finalize waitq donor-selection semantics from current decompiler output alone
- write new records under records/notes/
~~~

## Final state

This pass closes the Stage1 owned-wait-object PI list mechanics and most of the boost/recompute behavior.

Most important result:

~~~text
owned_pi_object_list_head_3c_candidate
  is the owner context's list of PI-capable objects it currently owns

next_owned_pi_object_0c_candidate
  is the singly-linked next pointer in that list

base_readyq_bucket_48_candidate
  is the owner/context base requested bucket while PI is active

priority_inheritance_active_4c_candidate
  is the active PI marker

readyq_bucket_20
  is the current effective scheduler bucket
~~~

The scheduler keeps list ordering correct by removing/reinserting contexts when their effective bucket changes.
