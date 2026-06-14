# 2026-06-14 - Stage1 timeout object and signal dispatch reverse findings

## Scope

This record documents the Stage1 reverse-engineering work around:

- timeout/list object structures and queue helpers
- periodic timeout deadline normalization
- timeout object init, activate, re-arm, cancel, and unlink paths
- global signal/post-state initialization and cleanup
- pending signal bit helpers
- current-thread pending signal/event dispatch
- Ghidra datatype cleanup needed to remove overlap warnings

This record preserves the findings as a new dated evidence log. It does not replace older logs.

## High-level result

The timeout subsystem is now mostly structurally decoded.

A `stage1_timeout_object_candidate` is an embedded 0x30-byte list/timer object with:

- circular list links at +0x00/+0x04
- queue pointer at +0x08
- callback pointer and callback argument at +0x0c/+0x10
- deadline tuple at +0x18/+0x1c
- interval tuple at +0x20/+0x24
- active/registered flag at +0x28
- owner/context back-reference candidate at +0x2c

The signal subsystem uses a global object cluster beginning at 0x81a67cd0:

- 0x81a67cd0: owned-wait/guard object
- 0x81a67ce4: condition/wait object
- 0x81a67cec: pending signal mask field inside the condition object
- 0x81a67cf0: per-signal target/handler table, entry size 0x10

The previous Ghidra warning about overlapping globals was caused by defining standalone symbols inside larger objects. The fix is to model those addresses as fields, not independent globals.

## Confirmed datatypes

### stage1_timeout_queue_candidate

~~~c
struct stage1_timeout_queue_candidate {
    struct stage1_timeout_object_candidate *head_00;
    undefined4 field_04_candidate;
    uint current_time_hi_08_candidate;
    uint current_time_lo_0c_candidate;
};
~~~

### stage1_timeout_object_candidate

Ghidra-safe version, avoiding callback typedefs:

~~~c
struct stage1_timeout_object_candidate {
    struct stage1_timeout_object_candidate *next_00;
    struct stage1_timeout_object_candidate *prev_04;
    struct stage1_timeout_queue_candidate *timeout_queue_08_candidate;

    undefined4 callback_0c_candidate; /* real type: callback/code pointer */
    undefined4 callback_arg_10_candidate;
    undefined4 field_14_candidate;

    uint deadline_hi_18_candidate;
    uint deadline_lo_1c_candidate;

    uint interval_hi_20_candidate;
    uint interval_lo_24_candidate;

    uint active_or_registered_28_candidate;
    struct stage1_context_candidate *owner_context_2c_candidate;
};
~~~

Size: 0x30.

### stage1_context_candidate timeout field

Replace the old byte array:

~~~c
undefined1 timeout_list_object_68_candidate[0x30];
~~~

with:

~~~c
struct stage1_timeout_object_candidate timeout_object_68_candidate;
~~~

Confirmed offsets:

- context +0x68 -> timeout object base
- context +0x70 -> timeout_object.timeout_queue_08_candidate
- context +0x90 -> timeout_object.active_or_registered_28_candidate
- context +0x94 -> timeout_object.owner_context_2c_candidate

## Timeout helper functions

### fn_stage1_timeout_object_init_80e94c0c

Initializer for a timeout object.

Signature:

~~~c
void fn_stage1_timeout_object_init_80e94c0c(
    stage1_timeout_object_candidate *timeout_object,
    stage1_timeout_queue_candidate *timeout_queue,
    undefined4 callback_0c_candidate,
    undefined4 callback_arg_10_candidate);
~~~

Behavior:

- self-links next_00 and prev_04
- stores timeout_queue_08_candidate
- stores callback_0c_candidate
- stores callback_arg_10_candidate
- clears deadline_hi_18_candidate and deadline_lo_1c_candidate
- clears interval_hi_20_candidate and interval_lo_24_candidate
- clears active_or_registered_28_candidate

Does not initialize +0x14 or +0x2c.

### fn_stage1_timeout_queue_remove_object_clear_active_80e940f4

Removes a timeout object from its timeout queue and clears active flag.

Signature:

~~~c
void fn_stage1_timeout_queue_remove_object_clear_active_80e940f4(
    stage1_timeout_queue_candidate *timeout_queue,
    stage1_timeout_object_candidate *timeout_object);
~~~

Behavior:

- enters scheduler defer/running nesting
- if timeout_object is queue head:
  - if only node, clears timeout_queue->head_00
  - else unlinks and advances head to next node
- if timeout_object is not queue head:
  - unlinks object from circular list
- self-links timeout_object
- clears active_or_registered_28_candidate
- leaves scheduler nesting and dispatches if outermost

### fn_stage1_timeout_object_cancel_and_unlink_80e94c40

Cancels active timeout object and ensures it is self-linked.

Signature:

~~~c
void fn_stage1_timeout_object_cancel_and_unlink_80e94c40(
    stage1_timeout_object_candidate *timeout_object);
~~~

Behavior:

- if active_or_registered_28_candidate is nonzero:
  - calls fn_stage1_timeout_queue_remove_object_clear_active_80e940f4
- if next_00 is not self-linked:
  - unlinks object from circular list
  - self-links object

### fn_stage1_timeout_object_cancel_and_unlink_alt_80e94c94_candidate

Alternate copy with same visible behavior as 80e94c40.

Kept candidate until caller role is clearer.

### fn_stage1_timeout_object_rearm_insert_80e94ce8_candidate

Re-arms a timeout object with four register-carried words and inserts it.

Inputs:

- a0 = timeout_object
- a1 = unused in shown body
- a2 = stored at +0x18
- a3 = stored at +0x1c
- t0 = stored at +0x20
- t1 = stored at +0x24

Behavior:

- if already active, removes it first
- stores new deadline/interval tuple at +0x18..+0x24
- calls fn_stage1_timeout_queue_insert_or_fire_due_80e93fc4_candidate

### fn_stage1_timeout_queue_insert_or_fire_due_80e93fc4_candidate

Timeout queue insert-or-fire helper.

Behavior:

- sets active_or_registered_28_candidate = 1
- compares timeout object deadline +0x18/+0x1c against queue current time +0x08/+0x0c
- if deadline is in the future:
  - inserts into timeout queue circular list
- if deadline is due:
  - calls callback_0c_candidate(timeout_object, callback_arg_10_candidate)
  - if interval is zero, clears active flag and does not insert
  - if callback cleared active flag, does not insert
  - otherwise advances periodic deadline and reinserts

### fn_stage1_timeout_object_normalize_periodic_deadline_80e94d68_candidate

Periodic timer catch-up helper.

Behavior:

- if interval +0x20/+0x24 is zero, returns unchanged
- reads queue current time +0x08/+0x0c
- computes current_time + interval
- compares against existing deadline +0x18/+0x1c
- if deadline is already inside current interval window, returns unchanged
- otherwise computes quotient through FUN_80023e9c:

    interval_count = floor(((current_time + interval) - deadline - 1) / interval)

- advances deadline by interval_count * interval

Interpretation:

This prevents repeating timeout objects from being reinserted far in the past after delayed callback handling.

### fn_stage1_timeout_object_activate_if_inactive_80e94e78_candidate

Inactive-only activation helper.

Behavior:

- if active flag is already nonzero, return
- normalizes periodic deadline
- sets active flag
- calls timeout queue insert/fire helper

Important correction:

The call at 80e94ea4 targets 80e93fc4, not 80e940f4. Any stale Ghidra label showing the remove helper at that call should be corrected.

## Timeout wrapper functions

- fn_stage1_timeout_object_rearm_insert_wrapper_80e957bc
  - direct wrapper for 80e94ce8

- fn_stage1_timeout_object_activate_if_inactive_wrapper_80e957d8
  - direct wrapper for 80e94e78

- fn_stage1_timeout_object_cancel_if_active_80e957f4
  - if active, removes timeout object from queue

- fn_stage1_timeout_object_init_store_out_80e95750_candidate
  - uses incoming t0 as timeout object pointer
  - calls 80e94c0c
  - stores t0 to output pointer

- fn_stage1_timeout_object_helper_80e94c94_wrapper_80e957a0_candidate
  - direct wrapper for 80e94c94


---

## Update 1 - Signal/global wait subsystem findings

### Global signal/post-state object layout

Correct object layout:

~~~text
0x81a67cd0 = g_stage1_post_state_guard_81a67cd0_candidate
             stage1_owned_wait_object_candidate, size 0x14

0x81a67ce4 = g_stage1_signal_condition_object_81a67ce4_candidate
             stage1_condition_object_candidate, size 0x0c

0x81a67cec = field inside g_stage1_signal_condition_object_81a67ce4_candidate
             global pending signal mask word

0x81a67cf0 = g_stage1_post_target_slots_81a67cf0_candidate
             per-signal table, entry size 0x10
~~~

Important Ghidra cleanup result:

The warning:

~~~text
Globals starting with '_' overlap smaller symbols at the same address
~~~

was removed by not defining standalone globals inside:

- g_stage1_post_state_guard_81a67cd0_candidate
- g_stage1_signal_condition_object_81a67ce4_candidate

Addresses 0x81a67cd4 and 0x81a67cec should be treated as fields, not independent globals.

### fn_stage1_signal_global_magic_init_or_cleanup_80ef5020_candidate

Magic:

~~~text
0xd6d8 = 55000 decimal
~~~

Init path:

~~~text
mode = 1, magic = 0xd6d8
~~~

Behavior:

- initializes owned wait object at 0x81a67cd0
- initializes condition object at 0x81a67ce4 associated with 0x81a67cd0
- initializes timeout object at 0x81a780f0:
  - timeout queue = *(stage1_timeout_queue_candidate **)0x81802ab4
  - callback = FUN_80ef4b74
  - callback arg = 0

Cleanup path:

~~~text
mode = 0, magic = 0xd6d8
~~~

Behavior:

- cancels/unlinks timeout object at 0x81a780f0
- cleans condition object at 0x81a67ce4
- drains owned-wait-object waitq at 0x81a67cd0

Wrappers:

- fn_stage1_signal_global_init_wrapper_80ef5130
  - calls 80ef5020(1, 0xd6d8)

- fn_stage1_signal_global_cleanup_wrapper_80ef5150
  - calls 80ef5020(0, 0xd6d8)

### fn_stage1_signal_pending_bit_set_checked_80ef4f6c_candidate

Behavior:

- accepts bit_index 1..31
- sets *pending_mask_ptr |= 1 << bit_index
- returns 0 on success
- invalid bit writes errno/status 0x16 through FUN_80ea365c
- returns -1 on invalid bit

### fn_stage1_signal_mask_bit_test_checked_80ef4fd4_candidate

Behavior:

- accepts bit_index 1..31
- returns 1 if selected bit is set
- returns 0 if selected bit is clear
- invalid bit writes errno/status 0x16
- returns -1 on invalid bit

### fn_stage1_signal_mask_word_clear_80ef4f60

Final enough.

Signature:

~~~c
undefined4 fn_stage1_signal_mask_word_clear_80ef4f60(uint *mask_word_ptr);
~~~

Behavior:

- clears *mask_word_ptr
- returns 0

Used for:

- thread_record +0x48 pending mask
- thread_record +0x4c blocked/masked word
- temporary stack signal/mask words

### fn_stage1_signal_timeout_callback_post_bit14_wake_80ef4b74_candidate

This is the callback installed into g_stage1_signal_timeout_object_81a780f0_candidate.

Behavior:

- clears g_stage1_signal_timeout_state_81803ad0_candidate
- sets g_stage1_signal_deferred_bit14_pending_81803ad4_candidate
- initializes temporary stack signal/mask state through 80ef4f60
- sets pending bit 0x0e in that temporary state
- wakes all waiters on g_stage1_signal_condition_object_81a67ce4_candidate
- calls FUN_80ef3360 on the temporary stack state

Adjacent globals:

~~~text
81803ad0 = g_stage1_signal_timeout_state_81803ad0_candidate
81803ad4 = g_stage1_signal_deferred_bit14_pending_81803ad4_candidate
~~~

These are two adjacent 32-bit globals, not one 64-bit object.

### fn_stage1_signal_post_deferred_bit14_then_dispatch_80ef4bc4_candidate

Behavior:

- if g_stage1_signal_deferred_bit14_pending_81803ad4_candidate is nonzero:
  - clears it
  - builds message {2, 0x0e, 0}
  - posts it through the post-message enqueue/signal helper
- always calls current-thread signal dispatcher
- returns dispatcher result

### fn_stage1_signal_dispatch_with_optional_mask_override_80ef4f00_candidate

Behavior:

- gets current thread record
- if no current thread, returns 0
- if temporary mask pointer is non-NULL:
  - saves current thread +0x4c mask
  - replaces +0x4c with *temporary_mask_or_null
- calls current-thread pending signal dispatcher
- restores old +0x4c mask if it was overridden
- returns dispatcher result

Ghidra repair:

Do not leave this as longlong/v1:v0 return. It returns v0 only. Use int or undefined4 with custom storage disabled.


---

## Update 2 - Current-thread signal/post-message dispatcher

### fn_stage1_signal_dispatch_pending_for_current_thread_80ef4908_candidate

Signature:

~~~c
int fn_stage1_signal_dispatch_pending_for_current_thread_80ef4908_candidate(void);
~~~

Return meaning:

- 0 = no pending signal/event handled
- 1 = at least one pending signal/event handled

Behavior:

- gets current thread record through current-context thread-record getter
- combines:
  - global pending signal mask field at 0x81a67cec
  - current_thread->pending_signal_or_work_mask_48_candidate
- masks combined word with inverse of:
  - current_thread->blocked_signal_mask_or_wait_mask_4c_candidate
- if no unmasked pending bit remains:
  - returns 0
- otherwise acquires global signal/post-state guard at 0x81a67cd0 unless current context/thread already owns it
- repeatedly selects lowest pending bit through readyq bitmap lowest-set-bit helper
- indexes per-signal table at:
  - 0x81a67cf0 + bit_index * 0x10
- if queued post/message record exists at entry +0x0c:
  - removes one queued record
  - copies three payload words to stack
  - returns record node to g_stage1_post_queue_free_list_81803acc_candidate
- if per-signal queue becomes empty:
  - clears selected bit from global pending mask field
  - clears selected bit from current thread pending mask
- temporarily ORs selected bit and table entry +0x00 into current_thread +0x4c mask
- releases global signal guard before invoking handler
- invokes installed callback according to table entry +0x04/+0x08
- reacquires global signal guard
- restores old current_thread +0x4c mask
- loops until no unmasked pending bits remain
- returns 1 if any pending item was handled

### Provisional per-signal table entry

Observed entry size: 0x10.

~~~c
struct stage1_signal_handler_entry_candidate {
    uint additional_mask_00_candidate;
    uint flags_04_candidate;
    undefined4 handler_or_mode_08_candidate;
    void *queued_record_head_0c_candidate;
};
~~~

Known behavior:

- +0x00 is ORed into current thread +0x4c while handler is running
- +0x04 bit 0x2 selects alternate callback calling form
- +0x08 is handler/mode/callback pointer
- +0x0c is queued post/message record list head

### Post queue free list

~~~text
81803acc = g_stage1_post_queue_free_list_81803acc_candidate
~~~

Queued record visible fields:

- record +0x04 -> local payload word 0
- record +0x08 -> local payload word 1
- record +0x0c -> local payload word 2

Record +0x00 links queue/free-list nodes.

### Thread signal fields

Confirmed in stage1_thread_record_candidate:

~~~text
+0x08 context_08
+0x48 pending_signal_or_work_mask_48_candidate
+0x4c blocked_signal_mask_or_wait_mask_4c_candidate
~~~

### Ghidra fixes applied / rules from this work

- Do not define 0x81a67cd4 as a standalone global.
  It is field +0x04 inside the owned-wait object at 0x81a67cd0.

- Do not define 0x81a67cec as a standalone global if the condition object at 0x81a67ce4 is typed.
  It is field +0x08 inside that condition object.

- Do not create enum types for context flags if Ghidra becomes unstable.
  Keep context_flags_50 as uint and use comments/equates.

- For timeout callback pointer +0x0c, use undefined4 in structures.h for now.
  Avoid callback typedefs if Ghidra 12.1 parser/QuickFix rendering becomes unstable.

- Avoid Ghidra Quick Fix table for datatype correction.
  It triggered a Java NullPointerException in QuickFixTableModel rendering.

- For functions incorrectly shown as longlong v1:v0 return, reset function signature:
  return int or undefined4, remove custom storage.

## Current naming summary

Timeout:

- fn_stage1_timeout_object_init_80e94c0c
- fn_stage1_timeout_queue_remove_object_clear_active_80e940f4
- fn_stage1_timeout_object_cancel_and_unlink_80e94c40
- fn_stage1_timeout_object_cancel_and_unlink_alt_80e94c94_candidate
- fn_stage1_timeout_object_rearm_insert_80e94ce8_candidate
- fn_stage1_timeout_queue_insert_or_fire_due_80e93fc4_candidate
- fn_stage1_timeout_object_normalize_periodic_deadline_80e94d68_candidate
- fn_stage1_timeout_object_activate_if_inactive_80e94e78_candidate
- fn_stage1_timeout_object_cancel_if_active_80e957f4

Signal/post-state:

- fn_stage1_signal_pending_bit_set_checked_80ef4f6c_candidate
- fn_stage1_signal_mask_bit_test_checked_80ef4fd4_candidate
- fn_stage1_signal_mask_word_clear_80ef4f60
- fn_stage1_signal_global_magic_init_or_cleanup_80ef5020_candidate
- fn_stage1_signal_global_init_wrapper_80ef5130
- fn_stage1_signal_global_cleanup_wrapper_80ef5150
- fn_stage1_signal_timeout_callback_post_bit14_wake_80ef4b74_candidate
- fn_stage1_signal_post_deferred_bit14_then_dispatch_80ef4bc4_candidate
- fn_stage1_signal_dispatch_pending_for_current_thread_80ef4908_candidate
- fn_stage1_signal_dispatch_with_optional_mask_override_80ef4f00_candidate
- fn_stage1_thread_signal_state_init_or_copy_mask_80ef4c18_candidate
- fn_stage1_signal_post_bit_checked_then_dispatch_80ef4c8c_candidate

## Remaining open targets

Priority next targets:

1. FUN_80ef52c0
   - likely thread signal-state attach/register helper

2. FUN_80ef52c8
   - likely thread/global signal-state cleanup helper

3. FUN_80ef3360
   - used after temporary signal/mask state manipulation

4. fn_stage1_post_message_enqueue_and_signal_80ef4754_candidate
   - needed to finalize queued post/message record format

5. FUN_808811f8
   - public caller of checked signal-bit post helper

6. FUN_80023e9c
   - 64-bit division helper used by periodic timeout normalization

## Result

The Stage1 timeout object model is now stable enough to replace the old context byte block at +0x68 with a structured timeout object.

The Stage1 signal/post-state global cluster is now modeled as objects rather than overlapping scalar globals, which removes the Ghidra overlap warning and improves decompiler output in 80ef4908.

This log should be used as the current handoff point for continuing Stage1 signal/post-message reverse work.
