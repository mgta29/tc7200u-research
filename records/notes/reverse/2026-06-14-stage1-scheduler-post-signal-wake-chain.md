# 2026-06-14 Stage1 scheduler post/signal/wake-chain reverse log

## Scope

This log records the current TC7200U Stage1 reverse-engineering work around the scheduler callback-pair path, post-message enqueue/signal helper, signal pending-bit helper, context wake helper, make-runnable transition, ready queue return path, related structs, memory map additions, decompiler repairs, naming changes, and remaining targets.

No repository changes are included here. This is a reverse note only.

## Current process position

Overall local-chain progress: about 82 percent.

Current chain under analysis:

```text
event wait/block
  -> scheduler readyq remove/select
  -> low-level context switch
  -> scheduler unlock-inner drain
  -> unlock callback enqueue/bump
  -> callback pair invoke
  -> installed scheduler callback maps input id
  -> post-message enqueue/signal
  -> signal pending-bit set
  -> context wake-if-waiting
  -> context make-runnable
  -> readyq add side
Current active point:

fn_stage1_context_make_runnable_80e96154_candidate
  -> fn_stage1_scheduler_readyq_add_context_80e97130_candidate
  -> fn_stage1_context_waitq_or_owner_remove_80e97634_candidate

The hard scheduler mechanics are mostly understood. The remaining high-value work is closing the readyq add helper and identifying exactly what context->waitq_owner_or_link_owner_28 represents.

Progress percentages
Area	Status	Percent
Stage1 event-slot blocking wait path	mostly closed	92
Wait-condition struct and slot pending-mask behavior	closed enough	93
Readyq remove/select side	closed enough	95
Readyq add side	current target	65
De Bruijn readyq bitmap helper	closed	98
Low-level context switch helper	closed enough	88
Fixed-stack unlock-inner trampoline	closed enough	88
Unlock-inner callback drain	closed enough	90
Unlock callback enqueue/bump helper	closed	94
Callback-pair helpers	closed	96
Installed scheduler callback 80ef5170	mostly understood	78
Post-message enqueue/signal 80ef4754	repaired and usable	75
Signal pending-bit helper 80ef4f6c	closed	95
Context wake helper 80e963a0	mostly closed	90
Context make-runnable 80e96154	in progress	80
Major findings
1. Callback pair mechanism is closed enough

The callback-pair object at 0x819dcc38 is a simple two-word callback pair.

Struct:

typedef struct stage1_callback_pair_candidate {
    undefined4 callback_00;
    undefined4 arg_04;
} stage1_callback_pair_candidate;

Relevant global:

0x819dcc38 g_stage1_scheduler_callback_pair_819dcc38_candidate

Functions closed:

80e96bc0 fn_stage1_callback_pair_noop_80e96bc0_candidate
80e96bc8 fn_stage1_callback_pair_reset_to_default_80e96bc8_candidate
80e96bdc fn_stage1_callback_pair_install_with_optional_old_out_80e96bdc_candidate
80e96c08 fn_stage1_callback_pair_invoke_80e96c08_candidate

Meaning:

reset helper installs no-op callback and clears arg
install helper replaces callback/arg and can return old values through t0/t1
invoke helper calls callback_pair->callback_00(callback_pair->arg_04)

The installed concrete callback is:

FUN_80ef5170 -> fn_stage1_installed_scheduler_callback_map_and_post_80ef5170_candidate
2. Unlock callback list head is separate from callback pair

Confirmed separate scheduler objects:

0x819dcc38 = callback pair object
0x819dcc4c = unlock/deferred callback list head

Global:

g_stage1_scheduler_unlock_callback_list_head_819dcc4c_candidate

Writers:

80e96e50 enqueue helper inserts record as new head
80e96d5c drain helper pops current head and advances to next_18

Readers include:

80e96d18 / 80e96d54 / 80e96d98 drain loop
80e976f0 / 80e977c0 scheduler dispatch loop pending callback checks
80e96e48 enqueue helper reads old head before pushing new record
3. Unlock callback record enqueue/bump helper closed

Function:

fn_stage1_scheduler_unlock_callback_record_enqueue_or_bump_80e96e00_candidate

Behavior:

disable CP0 Status.IE
callback_record->pending_count_or_arg1_14++
if value becomes 1:
    callback_record->next_18 = global list head
    global list head = callback_record
restore old interrupt-enable state

This explains handler_result_flags bit1 / 0x2 in:

fn_stage1_irq_post_handler_dispatch_cleanup_80e96e7c_candidate

If bit1 is set and handler_context_or_arg is nonzero, the callback record is enqueued/bumped.

4. Installed scheduler callback 80ef5170 mostly understood

Function:

fn_stage1_installed_scheduler_callback_map_and_post_80ef5170_candidate

Behavior:

runtime_state = FUN_80ef307c()
if runtime exists:
    scan key/value map at 0x8146c564
    map input_id_or_reason to mapped_value
    call FUN_80ef4fd4(runtime_state + 0x4c, mapped_value)
    if check result is zero:
        enable Status.IE
        build post message:
            msg_type = 2
            target_index = mapped_value
            payload = payload_arg
        call fn_stage1_post_message_enqueue_and_signal_80ef4754_candidate
        call FUN_80ef4908
        return result

Map struct:

typedef struct stage1_id_to_value_map_entry_candidate {
    int key_00;
    uint value_04;
} stage1_id_to_value_map_entry_candidate;

Global:

g_stage1_id_to_value_map_8146c564_candidate

The map is sentinel-style and stops when value_04 becomes zero.

Remaining callees for this area:

FUN_80ef307c runtime/state provider
FUN_80ef4fd4 runtime_state+0x4c check
FUN_80ef4908 final wait/result helper
5. Post-message enqueue/signal helper repaired and understood

Function:

fn_stage1_post_message_enqueue_and_signal_80ef4754_candidate

The decompiler originally failed with:

Low-level Error: Cannot specify logical size for multiple piece join

Repair actions performed:

cleared bad function metadata
forced raw 4x undefined4/int style arguments
sanitized callee return types
redisassembled/recreated exact function body when needed
kept structs out of the function to avoid re-breaking it

Final working prototype is intentionally raw:

int fn_stage1_post_message_enqueue_and_signal_80ef4754_candidate
              (int *post_msg_ptr,
               int post_arg_or_source,
               int optional_signal_state_ptr,
               undefined4 unused_a3)

Message layout:

post_msg_ptr +0x00 = msg_type
post_msg_ptr +0x04 = target_index / signal bit index
post_msg_ptr +0x08 = payload

Behavior:

msg_type 1 returns success immediately
msg_type 3 returns success immediately
other message types continue
runtime_state = FUN_80ef307c()
if runtime_state field_08 matches owner cookie at 0x81a67cd4:
    already owns post-state guard
else:
    acquire g_stage1_post_state_guard_81a67cd0_candidate with FUN_80e98770
target_index = post_msg_ptr[1]
target slot = 0x81a67cf0 + target_index * 0x10
if target_slot flags_04 bit1 / 0x2 is set:
    pop node from g_stage1_post_queue_free_list_81803acc_candidate
    fill node:
        node+0x04 = target_index
        node+0x08 = post_arg_or_source
        node+0x0c = post_msg_ptr[2]
    append node to target_slot tail_0c as circular singly-linked list
if optional_signal_state_ptr is nonzero:
    set pending bit in optional_signal_state_ptr+0x48
    if pending_mask & ~mask_word is nonzero:
        mark context pending callback flag at context+0x30
        call context wake helper
else:
    set pending bit in global signal state at 0x81a67cec
    call global signal helper path
release guard if this helper acquired it
return 1 on success
return 0 if queueing required but no free queue node exists

Important: Do not reapply structs inside this function yet. It is stable and readable enough with raw int/pointer types.

6. Signal pending-bit helper closed

Function:

fn_stage1_signal_pending_bit_set_checked_80ef4f6c_candidate

Final behavior:

args:
    pending_mask_ptr
    bit_index

if bit_index in 1..31:
    *pending_mask_ptr |= 1 << bit_index
    return 0
else:
    *FUN_80ea365c() = 0x16
    return -1

This confirms:

optional_signal_state_ptr +0x48 = pending-bit mask
optional_signal_state_ptr +0x4c = mask/seen/blocked word
g_stage1_global_signal_state_81a67cec_candidate = global pending-bit mask
target_index from post message is also the signal/event bit index
7. Context wake helper closed enough

Function:

fn_stage1_context_wake_if_waiting_make_runnable_80e963a0_candidate

Behavior:

increment stage1_dispatch_defer_or_running_flag_candidate
switch context->wait_state_98:
    1,2,3:
        context->wait_state_98 = 0
        context->resume_status_9c = 4
        fall through to make-runnable
    0,4,5,6,7:
        skip make-runnable and leave state unchanged
    other values:
        call make-runnable without changing wait_state/resume_status here
decrement dispatch defer/running flag
if outermost:
    call scheduler unlock/dispatch loop

This confirms:

context->wait_state_98 at +0x98
context->resume_status_9c at +0x9c
resume_status_9c = 4 means woken/signaled/resumed candidate
8. Context struct offset bug fixed

The context struct was off by two bytes.

Wrong prior layout:

0x60 context_trace_id_60 length 0x4
0x64 pad_62 length 0x36
0x9a wait_state_98
0x9e resume_status_9c

Corrected layout:

0x60 ushort context_trace_id_60
0x62 undefined1[0x36] pad_62
0x98 uint wait_state_98
0x9c uint resume_status_9c

Final struct size should be:

0xa0

After this correction, Ghidra correctly emitted:

switch(context->wait_state_98)
context->resume_status_9c = 4

instead of wrong padding expressions.

9. Make-runnable helper in progress

Function:

fn_stage1_context_make_runnable_80e96154_candidate

Behavior:

increment dispatch defer/running flag
if context->context_flags_50 low bits 0x3 are set:
    clear bits 0 and 1
    if context->waitq_owner_or_link_owner_28 is nonzero:
        call FUN_80e97634(owner, context)
        clear context->waitq_owner_or_link_owner_28
    if context->context_flags_50 is now zero:
        call FUN_80e97130(readyq_table, context)
decrement dispatch defer/running flag
if outermost:
    call scheduler unlock/dispatch loop

Current meaning:

This is the runnable transition helper.
It clears blocked/non-runnable flags, detaches from an owner/list, and returns the context to readyq when no blocking flags remain.

Current unresolved point:

context->waitq_owner_or_link_owner_28

Need to inspect:

FUN_80e97634

to identify if this owner is a wait queue, timer list, semaphore list, or generic blocking-list owner.

10. Readyq add side is current next closure point

Target:

FUN_80e97130 -> fn_stage1_scheduler_readyq_add_context_80e97130_candidate

Expected relation:

Pairs with already-closed fn_stage1_scheduler_readyq_remove_context_80e971e8_candidate.
Likely inserts context->readyq_node_18 into readyq_table bucket selected by context->readyq_bucket_20 and sets bitmap bit.

Existing readyq structs:

typedef struct stage1_readyq_node_candidate {
    struct stage1_readyq_node_candidate *next_00;
    struct stage1_readyq_node_candidate *prev_04;
} stage1_readyq_node_candidate;
typedef struct stage1_readyq_table_candidate {
    uint nonempty_bucket_bitmap_00;
    stage1_readyq_node_candidate *bucket_heads_04[32];
} stage1_readyq_table_candidate;
Structs and current definitions
stage1_callback_pair_candidate
typedef struct stage1_callback_pair_candidate {
    undefined4 callback_00;
    undefined4 arg_04;
} stage1_callback_pair_candidate;
stage1_scheduler_unlock_callback_record_candidate
typedef struct stage1_scheduler_unlock_callback_record_candidate {
    undefined4 callback_arg0_00;
    undefined4 field_04;
    undefined4 field_08;
    undefined4 callback_0c;
    undefined4 callback_arg2_10;
    undefined4 pending_count_or_arg1_14;
    struct stage1_scheduler_unlock_callback_record_candidate *next_18;
} stage1_scheduler_unlock_callback_record_candidate;
stage1_id_to_value_map_entry_candidate
typedef struct stage1_id_to_value_map_entry_candidate {
    int key_00;
    uint value_04;
} stage1_id_to_value_map_entry_candidate;
stage1_post_message_candidate

Recommended only. Do not force into 80ef4754 yet.

typedef struct stage1_post_message_candidate {
    int msg_type_00;
    uint target_index_04;
    undefined4 payload_08;
} stage1_post_message_candidate;
stage1_post_queue_node_candidate

Recommended only. Keep raw in 80ef4754 for now.

typedef struct stage1_post_queue_node_candidate {
    struct stage1_post_queue_node_candidate *next_00;
    uint target_index_04;
    undefined4 post_arg_or_source_08;
    undefined4 payload_0c;
} stage1_post_queue_node_candidate;
stage1_post_target_slot_candidate

Recommended only. Do not force into 80ef4754 yet.

typedef struct stage1_post_target_slot_candidate {
    undefined4 field_00;
    uint flags_04;
    undefined4 field_08;
    stage1_post_queue_node_candidate *tail_0c;
} stage1_post_target_slot_candidate;
stage1_context_candidate relevant current layout
typedef struct stage1_context_candidate {
    undefined1 pad_00[0x0c];

    undefined1 context_switch_state_0c[0x0c];

    stage1_readyq_node_candidate readyq_node_18;
    uint readyq_bucket_20;

    undefined4 field_24;
    undefined4 waitq_owner_or_link_owner_28;

    uint pending_callback_block_2c;
    uint pending_callback_flag_30;
    undefined4 pending_callback_arg_34;

    undefined1 pad_38[0x18];

    uint context_flags_50;

    undefined1 pad_54[0x08];

    stage1_event_wait_condition_candidate *wait_condition_5c;

    ushort context_trace_id_60;
    undefined1 pad_62[0x36];

    uint wait_state_98;
    uint resume_status_9c;
} stage1_context_candidate;

Important fixed offsets:

+0x18 readyq_node_18
+0x20 readyq_bucket_20
+0x28 waitq_owner_or_link_owner_28
+0x2c pending_callback_block_2c
+0x30 pending_callback_flag_30
+0x34 pending_callback_arg_34
+0x50 context_flags_50
+0x5c wait_condition_5c
+0x60 context_trace_id_60 as ushort
+0x98 wait_state_98
+0x9c resume_status_9c
Memory map notes and labels
0x819dcc38 callback pair block

Created or used area:

0x819dcc38..0x819dcc3f

Label:

g_stage1_scheduler_callback_pair_819dcc38_candidate

Type:

stage1_callback_pair_candidate
0x819dcc4c unlock callback list head

Label:

g_stage1_scheduler_unlock_callback_list_head_819dcc4c_candidate

Type:

stage1_scheduler_unlock_callback_record_candidate *

Meaning:

global head of pending unlock/deferred callback records
0x81a67cd0 post/signal state area

Used labels:

0x81a67cd0 g_stage1_post_state_guard_81a67cd0_candidate
0x81a67cd4 g_stage1_post_state_owner_cookie_81a67cd4_candidate or address-only if overlap prevents symbol
0x81a67ce8 g_stage1_global_signal_waiter_or_flag_81a67ce8_candidate
0x81a67cec g_stage1_global_signal_state_81a67cec_candidate
0x81a67cf0 g_stage1_post_target_slots_81a67cf0_candidate

Recommended block if missing:

Block Name: RAM_81a67cd0_post_state_candidate
Start: 0x81a67cd0
Length: 0x100
End: 0x81a67dcf
Read: yes
Write: yes
Execute: no
Initialized: no

Keep raw data types in this area for now, especially around 0x81a67cf0, because struct typing previously contributed to decompiler instability in 80ef4754.

0x81803acc post queue free list

Label:

g_stage1_post_queue_free_list_81803acc_candidate

Type currently safest as:

int *g_stage1_post_queue_free_list_81803acc_candidate;

Meaning:

singly-linked free list of 0x10-byte post queue nodes
0x81841500 fixed-stack slots

Earlier fixed-stack trampoline area:

0x81841500 stage1_fixed_stack_saved_sp_81841500_candidate
0x81841504 stage1_fixed_stack_saved_ra_81841504_candidate
0x81841508 stage1_fixed_stack_saved_status_81841508_candidate

Meaning:

used by fixed-stack scheduler unlock-inner trampoline around 800047a0
Ghidra repair notes
80ef4754 repair

Problem:

Low-level Error: Cannot specify logical size for multiple piece join

Likely causes included stale bad function/variable metadata, bad callee return types, and too-aggressive struct typing.

Repair result:

function now decompiles
kept raw int/int*/undefined4 parameters
do not retype post_msg_ptr as struct pointer yet
do not type 0x81a67cf0 target slots as array/struct inside this function yet

Safe current signature:

int fn_stage1_post_message_enqueue_and_signal_80ef4754_candidate
              (int *post_msg_ptr,
               int post_arg_or_source,
               int optional_signal_state_ptr,
               undefined4 unused_a3)
80ef4f6c repair

Problem:

Ghidra initially showed one visible argument and bit_index as in_a1.

Repair:

recreated function with two arguments:
pending_mask_ptr, bit_index
fixed FUN_80ea365c return to int * or undefined4 *

Safe current signature:

int fn_stage1_signal_pending_bit_set_checked_80ef4f6c_candidate
              (uint *pending_mask_ptr,
               uint bit_index)
Context struct repair

Problem:

context_trace_id_60 was incorrectly 4 bytes.
This shifted wait_state_98 and resume_status_9c by +2 bytes.

Fix:

context_trace_id_60 is ushort at +0x60
pad_62 is undefined1[0x36]
wait_state_98 starts exactly at +0x98
resume_status_9c starts exactly at +0x9c
Functions closed enough
80e96bc0 fn_stage1_callback_pair_noop_80e96bc0_candidate
80e96bc8 fn_stage1_callback_pair_reset_to_default_80e96bc8_candidate
80e96bdc fn_stage1_callback_pair_install_with_optional_old_out_80e96bdc_candidate
80e96c08 fn_stage1_callback_pair_invoke_80e96c08_candidate
80e96c28 fn_stage1_current_context_dispatch_or_yield_wrapper_80e96c28_candidate
80e96850 fn_stage1_if_current_context_call_scheduler_state_helper_80e96850_candidate
80e96e00 fn_stage1_scheduler_unlock_callback_record_enqueue_or_bump_80e96e00_candidate
80e96e7c fn_stage1_irq_post_handler_dispatch_cleanup_80e96e7c_candidate
80ef4f6c fn_stage1_signal_pending_bit_set_checked_80ef4f6c_candidate
80e963a0 fn_stage1_context_wake_if_waiting_make_runnable_80e963a0_candidate
Functions mostly understood but not fully closed
80ef5170 fn_stage1_installed_scheduler_callback_map_and_post_80ef5170_candidate
80ef4754 fn_stage1_post_message_enqueue_and_signal_80ef4754_candidate
80e96154 fn_stage1_context_make_runnable_80e96154_candidate
Next targets

Priority order:

1. FUN_80e97130
   Rename target: fn_stage1_scheduler_readyq_add_context_80e97130_candidate
   Goal: close readyq add side.

2. FUN_80e97634
   Rename target: fn_stage1_context_waitq_or_owner_remove_80e97634_candidate
   Goal: identify context->waitq_owner_or_link_owner_28.

3. FUN_80ef3360
   Goal: explain global/default signal state path when no optional signal object exists.

4. FUN_80e98cd0
   Goal: explain alternate global signal wake path when global waiter/flag is nonzero.

5. FUN_80ef307c
   Goal: identify runtime/state pointer and field_08 owner cookie relation.

6. FUN_80ef4fd4
   Goal: explain runtime_state+0x4c check used before posting from 80ef5170.

7. FUN_80ef4908
   Goal: identify final result/wait helper after post-message call.
Current working conclusion

The Stage1 event wait path is now connected to the post/signal/wake path:

post message / scheduler callback
  -> set pending signal bit
  -> pending_mask & ~mask_word detects unmasked work
  -> mark context pending callback flag at +0x30
  -> wake waiting context
  -> wait_state_98 becomes 0
  -> resume_status_9c becomes 4
  -> make-runnable clears context_flags_50 bits 0/1
  -> detach from wait/list owner if +0x28 is set
  -> add context back to readyq when context_flags_50 is zero
  -> scheduler dispatch loop may run if outermost

This confirms that the earlier event-slot blocking path and current post/signal path meet at the context wake/make-runnable transition.

