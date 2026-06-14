# 2026-06-14 - Stage1 readyq, static idle context, waitq drain, and timeslice scheduler findings

## Scope

This record captures the Stage1 scheduler work completed after the owned-wait-object / PI pass.

Main focus:

- waitq/list drain helper at `80f8997c`
- owned-wait-object waitq drain wrapper at `80e98754`
- scheduler readyq-table init/drain control helpers
- false Ghidra function splits in branch-delay / mid-function blocks
- readyq table initializer at `80e97084`
- static idle/bootstrap context area and Ghidra RAM block correction
- static idle context entry loop and registration chain
- scheduler global-slot store / context hold-release helper
- static idle context magic init/cleanup controller
- no-op priority-update hooks at `80e97304` and `80e9730c`
- scheduler timeslice countdown and same-bucket round-robin rotation
- datatype and field cleanup notes

Repository policy for this record:

- No old logs deleted.
- This file is a new dated reverse-engineering record.
- No git command was run or required for this note.
- Correct output directory: `~/tc7200u-research/records/reverse/`.
- `records/notes/` is not used for new records.

## High-level result

The Stage1 readyq / static idle context / timeslice chain is now significantly clearer.

Confirmed scheduler pieces:

~~~text
readyq table init:
  mode 1 + magic 0x2af8
  -> initialize/reset g_stage1_scheduler_readyq_table_819dcc5c

readyq table drain:
  mode 0 + magic 0x2af8
  -> drain/unlink all 32 readyq bucket lists

static idle context:
  record at 0x819dc310
  idle counter at 0x819dc308
  stack/work area at 0x819dc438, size 0x800
  entry loop at 0x80e96a14

timeslice countdown:
  g_stage1_scheduler_timeslice_or_budget_reload_819dcc50 decrements
  when zero, same-bucket readyq head is rotated
  dispatch-needed flag is set if another same-priority context is exposed
~~~

## Important Ghidra split corrections

False function starts identified in this pass:

~~~text
80e97b84
  false split inside 80e97b54

80e97bf0
  false split; it is the delay slot of jal at 80e97bec

80e96a44
  false split inside 80e96a3c

80e96a90
  false split inside 80e96a3c
~~~

Correct action in Ghidra:

~~~text
Delete false functions at:
  80e97b84
  80e97bf0
  80e96a44
  80e96a90

Keep real function starts at:
  80e97b54
  80e97be0
  80e97c00
  80e96a14
  80e96a3c
  80e96ac4
~~~

Reason:

- false functions showed `unaff_s0`, `unaff_s1`, or used saved registers initialized in earlier instructions
- some false starts were MIPS branch-delay slots
- Ghidra split in the middle of valid function bodies

## Naming rule applied

Function names were finalized when role, argument model, and side effects were clear.

Keep `_candidate` where:

~~~text
- exact semantic role is still inferred
- helper target has not been decoded
- field meaning is partial
- function is a magic init/cleanup controller whose full lifecycle is not closed
~~~

Do not mass-remove `_candidate` from structures. Structures still contain partial fields.

## New or changed function names from this pass

Finalized / safe names:

~~~text
fn_stage1_waitq_drain_unlink_all_80f8997c
fn_stage1_owned_wait_object_waitq_drain_unlink_all_80e98754
fn_stage1_scheduler_readyq_table_init_wrapper_80e97be0
fn_stage1_scheduler_readyq_table_drain_wrapper_80e97c00
fn_stage1_scheduler_readyq_table_init_80e97084
fn_stage1_scheduler_readyq_table_magic_init_or_drain_80e97b54
fn_stage1_scheduler_timeslice_countdown_maybe_expire_80e97314
fn_stage1_scheduler_timeslice_expire_rotate_readyq_bucket_80e97344
~~~

Still provisional names:

~~~text
fn_stage1_idle_context_entry_loop_80e96a14_candidate
fn_stage1_static_idle_context_init_register_80e96a3c_candidate
fn_stage1_scheduler_context_slot_store_then_release_hold_80e972d0_candidate
fn_stage1_static_idle_context_magic_init_or_cleanup_80e96ac4_candidate
fn_stage1_scheduler_priority_update_pre_hook_noop_80e9730c_candidate
fn_stage1_scheduler_priority_update_post_hook_noop_80e97304_candidate
~~~

## New field candidate from this pass

At `stage1_context_candidate + 0x24`:

~~~c
uint scheduler_timeslice_flag_24_candidate;
~~~

Reason:

- `fn_stage1_scheduler_timeslice_expire_rotate_readyq_bucket_80e97344` checks `current_context +0x24`
- if zero, no timeslice rotation is performed
- if nonzero, and budget is zero, current readyq bucket may be rotated

Do not finalize the exact field meaning yet. It may be a boolean, class flag, scheduler policy flag, or timeslice eligibility marker.

For Ghidra scalar search:

~~~text
0x24 = 36 decimal
~~~


---

# Memory blocks and datatype corrections

## Static idle/bootstrap context memory block

The missing data at `819dc308` belongs to RAM, not code.

Original attempted block:

~~~text
Start:  819dc300
Length: 0x94c
End:    819dcc4b
~~~

Conflict observed:

~~~text
Block address conflict: [819dcc38, 819dcc4b]
~~~

Reason:

Existing block already covers:

~~~text
RAM_819dcc38_scheduler_callback_candidate
  819dcc38 - 819dcc4b
~~~

Correct block must stop before `819dcc38`.

## Correct Ghidra block to add

Use:

~~~text
Window -> Memory Map -> Add Block

Name:        RAM_819dc300_static_idle_context_area
Start:       819dc300
Length:      0x938
Type:        Uninitialized
Read:        yes
Write:       yes
Execute:     no
Volatile:    no
~~~

This creates:

~~~text
819dc300 - 819dcc37
~~~

No conflict.

Calculation:

~~~text
819dcc38 - 819dc300 = 0x938
819dc300 + 0x938 - 1 = 819dcc37
~~~

## Covered static idle area objects

The corrected block covers:

~~~text
819dc308  idle loop counter
819dc310  static idle/bootstrap context record
819dc438  static idle stack/work area base
819dcc37  last byte of 0x800 stack/work area
~~~

Stack/work check:

~~~text
819dc438 + 0x800 - 1 = 819dcc37
~~~

Nothing is left behind.

## Correct block layout after fix

~~~text
RAM_819dc300_static_idle_context_area        819dc300 - 819dcc37  0x938
RAM_819dcc38_scheduler_callback_candidate    819dcc38 - 819dcc4b  0x14
RAM_819dcc4c_scheduler_head_candidate        819dcc4c - 819dcc4f  0x4
stage1_ram_global_819dcc50                   819dcc50 - 819dcc53  0x4
RAM_819dcc54_scheduler_globals               819dcc54 - 819dcd53  0x100
~~~

## Data to define after adding the block

At:

~~~text
819dc308
~~~

create:

~~~c
uint g_stage1_idle_loop_counter_819dc308_candidate;
~~~

At:

~~~text
819dc310
~~~

create:

~~~c
stage1_context_candidate g_stage1_static_idle_context_819dc310_candidate;
~~~

At:

~~~text
819dc438
~~~

create:

~~~c
undefined1 g_stage1_static_idle_stack_or_work_area_819dc438_candidate[0x800];
~~~

## Existing scheduler-global block relationship

Do not expand the static idle block into scheduler globals.

Known scheduler global cluster:

~~~text
819dcc4c  g_stage1_scheduler_unlock_callback_list_head_819dcc4c
819dcc50  g_stage1_scheduler_timeslice_or_budget_reload_819dcc50
819dcc54  g_stage1_current_context_819dcc54
819dcc58  g_stage1_scheduler_dispatch_needed_flag_819dcc58
819dcc5c  g_stage1_scheduler_readyq_table_819dcc5c
819dcce0  g_stage1_context_switch_counter_819dcce0
~~~

Important:

`g_stage1_current_context_819dcc54` must stay typed as:

~~~c
stage1_context_candidate *
~~~

not as an inline structure.

## `stage1_readyq_table_candidate`

Confirmed shape:

~~~c
typedef struct stage1_readyq_table_candidate {
    uint nonempty_bucket_bitmap_00;
    stage1_readyq_node_candidate *bucket_heads_04[32];
} stage1_readyq_table_candidate; // size 0x84
~~~

Confirmed global object:

~~~c
g_stage1_scheduler_readyq_table_819dcc5c
~~~

## `stage1_readyq_node_candidate`

Confirmed list node:

~~~c
typedef struct stage1_readyq_node_candidate {
    struct stage1_readyq_node_candidate *next_00;
    struct stage1_readyq_node_candidate *prev_04;
} stage1_readyq_node_candidate; // size 0x08
~~~

This is the node type drained by:

~~~c
fn_stage1_waitq_drain_unlink_all_80f8997c
~~~

## Relevant `stage1_context_candidate` field block

Current important scheduler fields:

~~~c
stage1_readyq_node_candidate readyq_node_18;                  // +0x18
uint readyq_bucket_20;                                        // +0x20
uint scheduler_timeslice_flag_24_candidate;                   // +0x24, provisional
stage1_readyq_node_candidate **owner_list_head_ref_28;        // +0x28

uint owned_pi_object_count_38_candidate;                      // +0x38
stage1_owned_wait_object_candidate *owned_pi_object_list_head_3c_candidate; // +0x3c
stage1_owned_wait_object_candidate *current_owned_wait_object_acquire_candidate; // +0x40

uint base_readyq_bucket_48_candidate;                         // +0x48
uint priority_inheritance_active_4c_candidate;                // +0x4c

uint context_flags_50;                                        // +0x50
uint wait_state_98;                                           // +0x98
uint resume_status_9c;                                        // +0x9c
~~~

`+0x24` is newly interpreted as a timeslice/scheduler policy field. Keep `_candidate`.

## Address and scalar search reminders

For Ghidra scalar search, use decimal:

~~~text
0x24   = 36 decimal
0x2af8 = 11000 decimal
0x3a98 = 15000 decimal
0x128  = 296 decimal
0x800  = 2048 decimal
0xc350 = 50000 decimal
~~~


---

# Function findings

## `fn_stage1_waitq_drain_unlink_all_80f8997c`

Old name:

~~~c
fn_stage1_waitq_cleanup_or_assert_empty_80f8997c_candidate
~~~

Final name:

~~~c
fn_stage1_waitq_drain_unlink_all_80f8997c
~~~

Signature:

~~~c
void fn_stage1_waitq_drain_unlink_all_80f8997c
        (stage1_readyq_node_candidate **waitq_head_ref)
~~~

Confirmed behavior:

~~~text
while *waitq_head_ref != NULL:
  node = *waitq_head_ref

  if node->next_00 == node:
      *waitq_head_ref = NULL

  else:
      next = node->next_00
      prev = node->prev_04

      next->prev_04 = prev
      prev->next_00 = next

      node->next_00 = node
      node->prev_04 = node

      *waitq_head_ref = next
~~~

Confirmed meaning:

~~~text
- drains/unlinks a circular doubly-linked waitq/list
- self-links each removed node
- does not wake contexts
- does not set wait_state_98
- does not set resume_status_9c
- does not clear owner_list_head_ref_28
- does not touch context_flags_50
~~~

Comment:

~~~c
/* Stage1 waitq/list drain unlink-all helper.

   Argument:
     waitq_head_ref =
       pointer to a waitq/list head slot, for example:
         &owned_wait_object->{@field waitq_08}
         &condition_object->{@field waitq_04}

   Behavior:
     - treats *waitq_head_ref as the head of a circular doubly-linked list of
       stage1_readyq_node_candidate nodes
     - repeatedly unlinks the current head node
     - if the current node is the only node, clears *waitq_head_ref to NULL
     - otherwise relinks next/prev around the removed node and advances the head
       to the next node
     - self-links each removed node

   Notes:
     - This helper drains/unlinks the list only.
     - It does not wake contexts.
     - It does not set wait_state_98 or resume_status_9c.
     - It does not clear context->{@field owner_list_head_ref_28}.
     - It does not touch context_flags_50.
*/
~~~

## `fn_stage1_owned_wait_object_waitq_drain_unlink_all_80e98754`

Old interpretation was initializer/reset. Corrected.

Final name:

~~~c
fn_stage1_owned_wait_object_waitq_drain_unlink_all_80e98754
~~~

Signature:

~~~c
void fn_stage1_owned_wait_object_waitq_drain_unlink_all_80e98754
        (stage1_owned_wait_object_candidate *owned_wait_object)
~~~

Confirmed body:

~~~c
fn_stage1_waitq_drain_unlink_all_80f8997c(&owned_wait_object->waitq_08);
~~~

Meaning:

~~~text
- wrapper only
- passes &owned_wait_object->waitq_08
- does not initialize the full object
- does not touch owner_context_04
- does not touch active_or_locked_00
- does not touch ownership_pi_mode_10
- does not touch next_owned_pi_object_0c_candidate
~~~

## `fn_stage1_scheduler_readyq_table_magic_init_or_drain_80e97b54`

Former provisional name had `_candidate`. After decoding `FUN_80e97084`, the mode table is closed enough to drop `_candidate`.

Final name:

~~~c
fn_stage1_scheduler_readyq_table_magic_init_or_drain_80e97b54
~~~

Signature:

~~~c
void fn_stage1_scheduler_readyq_table_magic_init_or_drain_80e97b54
        (int mode,
         int magic_2af8)
~~~

Mode table:

~~~text
mode = 1, magic = 0x2af8 / 11000
  -> initialize/reset g_stage1_scheduler_readyq_table_819dcc5c

mode = 0, magic = 0x2af8 / 11000
  -> drain/unlink all 32 readyq bucket lists

magic mismatch
  -> return without action
~~~

False split:

~~~text
80e97b84 is not a real standalone function.
It is a mid-function block inside 80e97b54.
~~~

## `fn_stage1_scheduler_readyq_table_init_wrapper_80e97be0`

Final wrapper name:

~~~c
fn_stage1_scheduler_readyq_table_init_wrapper_80e97be0
~~~

Signature:

~~~c
void fn_stage1_scheduler_readyq_table_init_wrapper_80e97be0(void)
~~~

Confirmed call:

~~~c
fn_stage1_scheduler_readyq_table_magic_init_or_drain_80e97b54(1, 0x2af8);
~~~

False split:

~~~text
80e97bf0 is not a real function.
It is the delay slot of the jal at 80e97bec.
~~~

## `fn_stage1_scheduler_readyq_table_drain_wrapper_80e97c00`

Final wrapper name:

~~~c
fn_stage1_scheduler_readyq_table_drain_wrapper_80e97c00
~~~

Signature:

~~~c
void fn_stage1_scheduler_readyq_table_drain_wrapper_80e97c00(void)
~~~

Confirmed call:

~~~c
fn_stage1_scheduler_readyq_table_magic_init_or_drain_80e97b54(0, 0x2af8);
~~~

Current XREF status:

~~~text
Only local stack references were seen:
  80e97c04 sw ra,0x0(sp)
  80e97c14 lw ra,0x0(sp)

No external code/data caller was visible in the checked XREF list.
~~~

Keep the function because it is valid code, but do not assume it runs in normal boot until a real caller or registration pointer is found.

## `fn_stage1_scheduler_readyq_table_init_80e97084`

Old decompiler confusion:

~~~text
stage1_boot_context_globals_reset_80e97094_candidate
~~~

This was wrong. `80e97094` is not a separate function start. It is inside the real function starting at `80e97084`.

Final name:

~~~c
fn_stage1_scheduler_readyq_table_init_80e97084
~~~

Signature:

~~~c
void fn_stage1_scheduler_readyq_table_init_80e97084
        (stage1_readyq_table_candidate *readyq_table)
~~~

Confirmed behavior:

~~~text
- sets stage1_dispatch_defer_or_running_flag_candidate = 1
- clears readyq_table->bucket_heads_04[0..31]
- clears readyq_table->nonempty_bucket_bitmap_00
- sets g_stage1_scheduler_timeslice_or_budget_reload_819dcc50 = 50000 / 0xc350
- sets g_stage1_scheduler_dispatch_needed_flag_819dcc58 = 1
~~~

Clean target form:

~~~c
void fn_stage1_scheduler_readyq_table_init_80e97084
        (stage1_readyq_table_candidate *readyq_table)

{
  uint bucket_idx;

  stage1_dispatch_defer_or_running_flag_candidate = 1;

  for (bucket_idx = 0; bucket_idx < 32; bucket_idx++) {
    readyq_table->bucket_heads_04[bucket_idx] = NULL;
  }

  readyq_table->nonempty_bucket_bitmap_00 = 0;

  g_stage1_scheduler_timeslice_or_budget_reload_819dcc50 = 50000;
  g_stage1_scheduler_dispatch_needed_flag_819dcc58 = 1;
}
~~~

## `fn_stage1_idle_context_entry_loop_80e96a14_candidate`

Current provisional name:

~~~c
fn_stage1_idle_context_entry_loop_80e96a14_candidate
~~~

Signature:

~~~c
void fn_stage1_idle_context_entry_loop_80e96a14_candidate(void)
~~~

Mark as noreturn if Ghidra allows.

Behavior:

~~~text
do forever:
  g_stage1_idle_loop_counter_819dc308_candidate++
  FUN_80ea3780()
~~~

Known use:

~~~text
Passed as the entry function to
fn_stage1_context_init_register_alt_80e95c00_candidate
by
fn_stage1_static_idle_context_init_register_80e96a3c_candidate
~~~

Keep `_candidate` until `FUN_80ea3780` is decoded.

## `fn_stage1_static_idle_context_init_register_80e96a3c_candidate`

Real function span:

~~~text
80e96a3c - 80e96ac0
~~~

False function starts inside it:

~~~text
80e96a44
80e96a90
~~~

Provisional name:

~~~c
fn_stage1_static_idle_context_init_register_80e96a3c_candidate
~~~

Signature:

~~~c
void fn_stage1_static_idle_context_init_register_80e96a3c_candidate
        (stage1_context_candidate *static_context)
~~~

Important constants:

~~~text
0x819dc310 = static context record base
0x128      = static context record stride / 296 decimal
0x819dc438 = static stack/work area base for slot 0
0x800      = static stack/work area size / 2048 decimal
0x1f       = readyq bucket 31, low priority bucket
0x813a0a84 = callback/table pointer passed through t0
~~~

Slot-index computation:

~~~text
slot_index = (static_context - 0x819dc310) / 0x128
~~~

Then stack/work area:

~~~text
stack_base = 0x819dc438 + slot_index * 0x800
~~~

For current observed slot:

~~~text
slot 0 context = 0x819dc310
slot 0 stack   = 0x819dc438
stack size     = 0x800
~~~

## `fn_stage1_scheduler_context_slot_store_then_release_hold_80e972d0_candidate`

Known caller passes:

~~~text
param_1 = &g_stage1_scheduler_readyq_table_819dcc5c
param_2 = static_context
param_3 = slot_index
~~~

Body writes:

~~~c
*(0x819dcc54 + slot_index * 4) = static_context;
~~~

Then calls:

~~~c
fn_stage1_context_decrement_start_hold_release_80e9628c_candidate(static_context);
~~~

For current proven slot:

~~~text
slot_index == 0
-> g_stage1_current_context_819dcc54 = static_context
~~~

Provisional name:

~~~c
fn_stage1_scheduler_context_slot_store_then_release_hold_80e972d0_candidate
~~~

Signature:

~~~c
void fn_stage1_scheduler_context_slot_store_then_release_hold_80e972d0_candidate
        (undefined4 unused_table_arg_candidate,
         stage1_context_candidate *context,
         uint scheduler_context_slot_index,
         undefined4 unused_arg3_candidate)
~~~

Caution:

Do not model `0x819dcc54` as a normal array yet. It overlaps the known scheduler global cluster.

## `fn_stage1_static_idle_context_magic_init_or_cleanup_80e96ac4_candidate`

Magic value:

~~~text
0x3a98 = 15000 decimal
~~~

Mode table:

~~~text
mode = 1, magic = 0x3a98 / 15000
  -> initialize/register one static context at 0x819dc310

mode = 0, magic = 0x3a98 / 15000
  -> cleanup/destroy one static context at 0x819dc310 through FUN_80e95f10

magic mismatch
  -> return without action
~~~

Provisional name:

~~~c
fn_stage1_static_idle_context_magic_init_or_cleanup_80e96ac4_candidate
~~~

Signature:

~~~c
void fn_stage1_static_idle_context_magic_init_or_cleanup_80e96ac4_candidate
        (int mode,
         int magic_3a98,
         int *unused_arg2_candidate,
         undefined4 unused_arg3_candidate)
~~~

Keep `_candidate` until `FUN_80e95f10` and `fn_stage1_context_init_register_alt_80e95c00_candidate` are fully decoded.

## No-op hook stubs at `80e97304` and `80e9730c`

Bodies:

~~~asm
jr ra
nop
~~~

Use provisional names:

~~~c
fn_stage1_scheduler_priority_update_post_hook_noop_80e97304_candidate
fn_stage1_scheduler_priority_update_pre_hook_noop_80e9730c_candidate
~~~

Placement:

~~~text
80e9730c
  called before priority-field writes in
  fn_stage1_context_update_priority_requeue_80e965e8

80e97304
  called after priority-field writes in
  fn_stage1_context_update_priority_requeue_80e965e8
~~~

No current side effects.

Keep `_candidate` because intended hook meaning is inferred from call placement.

## `fn_stage1_scheduler_timeslice_countdown_maybe_expire_80e97314`

Final name:

~~~c
fn_stage1_scheduler_timeslice_countdown_maybe_expire_80e97314
~~~

Signature:

~~~c
void fn_stage1_scheduler_timeslice_countdown_maybe_expire_80e97314(void)
~~~

Behavior:

~~~text
g_stage1_scheduler_timeslice_or_budget_reload_819dcc50--

if decremented value == 0:
  fn_stage1_scheduler_timeslice_expire_rotate_readyq_bucket_80e97344()
~~~

## `fn_stage1_scheduler_timeslice_expire_rotate_readyq_bucket_80e97344`

Final name:

~~~c
fn_stage1_scheduler_timeslice_expire_rotate_readyq_bucket_80e97344
~~~

Signature:

~~~c
void fn_stage1_scheduler_timeslice_expire_rotate_readyq_bucket_80e97344(void)
~~~

Confirmed behavior:

~~~text
current_context = g_stage1_current_context_819dcc54

if current_context->scheduler_timeslice_flag_24_candidate == 0:
  return

if g_stage1_scheduler_timeslice_or_budget_reload_819dcc50 != 0:
  return

if current_context->context_flags_50 != 0:
  return

bucket_head_ref =
  &g_stage1_scheduler_readyq_table_819dcc5c.bucket_heads_04[
      current_context->readyq_bucket_20
  ]

if *bucket_head_ref != NULL:
  *bucket_head_ref = (*bucket_head_ref)->next_00

next_context = (*bucket_head_ref != NULL) ? (*bucket_head_ref - 0x18) : NULL

if next_context != current_context:
  g_stage1_scheduler_dispatch_needed_flag_819dcc58 = 1

g_stage1_scheduler_timeslice_or_budget_reload_819dcc50 = 0xc350 / 50000
~~~

Scheduler meaning:

~~~text
same-priority bucket round-robin on timeslice expiration
~~~

This helper does not remove or insert list nodes. It only advances the bucket head pointer.


---

# Final result of this pass

## Closed or mostly closed chains

### Waitq drain chain

~~~text
fn_stage1_owned_wait_object_waitq_drain_unlink_all_80e98754
  -> passes &owned_wait_object->waitq_08

fn_stage1_waitq_drain_unlink_all_80f8997c
  -> drains/unlinks circular list
  -> self-links removed nodes
  -> does not wake contexts
~~~

### Readyq table init/drain chain

~~~text
fn_stage1_scheduler_readyq_table_init_wrapper_80e97be0
  -> fn_stage1_scheduler_readyq_table_magic_init_or_drain_80e97b54(1, 0x2af8)
     -> fn_stage1_scheduler_readyq_table_init_80e97084
        -> clears readyq table
        -> sets timeslice budget 50000
        -> sets dispatch-needed flag

fn_stage1_scheduler_readyq_table_drain_wrapper_80e97c00
  -> fn_stage1_scheduler_readyq_table_magic_init_or_drain_80e97b54(0, 0x2af8)
     -> drains all 32 bucket head lists
~~~

### Static idle context chain

~~~text
fn_stage1_static_idle_context_magic_init_or_cleanup_80e96ac4_candidate
  mode 1 + magic 0x3a98
    -> fn_stage1_static_idle_context_init_register_80e96a3c_candidate
       -> registers static context at 0x819dc310
       -> entry function fn_stage1_idle_context_entry_loop_80e96a14_candidate
       -> readyq bucket 0x1f
       -> stack/work area 0x819dc438, size 0x800
       -> fn_stage1_scheduler_context_slot_store_then_release_hold_80e972d0_candidate
          -> stores context into scheduler context slot 0
          -> releases start hold

  mode 0 + magic 0x3a98
    -> FUN_80e95f10(static context)
~~~

### Timeslice chain

~~~text
fn_stage1_scheduler_timeslice_countdown_maybe_expire_80e97314
  -> decrements g_stage1_scheduler_timeslice_or_budget_reload_819dcc50
  -> if zero:
       fn_stage1_scheduler_timeslice_expire_rotate_readyq_bucket_80e97344

fn_stage1_scheduler_timeslice_expire_rotate_readyq_bucket_80e97344
  -> requires current_context->scheduler_timeslice_flag_24_candidate != 0
  -> requires current_context->context_flags_50 == 0
  -> rotates current readyq bucket head
  -> sets dispatch-needed if another same-bucket context is exposed
  -> reloads budget to 0xc350 / 50000
~~~

## Ghidra action checklist

Delete false functions if still present:

~~~text
80e97b84
80e97bf0
80e96a44
80e96a90
~~~

Create / verify RAM block:

~~~text
RAM_819dc300_static_idle_context_area
  819dc300 - 819dcc37
  length 0x938
  R/W yes
  X no
  volatile no
  uninitialized
~~~

Define data:

~~~text
819dc308
  uint g_stage1_idle_loop_counter_819dc308_candidate

819dc310
  stage1_context_candidate g_stage1_static_idle_context_819dc310_candidate

819dc438
  undefined1 g_stage1_static_idle_stack_or_work_area_819dc438_candidate[0x800]
~~~

Rename field:

~~~text
stage1_context_candidate +0x24
  from field_24
  to scheduler_timeslice_flag_24_candidate
~~~

Keep it `_candidate`.

## Rename checklist

Final names:

~~~text
fn_stage1_waitq_drain_unlink_all_80f8997c
fn_stage1_owned_wait_object_waitq_drain_unlink_all_80e98754
fn_stage1_scheduler_readyq_table_init_wrapper_80e97be0
fn_stage1_scheduler_readyq_table_drain_wrapper_80e97c00
fn_stage1_scheduler_readyq_table_init_80e97084
fn_stage1_scheduler_readyq_table_magic_init_or_drain_80e97b54
fn_stage1_scheduler_timeslice_countdown_maybe_expire_80e97314
fn_stage1_scheduler_timeslice_expire_rotate_readyq_bucket_80e97344
~~~

Candidate names:

~~~text
fn_stage1_idle_context_entry_loop_80e96a14_candidate
fn_stage1_static_idle_context_init_register_80e96a3c_candidate
fn_stage1_scheduler_context_slot_store_then_release_hold_80e972d0_candidate
fn_stage1_static_idle_context_magic_init_or_cleanup_80e96ac4_candidate
fn_stage1_scheduler_priority_update_post_hook_noop_80e97304_candidate
fn_stage1_scheduler_priority_update_pre_hook_noop_80e9730c_candidate
~~~

## Comment cleanup checklist

Remove / replace wrong wording:

~~~text
cleanup_or_assert_empty
  -> drain_unlink_all

owned-wait-object initializer/reset at 80e98754
  -> waitq drain wrapper only

stage1_boot_context_globals_reset_80e97094_candidate
  -> wrong; 80e97094 is inside 80e97084

80e97bf0 as function
  -> wrong; delay slot

80e97b84 as function
  -> wrong; mid-function block

80e96a44 / 80e96a90 as functions
  -> wrong; mid-function blocks inside 80e96a3c
~~~

## Open cautions

Do not finalize yet:

~~~text
FUN_80ea3780
  called by idle loop forever

FUN_80e95f10
  cleanup target for static idle context controller mode 0

fn_stage1_context_init_register_alt_80e95c00_candidate
  still needs full signature cleanup

fn_stage1_context_decrement_start_hold_release_80e9628c_candidate
  involved in scheduler context-slot store path

scheduler_timeslice_flag_24_candidate
  currently only proves timeslice rotation eligibility
~~~

## Next targets

Recommended next Ghidra targets:

~~~text
FUN_80ea3780
  explain idle loop body

FUN_80e95f10
  explain static idle context cleanup path

fn_stage1_context_init_register_alt_80e95c00_candidate
  clean signature and arguments used by static idle context init

fn_stage1_context_decrement_start_hold_release_80e9628c_candidate
  close scheduler context-slot store/release chain

xrefs to context +0x24
  prove whether scheduler_timeslice_flag_24_candidate is boolean, policy flag,
  counter, or class/quantum selector
~~~

## Do not do next

Do not:

~~~text
- add a RAM block overlapping 819dcc38 - 819dcc4b
- use length 0x94c for RAM_819dc300_static_idle_context_area
- delete old logs
- write new notes under records/notes/
- invent missing fields
- create dummy functions
- keep false Ghidra function splits
- finalize field +0x24 beyond timeslice eligibility
~~~

## Final state

This pass closed three scheduler areas:

~~~text
1. waitq drain mechanics:
   linked-list drain/unlink helper is now clear

2. readyq table lifecycle:
   magic init/drain control and table initializer are now clear

3. timeslice same-bucket rotation:
   countdown and expire/rotate helper are now clear
~~~

The static idle/bootstrap context chain is mostly connected but remains candidate until the idle-loop callee and context init/cleanup helpers are decoded.
