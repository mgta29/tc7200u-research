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
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-16-stage1-socket-object-type2-setsockopt.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-19-dma-fpm-allocator-runtime-init.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-19-stage1-netif-aux-context-route-output.md`

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-21-bcm-periph-host-dqm-im5-reenable-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-21-natp-host-dqm-ghidra-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-21-net-config-heap-natp-gfap-ghidra-log.md`
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
    uint32_t fpm_buffer_size_hw_code;                    /* +0x04 */
    uint32_t configured_fpm_buffer_size;                 /* +0x08 */
    uint32_t fpm_backing_base_aligned;                   /* +0x0c */
    uint8_t  embedded_flag_log_object[0x18];             /* +0x10 */
    uint8_t  pool_size_shift_bits;                       /* +0x28 */
    uint8_t  pad_29[3];                                  /* +0x29 */
    uint32_t pool_class_lookup_table_ptr;                /* +0x2c */
    uint32_t max_alloc_size;                             /* +0x30 */
    uint32_t fpm_extra_base_offset_candidate;            /* +0x34 */
    uint32_t pool_size_by_token_highbits[4];             /* +0x38 */
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
    byte pad_00[20];
    vuint32_t reg14_channel_status_or_current;
    vuint32_t reg18_channel_enable_or_pending;
    undefined4 reg1c_queue_bit_or_ack;
    vuint32_t reg20_channel_status_or_busy;
} host_dqm_register_block_1800_candidate;

typedef void host_dqm_obj_ops_fn_candidate(void *self);

typedef struct host_dqm_object_ops_candidate {
    host_dqm_obj_ops_fn_candidate *destroy_00;
    host_dqm_obj_ops_fn_candidate *destroy_and_free_04;
    host_dqm_obj_ops_fn_candidate *method_08_null;
    host_dqm_obj_ops_fn_candidate *method_0c_null;
} host_dqm_object_ops_candidate;

typedef struct host_dqm_channel_obj_candidate {
    host_dqm_object_ops_candidate *ops_table;              /* +0x00 */
    char *name_copy_04;                                    /* +0x04 */
    uint32_t queue_index_a_08;                             /* +0x08 */
    uint32_t channel_index;                                /* +0x0c */
    uint32_t init_flag_byte_10;                            /* +0x10 */
    uint32_t queue_or_expected_index_14;                   /* +0x14 */
    uint32_t queue_a_initial_index_18;                     /* +0x18 */
    dma_allocator_global_state_81848740_candidate *fpm_allocator_1c; /* +0x1c */
    uint32_t record_word_count_or_limit;                   /* +0x20 */
    uint32_t host_dqm_selector;                            /* +0x24 */
    uint32_t host_dqm_base;                                /* +0x28 */
    host_dqm_register_block_1800_candidate *register_block;/* +0x2c */
    uint32_t *queue_a_window_1a00_30;                      /* +0x30 */
    uint32_t *queue_b_window_1a00_34;                      /* +0x34 */
    uint32_t *record_words;                                /* +0x38 */
    uint32_t *tx_submit_window_3c;                         /* +0x3c */
    uint32_t *tx_credit_or_depth_ptr_40;                   /* +0x40 */
    uint32_t *queue_index_or_cursor_ptr_44;                /* +0x44 */
    uint32_t tx_submit_count_48;                           /* +0x48 */
    uint32_t tx_no_credit_error_count_4c;                  /* +0x4c */
    uint32_t ready_copy_count_50;                          /* +0x50 */
    uint32_t field_54_dead_len_check_candidate;            /* +0x54 */
    uint32_t queue_delta_high_water_58;                    /* +0x58 */
} host_dqm_channel_obj_candidate;                          /* size 0x5c */

typedef struct host_downstream_dqm_queue_obj_candidate {
    host_dqm_channel_obj_candidate base;                         /* +0x00..+0x5b */
    uint8_t active_flag_5c;                                      /* +0x5c */
    uint8_t pad_5d[3];                                           /* +0x5d..+0x5f */
    uint32_t field_60_unknown;                                   /* +0x60 */
    uint32_t field_64_unknown;                                   /* +0x64 */
    dma_allocator_global_state_81848740_candidate *fpm_allocator_68; /* +0x68 */
} host_downstream_dqm_queue_obj_candidate;                       /* size 0x6c */

typedef struct natp_nomatch_rx_manager_candidate {
    host_dqm_channel_obj_candidate *host_dqm_obj_00; /* +0x00 */
    uint8_t flag_04;                                /* +0x04 */
    uint8_t flag_05;                                /* +0x05 */
    uint8_t flag_06;                                /* +0x06 */
    uint8_t pad_07;                                 /* +0x07 */
    uint32_t field_08;                              /* +0x08 */
    void *state_block_0c;                            /* +0x0c, allocated 0xdc */
} natp_nomatch_rx_manager_candidate;

typedef struct fap_bypass_context_candidate {
    void *ops_table_00;                                      /* +0x00 */
    undefined4 field_04_unknown;                             /* +0x04 */
    undefined4 field_08_unknown;                             /* +0x08 */
    uint32_t event_raise_mask_0c;                             /* +0x0c */
    uint32_t event_slot_id_10;                                /* +0x10 */
    uint32_t enabled_queue_mask_14;                           /* +0x14 */
    int32_t active_queue_index_18;                            /* +0x18 */
    int32_t data_enabled_queue_last_index_1c;                 /* +0x1c */
    int32_t bypass_queue_last_index_20;                       /* +0x20 */
    host_dqm_channel_obj_candidate *command_channel_obj_24;   /* +0x24, selector 1/MSP */
    host_downstream_dqm_queue_obj_candidate *active_queue_obj_28; /* +0x28 */
    host_downstream_dqm_queue_obj_candidate *data_queue_objs_2c[8]; /* +0x2c */
    host_downstream_dqm_queue_obj_candidate *bypass_queue_objs_4c[2]; /* +0x4c */
    uint8_t data_mode_enabled_54;                             /* +0x54 */
    uint8_t pad_55[3];                                        /* +0x55 */
    host_downstream_dqm_queue_obj_candidate *mac_message_queue_obj_58; /* +0x58 */
    host_dqm_channel_obj_candidate *async_message_channel_obj_5c;      /* +0x5c */
} fap_bypass_context_candidate;
```

Apply `host_dqm_register_block_1800_candidate` at `b8001800`, `b8201800`, `b8401800`, `b8601800`, `b8801800`, and `b8a01800`. NATP/no-match RX uses selector `4` / MPEG_PROC with base `b8a00000`, queue index `0x10`, and channel index `0x11`.
### Stage1 event-slot structures

`c
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
    int (*callback_14_candidate)(stage1_signal_object_candidate *, char *);
    int (*callback_18_t0_candidate)(stage1_signal_object_candidate *, char *, int *, undefined4);
    int (*setsockopt_t0_callback_1c_candidate)(stage1_signal_object_candidate *, int, int, void *);
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

typedef struct stage1_socket_object_candidate stage1_socket_object_candidate;
typedef struct stage1_socket_object_vtable_candidate stage1_socket_object_vtable_candidate;

typedef struct stage1_socket_object_candidate {
    stage1_socket_object_vtable_candidate *vtable_00;
    uint signal_index_or_socket_handle_04;
    undefined4 field_08;
    uint create_flags_or_t0_0c_candidate;
    undefined4 boot_context_base_10_candidate;
} stage1_socket_object_candidate; /* size at least 0x14 */

typedef struct stage1_socket_object_vtable_candidate {
    undefined4 field_00;
    undefined4 field_04;
    undefined4 field_08;
    undefined4 field_0c;
    void (*close_or_reset_10_candidate)(stage1_socket_object_candidate *);
    undefined1 pad_14[0x24];
    int (*getsockopt_t0_method_38_candidate)(stage1_socket_object_candidate *, int, int, void *);
} stage1_socket_object_vtable_candidate; /* size at least 0x3c */
```

Notes:

- `stage1_signal_object_candidate +0x0c` is now a real ops or class callback table, not an opaque side pointer.
- `stage1_signal_object_candidate +0x18` is a type2 ops table when `type_or_mode_06_candidate == 2`.
- `stage1_signal_object_candidate +0x1c` must remain broad as `provider_or_related_entry_1c_candidate`, because one creation path stores a provider entry there while earlier notes tied it too narrowly to the related-object path.
- `stage1_signal_ops_or_class_candidate +0x10` is now strong enough to carry as the select or wait readiness-test callback slot.
- `stage1_signal_object_type2_ops_candidate +0x1c` is now socket-provider-aware as `setsockopt_t0_callback_1c_candidate`; hidden incoming `t0` is the option length in the observed socket path.
- `stage1_socket_object_candidate +0x04` is the Stage1 signal-object index or socket handle created by the provider-table path.
- `stage1_socket_object_vtable_candidate +0x38` is getsockopt-like in the close/cleanup path; hidden incoming `t0` is an option-length pointer.
- `stage1_timeout_scale_table_candidate` stays intentionally generic; the current carry only proves its role in the timeout-to-ticks conversion tables at `0x81a6ba70` and `0x81a6ba90`.

### Stage1 netif, socket-create-flag, aux-context, and route-output structures

```c
typedef struct stage1_socket_build_context_candidate {
    undefined1 pad_00[0x40];                    /* +0x00 */
    void *option_state_record_40_candidate;     /* +0x40 */
    uint flags_44_candidate;                    /* +0x44 */
    undefined1 build_state_48_candidate[0x94];  /* +0x48 */
    undefined4 build_context_dc_candidate;      /* +0xdc */
    undefined4 hidden_t0_arg_e0_candidate;      /* +0xe0 */
} stage1_socket_build_context_candidate;        /* size at least 0xe4 */

typedef struct stage1_socket_create_flag_iface_name_record_candidate {
    char iface_name_00[4];       /* +0x00, examples: bcm0..bcm7 */
    undefined1 nul_pad_04[4];    /* +0x04 */
} stage1_socket_create_flag_iface_name_record_candidate; /* size 0x08 */

typedef struct stage1_netif_list_head_candidate {
    struct stage1_netif_object_candidate *first_00;              /* +0x00 */
    struct stage1_netif_object_candidate **tail_next_slot_04_candidate; /* +0x04 */
} stage1_netif_list_head_candidate;                              /* size 0x08 */

typedef struct stage1_netif_object_candidate {
    undefined1 pad_00[4];                                      /* +0x00 */
    char *base_name_04_candidate;                              /* +0x04 */
    struct stage1_netif_object_candidate *next_08_candidate;   /* +0x08 */
    struct stage1_netif_object_candidate **prev_next_slot_0c_candidate; /* +0x0c */
    struct stage1_netif_aux_object_candidate *aux_list_first_10_candidate; /* +0x10 */
    struct stage1_netif_aux_object_candidate **aux_list_tail_slot_14_candidate; /* +0x14 */
    undefined1 pad_18[0x18];                                   /* +0x18 */
    ushort registration_index_30_candidate;                    /* +0x30 */
    short unit_index_32_candidate;                             /* +0x32 */
    undefined1 pad_34[2];                                      /* +0x34 */
    ushort flags_36_candidate;                                 /* +0x36 */
    undefined1 pad_38[0x0c];                                   /* +0x38 */
    byte field_44_candidate;                                   /* +0x44 */
    undefined1 field_45_candidate;                             /* +0x45 */
    byte name_extra_len_46_candidate;                          /* +0x46 */
    undefined1 pad_47[0x45];                                   /* +0x47 */
    undefined1 lock_or_state_8c_candidate[8];                  /* +0x8c */
    undefined4 field_94_candidate;                             /* +0x94 */
    undefined1 pad_98[0x3c];                                   /* +0x98 */
    uint default_or_timeout_d4_candidate;                      /* +0xd4 */
    undefined1 pad_d8[8];                                      /* +0xd8 */
    undefined4 embedded_list2_first_e0_candidate;              /* +0xe0 */
    undefined4 embedded_list2_tail_slot_e4_candidate;          /* +0xe4 */
} stage1_netif_object_candidate;                               /* size at least 0xe8 */

typedef struct stage1_netif_aux_object_candidate {
    byte *primary_key_blob_00_candidate;       /* +0x00 */
    byte *secondary_key_blob_04_candidate;     /* +0x04 */
    byte *key_mask_blob_08_candidate;          /* +0x08 */
    undefined1 pad_0c[0x50];                   /* +0x0c */
    stage1_netif_object_candidate *parent_netif_5c_candidate; /* +0x5c */
    struct stage1_netif_aux_object_candidate *next_60_candidate; /* +0x60 */
    struct stage1_netif_aux_object_candidate **prev_next_slot_64_candidate; /* +0x64 */
    void (*callback_68_candidate)(int, struct stage1_netif_aux_event_context_candidate *, undefined4); /* +0x68 */
    undefined4 field_6c_candidate;             /* +0x6c */
    uint hold_count_70_candidate;              /* +0x70 */
} stage1_netif_aux_object_candidate;           /* size at least 0x74 */

typedef struct stage1_netif_aux_event_context_candidate {
    undefined1 pad_00[0x0b];                   /* +0x00 */
    byte state_flags_0b_candidate;             /* +0x0b */
    byte *lookup_key_blob_0c_candidate;         /* +0x0c */
    undefined4 field_10_candidate;             /* +0x10 */
    undefined1 pad_14[0x1c];                   /* +0x14 */
    undefined4 field_30_candidate;             /* +0x30 */
    uint hold_count_or_ref_34_candidate;       /* +0x34 */
    uint flags_38_candidate;                   /* +0x38 */
    stage1_netif_object_candidate *parent_netif_3c_candidate; /* +0x3c */
    stage1_netif_aux_object_candidate *current_aux_40_candidate; /* +0x40 */
    byte *route_or_key_blob_44_candidate;      /* +0x44 */
    undefined4 route_field_48_candidate;       /* +0x48 */
    uint route_mask_or_state_4c_candidate;     /* +0x4c */
    undefined1 route_state_copy_50_candidate[0x3c]; /* +0x50 */
    struct stage1_netif_aux_event_context_candidate *parent_or_related_ctx_8c_candidate; /* +0x8c */
} stage1_netif_aux_event_context_candidate;    /* size at least 0x90 */

typedef struct stage1_netif_aux_keyclass_ops_candidate {
    undefined1 pad_00[0x1c];                   /* +0x00 */
    stage1_netif_aux_event_context_candidate *(*lookup_or_acquire_1c_candidate)(byte *, void *); /* +0x1c */
    stage1_netif_aux_event_context_candidate *(*create_or_lookup_20_candidate)(byte *, void *);  /* +0x20 */
    undefined1 pad_24[0x0c];                   /* +0x24 */
    undefined4 release_zero_ref_30_candidate;  /* +0x30 */
} stage1_netif_aux_keyclass_ops_candidate;     /* size at least 0x34 */

typedef struct stage1_netif_aux_context_stats_81a60b98_candidate {
    undefined1 pad_00[0x06];                   /* +0x00 */
    ushort acquire_fail_or_reject_count_06_candidate; /* +0x06 */
} stage1_netif_aux_context_stats_81a60b98_candidate;  /* size 0x08 */
```

Notes:

- `stage1_socket_create_flag_iface_name_record_candidate[8]` lives at `0x80f99618` and carries `bcm0` through `bcm7`.
- `0x8146f660` is the pointer table for those interface-name records.
- `0x8146f690` is the runtime socket create-flag netif pointer table.
- `stage1_netif_list_head_candidate` is applied at `0x81840370`.
- `0x81802fb8` is a pointer variable to a heap netif pointer array; do not apply an embedded `stage1_netif_object_candidate *[8]` at `0x81802fb8`.
- `stage1_netif_aux_keyclass_ops_candidate` is table-indexed by key blob byte `+0x01` from base `0x81c0cf10`.
- `stage1_netif_aux_context_stats_81a60b98_candidate +0x06` fixes the overlapping `_DAT_81a60b9e` warning as a field, not a separate global.
- Route-output status values observed in this layer include `0x16`, `0x145`, `0x147`, `0x149`, and `0x163`.
- These structures describe Stage1 software state and route-output correlation, not Linux-visible MMIO state.
### Additional screenshot-derived structures

```c
typedef struct dma_allocator_global_state_81848740_candidate {
    uint32_t fpm_hw_base_kseg1_00;                         /* +0x00 */
    uint32_t fpm_buffer_size_hw_code_04;                   /* +0x04 */
    uint32_t configured_fpm_buffer_size_08;                /* +0x08 */
    void *fpm_backing_base_aligned_0c;                     /* +0x0c */
    undefined1 embedded_log_or_flags_object_10_candidate[0x18]; /* +0x10 */
    uint8_t pool_size_shift_bits_28;                       /* +0x28 */
    undefined1 pad_29[3];                                  /* +0x29 */
    uint8_t *pool_class_lookup_table_ptr_2c;               /* +0x2c */
    uint32_t max_alloc_size_30;                            /* +0x30 */
    uint32_t fpm_extra_base_offset_34_candidate;           /* +0x34 */
    uint32_t pool_size_by_token_highbits_38[4];            /* +0x38 */
    /* token_highbits_table begins immediately at +0x48; the full logical allocator object continues past this local header slice */
} dma_allocator_global_state_81848740_candidate; /* size 0x48 */

/* fap_bypass_context_candidate and host_downstream_dqm_queue_obj_candidate moved to the Host-DQM structures section after the 2026-06-21 NATP control update. */typedef struct stage1_bcm_sem_candidate {
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

### 2026-06-20/21 DQM runtime, mailbox, FPM endpoint, and IM5 IRQ structures

These structures come from the June 20/21 Ghidra export and reverse-note pass. They are carried here because they affect TC7200U OpenWrt ENET bring-up and the IRQ13 investigation.

```c
typedef volatile uint16_t vuint16_t;
typedef volatile uint32_t vuint32_t;

typedef struct dqm_runtime_state_80004000_candidate {
    uint8_t reserved_00[65];
    uint8_t runtime_enable_or_active_byte_41_candidate;
    uint8_t trace_disable_byte_42_candidate;
    uint8_t reserved_43[7];
    vuint16_t cp2_pool_class_debug_4a_candidate;
    uint8_t reserved_4c[4];
    vuint32_t trace_queue_mask_50_candidate;
    uint8_t reserved_54[20];
    vuint32_t service_mask_68_candidate;
    uint8_t reserved_6c[72];
    vuint32_t special_service_mask_b4_candidate;
    uint8_t reserved_b8[4];
    vuint32_t active_queue_mask_bc_candidate;
    vuint32_t event1800008_mask_c0_candidate;
    vuint32_t event07_pull_queue_mask_c4_candidate;
} dqm_runtime_state_80004000_candidate;

typedef struct dqm_runtime_event_state_80008000_candidate {
    vuint32_t selector_active_mask_00_candidate;
    uint8_t reserved_04[8];
    vuint32_t event1800008_pending_status_0c_candidate;
    uint8_t reserved_10[132];
    vuint32_t cp2_submit_busy_or_lock_94_candidate;
    uint8_t reserved_98[4];
    vuint32_t cp2_return_token_9c_candidate;
    uint8_t reserved_a0[128];
    vuint32_t event_fifo_pending_flags_120_candidate;
    uint8_t reserved_124[156];
    vuint32_t event07_skip_pull_mask_1c0_candidate;
} dqm_runtime_event_state_80008000_candidate;

typedef struct tc7200_fpm_endpoint_registers_candidate {
    uint32_t endpoint_800_200_candidate;
    uint32_t reserved_204_candidate;
    uint32_t endpoint_400_208_candidate;
    uint32_t reserved_20c_candidate;
    uint32_t endpoint_200_210_candidate;
    uint32_t reserved_214_candidate;
    uint32_t endpoint_100_218_candidate;
} tc7200_fpm_endpoint_registers_candidate;

typedef struct dqm_cp2_b604_selector_programming_candidate {
    undefined field_0000[0x164];
    vuint32_t selector_a_cmd_word_0164;
    vuint32_t selector_b_cmd_word_0168;
    undefined field_016c[0x54];
    vuint32_t selector_a_target_low_01c0;
    vuint32_t selector_b_target_low_01c4;
} dqm_cp2_b604_selector_programming_candidate;

typedef struct dqm_ctrl_mailbox_words_candidate {
    vuint32_t word0_command_1de0;
    vuint32_t word1_arg0_1de4;
    vuint32_t word2_arg1_1de8;
    vuint32_t word3_arg2_1dec;
} dqm_ctrl_mailbox_words_candidate;

typedef struct dqm_ctrl_mailbox_response_words_candidate {
    vuint32_t response_word0_1df0;
    vuint32_t response_word1_1df4;
    vuint32_t response_word2_1df8;
    vuint32_t response_word3_1dfc;
} dqm_ctrl_mailbox_response_words_candidate;

typedef struct dqm_selector_context_candidate {
    undefined field_00[4];
    uint8_t selector_byte_04_candidate;
    uint8_t selector_byte_05_candidate;
    uint8_t lane_or_mode_byte_06_candidate;
    uint8_t enable_or_flags_byte_07_candidate;
} dqm_selector_context_candidate;

typedef void bcm_periph_irq_handler_fn_candidate(uint32_t handler_arg);

typedef struct bcm_periph_irq_handler_entry_candidate {
    bcm_periph_irq_handler_fn_candidate *handler_00;
    uint32_t handler_arg_04;
} bcm_periph_irq_handler_entry_candidate;

typedef struct tc7200_periph_irq_im5_parent_bank_candidate {
    vuint32_t mask_or_enable_00;
    vuint32_t status_or_pending_04;
} tc7200_periph_irq_im5_parent_bank_candidate;

typedef struct bcm_periph_irq_child_bank_regs_candidate {
    vuint32_t field_00_unknown;
    vuint32_t field_04_unknown;
    vuint32_t child_mask_or_enable_08;
    vuint32_t child_status_or_pending_0c;
} bcm_periph_irq_child_bank_regs_candidate;

typedef struct tc7200_bcm34xx_serial_regs_candidate {
    vuint32_t ctrl_000;
    vuint32_t register_index_or_div_004_candidate;
    vuint32_t cmd_byte0_low_008_candidate;
    vuint32_t cmd_byte1_00c_candidate;
    vuint32_t cmd_byte2_010_candidate;
    vuint32_t cmd_byte3_high_014_candidate;
    vuint32_t config_018_candidate;
    vuint32_t config_01c_candidate;
    vuint32_t config_020_candidate;
    vuint32_t transfer_len_024;
    vuint32_t opcode_028;
    vuint32_t cmd_status_02c;
    vuint32_t read_fifo_030;
} tc7200_bcm34xx_serial_regs_candidate;

typedef struct bcm34xx_serial_access_lock_candidate {
    uint32_t recursion_count_00;
    uint32_t waiter_count_04;
    void *owner_context_08_candidate;
    stage1_bcm_sem_candidate *semaphore_0c;
} bcm34xx_serial_access_lock_candidate;
```

Application notes:

- Apply `tc7200_fpm_endpoint_registers_candidate` at `b2200200` / physical `12200200`.
- Apply `dqm_cp2_b604_selector_programming_candidate` at `b6040400`.
- Apply `dqm_ctrl_mailbox_words_candidate` at `b6001de0`.
- Apply `dqm_ctrl_mailbox_response_words_candidate` at `b6001df0`.
- Apply `dqm_selector_context_candidate *` at `80007064` and `80007068`.
- Apply `bcm_periph_irq_handler_entry_candidate[?]` conceptually at `81743214`; do not force a fixed full array length until table extent is proven.
- Apply `tc7200_periph_irq_im5_parent_bank_candidate` at `b4e00050`.
- Do not apply `tc7200_periph_irq_child_bank_candidate` globally yet; first inspect the table at `81745b14` to identify concrete child-bank bases.
- Apply `tc7200_bcm34xx_serial_regs_candidate` at `b4e00e00`.
- `bcm34xx_serial_access_lock_candidate` is provisional and belongs with the BCM34xx serial helper, not the IRQ13 clear path.

### Late 2026-06-21 IM5, NATP/GFAP, heap, and net-config structures

```c
typedef struct bcm_irq_encoded_id_decode_entry_candidate {
    uint16_t encoded_irq_id_00;
    uint8_t group_id_02;
    uint8_t child_id_03;
} bcm_irq_encoded_id_decode_entry_candidate;

typedef struct natp_gfap_manager_ops_candidate {
    natp_gfap_manager_destroy_fn_candidate *destroy_00;
    natp_gfap_manager_destroy_fn_candidate *destroy_and_free_04;
    natp_gfap_manager_runtime_init_fn_candidate *runtime_init_08;
    natp_gfap_manager_thread_main_fn *thread_main_0c;
    natp_gfap_manager_timer_release_fn_candidate *release_timer_objects_10;
} natp_gfap_manager_ops_candidate;

typedef struct natp_gfap_runtime_entry_44_candidate {
    uint8_t active_00;
    byte pad_01[0x43];
} natp_gfap_runtime_entry_44_candidate;

typedef struct natp_gfap_u32_vector_candidate {
    uint32_t *begin_00;
    uint32_t *end_04;
    uint32_t *capacity_end_08;
} natp_gfap_u32_vector_candidate;

typedef struct natp_gfap_l1_cache_entry_candidate {
    void *session_key_or_context_00;
} natp_gfap_l1_cache_entry_candidate;

typedef struct natp_gfap_l1_cache_vector_candidate {
    natp_gfap_l1_cache_entry_candidate **begin_00;
    natp_gfap_l1_cache_entry_candidate **end_04;
    natp_gfap_l1_cache_entry_candidate **capacity_end_08;
} natp_gfap_l1_cache_vector_candidate;

typedef struct stage1_heap_block_header_candidate {
    struct stage1_heap_block_header_candidate *next_00;
    struct stage1_heap_block_header_candidate *prev_04;
    uint32_t size_08;
} stage1_heap_block_header_candidate;

typedef struct stage1_heap_stats_candidate {
    uint32_t field_00_unknown;
    uint32_t free_bytes_or_total_04;
    uint32_t field_08_unknown;
    uint32_t field_0c_unknown;
    uint32_t free_block_count_10;
    uint32_t alloc_block_count_14;
} stage1_heap_stats_candidate;

typedef struct net_config_cache_entry_24_candidate {
    uint8_t active_00;
    byte pad_01[3];
    uint32_t field_04_zeroed_or_index_candidate;
    uint32_t field_08_zeroed_or_owner_candidate;
    byte object_0c[0x18];
} net_config_cache_entry_24_candidate;

typedef struct net_config_indexed_cache_entry_400_candidate {
    byte raw_00[0x400];
} net_config_indexed_cache_entry_400_candidate;
```

Apply notes:

- `bcm_periph_irq_child_bank_regs_candidate` applies at `b3001000`, `b3201000`, `b4201000`, `b3601000`, `b3401000`, and `b3e01000`.
- `bcm_irq_encoded_id_decode_entry_candidate[132]` applies at `81745b2c`.
- `natp_gfap_runtime_entry_44_candidate[64]` applies at NATP/GFAP manager offset `0x0dec`.
- `natp_gfap_l1_cache_vector_candidate` applies at NATP/GFAP manager offset `0x1eec`.
- `net_config_cache_entry_24_candidate[6]` applies at `8187bcb8`.
- `net_config_indexed_cache_entry_400_candidate[32]` applies at `8187bdb0` only after resizing the `8187bc60` block to `8187bc60..81883daf`.
- `stage1_heap_block_header_candidate` is the 12-byte header at `heap_payload_ptr - 0x0c`; `fn_heap_free_list_block_8002a280_candidate` is the corrected heap-free entry.
- `fn_natp_gfap_manager_thread_main_8053d514` is the corrected NATP/GFAP ops `thread_main_0c` target.
## Current carried status

This reference currently carries:

- 6 FPM and allocator or packet structures
- 7 Host-DQM object, MMIO, or support layouts
- 2 DQM runtime-overlay structures
- 4 DQM mailbox and selector structures
- 2 Stage1 event-slot structures
- 19 Stage1 scheduler and wake-chain structures
- 14 Stage1 signal-object, related-object, socket-object, and timeout-conversion structures
- 9 Stage1 netif, socket-create-flag, aux-context, and route-output structures
- 4 additional synchronization or semaphore structures
- 6 peripheral IRQ, handler-entry, child-bank, decode-entry, and BCM34xx MMIO structures
- 5 NATP/GFAP manager, runtime-entry, vector, and L1-cache structures
- 2 heap/free-list structures
- 2 net-config cache structures

Total current carried structures/support layouts: `82`

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
- the live export also confirms the June 16 socket-object carry set:
  - `stage1_socket_object_candidate`
  - `stage1_socket_object_vtable_candidate`
  - `stage1_signal_object_type2_ops_candidate +0x14` as `callback_14_candidate`
  - `stage1_signal_object_type2_ops_candidate +0x1c` as `setsockopt_t0_callback_1c_candidate`
- the live exports and June 19 route-output note now also confirm the netif/aux carry set:
  - `stage1_socket_build_context_candidate`
  - `stage1_socket_create_flag_iface_name_record_candidate`
  - `stage1_netif_list_head_candidate`
  - `stage1_netif_object_candidate`
  - `stage1_netif_aux_object_candidate`
  - `stage1_netif_aux_event_context_candidate`
  - `stage1_netif_aux_keyclass_ops_candidate`
  - `stage1_netif_aux_context_stats_81a60b98_candidate`
  - `0x81802fb8` remains a pointer variable to a heap netif pointer array, not an embedded array location
- the carried `setsockopt_t0_callback_1c_candidate` signature uses the semantic socket-option argument types from the dated note; current header export still degrades some callback argument types
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

- 2026-06-21 controls use `records/reverse/exports/datatype.json` plus the June 20/21 dated notes for the newest DQM, FPM endpoint, mailbox, IM5 IRQ, and BCM34xx datatype confirmation
- current worktree status shows the older `records/reverse/structures.h` path deleted, so do not treat that path as a current confirmation source until it is regenerated

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
- 2026-06-18: added the June 16 socket-object and socket-vtable layouts, refined the type2 ops `+0x14/+0x1c` slots, and raised the carried set to `47` structures
- 2026-06-19: added the June 19 socket build/create-flag, netif, aux-object, aux-context, keyclass ops, and aux-context stats layouts, and raised the carried set to `56` structures
- 2026-06-20: added the June 19 DMA/FPM allocator runtime-init note to the carried source set and refined the allocator field semantics at `0x81848740` without changing the carried structure count
- 2026-06-21: added the June 20/21 DQM runtime-overlay, FPM endpoint, DQM mailbox/selector, IM5 parent/child IRQ, handler-entry, BCM34xx serial, and BCM34xx access-lock structures, and raised the carried set to `68` structures

- 2026-06-21: added the late 2026-06-21 Host-DQM/NATP/GFAP, heap, net-config cache, corrected child-bank, and encoded IRQ decode carry, and raised the carried set to 82 structures/support layouts.

## Preservation

This file is the stable carry layer. Dated reverse logs remain preserved separately.
