# Important reverse structure reference

## Scope

This is the stable dateless carry note for the currently made TC7200U reverse-engineered structures.

Use dated notes for discovery, rationale, and stepwise corrections. Use this file for the current carried layouts that are important enough to keep as a reusable reference.

## Source notes

This reference currently carries layouts from:

- the in-thread June 14 screenshot-derived structure extraction later promoted directly into this dateless reference; no standalone dated note is currently present for that extraction
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-09-ghidra-fpm-datatypes.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-13-host-dqm-msp-comms-guarded-enable-path-updated.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-13-stage1-event-slot-wait-chain-update.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-scheduler-post-signal-wake-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-thread-record-datatype-correction.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-thread-exit-tsd-cleanup.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-pi-owned-wait-object-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-owner-list-wakeup-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-static-idle-timeslice.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-timeout-signal-dispatch.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-signal-object-path-dispatch-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-signal-object-type2-dispatcher-path.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-timeout-select-wait-reverse-log.md`

## Notes

- Candidate names keep `_candidate` suffix where semantics are still provisional.
- Ghidra-style scalar types such as `undefined1`, `undefined4`, `uint`, `ushort`, and `byte` are preserved where that is the current carried form.
- For duplicated structures, this file keeps the newest carried layout.
- This is a working reverse reference, not a vendor-confirmed header set.

## Extracted structures

### FPM allocator and packet structures

```c
typedef struct tc7200_fpm_allocator {
    uint32_t fpm_hw_base_kseg1;                          /* +0x00 */
    uint32_t board_or_buffer_class;                      /* +0x04 */
    uint32_t largest_default_pool_size;                  /* +0x08 */
    uint32_t fpm_backing_base_aligned;                   /* +0x0c */
    uint8_t  embedded_flag_log_object[0x18];             /* +0x10 */
    uint8_t  pool_size_shift_bits;                       /* +0x28 */
    uint8_t  pad_29[3];                                  /* +0x29 */
    uint32_t pool_class_lookup_table_ptr;                /* +0x2c */
    uint32_t max_largest_request_state;                  /* +0x30 */
    uint32_t fpm_extra_base_offset_or_headroom_candidate;/* +0x34 */
    uint32_t pool_size_table[4];                         /* +0x38 */
    uint32_t token_highbits_table[32768];                /* +0x48 */
} tc7200_fpm_allocator;                                  /* size 0x20048 */

typedef struct tc7200_fpm_packet_allocator {
    uint8_t  embedded_flag_log_object[0x18]; /* +0x00 */
    uint32_t packet_header_slot_size;        /* +0x18 */
    uint32_t packet_header_arena_aligned;    /* +0x1c */
    uint32_t main_fpm_allocator_ptr;         /* +0x20 */
} tc7200_fpm_packet_allocator;               /* size 0x24 */

typedef struct tc7200_fpm_packet_inner_header {
    uint32_t data_addr;                    /* +0x00 */
    uint32_t requested_payload_len;        /* +0x04 */
    uint8_t  unknown_08[0x10];             /* +0x08 */
    void    *ptr_or_list_18;               /* +0x18 */
    uint8_t  unknown_1c[4];                /* +0x1c */
    uint16_t flags_20;                     /* +0x20 */
    uint8_t  unknown_22[0x0a];             /* +0x22 */
    uint32_t fpm_extra_base_offset_saved;  /* +0x2c */
} tc7200_fpm_packet_inner_header;          /* size 0x30 */

typedef struct tc7200_fpm_packet_header {
    void *free_callback;                         /* +0x00 */
    tc7200_fpm_packet_inner_header *inner_header;/* +0x04 */
    void *list_or_inner_ptr_a;                  /* +0x08 */
    uint32_t active_or_refcount;                /* +0x0c */
    uint8_t unknown_10[0x10];                   /* +0x10 */
    tc7200_fpm_packet_inner_header embedded_inner;/* +0x20 */
    uint8_t unknown_50[0x90];                   /* +0x50 */
} tc7200_fpm_packet_header;                     /* size 0xe0 */
```

### Host-DQM structures

```c
typedef struct host_dqm_register_block_1800_candidate {
    byte pad_00[0x14];                 /* +0x00..+0x13 */
    uint reg14_status_current_bits;    /* +0x14 */
    uint reg18_enabled_pending_mask;   /* +0x18 */
    uint reg1c_queue_bit_or_ack;       /* +0x1c */
    uint reg20_channel_status_or_busy; /* +0x20 */
} host_dqm_register_block_1800_candidate;

typedef struct host_dqm_channel_obj_candidate {
    undefined4 *ops_table;                               /* +0x00 base ops table */
    char *name_copy_04;                                  /* +0x04 allocated/copy of t1 string */
    uint queue_index_a_08;                               /* +0x08 queue index A */
    uint channel_index;                                  /* +0x0c channel/bit index */
    uint init_flag_byte_10;                              /* +0x10 low byte init flag */
    uint queue_or_expected_index_14;                     /* +0x14 queue/backlog expected index */
    uint queue_a_initial_index_18;                       /* +0x18 high16 from queue-A +0x1a08 */
    void *fpm_allocator_1c;                              /* +0x1c FPM allocator pointer */
    uint record_word_count_or_limit;                     /* +0x20 record/payload word count */
    uint host_dqm_selector;                              /* +0x24 selector from t0 */
    uint host_dqm_base;                                  /* +0x28 selector MMIO base */
    host_dqm_register_block_1800_candidate *register_block; /* +0x2c */
    undefined4 *queue_a_window_1a00_30;                  /* +0x30 base + queue_index_a*0x10 + 0x1a00; header export currently degrades this to field_30_unknown */
    undefined4 *queue_b_window_1a00_34;                  /* +0x34 base + channel_index*0x10 + 0x1a00 */
    undefined4 *record_words;                            /* +0x38 base + channel_index*0x10 + 0x1c00 */
    undefined4 *queue_a_window_1c00_3c;                  /* +0x3c base + queue_index_a*0x10 + 0x1c00; header export currently degrades this to field_3c_unknown */
    uint *queue_a_cursor_or_index_ptr_40;                /* +0x40 base + queue_index_a*4 + 0x1f00; header export currently degrades this to field_40_unknown */
    uint *queue_index_or_cursor_ptr_44;                  /* +0x44 base + channel_index*4 + 0x1f00 */
    undefined4 field_48_unknown;                         /* +0x48 zeroed */
    undefined4 field_4c_unknown;                         /* +0x4c zeroed */
    uint ready_copy_count_50;                            /* +0x50 successful ready payload copy counter */
    undefined4 field_54_unknown;                         /* +0x54 zeroed */
    uint queue_delta_high_water_58;                      /* +0x58 queue/backlog high-water stat */
} host_dqm_channel_obj_candidate;                        /* size 0x5c */
```

### Stage1 event-slot structures

```c
typedef struct stage1_event_slot_candidate {
    uint pending_mask_00; /* +0x00 accumulated/raised event bits */
    stage1_readyq_node_candidate *waitq_04; /* +0x04 wait queue/list head */
} stage1_event_slot_candidate;

typedef struct stage1_event_wait_condition_candidate {
    uint require_all_mask_00;      /* +0x00 all bits required if nonzero */
    uint require_any_mask_04;      /* +0x04 any matching bit wakes */
    uint observed_pending_mask_08; /* +0x08 receives slot->pending_mask_00 */
    uint clear_slot_on_wake_0c;    /* +0x0c clear slot pending mask after wake if nonzero */
} stage1_event_wait_condition_candidate;
```

### Stage1 scheduler and wake-chain structures

```c
typedef struct stage1_readyq_node_candidate {
    struct stage1_readyq_node_candidate *next_00;
    struct stage1_readyq_node_candidate *prev_04;
} stage1_readyq_node_candidate;

typedef struct stage1_readyq_table_candidate {
    uint nonempty_bucket_bitmap_00;
    stage1_readyq_node_candidate *bucket_heads_04[32];
} stage1_readyq_table_candidate;

typedef struct stage1_callback_pair_candidate {
    undefined4 callback_00;
    undefined4 arg_04;
} stage1_callback_pair_candidate;

typedef struct stage1_cleanup_callback_pair_candidate {
    void *callback_00;
    void *callback_arg_04;
} stage1_cleanup_callback_pair_candidate;

typedef struct stage1_signal_select_state_candidate {
    undefined1 pad_00[0x48];
    uint pending_signal_or_work_mask_48_candidate;
    uint blocked_signal_mask_or_wait_mask_4c_candidate;
} stage1_signal_select_state_candidate;

typedef struct stage1_thread_create_attr_candidate {
    uint flags_00;
    uint priority_or_class_04;
    uint stack_top_or_end_08;
    uint stack_size_0c;
} stage1_thread_create_attr_candidate;

typedef struct stage1_scheduler_unlock_callback_record_candidate {
    undefined4 callback_arg0_00;
    undefined4 field_04;
    undefined4 field_08;
    undefined4 callback_0c;
    undefined4 callback_arg2_10;
    undefined4 pending_count_or_arg1_14;
    struct stage1_scheduler_unlock_callback_record_candidate *next_18;
} stage1_scheduler_unlock_callback_record_candidate;

typedef struct stage1_id_to_value_map_entry_candidate {
    int key_00;
    uint value_04;
} stage1_id_to_value_map_entry_candidate;

typedef struct stage1_post_message_candidate {
    int msg_type_00;
    uint target_index_04;
    undefined4 payload_08;
} stage1_post_message_candidate;

typedef struct stage1_post_queue_node_candidate {
    struct stage1_post_queue_node_candidate *next_00;
    uint target_index_04;
    undefined4 post_arg_or_source_08;
    undefined4 payload_0c;
} stage1_post_queue_node_candidate;

typedef struct stage1_post_target_slot_candidate {
    undefined4 field_00;
    uint flags_04;
    undefined4 field_08;
    stage1_post_queue_node_candidate *tail_0c;
} stage1_post_target_slot_candidate;

typedef struct stage1_owned_wait_object_candidate stage1_owned_wait_object_candidate;
typedef struct stage1_thread_record_candidate stage1_thread_record_candidate;
typedef struct stage1_timeout_object_candidate stage1_timeout_object_candidate;

typedef struct stage1_timeout_queue_candidate {
    stage1_timeout_object_candidate *head_00;
    undefined4 field_04_candidate;
    uint current_time_hi_08_candidate;
    uint current_time_lo_0c_candidate;
} stage1_timeout_queue_candidate; /* size 0x10 */

typedef struct stage1_timeout_object_candidate {
    stage1_timeout_object_candidate *next_00;
    stage1_timeout_object_candidate *prev_04;
    stage1_timeout_queue_candidate *timeout_queue_08_candidate;
    undefined4 callback_0c_candidate;
    undefined4 callback_arg_10_candidate;
    undefined4 field_14_candidate;
    uint deadline_hi_18_candidate;
    uint deadline_lo_1c_candidate;
    uint interval_hi_20_candidate;
    uint interval_lo_24_candidate;
    uint active_or_registered_28_candidate;
    struct stage1_context_candidate *owner_context_2c_candidate;
} stage1_timeout_object_candidate; /* size 0x30 */

typedef struct stage1_context_candidate {
    undefined1 pad_00[0x0c];
    undefined1 context_switch_state_0c[0x0c];
    stage1_readyq_node_candidate readyq_node_18;
    uint readyq_bucket_20;
    uint scheduler_timeslice_flag_24_candidate; /* still provisional: timeslice/scheduler policy or eligibility field */
    stage1_readyq_node_candidate **owner_list_head_ref_28; /* header export currently flattens this to undefined4 */
    uint scheduler_callback_block_count_2c_candidate; /* header export currently names this pending_callback_block_2c */
    uint pending_callback_flag_30;
    undefined4 pending_callback_arg_34;
    uint owned_pi_object_count_38_candidate;
    stage1_owned_wait_object_candidate *owned_pi_object_list_head_3c_candidate;
    stage1_owned_wait_object_candidate *current_owned_wait_object_acquire_candidate;
    undefined4 field_44;
    uint base_readyq_bucket_48_candidate;
    uint priority_inheritance_active_4c_candidate;
    uint context_flags_50;
    uint context_activation_hold_count_54_candidate;
    undefined4 field_58; /* header export currently carries this slot as undefined4 *field_58 */
    stage1_event_wait_condition_candidate *wait_condition_5c;
    ushort context_trace_id_60;
    undefined1 pad_62[6];
    stage1_timeout_object_candidate timeout_object_68_candidate;
    uint wait_state_98;
    uint resume_status_9c;
    undefined4 extended_zero_area_a0_candidate[3];
    stage1_thread_record_candidate *thread_record_ac_candidate;
    undefined4 extended_zero_area_b0_candidate[12];
    stage1_cleanup_callback_pair_candidate cleanup_callback_pairs_e0_candidate[8];
    undefined4 field_120_candidate;
    struct stage1_context_candidate *next_registered_context_124_candidate;
} stage1_context_candidate; /* size 0x128 */

typedef struct stage1_owned_wait_object_candidate {
    undefined1 active_or_locked_00;
    undefined1 pad_01[3];
    stage1_context_candidate *owner_context_04;
    stage1_readyq_node_candidate *waitq_08;
    stage1_owned_wait_object_candidate *next_owned_pi_object_0c;
    uint ownership_pi_mode_10;
} stage1_owned_wait_object_candidate; /* size 0x14 */

typedef struct stage1_condition_object_candidate {
    stage1_owned_wait_object_candidate *associated_owned_wait_object_00_candidate;
    stage1_readyq_node_candidate *waitq_04;
    uint field_08;
} stage1_condition_object_candidate;

typedef void stage1_thread_cleanup_callback_candidate(uint arg);

typedef struct stage1_thread_join_condition_candidate {
    stage1_owned_wait_object_candidate *associated_owned_wait_object_00_candidate;
    stage1_readyq_node_candidate *waitq_04;
    void **tsd_value_slots_base_08_candidate;
} stage1_thread_join_condition_candidate; /* size 0x0c */

typedef struct stage1_thread_cleanup_handler_candidate {
    struct stage1_thread_cleanup_handler_candidate *next_00;
    stage1_thread_cleanup_callback_candidate *callback_04;
    uint arg_08;
} stage1_thread_cleanup_handler_candidate; /* size 0x0c */

typedef struct stage1_thread_record_candidate {
    uint flags_00;
    uint thread_id_or_handle_04;
    stage1_context_candidate *context_08;
    uint attr_flags_0c;
    uint attr_priority_or_class_10;
    uint attr_stack_top_or_end_14;
    uint attr_stack_size_18;
    uint exit_value_or_status_1c_candidate;
    void *entry_function_20;
    void *entry_arg_24;
    char name_28[0x10];
    uint field_38;
    stage1_condition_object_candidate *join_condition_3c_candidate;
    void *allocation_base_or_stack_base_40;
    stage1_thread_cleanup_handler_candidate *cleanup_handler_head_44_candidate;
    uint pending_signal_or_work_mask_48_candidate;
    uint blocked_signal_mask_or_wait_mask_4c_candidate;
    stage1_context_candidate embedded_context_50;
    stage1_thread_join_condition_candidate embedded_join_condition_178;
    /* stack/work area starts at +0x184; absolute +0x180 is embedded_join_condition_178.tsd_value_slots_base_08_candidate */
} stage1_thread_record_candidate; /* fixed prefix size 0x184 */
```

Notes:

- `owner_list_head_ref_28` is a pointer to the exact external list-head slot that currently owns `context->readyq_node_18`.
- `scheduler_timeslice_flag_24_candidate` remains provisional; current evidence only proves timeslice rotation eligibility/policy gating.
- `timeout_object_68_candidate` replaces the older raw `0x30`-byte byte-block carry at `stage1_context_candidate +0x68`.
- `join_condition_3c_candidate` remains the generic `stage1_condition_object_candidate *` in the current carried model.
- only the embedded join object at `stage1_thread_record_candidate +0x178` is specialized to `stage1_thread_join_condition_candidate`, because its `+0x08` field is used as the per-thread TSD/TLS slot-base pointer.

### Stage1 signal-object, related-object, and timeout-conversion structures

```c
typedef struct stage1_signal_object_candidate stage1_signal_object_candidate;
typedef struct stage1_signal_ops_or_class_candidate stage1_signal_ops_or_class_candidate;
typedef struct stage1_signal_object_type2_ops_candidate stage1_signal_object_type2_ops_candidate;
typedef struct stage1_related_object_pool_a_entry_candidate stage1_related_object_pool_a_entry_candidate;
typedef struct stage1_related_object_pool_b_entry_candidate stage1_related_object_pool_b_entry_candidate;

typedef struct stage1_iovec_candidate {
    void *base_00;
    uint length_04;
} stage1_iovec_candidate; /* size 0x08 */

typedef struct stage1_signal_object_candidate {
    uint flags_00;
    ushort refcount_04;
    ushort type_or_mode_06_candidate;
    uint flags_08_candidate;
    stage1_signal_ops_or_class_candidate *ops_or_class_0c;
    undefined4 field_10;
    undefined4 field_14;
    stage1_signal_object_type2_ops_candidate *type2_ops_18_candidate;
    stage1_related_object_pool_b_entry_candidate *provider_or_related_entry_1c_candidate;
} stage1_signal_object_candidate; /* size 0x20 */

typedef struct stage1_related_object_pool_a_entry_candidate {
    undefined1 pad_00[8];
    uint lock_flags_08_candidate;
    undefined1 pad_0c[8];
    undefined4 create_or_init_callback_14;
    undefined4 field_18;
    int (*callback_1c_candidate)(stage1_related_object_pool_b_entry_candidate *, void *, void *);
    undefined1 pad_20[0x0c];
    int (*callback_2c_candidate)(stage1_related_object_pool_b_entry_candidate *, void *, void *, stage1_signal_object_candidate *);
    int (*path_context_callback_30_candidate)(stage1_related_object_pool_b_entry_candidate *, void *, char *, void **);
    int (*callback_34_candidate)(stage1_related_object_pool_b_entry_candidate *, void *, void *, uint);
    undefined1 pad_38[8];
} stage1_related_object_pool_a_entry_candidate; /* size 0x40 */

typedef struct stage1_related_object_pool_b_entry_candidate {
    undefined1 pad_00[0x14];
    stage1_related_object_pool_a_entry_candidate *pool_a_entry_14_candidate;
    undefined1 pad_18[8];
} stage1_related_object_pool_b_entry_candidate; /* size 0x20 */

typedef struct stage1_signal_iovec_io_request_candidate {
    stage1_iovec_candidate *iov_00;
    int iov_count_04;
    undefined4 field_08;
    uint remaining_or_total_len_0c;
    uint field_10_zero_init;
    uint mode_index_14;
} stage1_signal_iovec_io_request_candidate; /* size 0x18 */

typedef struct stage1_signal_ops_or_class_candidate {
    int (*io_mode1_callback_00_candidate)(stage1_signal_object_candidate *, stage1_signal_iovec_io_request_candidate *);
    int (*io_mode2_callback_04_candidate)(stage1_signal_object_candidate *, stage1_signal_iovec_io_request_candidate *);
    int (*callback_08_candidate)(stage1_signal_object_candidate *, void **, void *);
    int (*callback_0c_candidate)(stage1_signal_object_candidate *, void *, void *);
    int (*test_callback_10)(stage1_signal_object_candidate *, uint);
    int (*callback_14_candidate)(stage1_signal_object_candidate *, uint);
    int (*final_release_18)(stage1_signal_object_candidate *);
    int (*callback_1c_candidate)(stage1_signal_object_candidate *, void *);
} stage1_signal_ops_or_class_candidate; /* size 0x20 */

typedef struct stage1_signal_object_provider_entry_candidate {
    undefined4 field_00_candidate;
    uint flags_or_mode_04_candidate;
    undefined1 pad_08[0x10];
    undefined4 create_callback_18;
    undefined1 pad_1c[4];
} stage1_signal_object_provider_entry_candidate; /* size 0x20 */

typedef struct stage1_signal_object_type2_ops_candidate {
    int (*callback_00_candidate)(stage1_signal_object_candidate *, char *, int *);
    int (*callback_04_candidate)(stage1_signal_object_candidate *, char *, int *);
    int (*clone_callback_08)(stage1_signal_object_candidate *, stage1_signal_object_candidate *, undefined4, undefined4);
    int (*callback_0c_candidate)(stage1_signal_object_candidate *, char *);
    int (*callback_10_candidate)(stage1_signal_object_candidate *, char *, int *, uint);
    undefined4 field_14_candidate;
    int (*callback_18_t0_candidate)(stage1_signal_object_candidate *, char *, int *, undefined4);
    undefined4 field_1c_candidate;
    int (*callback_20_out_candidate)(stage1_signal_object_candidate *, void *, void *, int *);
    int (*callback_24_out_candidate)(stage1_signal_object_candidate *, undefined1 *, undefined4, int *);
} stage1_signal_object_type2_ops_candidate; /* size at least 0x28 */

typedef struct stage1_signal_object_type2_callback_20_request_candidate {
    undefined4 field_00_from_t0_candidate;
    undefined4 field_04_from_t1_candidate;
    undefined4 *payload_pair_ptr_08_candidate;
    undefined4 field_0c_const1_candidate;
    undefined4 field_10_zero_candidate;
    undefined4 field_14_candidate;
    undefined4 field_18_zero_candidate;
    undefined4 field_1c_candidate;
    undefined4 payload_arg0_20_candidate;
    undefined4 payload_arg1_24_candidate;
} stage1_signal_object_type2_callback_20_request_candidate; /* size 0x28 */

typedef struct stage1_signal_object_type2_callback_24_request_candidate {
    undefined4 field_00_from_t0_candidate;
    undefined4 field_04_from_optional_aux_deref_candidate;
    undefined4 *payload_pair_ptr_08_candidate;
    undefined4 field_0c_const1_candidate;
    undefined4 field_10_zero_candidate;
    undefined4 field_14_candidate;
    undefined4 field_18_candidate;
    undefined4 field_1c_candidate;
    undefined4 payload_arg0_20_candidate;
    undefined4 payload_arg1_24_candidate;
} stage1_signal_object_type2_callback_24_request_candidate; /* size 0x28 */

typedef struct stage1_timeout_scale_table_candidate {
    uint word_00;
    uint word_04;
    uint word_08;
    uint word_0c;
    uint word_10;
    uint word_14;
    uint word_18;
    uint word_1c;
} stage1_timeout_scale_table_candidate; /* size 0x20 */

typedef struct stage1_timeval32_candidate {
    int tv_sec_00;
    int tv_usec_04;
} stage1_timeval32_candidate; /* size 0x08 */
```

Notes:

- `stage1_signal_object_candidate +0x0c` is now a real ops or class callback table, not an opaque side pointer.
- `stage1_signal_object_candidate +0x18` is a type2 ops table when `type_or_mode_06_candidate == 2`.
- `stage1_signal_object_candidate +0x1c` must remain broad as `provider_or_related_entry_1c_candidate`, because one creation path stores a provider entry there while earlier notes tied it too narrowly to the related-object path.
- `stage1_signal_ops_or_class_candidate +0x10` is now strong enough to carry as the select or wait readiness-test callback slot.
- `stage1_timeout_scale_table_candidate` stays intentionally generic; the current carry only proves its role in the timeout-to-ticks conversion tables at `0x81a6ba70` and `0x81a6ba90`.

### Additional screenshot-derived structures

```c
typedef struct dma_allocator_global_state_81848740_candidate {
    undefined4 field_00;                  /* +0x00 */
    undefined4 header_field_04;           /* +0x04 */
    uint default_pool_size_08;            /* +0x08 */
    void *backing_fpm_pool_base_0c;       /* +0x0c */
    undefined1 pad_10[0x18];              /* +0x10 */
    uint pool_shift_28;                   /* +0x28 */
    void *pool_class_table_ptr_2c;        /* +0x2c */
    uint max_or_largest_request_30;       /* +0x30 */
    uint timer_counter_or_state_34;       /* +0x34 */
    undefined1 pad_38[8];                 /* +0x38 */
    undefined4 default_pool_sizes_copy_40;/* +0x40 */
    undefined4 high_bits_table_48;        /* +0x44 screenshot field name kept as-is */
} dma_allocator_global_state_81848740_candidate; /* size 0x48 */

typedef struct fap_bypass_context_candidate {
    undefined1 pad_00[0x14];                           /* +0x00 */
    uint enabled_queue_mask_14;                        /* +0x14 */
    int active_queue_index_18;                         /* +0x18 */
    int data_enabled_queue_last_index_1c;              /* +0x1c */
    int bypass_queue_last_index_20;                    /* +0x20 */
    host_dqm_channel_obj_candidate *cmd_dqm_obj_24;    /* +0x24 */
    host_dqm_channel_obj_candidate *active_queue_obj_28;/* +0x28 */
    host_dqm_channel_obj_candidate *data_queue_objs_2c[8];/* +0x2c inferred from size/type */
    host_dqm_channel_obj_candidate *bypass_queue_objs_4c[2];/* +0x4c inferred from size/type */
    uint8_t data_mode_enabled_54;                      /* +0x54 */
} fap_bypass_context_candidate;                        /* size 0x55 */

typedef struct host_downstream_dqm_queue_obj_candidate {
    host_dqm_channel_obj_candidate base; /* +0x00..+0x5b */
    byte active_flag_5c;                 /* +0x5c */
    byte pad_5d[3];                      /* +0x5d */
    undefined4 field_60_unknown;         /* +0x60 */
    undefined4 field_64_unknown;         /* +0x64 */
    void *fpm_allocator_68;              /* +0x68 */
} host_downstream_dqm_queue_obj_candidate; /* size 0x6c */

typedef struct stage1_bcm_sem_candidate {
    undefined4 count_or_state;   /* +0x00 */
    undefined4 wait_queue_or_list;/* +0x04 */
} stage1_bcm_sem_candidate;      /* size 0x8 */

typedef struct stage1_semaphore_candidate {
    int count;            /* +0x00 */
    stage1_readyq_node_candidate *waitq_04;  /* +0x04 */
} stage1_semaphore_candidate; /* size 0x8 */

typedef struct stage1_guarded_context_lock_candidate {
    int refcount;                           /* +0x00 */
    int waiter_count;                       /* +0x04 */
    void *owner_context;                    /* +0x08 */
    stage1_semaphore_candidate *semaphore;  /* +0x0c */
} stage1_guarded_context_lock_candidate;    /* size 0x10 */
```

## Current carried status

This reference currently carries:

- 5 FPM and allocator or packet structures
- 4 Host-DQM structures
- 2 Stage1 event-slot structures
- 19 Stage1 scheduler and wake-chain structures
- 12 Stage1 signal-object, related-object, and timeout-conversion structures
- 3 additional synchronization or semaphore structures

Total current carried structures: `45`

## Header cross-check

Cross-checks against `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\tools\tc7200u_stage1_custom_structs.h`, `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\structures.h`, and `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\image.raw.h`:

- confirms the carried `stage1_thread_create_attr_candidate`, `stage1_condition_object_candidate`, and `stage1_thread_record_candidate` layouts
- the newer exported `records\\reverse\\structures.h` also confirms:
  - `stage1_thread_cleanup_handler_candidate`
  - `stage1_thread_join_condition_candidate`
  - `stage1_thread_record_candidate +0x1c/+0x44/+0x178`
- the same live exports now also confirm the newer June 15 signal-object carry set:
  - `stage1_signal_object_candidate`
  - `stage1_signal_ops_or_class_candidate`
  - `stage1_signal_object_type2_ops_candidate`
  - `stage1_signal_object_provider_entry_candidate`
  - `stage1_signal_object_type2_callback_20_request_candidate`
  - `stage1_signal_object_type2_callback_24_request_candidate`
  - `stage1_timeout_scale_table_candidate`
  - `stage1_timeval32_candidate`
- the live exports also strengthen several scheduler-side field interpretations:
  - `stage1_event_slot_candidate +0x04` as a waitq pointer
  - `stage1_context_candidate +0x28` as a double-pointer owner-list head reference
  - `stage1_semaphore_candidate +0x04` as a waitq pointer
- confirms `stage1_context_candidate +0xac` as `stage1_thread_record_candidate *thread_record_ac_candidate`
- confirms the stronger signal-object-side field interpretations:
  - `stage1_signal_object_candidate +0x18` as `type2_ops_18_candidate`
  - `stage1_signal_object_candidate +0x1c` as the broader `provider_or_related_entry_1c_candidate`
  - `stage1_signal_ops_or_class_candidate +0x10` as the `test_callback_10` slot
- keeps `stage1_signal_select_state_candidate` only as a separate carried candidate layout; it should not replace the `thread_record_ac_candidate` interpretation at `stage1_context_candidate +0xac`
- the exported header currently weakens some already-better carried fields:
  - `host_dqm_channel_obj_candidate +0x30/+0x3c/+0x40` are exported as unknowns
  - `stage1_context_candidate +0x28` is flattened to `undefined4`
  - `stage1_context_candidate +0x2c` is exported as `pending_callback_block_2c`
  - `stage1_context_candidate +0x58` is exported as `undefined4 *field_58`
- the header still contains export artifacts such as `-BAD-` array placeholders, `pointer` pseudo-types, and one truncated field name

## Maintenance log

Recorded modifications worth keeping:

- 2026-06-14: controlled the earlier dead source-file citation by recording the screenshot-derived extraction as in-thread carry material instead of keeping a nonexistent dated-note path
- 2026-06-14: carried the current `26`-structure set, including the `0x128` `stage1_context_candidate` layout
- 2026-06-14: carried `stage1_cleanup_callback_pair_candidate`, `stage1_owned_wait_object_candidate`, and `stage1_signal_select_state_candidate`
- 2026-06-14: added `stage1_thread_create_attr_candidate` and raised the carried set to `27` structures
- 2026-06-14: added `stage1_condition_object_candidate` and raised the carried set to `28` structures
- 2026-06-14: added `stage1_thread_record_candidate` and raised the carried set to `29` structures
- 2026-06-14: refined `stage1_context_candidate +0xac` from `signal_select_state_ac_candidate` to `thread_record_ac_candidate`
- 2026-06-14: added `2026-06-14-stage1-thread-record-datatype-correction.md` to the carried source set so the thread-record-owned signal/work-mask correction remains attached to the stable reference
- 2026-06-14: added `2026-06-14-stage1-thread-exit-tsd-cleanup.md`, added `stage1_thread_cleanup_handler_candidate` and `stage1_thread_join_condition_candidate`, and raised the carried set to `31` structures
- 2026-06-14: refined `stage1_thread_record_candidate +0x1c/+0x44/+0x178` to exit value/status, cleanup-handler head, and embedded join/TSD object semantics
- 2026-06-14: added the later readyq/owner-list, PI, timeslice, and timeout notes to the carried source set
- 2026-06-14: added `stage1_timeout_queue_candidate` and `stage1_timeout_object_candidate`, raised the carried set to `33` structures, and replaced the old raw `context +0x68` byte block with the structured timeout-object carry
- 2026-06-14: refined `stage1_context_candidate +0x24/+0x48` to `scheduler_timeslice_flag_24_candidate` and `base_readyq_bucket_48_candidate`
- 2026-06-14: cross-checked the carried note against `tools/tc7200u_stage1_custom_structs.h` and recorded header-export degradations without replacing better carried semantics
- 2026-06-16: added the June 15 signal-object, related-object, type2-dispatch, timeout-scale, and select-wait helper layouts, and raised the carried set to `45` structures

## Preservation

This file is the stable carry layer. Dated reverse logs remain preserved separately.
