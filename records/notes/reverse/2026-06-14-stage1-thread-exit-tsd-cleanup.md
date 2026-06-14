# 2026-06-14 Stage1 thread-exit cleanup, TSD destructors, join wake, and datatype cleanup

## Scope

This note records the reverse-engineering progress around `fn_stage1_current_thread_exit_cleanup_wake_joiners_80ef3860_candidate` and the related stage1 thread-record datatypes, cleanup-handler datatype, TSD/TLS destructor table, RAM global labels, and exported `structures.h` cleanup.

No repository operations were performed by this note. Existing logs are preserved. This script writes a new dated note and avoids overwriting an existing file by adding a numeric suffix if needed.

## Main function analyzed

```c
void fn_stage1_current_thread_exit_cleanup_wake_joiners_80ef3860_candidate(uint exit_value_or_status)
```

Address:

```text
0x80ef3860
```

Confirmed interpretation:

```text
Stage1 current-thread exit / pthread_exit-like path
```

The function is not a generic wait helper. It is a terminal current-thread exit path that runs thread cleanup handlers, runs TSD/TLS destructors, stores the thread exit value, updates high-nibble thread state bits, wakes join waiters, releases the global thread/wait-object lock, marks the current context dead, and then enters a final no-return safety spin.

## High-level behavior

Confirmed behavior:

1. Gets the current thread record through `fn_stage1_current_context_get_thread_record_80ef307c_candidate`.
2. Walks and drains the current thread cleanup-handler LIFO list at `thread_record->cleanup_handler_head_44_candidate`.
3. For each cleanup handler:
   - loads next handler from `+0x00`
   - calls callback from `+0x04`
   - passes callback argument from `+0x08`
4. If `embedded_join_condition_178.tsd_value_slots_base_08_candidate` is non-NULL, scans 128 TSD/TLS key slots.
5. For each eligible key slot:
   - checks key mask bitmap at `g_stage1_tsd_key_valid_or_free_mask_81a64f18_candidate`
   - checks destructor table entry at `g_stage1_tsd_key_destructor_table_81a64f28_candidate[key_index]`
   - checks current thread TSD slot value
   - clears the slot before destructor call
   - calls the destructor with the old slot value
6. Repeats the destructor scan while any destructor ran, with maximum 5 passes.
7. Acquires global thread/wait-object lock at `0x81a64df8` through `fn_stage1_owned_wait_object_acquire_blocking_80e98770_candidate`.
8. Stores `exit_value_or_status` to `current_thread->exit_value_or_status_1c_candidate`.
9. Updates the high-nibble state in `flags_00`:
   - `0x10000000 -> 0x40000000`, incrementing `g_stage1_thread_exit_state4_count_81a64f10_candidate`
   - otherwise `-> 0x30000000`, incrementing `g_stage1_thread_exit_state3_count_81a64f14_candidate`
10. Wakes all join waiters on `current_thread->join_condition_3c_candidate` through `fn_stage1_wait_object_wake_all_success_80e98cd0_candidate`.
11. Releases global lock `0x81a64df8` through `fn_stage1_owned_wait_object_release_wake_one_80e989dc_candidate`.
12. Calls `fn_stage1_current_context_cleanup_mark_dead_80e96428_candidate`.
13. Enters a final intentional infinite loop. This is a no-return terminal safety sink.

## Final function name

Kept name:

```text
fn_stage1_current_thread_exit_cleanup_wake_joiners_80ef3860_candidate
```

Reason:

- Captures current-thread exit behavior.
- Captures cleanup handlers.
- Captures join wake behavior.
- Avoids overclaiming the exact exported API name as plain `pthread_exit`.
- The behavior is pthread-exit-like, but exact wrapper identity is not yet proven.

## No-return status

The function should remain marked No Return in Ghidra.

The final block:

```c
do {
    /* WARNING: Do nothing block with infinite loop */
} while (true);
```

is intentional for this function. It represents a terminal spin after current-context cleanup. Marking the function No Return does not remove the loop from the decompiler. The loop is real code and is consistent with a thread-exit path that must never return to its caller.

Recommended comment for the loop:

```c
/* Intentional no-return terminal spin after current context is marked dead.
   This thread-exit path must not return to its caller. */
```

Do not patch the loop out.

Do not mark `fn_stage1_current_context_cleanup_mark_dead_80e96428_candidate` as No Return yet unless its other xrefs prove that it never returns. In this function the explicit loop exists after that helper call, so the helper itself may return at machine-code level.

## Cleanup-handler datatype

Created or confirmed datatype:

```c
typedef void stage1_thread_cleanup_callback_candidate(uint arg);

struct stage1_thread_cleanup_handler_candidate {
    struct stage1_thread_cleanup_handler_candidate *next_00;
    stage1_thread_cleanup_callback_candidate *callback_04;
    uint arg_08;
};
```

Size:

```text
0x0c
```

Evidence from decompile:

```c
cleanup_node = current_thread->cleanup_handler_head_44_candidate;
while (cleanup_node != 0) {
    current_thread->cleanup_handler_head_44_candidate = cleanup_node->next_00;
    (*cleanup_node->callback_04)(cleanup_node->arg_08);
    cleanup_node = current_thread->cleanup_handler_head_44_candidate;
}
```

This proves that `stage1_thread_record_candidate +0x44` is a cleanup-handler linked-list head, not a plain integer.

## Thread join and TSD slots datatype

Created or confirmed datatype:

```c
struct stage1_thread_join_condition_candidate {
    struct stage1_owned_wait_object_candidate *associated_owned_wait_object_00_candidate;
    struct stage1_readyq_node_candidate *waitq_04;
    void **tsd_value_slots_base_08_candidate;
};
```

Size:

```text
0x0c
```

This datatype replaced the generic `stage1_condition_object_candidate` only for the embedded join object inside `stage1_thread_record_candidate`.

Reason:

- The original embedded object starts at `thread_record +0x178`.
- Its field at `+0x08` is therefore absolute thread-record offset `+0x180`.
- In this function, that field is used as the base pointer for per-thread TSD/TLS value slots.
- The generic condition object may still use field `+0x08` differently in other contexts, so a thread-specific struct is safer.

Confirmed field in thread record:

```c
struct stage1_thread_join_condition_candidate embedded_join_condition_178;
```

## TSD destructor callback datatype

Created or confirmed Ghidra Function Definition:

```c
void stage1_tsd_key_destructor_callback_candidate(void *value);
```

Important Ghidra note:

- In the Function Definition editor, enter the prototype as:

```c
void stage1_tsd_key_destructor_callback_candidate(void *value)
```

- Do not enter C pointer-typedef syntax there:

```c
void (*stage1_tsd_key_destructor_callback_candidate)(void *value)
```

In Ghidra structures or arrays, use a pointer to the function definition:

```c
stage1_tsd_key_destructor_callback_candidate *
```

## TSD destructor argument proof

Assembly around the indirect destructor call confirmed that the old TSD slot value is passed in `a0`.

Relevant assembly:

```asm
80ef3920  lw      v0,0x180(s0)      ; v0 = current_thread->tsd_value_slots_base
80ef3924  addu    v0,v1,v0          ; v0 = &tsd_value_slots[key_index]
80ef3928  lw      a0,0x0(v0)        ; a0 = old TSD value
80ef392c  beq     a0,zero,LAB_80ef3948
80ef3934  sw      zero,0x0(v0)      ; clear slot before destructor
80ef3938  lw      v0,0x0(a1)        ; v0 = destructor function pointer
80ef393c  jalr    v0                ; destructor(a0)
80ef3940  nop
80ef3944  li      a2,0x1            ; destructor_ran = true
```

Confirmed behavior:

```c
value = *tsd_value_slot;
if (value != NULL) {
    *tsd_value_slot = NULL;
    destructor(value);
    destructor_ran = true;
}
```

This supersedes the older note that destructor argument passing still needed verification.

## Global RAM labels created or confirmed

The following RAM/global labels were created or confirmed after adding or using a RAM block for the `0x81a64xxx` region:

```text
0x81a64f10  g_stage1_thread_exit_state4_count_81a64f10_candidate
0x81a64f14  g_stage1_thread_exit_state3_count_81a64f14_candidate
0x81a64f18  g_stage1_tsd_key_valid_or_free_mask_81a64f18_candidate
0x81a64f28  g_stage1_tsd_key_destructor_table_81a64f28_candidate
```

The decompiler originally showed the TSD globals as signed negative constants:

```text
-0x7e59b0e8 -> 0x81a64f18
-0x7e59b0d8 -> 0x81a64f28
```

Decimal scalar equivalents used for searching in this Ghidra setup:

```text
-2119807208 -> -0x7e59b0e8 -> 0x81a64f18
-2119807192 -> -0x7e59b0d8 -> 0x81a64f28
2175160088  -> 0x81a64f18
2175160104  -> 0x81a64f28
```

The signed negative constants came from 32-bit address wraparound in decompiler output.

## RAM memory-map note

If the program has no mapped RAM block covering `0x81a64f10` through `0x81a64f28`, add a small uninitialized RAM block rather than a huge generic RAM range.

Recommended block:

```text
Name:        RAM_STAGE1_GLOBALS_81A64000
Start:       0x81a64000
Length:      0x2000
Initialized: no
Read:        yes
Write:       yes
Execute:     no
Volatile:    no
Overlay:     no
```

This covers:

```text
0x81a64000 - 0x81a65fff
```

It includes:

```text
0x81a64df8  global thread lock / wait object
0x81a64f10  exit-state counter
0x81a64f14  exit-state counter
0x81a64f18  TSD key mask base
0x81a64f28  TSD destructor table base
```

Do not map a huge fake RAM block such as `0x80000000` length `0x02000000` just to solve this one issue.

Do not create initialized/file-backed bytes for this RAM area. It should be uninitialized RAM.

## TSD global datatype expectations

TSD key mask:

```c
uint g_stage1_tsd_key_valid_or_free_mask_81a64f18_candidate[4];
```

Reason:

- 128 key slots.
- 32 bits per word.
- 4 words total.

Destructor table:

```c
stage1_tsd_key_destructor_callback_candidate *g_stage1_tsd_key_destructor_table_81a64f28_candidate[128];
```

Reason:

- One function pointer per key index.
- 128 key slots.

Mask polarity remains cautious:

```c
if ((mask_word & (1 << (key_index & 0x1f))) == 0) {
    /* key is eligible for destructor check */
}
```

The current name `valid_or_free_mask` is intentionally cautious because this function proves bit-clear means eligible to check the destructor path, but does not fully prove the global polarity across all key-management functions.

## Updated thread-record fields

Important confirmed fields in `stage1_thread_record_candidate`:

```text
+0x00 flags_00
+0x04 thread_id_or_handle_04
+0x08 context_08
+0x0c attr_flags_0c
+0x10 attr_priority_or_class_10
+0x14 attr_stack_top_or_end_14
+0x18 attr_stack_size_18
+0x1c exit_value_or_status_1c_candidate
+0x20 entry_function_20
+0x24 entry_arg_24
+0x28 name_28[16]
+0x38 field_38
+0x3c join_condition_3c_candidate
+0x40 allocation_base_or_stack_base_40
+0x44 cleanup_handler_head_44_candidate
+0x48 pending_signal_or_work_mask_48_candidate
+0x4c blocked_signal_mask_or_wait_mask_4c_candidate
+0x50 embedded_context_50
+0x178 embedded_join_condition_178
```

Known size through the embedded join object:

```text
0x184
```

Key correction:

```text
0x50 + sizeof(stage1_context_candidate 0x128) = 0x178
0x178 + 0x08 = 0x180
```

Therefore, absolute offset `+0x180` is not a separate top-level field. It is:

```c
current_thread->embedded_join_condition_178.tsd_value_slots_base_08_candidate
```

## `stage1_context_candidate` relationship

The thread record embeds a full `stage1_context_candidate` at offset `+0x50`.

The known `stage1_context_candidate` length is:

```text
0x128 / 296 bytes
```

Important existing fields inside `stage1_context_candidate` include:

```text
+0x18 readyq_node_18
+0x20 readyq_bucket_20
+0x2c pending_callback_block_2c
+0x30 pending_callback_flag_30
+0x34 pending_callback_arg_34
+0x38 owned_pi_object_count_38_candidate
+0x3c owned_pi_object_list_head_3c_candidate
+0x40 current_owned_wait_object_acquire_candidate
+0x48 saved_base_readyq_bucket_48_candidate
+0x4c priority_inheritance_active_4c_candidate
+0x50 context_flags_50
+0x54 context_activation_hold_count_54_candidate
+0x5c wait_condition_5c
+0x60 context_trace_id_60
+0x68 timeout_list_object_68_candidate
+0x98 wait_state_98
+0x9c resume_status_9c
+0xac thread_record_ac_candidate
+0xe0 cleanup_callback_pairs_e0_candidate[8]
+0x120 field_120_candidate
+0x124 next_registered_context_124_candidate
```

The `thread_record_ac_candidate` pointer inside the embedded context points back to or references the owning thread record in related context-management logic.

## Exported `structures.h` cleanup result

The exported `structures.h` was checked twice.

Initial problem:

```c
struct stage1_thread_join_condition_candidate {
    struct stage1_owned_wait_object_candidate.conflict *associated_owned_wait_object_00_candidate;
    struct stage1_readyq_node_candidate *waitq_04;
    void **tsd_value_slots_base_08_candidate;
};
```

The `.conflict` type was a Ghidra datatype-manager conflict, not a real firmware datatype. It was corrected so that the join condition uses:

```c
struct stage1_owned_wait_object_candidate *associated_owned_wait_object_00_candidate;
```

Final checked stage1 structs were clean:

```c
struct stage1_thread_join_condition_candidate {
    struct stage1_owned_wait_object_candidate *associated_owned_wait_object_00_candidate;
    struct stage1_readyq_node_candidate *waitq_04;
    void **tsd_value_slots_base_08_candidate;
};

struct stage1_thread_cleanup_handler_candidate {
    struct stage1_thread_cleanup_handler_candidate *next_00;
    void (*callback_04)(uint);
    uint arg_08;
};
```

The thread record export also correctly referenced:

```c
struct stage1_thread_cleanup_handler_candidate *cleanup_handler_head_44_candidate;
struct stage1_thread_join_condition_candidate embedded_join_condition_178;
```

Remaining exported header issue outside the stage1 thread structs:

```c
struct fap_bypass_context_candidate
```

still had two `-BAD-` fields caused by deleted datatype references:

```c
-BAD- data_queue_objs_2c;    /* Type host_dqm_channel_obj_candidate *[8] was deleted */
-BAD- bypass_queue_objs_4c;  /* Type host_dqm_channel_obj_candidate *[2] was deleted */
```

Recommended fix:

```c
struct host_dqm_channel_obj_candidate *data_queue_objs_2c[8];
struct host_dqm_channel_obj_candidate *bypass_queue_objs_4c[2];
```

These `-BAD-` fields are unrelated to the current stage1 thread-exit function, but should be cleaned later before using the exported header as a general reference.

## Ghidra conflict datatype rule from this pass

Observed conflict types:

```text
stage1_thread_join_condition_candidate.conflict
stage1_owned_wait_object_candidate.conflict
stage1_condition_object_candidate.conflict
```

Rule:

- `.conflict` means Ghidra had duplicate datatypes with the same desired name but different definitions.
- It is usually a datatype-manager artifact, not a real firmware type.
- Compare both definitions before deleting.
- Keep the correct non-conflict datatype name where possible.
- Replace uses of `.conflict` with the correct base datatype.
- Delete `.conflict` only after `Find Uses` shows it is no longer referenced.

No old research logs should be deleted during datatype cleanup.

## Current decompile shape

The clean current decompile shape is:

```c
void fn_stage1_current_thread_exit_cleanup_wake_joiners_80ef3860_candidate(uint exit_value_or_status)
{
    stage1_thread_record_candidate *current_thread;
    stage1_thread_cleanup_handler_candidate *cleanup_node;
    void **tsd_value_slot;
    uint mask_word_index;
    void *value;
    stage1_tsd_key_destructor_callback_candidate **destructor_entry_ptr;
    bool destructor_ran;
    uint key_index;
    int destructor_pass;

    current_thread = fn_stage1_current_context_get_thread_record_80ef307c_candidate();

    cleanup_node = current_thread->cleanup_handler_head_44_candidate;
    while (cleanup_node != NULL) {
        current_thread->cleanup_handler_head_44_candidate = cleanup_node->next_00;
        (*cleanup_node->callback_04)(cleanup_node->arg_08);
        cleanup_node = current_thread->cleanup_handler_head_44_candidate;
    }

    if (current_thread->embedded_join_condition_178.tsd_value_slots_base_08_candidate != NULL) {
        destructor_pass = 0;
        do {
            destructor_ran = false;
            key_index = 0;
            mask_word_index = 0;
            do {
                if ((g_stage1_tsd_key_valid_or_free_mask_81a64f18_candidate[mask_word_index] &
                    (1 << (key_index & 0x1f))) == 0) {
                    destructor_entry_ptr = g_stage1_tsd_key_destructor_table_81a64f28_candidate + key_index;
                    if (*destructor_entry_ptr != NULL) {
                        tsd_value_slot = current_thread->embedded_join_condition_178.tsd_value_slots_base_08_candidate + key_index;
                        value = *tsd_value_slot;
                        if (value != NULL) {
                            *tsd_value_slot = NULL;
                            (**destructor_entry_ptr)(value);
                            destructor_ran = true;
                        }
                    }
                }
                key_index++;
                mask_word_index = key_index >> 5;
            } while (key_index < 0x80);
            destructor_pass++;
        } while (destructor_ran && destructor_pass < 5);
    }

    fn_stage1_owned_wait_object_acquire_blocking_80e98770_candidate(0x81a64df8);
    current_thread->exit_value_or_status_1c_candidate = exit_value_or_status;

    /* State update and join wake follow. */
}
```

Decompiler artifacts still visible:

```text
arg0
in_a2
in_a3
destructor_entry_ptr reused as stale a1 in later calls
```

These are stale MIPS register carryover artifacts. They should not be treated as semantic arguments for the wake or cleanup-dead calls.

## Function comment update still needed

Replace the stale note:

```text
- verify destructor callback argument passing in assembly before changing the
  TSD destructor prototype to void (*)(void *).
```

with:

```text
- assembly confirms the TSD destructor is called with the old slot value in a0:
  value = *tsd_value_slot; *tsd_value_slot = 0; destructor(value).
```

## Open questions and cautions

1. Exact meaning of high-nibble thread states `0x30000000` and `0x40000000` is still not fully proven.
   - Current cautious labels are `state3` and `state4`.
   - Do not rename them detached or joined until other functions confirm that.
2. Exact polarity of `g_stage1_tsd_key_valid_or_free_mask_81a64f18_candidate` remains cautious.
   - This function proves bit clear means destructor path can be checked.
   - Other key create/delete functions should be used before final polarity naming.
3. `fn_stage1_wait_object_wake_all_success_80e98cd0_candidate` and `fn_stage1_current_context_cleanup_mark_dead_80e96428_candidate` still show stale argument registers in this caller.
   - Do not change their prototypes solely from this function.
4. Do not rename this function to plain `pthread_exit` yet.
   - It is pthread-exit-like, but exact exported wrapper identity is not proven.
5. Do not remove the final infinite loop.
   - It is the no-return terminal safety sink for this current-thread exit path.

## Result

This pass converted `FUN_80ef3860` from a noisy low-confidence decompile into a well-typed, high-confidence stage1 thread-exit candidate with confirmed cleanup-handler list handling, confirmed TSD/TLS destructor behavior, confirmed destructor argument passing, corrected join/TSD embedded datatype, corrected cleanup-handler datatype, and usable RAM global labels for the thread-exit counters and TSD key tables.

The function is ready to move on from, except for replacing the stale destructor-verification note in the function comment.
