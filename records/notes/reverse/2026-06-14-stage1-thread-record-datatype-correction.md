# 2026-06-14 Stage1 thread-record datatype correction and scheduler/signal follow-up log

## Scope

This log records the current TC7200U Stage1 reverse-engineering findings around the thread-record create path, current-context thread-record getter, signal mask helpers, current-thread id getter, datatype corrections, Ghidra naming changes, and the correction from the earlier false signal-select-state model.

No git action is included. This is an additive reverse note only.

## Summary result

The earlier model that treated context +0xac as a pointer to a standalone signal/select-state object was corrected.

The current model is:

```text
stage1_context_candidate +0xac = stage1_thread_record_candidate * thread_record_ac_candidate
stage1_thread_record_candidate +0x48 = pending_signal_or_work_mask_48_candidate
stage1_thread_record_candidate +0x4c = blocked_signal_mask_or_wait_mask_4c_candidate
The signal/select masks are fields inside the owning thread record. They are not a separate object pointer stored in the context.

The create path proves this because the embedded context begins at thread_record +0x50 and the create helper writes the thread-record pointer to record +0xfc:

record +0x50 = embedded_context_50
embedded_context_50 +0xac = thread_record_ac_candidate
0x50 + 0xac = 0xfc
ptr[0x3f] = ptr
0x3f * 4 = 0xfc

Therefore:

thread_record->embedded_context_50.thread_record_ac_candidate = thread_record;
Corrected datatype model
stage1_context_candidate relevant corrected block
typedef struct stage1_context_candidate {
    undefined1 pad_00[0x0c];                                      /* +0x00 */
    undefined1 context_switch_state_0c[0x0c];                     /* +0x0c */
    stage1_readyq_node_candidate readyq_node_18;                  /* +0x18 */
    uint readyq_bucket_20;                                        /* +0x20 */
    undefined4 field_24;                                          /* +0x24 */
    stage1_readyq_node_candidate **owner_list_head_ref_28;        /* +0x28 */
    uint scheduler_callback_block_count_2c_candidate;             /* +0x2c */
    uint pending_callback_flag_30;                                /* +0x30 */
    undefined4 pending_callback_arg_34;                           /* +0x34 */
    uint owned_pi_object_count_38_candidate;                      /* +0x38 */
    stage1_owned_wait_object_candidate *owned_pi_object_list_head_3c_candidate; /* +0x3c */
    stage1_owned_wait_object_candidate *current_owned_wait_object_acquire_candidate; /* +0x40 */
    undefined4 field_44;                                          /* +0x44 */
    uint saved_base_readyq_bucket_48_candidate;                   /* +0x48 */
    uint priority_inheritance_active_4c_candidate;                /* +0x4c */
    uint context_flags_50;                                        /* +0x50 */
    uint context_activation_hold_count_54_candidate;              /* +0x54 */
    undefined4 field_58;                                          /* +0x58 */
    stage1_event_wait_condition_candidate *wait_condition_5c;     /* +0x5c */
    ushort context_trace_id_60;                                   /* +0x60 */
    undefined1 pad_62[6];                                         /* +0x62 */
    undefined1 timeout_list_object_68_candidate[0x30];            /* +0x68 */
    uint wait_state_98;                                           /* +0x98 */
    uint resume_status_9c;                                        /* +0x9c */
    undefined4 extended_zero_area_a0_candidate[3];                /* +0xa0 */
    stage1_thread_record_candidate *thread_record_ac_candidate;   /* +0xac */
    undefined4 extended_zero_area_b0_candidate[12];               /* +0xb0 */
    stage1_cleanup_callback_pair_candidate cleanup_callback_pairs_e0_candidate[8]; /* +0xe0 */
    undefined4 field_120_candidate;                               /* +0x120 */
    stage1_context_candidate *next_registered_context_124_candidate; /* +0x124 */
} stage1_context_candidate;                                       /* size 0x128 */

Important correction:

Do not use signal_select_state_ac_candidate at context +0xac.
Use thread_record_ac_candidate.
stage1_thread_record_candidate current carried layout
typedef struct stage1_thread_record_candidate {
    uint flags_00;                                                /* +0x00 */
    uint thread_id_or_handle_04;                                  /* +0x04 */
    stage1_context_candidate *context_08;                         /* +0x08 */
    uint attr_flags_0c;                                           /* +0x0c */
    uint attr_priority_or_class_10;                               /* +0x10 */
    uint attr_stack_top_or_end_14;                                /* +0x14 */
    uint attr_stack_size_18;                                      /* +0x18 */
    uint field_1c;                                                /* +0x1c */
    void *entry_function_20;                                      /* +0x20 */
    void *entry_arg_24;                                           /* +0x24 */
    char name_28[0x10];                                           /* +0x28 */
    uint field_38;                                                /* +0x38 */
    stage1_condition_object_candidate *join_condition_3c_candidate; /* +0x3c */
    void *allocation_base_or_stack_base_40;                       /* +0x40 */
    uint field_44;                                                /* +0x44 */
    uint pending_signal_or_work_mask_48_candidate;                /* +0x48 */
    uint blocked_signal_mask_or_wait_mask_4c_candidate;           /* +0x4c */
    stage1_context_candidate embedded_context_50;                 /* +0x50 */
    stage1_condition_object_candidate embedded_join_condition_178; /* +0x178 */
} stage1_thread_record_candidate;                                 /* size 0x184 */

Important relation:

thread_record +0x50 = embedded_context_50
thread_record +0xfc = embedded_context_50.thread_record_ac_candidate
thread_record +0x178 = embedded_join_condition_178
stack/work area starts after +0x184
stage1_thread_create_attr_candidate
typedef struct stage1_thread_create_attr_candidate {
    uint flags_00;                   /* +0x00 */
    uint priority_or_class_04;       /* +0x04 */
    uint stack_top_or_end_08;        /* +0x08 */
    uint stack_size_0c;              /* +0x0c */
} stage1_thread_create_attr_candidate; /* size 0x10 */
stage1_condition_object_candidate
typedef struct stage1_condition_object_candidate {
    stage1_owned_wait_object_candidate *associated_owned_wait_object_00_candidate; /* +0x00 */
    stage1_readyq_node_candidate *waitq_04;                                       /* +0x04 */
    uint field_08;                                                               /* +0x08 */
} stage1_condition_object_candidate;                                             /* size 0x0c */
Function findings
80ef3410 thread-record create/register helper

Current name:

fn_stage1_thread_record_create_register_80ef3410_candidate

Behavior:

- validates output thread id pointer and entry function pointer
- returns 0x16 on invalid arguments
- gets current thread record through fn_stage1_current_context_get_thread_record_80ef307c_candidate
- loads caller attributes or builds defaults through FUN_80ef3bd8
- if inheritance flags request it, copies class/priority from current thread record +0x0c and +0x10
- computes allocation size
- default size is 0x850
- if attr flag 0x400000 is set, uses caller supplied size from attr +0x0c
- if attr flag 0x800000 is clear, allocates memory through fn_heap_alloc_wrapper_800049b4_candidate
- if attr flag 0x800000 is set, derives the record base from caller supplied memory
- locks global thread table mutex at 0x81a64df8 through fn_stage1_owned_wait_object_acquire_blocking_80e98770_candidate
- calls FUN_80ef3174 before table slot allocation
- scans 64-entry thread table at 0x81a64e10 for a free slot
- stores the new thread record pointer into the selected table slot
- updates global id generation state
- initializes thread record fields
- builds generated name pthread.%08X in name_28
- initializes embedded join condition at record +0x178 through FUN_80e98b30
- stores join condition pointer into record +0x3c
- initializes thread-record runtime fields through FUN_80ef4c18
- initializes embedded context at record +0x50 through fn_stage1_context_init_register_80e95d50_candidate
- writes context pointer into record +0x08
- writes record pointer into embedded context +0xac by ptr[0x3f] = ptr
- conditionally adjusts context field +0x24 or thread record +0x74 depending on attr flags
- registers cleanup callback through FUN_80e978ac
- stores generated thread id/handle into *param_1
- increments global active thread count DAT_81803ab8
- releases global thread table mutex
- releases the new context start-hold through fn_stage1_context_decrement_start_hold_release_if_zero_80e9628c_candidate

Important assignment table:

ptr[0x01] = thread_id_or_handle_04
ptr[0x02] = context_08
ptr[0x03] = attr_flags_0c
ptr[0x04] = attr_priority_or_class_10
ptr[0x05] = attr_stack_top_or_end_14
ptr[0x06] = attr_stack_size_18
ptr[0x07] = field_1c
ptr[0x08] = entry_function_20
ptr[0x09] = entry_arg_24
ptr[0x0f] = join_condition_3c_candidate
ptr[0x10] = allocation_base_or_stack_base_40
ptr[0x11] = field_44
ptr[0x14] = embedded_context_50
ptr[0x3f] = embedded_context_50.thread_record_ac_candidate
ptr[0x5e] = embedded_join_condition_178
ptr[0x60] = embedded_join_condition_178.field_08 or adjacent condition state
80ef307c current-context thread-record getter

Correct name:

fn_stage1_current_context_get_thread_record_80ef307c_candidate

Correct prototype:

stage1_thread_record_candidate *
fn_stage1_current_context_get_thread_record_80ef307c_candidate(void)
{
    return g_stage1_current_context_819dcc54_candidate->thread_record_ac_candidate;
}

Previous stale name/comment:

fn_stage1_current_context_get_signal_select_state_80ef307c_candidate
signal_select_state_ac_candidate

Correction:

This function returns the owning thread record, not a separate signal/select object.
80ef4e60 signal-mask swap helper

Correct name:

fn_stage1_current_thread_record_swap_signal_mask_80ef4e60_candidate

Behavior:

thread_record = fn_stage1_current_context_get_thread_record_80ef307c_candidate()

if old_mask_out != NULL:
    *old_mask_out = thread_record->blocked_signal_mask_or_wait_mask_4c_candidate

if new_mask_in != NULL:
    thread_record->blocked_signal_mask_or_wait_mask_4c_candidate = *new_mask_in

Known use:

select/wait path installs a temporary signal mask before sleeping and restores the old mask after wake.

Caution:

thread_record +0x4c = blocked/wait signal mask
context +0x4c = priority_inheritance_active_4c_candidate
80ef4eb8 unmasked-pending signal/work helper

Correct name:

fn_stage1_current_thread_record_get_unmasked_pending_signal_80ef4eb8_candidate

Behavior:

thread_record = fn_stage1_current_context_get_thread_record_80ef307c_candidate()

pending_unmasked =
    (g_stage1_global_signal_state_81a67cec_candidate |
     thread_record->pending_signal_or_work_mask_48_candidate) &
    ~thread_record->blocked_signal_mask_or_wait_mask_4c_candidate

Return convention:

v0 = pending_unmasked != 0
v1 = pending_unmasked

Ghidra may display this as undefined8 or CONCAT44(v1, v0).

80ef3840 current-thread id getter

Correct name:

fn_stage1_current_thread_get_id_or_handle_80ef3840_candidate

Prototype:

uint fn_stage1_current_thread_get_id_or_handle_80ef3840_candidate(void)

Behavior:

stage1_thread_record_candidate *thread_record;

thread_record = fn_stage1_current_context_get_thread_record_80ef307c_candidate();
return thread_record->thread_id_or_handle_04;

This confirms:

stage1_thread_record_candidate +0x04 = thread_id_or_handle_04
Naming changes made or required
Required final names
80ef307c -> fn_stage1_current_context_get_thread_record_80ef307c_candidate
80ef3410 -> fn_stage1_thread_record_create_register_80ef3410_candidate
80ef3840 -> fn_stage1_current_thread_get_id_or_handle_80ef3840_candidate
80ef4e60 -> fn_stage1_current_thread_record_swap_signal_mask_80ef4e60_candidate
80ef4eb8 -> fn_stage1_current_thread_record_get_unmasked_pending_signal_80ef4eb8_candidate
Stale names to remove from comments and decompiler type notes
fn_stage1_current_context_get_signal_select_state_80ef307c_candidate
signal_select_state_ac_candidate
stage1_signal_select_state_candidate pointer at context +0xac

The standalone stage1_signal_select_state_candidate may remain in the datatype tree as an older compatibility or temporary structure, but it must not be used as the type of context +0xac.

Ghidra correction notes
Do this manually in Ghidra
1. Open Data Type Manager.
2. Open /custom/stage1_context_candidate.
3. At offset +0xac, replace stale signal_select_state_ac_candidate field.
4. Set type to stage1_thread_record_candidate *.
5. Set field name to thread_record_ac_candidate.
6. Open 80ef307c.
7. Set return type to stage1_thread_record_candidate *.
8. Rename function to fn_stage1_current_context_get_thread_record_80ef307c_candidate.
9. Refresh decompiler for 80ef3410, 80ef4e60, 80ef4eb8, and 80ef3840.
Expected decompiler improvements

Expected after datatype fix:

current_thread_record =
    fn_stage1_current_context_get_thread_record_80ef307c_candidate();

Expected in 80ef3410:

thread_record->embedded_context_50.thread_record_ac_candidate = thread_record;

If Ghidra still shows:

ptr[0x3f] = (uint)ptr;

then the datatype has not propagated into the function yet, or the local variable is still typed as uint * instead of stage1_thread_record_candidate *.

Current mistakes corrected in this pass
Mistake 1: context +0xac false pointer type

Wrong:

context +0xac = stage1_signal_select_state_candidate * signal_select_state_ac_candidate

Correct:

context +0xac = stage1_thread_record_candidate * thread_record_ac_candidate
Mistake 2: stale function comment at 80ef307c

Wrong:

Stage1 current-context signal/select-state getter
Returns current_context->signal_select_state_ac_candidate

Correct:

Stage1 current-context thread-record getter
Returns current_context->thread_record_ac_candidate
Mistake 3: treating +0x48/+0x4c as fields of a separate state object

Wrong:

state_object +0x48 = pending mask
state_object +0x4c = blocked mask

Correct:

thread_record +0x48 = pending_signal_or_work_mask_48_candidate
thread_record +0x4c = blocked_signal_mask_or_wait_mask_4c_candidate
Mistake 4: symbol reference error in 80ef3410 comment

Ghidra showed:

No symbol: fn_stage1_current_context_get_thread_record_80ef307c_candidate

Cause:

The function had not yet been renamed from the old signal-select-state name.

Fix:

Rename 80ef307c first, then use {@symbol fn_stage1_current_context_get_thread_record_80ef307c_candidate} in comments.
Current structure and function status
stage1_context_candidate: corrected enough for scheduler, wait, PI, timeout, cleanup, and thread-record owner pointer
stage1_thread_record_candidate: newly carried and linked to embedded context
stage1_thread_create_attr_candidate: carried enough for 80ef3410
stage1_condition_object_candidate: carried enough for embedded join condition and global condition objects
80ef3410 thread create/register: closed enough
80ef307c current thread-record getter: closed
80ef4e60 signal mask swap: closed
80ef4eb8 unmasked pending signal/work check: closed
80ef3840 current thread id getter: closed
Remaining next targets

Continue from the remaining xrefs to fn_stage1_current_context_get_thread_record_80ef307c_candidate.

Recommended order:

1. xref around 80ef3880
2. xref around 80ef3d88
3. xref around 80ef4794
4. xref around 80ef492c
5. xref around 80ef4da8
6. xref around 80ef4f14
7. xref around 80ef518c

Immediate next target:

Open containing function around 80ef3880 and inspect whether it reads or writes thread-record lifecycle fields, masks, join condition, table state, or exit status.
Preservation

This note is additive. No older notes, logs, or Ghidra evidence are deleted or overwritten. No git action is part of this command.

