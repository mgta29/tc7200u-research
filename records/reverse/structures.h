typedef unsigned char   undefined;

typedef unsigned char    bool;
typedef unsigned char    byte;
typedef unsigned int    dword;
typedef long double    longdouble;
typedef long long    longlong;
typedef unsigned char    uchar;
typedef unsigned int    uint;
typedef unsigned int    uint3;
typedef unsigned long long    ulonglong;
typedef unsigned char    undefined1;
typedef unsigned short    undefined2;
typedef unsigned int    undefined3;
typedef unsigned int    undefined4;
typedef unsigned long long    undefined6;
typedef unsigned long long    undefined8;
typedef unsigned short    ushort;
typedef struct stage1_callback_pair_candidate stage1_callback_pair_candidate, *Pstage1_callback_pair_candidate;

struct stage1_callback_pair_candidate {
    undefined4 callback_00; /* +0x00 function pointer */
    undefined4 arg_04; /* +0x04 passed as callback argument */
};

typedef struct stage1_cleanup_callback_pair_candidate stage1_cleanup_callback_pair_candidate, *Pstage1_cleanup_callback_pair_candidate;

struct stage1_cleanup_callback_pair_candidate {
    void *callback_00;
    void *callback_arg_04;
};

typedef struct stage1_id_to_value_map_entry_candidate stage1_id_to_value_map_entry_candidate, *Pstage1_id_to_value_map_entry_candidate;

struct stage1_id_to_value_map_entry_candidate {
    int key_00;
    uint value_04;
};

typedef struct stage1_iovec_candidate stage1_iovec_candidate, *Pstage1_iovec_candidate;

struct stage1_iovec_candidate {
    void *base_00;
    uint length_04;
};

typedef struct fap_bypass_context_candidate fap_bypass_context_candidate, *Pfap_bypass_context_candidate;

typedef struct host_dqm_channel_obj_candidate host_dqm_channel_obj_candidate, *Phost_dqm_channel_obj_candidate;

typedef uchar uint8_t;

typedef struct host_dqm_register_block_1800_candidate host_dqm_register_block_1800_candidate, *Phost_dqm_register_block_1800_candidate;

struct fap_bypass_context_candidate {
    undefined1 pad_00[20];
    uint enabled_queue_mask_14;
    int active_queue_index_18;
    int data_enabled_queue_last_index_1c;
    int bypass_queue_last_index_20;
    struct host_dqm_channel_obj_candidate *cmd_dqm_obj_24;
    struct host_dqm_channel_obj_candidate *active_queue_obj_28;
    struct host_dqm_channel_obj_candidate *data_queue_objs_2c[8]; /* Type 'host_dqm_channel_obj_candidate *[8]' was deleted; +0x2c guessed count */
    struct host_dqm_channel_obj_candidate *bypass_queue_objs_4c[2]; /* Type 'host_dqm_channel_obj_candidate *[2]' was deleted; +0x4c guessed count */
    uint8_t data_mode_enabled_54;
};

struct host_dqm_channel_obj_candidate {
    undefined4 *ops_table; /* +0x00 base Host-DQM ops table pointer; initialized to PTR_FUN_81826978 */
    char *name_copy_04; /* +0x04 allocated/copy of register-carried t1 object/name string */
    undefined4 queue_index_a_08; /* +0x08 initializer arg0/owner value */
    uint channel_index; /* +0x0c channel/bit index */
    uint init_flag_byte_10; /* +0x10 low byte of init flag argument */
    uint queue_or_expected_index_14; /* +0x14 initialized to 0; used in Host-DQM queue/backlog delta */
    undefined4 queue_a_initial_index_18; /* +0x18 initialized to 0 */
    void *fpm_allocator_1c; /* +0x1c DMA/FPM allocator pointer from fn_dma_fpm_allocator_get_or_init_8009xxxx_candidate */
    uint record_word_count_or_limit; /* +0x20 record/payload word count; used by 80844aa0 and 8002b998 */
    uint host_dqm_selector; /* +0x24 register-carried t0 selector: 0 UTP, 1 MSP, 2 FAP, 3 MSG_PROC, 4 MPEG_PROC, 5 PMC */
    uint host_dqm_base; /* +0x28 selector base: b800/b820/b840/b860/b8a0/b880 */
    struct host_dqm_register_block_1800_candidate *register_block; /* +0x2c Host-DQM register block pointer, normally base + 0x1800 */
    undefined4 field_30_unknown; /* +0x30 unknown */
    undefined4 *queue_b_window_1a00_34; /* +0x34 host_dqm_base + channel_index*0x10 + 0x1a00 */
    undefined4 *record_words; /* +0x38 record/payload word buffer pointer; read by 80844aa0 and copied by 8002b998 */
    undefined4 field_3c_unknown; /* +0x3c unknown */
    undefined4 field_40_unknown; /* +0x40 unknown */
    uint *queue_index_or_cursor_ptr_44; /* +0x44 pointer to queue index/cursor used in queue/backlog delta */
    undefined4 field_48_unknown; /* +0x48 zeroed by base initializer */
    undefined4 field_4c_unknown; /* +0x4c zeroed by base initializer */
    uint ready_copy_count_50; /* +0x50 successful ready-payload copy counter */
    undefined4 field_54_unknown; /* +0x54 zeroed by base initializer */
    uint queue_delta_high_water_58; /* +0x58 queue/backlog delta high-water statistic */
};

struct host_dqm_register_block_1800_candidate {
    byte pad_00[20]; /* +0x00..+0x13 unknown/padding before observed channel registers */
    uint reg14_channel_status_or_current; /* +0x14 channel bit register; set by 8002b7e0, cleared by 80844a78 */
    uint reg18_channel_enable_or_pending; /* +0x18 channel bit register; set by 8002b7e0 */
    undefined4 reg1c_queue_bit_or_ack; /* +0x1c unknown register */
    uint reg20_channel_status_or_busy; /* +0x20 channel status/busy/ready bit register */
};

typedef struct host_downstream_dqm_queue_obj_candidate host_downstream_dqm_queue_obj_candidate, *Phost_downstream_dqm_queue_obj_candidate;

struct host_downstream_dqm_queue_obj_candidate {
    struct host_dqm_channel_obj_candidate base; /* +0x00..+0x5b base Host-DQM channel object */
    byte active_flag_5c; /* +0x5c software active flag; set by 80845aec, cleared by 80845af8 */
    byte pad_5d[3]; /* +0x5d alignment padding */
    undefined4 field_60_unknown; /* +0x60 cleared in fn_host_downstream_dqm_queue_obj_init_80845a7c_candidate */
    undefined4 field_64_unknown; /* +0x64 cleared in fn_host_downstream_dqm_queue_obj_init_80845a7c_candidate */
    void *fpm_allocator_68; /* +0x68 DMA/FPM allocator pointer stored by downstream queue init */
};

typedef struct dma_allocator_global_state_81848740_candidate dma_allocator_global_state_81848740_candidate, *Pdma_allocator_global_state_81848740_candidate;

struct dma_allocator_global_state_81848740_candidate {
    undefined4 field_00;
    undefined4 header_field_04;
    uint default_pool_size_08;
    void *backing_fpm_pool_base_0c;
    undefined1 pad_10[24];
    uint pool_shift_28;
    void *pool_class_table_ptr_2c;
    uint max_or_largest_request_30;
    uint timer_counter_or_state_34;
    undefined1 pad_38[8];
    undefined4 default_pool_sizes_copy_40;
    undefined4 high_bits_table_48;
};

typedef struct tc7200_fpm_allocator tc7200_fpm_allocator, *Ptc7200_fpm_allocator;

typedef uint uint32_t;

struct tc7200_fpm_allocator {
    uint32_t fpm_hw_base_kseg1; /* +0x00 */
    uint32_t board_or_buffer_class; /* +0x04 */
    uint32_t largest_default_pool_size; /* +0x08 */
    uint32_t fpm_backing_base_aligned; /* +0x0c */
    uint8_t embedded_flag_log_object[24]; /* +0x10..+0x27 */
    uint8_t pool_size_shift_bits; /* +0x28 */
    uint8_t pad_29[3]; /* +0x29..+0x2b */
    uint32_t pool_class_lookup_table_ptr; /* +0x2c */
    uint32_t max_largest_request_state; /* +0x30 */
    uint32_t fpm_extra_base_offset_or_headroom_candidate; /* +0x34, Extra base/headroom offset used in FPM token-to-buffer translation.    Used as:      data_addr = allocator->fpm_backing_base_aligned                + fpm_extra_base_offset_or_headroom_candidate                + token_index * 0x100 */
    uint32_t pool_size_table[4]; /* +0x38 */
    uint32_t token_highbits_table[32768]; /* +0x48 */
};

typedef struct tc7200_fpm_packet_allocator tc7200_fpm_packet_allocator, *Ptc7200_fpm_packet_allocator;

struct tc7200_fpm_packet_allocator {
    uint8_t embedded_flag_log_object[24]; /* +0x00..+0x17 */
    uint32_t packet_header_slot_size; /* +0x18 */
    uint32_t packet_header_arena_aligned; /* +0x1c */
    uint32_t main_fpm_allocator_ptr; /* +0x20 */
};

typedef struct tc7200_fpm_packet_header tc7200_fpm_packet_header, *Ptc7200_fpm_packet_header;

typedef struct tc7200_fpm_packet_inner_header tc7200_fpm_packet_inner_header, *Ptc7200_fpm_packet_inner_header;

typedef ushort uint16_t;

struct tc7200_fpm_packet_inner_header {
    uint32_t data_addr; /* +0x00 */
    uint32_t requested_payload_len; /* +0x04 */
    uint8_t unknown_08[16]; /* +0x08..+0x1f */
    void *ptr_or_list_18; /* +0x18 */
    uint8_t unknown_1c[4]; /* +0x1c..+0x1f */
    uint16_t flags_20; /* +0x20 */
    uint8_t unknown_22[10]; /* +0x22..+0x2b */
    uint32_t fpm_extra_base_offset_saved; /* +0x2c */
};

struct tc7200_fpm_packet_header {
    void *free_callback; /* +0x00 */
    struct tc7200_fpm_packet_inner_header *inner_header; /* +0x04 */
    void *list_or_inner_ptr_a; /* +0x08 */
    uint32_t active_or_refcount; /* +0x0c */
    uint8_t unknown_10[16]; /* +0x10..+0x1f */
    struct tc7200_fpm_packet_inner_header embedded_inner; /* +0x20..+0x4f */
    uint8_t unknown_50[144]; /* +0x50..+0xdf */
};

typedef struct stage1_context_candidate stage1_context_candidate, *Pstage1_context_candidate;

typedef struct stage1_readyq_node_candidate stage1_readyq_node_candidate, *Pstage1_readyq_node_candidate;

typedef struct stage1_owned_wait_object_candidate stage1_owned_wait_object_candidate, *Pstage1_owned_wait_object_candidate;

typedef struct stage1_event_wait_condition_candidate stage1_event_wait_condition_candidate, *Pstage1_event_wait_condition_candidate;

typedef struct stage1_timeout_object_candidate stage1_timeout_object_candidate, *Pstage1_timeout_object_candidate;

typedef struct stage1_thread_record_candidate stage1_thread_record_candidate, *Pstage1_thread_record_candidate;

typedef struct stage1_timeout_queue_candidate stage1_timeout_queue_candidate, *Pstage1_timeout_queue_candidate;

typedef struct stage1_condition_object_candidate stage1_condition_object_candidate, *Pstage1_condition_object_candidate;

typedef struct stage1_thread_cleanup_handler_candidate stage1_thread_cleanup_handler_candidate, *Pstage1_thread_cleanup_handler_candidate;

typedef struct stage1_thread_join_condition_candidate stage1_thread_join_condition_candidate, *Pstage1_thread_join_condition_candidate;

struct stage1_event_wait_condition_candidate {
    uint require_all_mask_00; /*  +0x00 if nonzero, all these bits must be present */
    uint require_any_mask_04; /* +0x04 wake if any of these bits are present */
    uint observed_pending_mask_08; /* +0x08 receives slot pending mask at wake */
    uint clear_slot_on_wake_0c; /* +0x0c if nonzero, clears slot pending_mask_00 after wake */
};

struct stage1_readyq_node_candidate {
    struct stage1_readyq_node_candidate *next_00;
    struct stage1_readyq_node_candidate *prev_04;
};

struct stage1_timeout_object_candidate {
    struct stage1_timeout_object_candidate *next_00;
    struct stage1_timeout_object_candidate *prev_04;
    struct stage1_timeout_queue_candidate *timeout_queue_08_candidate;
    undefined4 callback_0c_candidate;
    undefined4 callback_arg_10_candidate;
    undefined4 field_14_candidate;
    uint deadline_hi_18_candidate; /* +0x18, incoming a2 */
    uint deadline_lo_1c_candidate; /* +0x1c, incoming a3 */
    uint interval_hi_20_candidate; /* +0x20, incoming t0 */
    uint interval_lo_24_candidate; /* +0x24, incoming t1 */
    uint active_or_registered_28_candidate;
    struct stage1_context_candidate *owner_context_2c_candidate;
};

struct stage1_context_candidate {
    struct stage1_readyq_node_candidate header_node_00_candidate;
    undefined4 context_seed_or_vector_end_ptr_08_candidate;
    uint context_header_state_0c_candidate;
    undefined4 context_switch_state_10_candidate;
    undefined4 context_switch_state_14_candidate;
    struct stage1_readyq_node_candidate readyq_node_18; /* +0x18 embedded circular list next */
    uint readyq_bucket_20; /* +0x20 readyq bucket / priority index */
    uint scheduler_timeslice_flag_24_candidate;
    struct stage1_readyq_node_candidate **owner_list_head_ref_28;
    uint scheduler_callback_block_count_2c_candidate; /* +0x2c must be 0 to run pending callback */
    uint pending_callback_flag_30; /* +0x30 nonzero means callback pending */
    undefined4 pending_callback_arg_34; /* +0x34 passed to global callback handler */
    uint owned_pi_object_count_38_candidate;
    struct stage1_owned_wait_object_candidate *owned_pi_object_list_head_3c_candidate;
    struct stage1_owned_wait_object_candidate *current_owned_wait_object_acquire_candidate;
    undefined4 field_44;
    uint base_readyq_bucket_48_candidate;
    uint priority_inheritance_active_4c_candidate;
    uint context_flags_50; /* context_flags_50 known bits/states:      bit0 / 0x01 = non-ready / blocked / removed from readyq.                    Set by {@symbol fn_stage1_current_context_mark_nonready_remove_readyq_80e960d0}.                    Cleared by {@symbol fn_stage1_context_make_runnable_80e96154}.       bit1 / 0x02 = low non-runnable-related bit.                    Cleared together with bit0 by                    {@symbol fn_stage1_context_make_runnable_80e96154}                    through flags &= ~0x3.                    Setter not found yet.       value 0x10 = terminal / dead / cleanup-marked state.                   Set by {@symbol fn_stage1_current_context_cleanup_mark_dead_80e96428}.                   Distinct from normal blocked state. */
    uint context_activation_hold_count_54_candidate;
    undefined4 *field_58;
    struct stage1_event_wait_condition_candidate *wait_condition_5c;
    ushort context_trace_id_60;
    undefined1 pad_62[6];
    struct stage1_timeout_object_candidate timeout_object_68_candidate; /* // observed through abort-wait helper: // +0x70 = timeout_list_object_68_candidate +0x08, passed as arg0 to FUN_80e940f4 // +0x90 = timeout_list_object_68_candidate +0x28, linked/active flag or list state */
    uint wait_state_98;
    uint resume_status_9c;
    undefined4 extended_zero_area_a0_candidate[3];
    struct stage1_thread_record_candidate *thread_record_ac_candidate;
    undefined4 extended_zero_area_b0_candidate[12];
    struct stage1_cleanup_callback_pair_candidate cleanup_callback_pairs_e0_candidate[8];
    undefined4 field_120_candidate;
    struct stage1_context_candidate *next_registered_context_124_candidate;
};

struct stage1_thread_join_condition_candidate {
    struct stage1_owned_wait_object_candidate *associated_owned_wait_object_00_candidate;
    struct stage1_readyq_node_candidate *waitq_04;
    void **tsd_value_slots_base_08_candidate;
};

struct stage1_thread_record_candidate {
    uint flags_00;
    uint thread_id_or_handle_04;
    struct stage1_context_candidate *context_08;
    uint attr_flags_0c;
    uint attr_priority_or_class_10;
    uint attr_stack_top_or_end_14;
    uint attr_stack_size_18;
    uint exit_value_or_status_1c_candidate;
    pointer entry_function_20;
    pointer entry_arg_24;
    char name_28[16];
    uint field_38;
    struct stage1_condition_object_candidate *join_condition_3c_candidate;
    pointer allocation_base_or_stack_base_40;
    struct stage1_thread_cleanup_handler_candidate *cleanup_handler_head_44_candidate;
    uint pending_signal_or_work_mask_48_candidate;
    uint blocked_signal_mask_or_wait_mask_4c_candidate;
    struct stage1_context_candidate embedded_context_50;
    struct stage1_thread_join_condition_candidate embedded_join_condition_178;
};

struct stage1_condition_object_candidate {
    struct stage1_owned_wait_object_candidate *associated_owned_wait_object_00_candidate;
    struct stage1_readyq_node_candidate *waitq_04;
    uint field_08;
};

struct stage1_thread_cleanup_handler_candidate {
    struct stage1_thread_cleanup_handler_candidate *next_00;
    void (*callback_04)(uint);
    uint arg_08;
};

struct stage1_timeout_queue_candidate {
    struct stage1_timeout_object_candidate *head_00;
    undefined4 field_04_candidate;
    uint current_time_hi_08_candidate;
    uint current_time_lo_0c_candidate;
};

struct stage1_owned_wait_object_candidate {
    byte active_or_locked_00;
    byte pad_01[3];
    struct stage1_context_candidate *owner_context_04;
    struct stage1_readyq_node_candidate *waitq_08;
    struct stage1_owned_wait_object_candidate *next_owned_pi_object_0c_candidate;
    uint ownership_pi_mode_10;
};

typedef struct stage1_context_cleanup_callback_pair_candidate stage1_context_cleanup_callback_pair_candidate, *Pstage1_context_cleanup_callback_pair_candidate;

struct stage1_context_cleanup_callback_pair_candidate {
    void (*callback_00)(undefined4);
    undefined4 callback_arg_04;
};

typedef struct stage1_post_message_candidate stage1_post_message_candidate, *Pstage1_post_message_candidate;

struct stage1_post_message_candidate {
    int msg_type_00;
    uint target_index_04;
    undefined4 payload_08;
};

typedef struct stage1_post_queue_node_candidate stage1_post_queue_node_candidate, *Pstage1_post_queue_node_candidate;

struct stage1_post_queue_node_candidate {
    struct stage1_post_queue_node_candidate *next_00;
    uint target_index_04;
    undefined4 post_arg_or_source_08;
    undefined4 payload_0c;
};

typedef struct stage1_post_target_slot_candidate stage1_post_target_slot_candidate, *Pstage1_post_target_slot_candidate;

struct stage1_post_target_slot_candidate {
    undefined4 field_00;
    uint flags_04;
    undefined4 field_08;
    struct stage1_post_queue_node_candidate *tail_0c;
};

typedef struct stage1_readyq_table_candidate stage1_readyq_table_candidate, *Pstage1_readyq_table_candidate;

struct stage1_readyq_table_candidate {
    uint nonempty_bucket_bitmap_00;
    struct stage1_readyq_node_candidate *bucket_heads_04[32];
};

typedef struct stage1_scheduler_unlock_callback_record_candidate stage1_scheduler_unlock_callback_record_candidate, *Pstage1_scheduler_unlock_callback_record_candidate;

struct stage1_scheduler_unlock_callback_record_candidate {
    undefined4 callback_arg0_00;
    undefined4 field_04;
    undefined4 field_08;
    undefined4 callback_0c; /* +0x0c function pointer */
    undefined4 callback_arg2_10;
    undefined4 pending_count_or_arg1_14;
    struct stage1_scheduler_unlock_callback_record_candidate *next_18;
};

typedef struct stage1_related_object_pool_a_entry_candidate stage1_related_object_pool_a_entry_candidate, *Pstage1_related_object_pool_a_entry_candidate;

typedef struct stage1_related_object_pool_b_entry_candidate stage1_related_object_pool_b_entry_candidate, *Pstage1_related_object_pool_b_entry_candidate;

typedef struct stage1_signal_object_candidate stage1_signal_object_candidate, *Pstage1_signal_object_candidate;

typedef struct stage1_signal_ops_or_class_candidate stage1_signal_ops_or_class_candidate, *Pstage1_signal_ops_or_class_candidate;

typedef struct stage1_signal_iovec_io_request_candidate stage1_signal_iovec_io_request_candidate, *Pstage1_signal_iovec_io_request_candidate;

typedef struct stage1_signal_object_type2_ops_candidate stage1_signal_object_type2_ops_candidate, *Pstage1_signal_object_type2_ops_candidate;

struct stage1_signal_object_candidate {
    uint flags_00;
    ushort refcount_04;
    ushort type_or_mode_06_candidate;
    uint flags_08_candidate;
    struct stage1_signal_ops_or_class_candidate *ops_or_class_0c;
    undefined4 field_10;
    undefined4 field_14;
    struct stage1_signal_object_type2_ops_candidate *type2_ops_18_candidate;
    struct stage1_related_object_pool_b_entry_candidate *provider_or_related_entry_1c_candidate;
};

struct stage1_related_object_pool_a_entry_candidate {
    undefined1 pad_00[8];
    uint lock_flags_08_candidate;
    undefined1 pad_0c[8];
    undefined4 create_or_init_callback_14;
    undefined4 field_18;
    int (*callback_1c_candidate)(struct stage1_related_object_pool_b_entry_candidate *, void *, void *);
    undefined1 pad_20[12];
    int (*callback_2c_candidate)(struct stage1_related_object_pool_b_entry_candidate *, void *, void *, struct stage1_signal_object_candidate *);
    int (*path_context_callback_30_candidate)(struct stage1_related_object_pool_b_entry_candidate *, void *, char *, void **);
    int (*callback_34_candidate)(struct stage1_related_object_pool_b_entry_candidate *, void *, void *, uint);
    undefined1 pad_38[8];
};

struct stage1_signal_object_type2_ops_candidate {
    int (*callback_00_candidate)(struct stage1_signal_object_candidate *, char *, int *);
    int (*callback_04_candidate)(struct stage1_signal_object_candidate *, char *, int *);
    int (*clone_callback_08)(struct stage1_signal_object_candidate *, struct stage1_signal_object_candidate *, undefined4, undefined4);
    int (*callback_0c_candidate)(struct stage1_signal_object_candidate *, char *);
    int (*callback_10_candidate)(struct stage1_signal_object_candidate *, char *, int *, uint);
    int (*callback_14_candidate)(struct stage1_signal_object_candidate *, char *);
    int (*callback_18_t0_candidate)(struct stage1_signal_object_candidate *, char *, int *, undefined4);
    int (*setsockopt_t0_callback_1c_candidate)(struct stage1_signal_object_candidate *, char *, int *, undefined4);
    int (*callback_20_out_candidate)(struct stage1_signal_object_candidate *, void *, void *, int *);
    int (*callback_24_out_candidate)(struct stage1_signal_object_candidate *, undefined1 *, undefined4, int *);
};

struct stage1_related_object_pool_b_entry_candidate {
    undefined1 pad_00[20];
    struct stage1_related_object_pool_a_entry_candidate *pool_a_entry_14_candidate;
    undefined1 pad_18[8];
};

struct stage1_signal_iovec_io_request_candidate {
    struct stage1_iovec_candidate *iov_00;
    int iov_count_04;
    undefined4 field_08;
    uint remaining_or_total_len_0c;
    uint field_10_zero_init;
    uint mode_index_14;
};

struct stage1_signal_ops_or_class_candidate {
    int (*io_mode1_callback_00_candidate)(struct stage1_signal_object_candidate *, struct stage1_signal_iovec_io_request_candidate *);
    int (*io_mode2_callback_04_candidate)(struct stage1_signal_object_candidate *, struct stage1_signal_iovec_io_request_candidate *);
    int (*callback_08_candidate)(struct stage1_signal_object_candidate *, void **, void *);
    int (*callback_0c_candidate)(struct stage1_signal_object_candidate *, void *, void *);
    int (*test_callback_10)(struct stage1_signal_object_candidate *, uint);
    int (*callback_14_candidate)(struct stage1_signal_object_candidate *, uint);
    int (*final_release_18)(struct stage1_signal_object_candidate *);
    int (*callback_1c_candidate)(struct stage1_signal_object_candidate *, void *);
};

typedef struct stage1_signal_handler_entry_candidate stage1_signal_handler_entry_candidate, *Pstage1_signal_handler_entry_candidate;

struct stage1_signal_handler_entry_candidate {
    uint additional_mask_00_candidate;
    uint flags_04_candidate;
    undefined4 handler_or_mode_08_candidate;
    void *queued_record_head_0c_candidate;
};

typedef struct stage1_signal_object_provider_entry_candidate stage1_signal_object_provider_entry_candidate, *Pstage1_signal_object_provider_entry_candidate;

struct stage1_signal_object_provider_entry_candidate {
    undefined4 field_00_candidate;
    uint flags_or_mode_04_candidate; /* +0x04 copied into signal_object +0x08 on success */
    undefined1 pad_08[16];
    undefined4 create_callback_18; /* +0x18 call target, receives new object in t0 */
    undefined1 pad_1c[4];
};

typedef struct stage1_signal_object_type2_callback_20_request_candidate stage1_signal_object_type2_callback_20_request_candidate, *Pstage1_signal_object_type2_callback_20_request_candidate;

struct stage1_signal_object_type2_callback_20_request_candidate {
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
};

typedef struct stage1_signal_object_type2_callback_24_request_candidate stage1_signal_object_type2_callback_24_request_candidate, *Pstage1_signal_object_type2_callback_24_request_candidate;

struct stage1_signal_object_type2_callback_24_request_candidate {
    undefined4 field_00_from_t0_candidate;
    undefined4 field_04_from_optional_aux_deref_candidate;
    undefined4 *payload_pair_ptr_08_candidate; /* +0x08 -> stack +0x20 */
    undefined4 field_0c_const1_candidate;
    undefined4 field_10_zero_candidate;
    undefined4 field_14_candidate; /* +0x14 not initialized here */
    undefined4 field_18_candidate;
    undefined4 field_1c_candidate;
    undefined4 payload_arg0_20_candidate;
    undefined4 payload_arg1_24_candidate;
};

typedef struct stage1_signal_select_state_candidate stage1_signal_select_state_candidate, *Pstage1_signal_select_state_candidate;

struct stage1_signal_select_state_candidate {
    undefined1 pad_00[72];
    uint pending_signal_or_work_mask_48_candidate;
    uint blocked_signal_mask_or_wait_mask_4c_candidate;
};

typedef struct stage1_thread_create_attr_candidate stage1_thread_create_attr_candidate, *Pstage1_thread_create_attr_candidate;

struct stage1_thread_create_attr_candidate {
    uint flags_00;
    uint priority_or_class_04;
    uint stack_top_or_end_08;
    uint stack_size_0c;
};

typedef struct stage1_timeout_scale_table_candidate stage1_timeout_scale_table_candidate, *Pstage1_timeout_scale_table_candidate;

struct stage1_timeout_scale_table_candidate {
    uint word_00;
    uint word_04;
    uint word_08;
    uint word_0c;
    uint word_10;
    uint word_14;
    uint word_18;
    uint word_1c;
};

typedef struct stage1_timeval32_candidate stage1_timeval32_candidate, *Pstage1_timeval32_candidate;

struct stage1_timeval32_candidate {
    int tv_sec_00;
    int tv_usec_04;
};

typedef struct stage1_bcm_sem_candidate stage1_bcm_sem_candidate, *Pstage1_bcm_sem_candidate;

struct stage1_bcm_sem_candidate {
    undefined4 count_or_state; /* +0x00 initialized from param_2 */
    undefined4 wait_queue_or_list; /* +0x04 wait queue/list head pointer */
};

typedef struct stage1_event_slot_candidate stage1_event_slot_candidate, *Pstage1_event_slot_candidate;

struct stage1_event_slot_candidate {
    uint pending_mask_00; /* +0x00 accumulated/raised event bits */
    struct stage1_readyq_node_candidate *waitq_04; /* +0x04 wait queue/list head */
};

typedef struct stage1_guarded_context_lock_candidate stage1_guarded_context_lock_candidate, *Pstage1_guarded_context_lock_candidate;

typedef struct stage1_semaphore_candidate stage1_semaphore_candidate, *Pstage1_semaphore_candidate;

struct stage1_guarded_context_lock_candidate {
    int refcount; /* +0x00 active holder/reference count */
    int waiter_count; /* +0x04 waiters blocked on semaphore */
    void *owner_context; /* +0x08 current boot/context token */
    struct stage1_semaphore_candidate *semaphore;
};

struct stage1_semaphore_candidate {
    int count; /* +0x00 semaphore count */
    struct stage1_readyq_node_candidate *waitq_04; /* +0x04 queue/list field */
};

typedef struct stage1_socket_object_candidate stage1_socket_object_candidate, *Pstage1_socket_object_candidate;

typedef struct stage1_socket_object_vtable_candidate stage1_socket_object_vtable_candidate, *Pstage1_socket_object_vtable_candidate;

struct stage1_socket_object_candidate {
    struct stage1_socket_object_vtable_candidate *vtable_00;
    uint signal_index_or_socket_handle_04;
    undefined4 field_08;
    uint create_flags_or_t0_0c_candidate;
    undefined4 boot_context_base_10_candidate;
};

struct stage1_socket_object_vtable_candidate {
    undefined4 field_00;
    undefined4 field_04;
    undefined4 field_08;
    undefined4 field_0c;
    void (*close_or_reset_10_candidate)(struct stage1_socket_object_candidate *);
    undefined1 pad_14[36];
    int (*getsockopt_t0_method_38_candidate)(struct stage1_socket_object_candidate *, int, int, void *);
};

