#@category TC7200
#
# Build the current carried TC7200 reverse-engineered structures in Ghidra.
# Default target category is /<current-program-name>/custom, which matches
# the observed image.raw/custom layout when run on image.raw.

from ghidra.program.model.data import ArrayDataType
from ghidra.program.model.data import ByteDataType
from ghidra.program.model.data import CharDataType
from ghidra.program.model.data import DataTypeConflictHandler
from ghidra.program.model.data import IntegerDataType
from ghidra.program.model.data import PointerDataType
from ghidra.program.model.data import StructureDataType
from ghidra.program.model.data import Undefined1DataType
from ghidra.program.model.data import Undefined4DataType
from ghidra.program.model.data import UnsignedIntegerDataType
from ghidra.program.model.data import UnsignedShortDataType
from ghidra.program.model.data import VoidDataType


def ensure_child_category(parent, name):
    child = parent.getCategory(name)
    if child is None:
        child = parent.createCategory(name)
    return child


def ensure_custom_category(dtm, program_name):
    root = dtm.getRootCategory()
    program_cat = ensure_child_category(root, program_name)
    custom_cat = ensure_child_category(program_cat, "custom")
    return custom_cat.getCategoryPath()


def arr(data_type, count):
    return ArrayDataType(data_type, count, data_type.getLength())


def ptr(dtm, data_type):
    return PointerDataType(data_type, 4, dtm)


def add_field(structure, offset, data_type, name, comment=None):
    structure.replaceAtOffset(offset, data_type, data_type.getLength(), name, comment)


def build_structures(category_path, dtm):
    u32 = UnsignedIntegerDataType.dataType
    s32 = IntegerDataType.dataType
    u16 = UnsignedShortDataType.dataType
    u8 = ByteDataType.dataType
    ch = CharDataType.dataType
    undef1 = Undefined1DataType.dataType
    undef4 = Undefined4DataType.dataType
    void_dt = VoidDataType.dataType

    structs = {}

    structs["tc7200_fpm_allocator"] = StructureDataType(category_path, "tc7200_fpm_allocator", 0x20048)
    add_field(structs["tc7200_fpm_allocator"], 0x00, u32, "fpm_hw_base_kseg1")
    add_field(structs["tc7200_fpm_allocator"], 0x04, u32, "board_or_buffer_class")
    add_field(structs["tc7200_fpm_allocator"], 0x08, u32, "largest_default_pool_size")
    add_field(structs["tc7200_fpm_allocator"], 0x0c, u32, "fpm_backing_base_aligned")
    add_field(structs["tc7200_fpm_allocator"], 0x10, arr(u8, 0x18), "embedded_flag_log_object")
    add_field(structs["tc7200_fpm_allocator"], 0x28, u8, "pool_size_shift_bits")
    add_field(structs["tc7200_fpm_allocator"], 0x29, arr(u8, 3), "pad_29")
    add_field(structs["tc7200_fpm_allocator"], 0x2c, u32, "pool_class_lookup_table_ptr")
    add_field(structs["tc7200_fpm_allocator"], 0x30, u32, "max_largest_request_state")
    add_field(structs["tc7200_fpm_allocator"], 0x34, u32, "fpm_extra_base_offset_or_headroom_candidate")
    add_field(structs["tc7200_fpm_allocator"], 0x38, arr(u32, 4), "pool_size_table")
    add_field(structs["tc7200_fpm_allocator"], 0x48, arr(u32, 32768), "token_highbits_table")

    structs["tc7200_fpm_packet_allocator"] = StructureDataType(category_path, "tc7200_fpm_packet_allocator", 0x24)
    add_field(structs["tc7200_fpm_packet_allocator"], 0x00, arr(u8, 0x18), "embedded_flag_log_object")
    add_field(structs["tc7200_fpm_packet_allocator"], 0x18, u32, "packet_header_slot_size")
    add_field(structs["tc7200_fpm_packet_allocator"], 0x1c, u32, "packet_header_arena_aligned")
    add_field(structs["tc7200_fpm_packet_allocator"], 0x20, u32, "main_fpm_allocator_ptr")

    structs["tc7200_fpm_packet_inner_header"] = StructureDataType(category_path, "tc7200_fpm_packet_inner_header", 0x30)
    add_field(structs["tc7200_fpm_packet_inner_header"], 0x00, u32, "data_addr")
    add_field(structs["tc7200_fpm_packet_inner_header"], 0x04, u32, "requested_payload_len")
    add_field(structs["tc7200_fpm_packet_inner_header"], 0x08, arr(u8, 0x10), "unknown_08")
    add_field(structs["tc7200_fpm_packet_inner_header"], 0x18, ptr(dtm, void_dt), "ptr_or_list_18")
    add_field(structs["tc7200_fpm_packet_inner_header"], 0x1c, arr(u8, 4), "unknown_1c")
    add_field(structs["tc7200_fpm_packet_inner_header"], 0x20, u16, "flags_20")
    add_field(structs["tc7200_fpm_packet_inner_header"], 0x22, arr(u8, 0x0a), "unknown_22")
    add_field(structs["tc7200_fpm_packet_inner_header"], 0x2c, u32, "fpm_extra_base_offset_saved")

    structs["tc7200_fpm_packet_header"] = StructureDataType(category_path, "tc7200_fpm_packet_header", 0xe0)
    add_field(structs["tc7200_fpm_packet_header"], 0x00, ptr(dtm, void_dt), "free_callback")
    add_field(structs["tc7200_fpm_packet_header"], 0x04, ptr(dtm, structs["tc7200_fpm_packet_inner_header"]), "inner_header")
    add_field(structs["tc7200_fpm_packet_header"], 0x08, ptr(dtm, void_dt), "list_or_inner_ptr_a")
    add_field(structs["tc7200_fpm_packet_header"], 0x0c, u32, "active_or_refcount")
    add_field(structs["tc7200_fpm_packet_header"], 0x10, arr(u8, 0x10), "unknown_10")
    add_field(structs["tc7200_fpm_packet_header"], 0x20, structs["tc7200_fpm_packet_inner_header"], "embedded_inner")
    add_field(structs["tc7200_fpm_packet_header"], 0x50, arr(u8, 0x90), "unknown_50")

    structs["host_dqm_register_block_1800_candidate"] = StructureDataType(category_path, "host_dqm_register_block_1800_candidate", 0x24)
    add_field(structs["host_dqm_register_block_1800_candidate"], 0x00, arr(u8, 0x14), "pad_00")
    add_field(structs["host_dqm_register_block_1800_candidate"], 0x14, u32, "reg14_status_current_bits")
    add_field(structs["host_dqm_register_block_1800_candidate"], 0x18, u32, "reg18_enabled_pending_mask")
    add_field(structs["host_dqm_register_block_1800_candidate"], 0x1c, u32, "reg1c_queue_bit_or_ack")
    add_field(structs["host_dqm_register_block_1800_candidate"], 0x20, u32, "reg20_channel_status_or_busy")

    structs["host_dqm_channel_obj_candidate"] = StructureDataType(category_path, "host_dqm_channel_obj_candidate", 0x5c)
    add_field(structs["host_dqm_channel_obj_candidate"], 0x00, ptr(dtm, undef4), "ops_table")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x04, ptr(dtm, ch), "name_copy_04")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x08, u32, "queue_index_a_08")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x0c, u32, "channel_index")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x10, u32, "init_flag_byte_10")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x14, u32, "queue_or_expected_index_14")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x18, u32, "queue_a_initial_index_18")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x1c, ptr(dtm, void_dt), "fpm_allocator_1c")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x20, u32, "record_word_count_or_limit")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x24, u32, "host_dqm_selector")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x28, u32, "host_dqm_base")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x2c, ptr(dtm, structs["host_dqm_register_block_1800_candidate"]), "register_block")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x30, ptr(dtm, undef4), "queue_a_window_1a00_30")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x34, ptr(dtm, undef4), "queue_b_window_1a00_34")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x38, ptr(dtm, undef4), "record_words")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x3c, ptr(dtm, undef4), "queue_a_window_1c00_3c")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x40, ptr(dtm, u32), "queue_a_cursor_or_index_ptr_40")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x44, ptr(dtm, u32), "queue_index_or_cursor_ptr_44")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x48, undef4, "field_48_unknown")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x4c, undef4, "field_4c_unknown")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x50, u32, "ready_copy_count_50")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x54, undef4, "field_54_unknown")
    add_field(structs["host_dqm_channel_obj_candidate"], 0x58, u32, "queue_delta_high_water_58")

    structs["stage1_event_slot_candidate"] = StructureDataType(category_path, "stage1_event_slot_candidate", 0x08)
    add_field(structs["stage1_event_slot_candidate"], 0x00, u32, "pending_mask_00")
    add_field(structs["stage1_event_slot_candidate"], 0x04, s32, "waitq_04")

    structs["stage1_event_wait_condition_candidate"] = StructureDataType(category_path, "stage1_event_wait_condition_candidate", 0x10)
    add_field(structs["stage1_event_wait_condition_candidate"], 0x00, u32, "require_all_mask_00")
    add_field(structs["stage1_event_wait_condition_candidate"], 0x04, u32, "require_any_mask_04")
    add_field(structs["stage1_event_wait_condition_candidate"], 0x08, u32, "observed_pending_mask_08")
    add_field(structs["stage1_event_wait_condition_candidate"], 0x0c, u32, "clear_slot_on_wake_0c")

    structs["stage1_readyq_node_candidate"] = StructureDataType(category_path, "stage1_readyq_node_candidate", 0x08)
    add_field(structs["stage1_readyq_node_candidate"], 0x00, ptr(dtm, structs["stage1_readyq_node_candidate"]), "next_00")
    add_field(structs["stage1_readyq_node_candidate"], 0x04, ptr(dtm, structs["stage1_readyq_node_candidate"]), "prev_04")

    structs["stage1_readyq_table_candidate"] = StructureDataType(category_path, "stage1_readyq_table_candidate", 0x84)
    add_field(structs["stage1_readyq_table_candidate"], 0x00, u32, "nonempty_bucket_bitmap_00")
    add_field(structs["stage1_readyq_table_candidate"], 0x04, arr(ptr(dtm, structs["stage1_readyq_node_candidate"]), 32), "bucket_heads_04")

    structs["stage1_callback_pair_candidate"] = StructureDataType(category_path, "stage1_callback_pair_candidate", 0x08)
    add_field(structs["stage1_callback_pair_candidate"], 0x00, undef4, "callback_00")
    add_field(structs["stage1_callback_pair_candidate"], 0x04, undef4, "arg_04")

    structs["stage1_cleanup_callback_pair_candidate"] = StructureDataType(category_path, "stage1_cleanup_callback_pair_candidate", 0x08)
    add_field(structs["stage1_cleanup_callback_pair_candidate"], 0x00, ptr(dtm, void_dt), "callback_00")
    add_field(structs["stage1_cleanup_callback_pair_candidate"], 0x04, ptr(dtm, void_dt), "callback_arg_04")

    structs["stage1_signal_select_state_candidate"] = StructureDataType(category_path, "stage1_signal_select_state_candidate", 0x50)
    add_field(structs["stage1_signal_select_state_candidate"], 0x00, arr(undef1, 0x48), "pad_00")
    add_field(structs["stage1_signal_select_state_candidate"], 0x48, u32, "pending_signal_or_work_mask_48_candidate")
    add_field(structs["stage1_signal_select_state_candidate"], 0x4c, u32, "blocked_signal_mask_or_wait_mask_4c_candidate")

    structs["stage1_thread_create_attr_candidate"] = StructureDataType(category_path, "stage1_thread_create_attr_candidate", 0x10)
    add_field(structs["stage1_thread_create_attr_candidate"], 0x00, u32, "flags_00")
    add_field(structs["stage1_thread_create_attr_candidate"], 0x04, u32, "priority_or_class_04")
    add_field(structs["stage1_thread_create_attr_candidate"], 0x08, u32, "stack_top_or_end_08")
    add_field(structs["stage1_thread_create_attr_candidate"], 0x0c, u32, "stack_size_0c")

    structs["stage1_owned_wait_object_candidate"] = StructureDataType(category_path, "stage1_owned_wait_object_candidate", 0x14)
    structs["stage1_thread_record_candidate"] = StructureDataType(category_path, "stage1_thread_record_candidate", 0x184)

    structs["stage1_scheduler_unlock_callback_record_candidate"] = StructureDataType(category_path, "stage1_scheduler_unlock_callback_record_candidate", 0x1c)
    add_field(structs["stage1_scheduler_unlock_callback_record_candidate"], 0x00, undef4, "callback_arg0_00")
    add_field(structs["stage1_scheduler_unlock_callback_record_candidate"], 0x04, undef4, "field_04")
    add_field(structs["stage1_scheduler_unlock_callback_record_candidate"], 0x08, undef4, "field_08")
    add_field(structs["stage1_scheduler_unlock_callback_record_candidate"], 0x0c, undef4, "callback_0c")
    add_field(structs["stage1_scheduler_unlock_callback_record_candidate"], 0x10, undef4, "callback_arg2_10")
    add_field(structs["stage1_scheduler_unlock_callback_record_candidate"], 0x14, undef4, "pending_count_or_arg1_14")
    add_field(structs["stage1_scheduler_unlock_callback_record_candidate"], 0x18, ptr(dtm, structs["stage1_scheduler_unlock_callback_record_candidate"]), "next_18")

    structs["stage1_id_to_value_map_entry_candidate"] = StructureDataType(category_path, "stage1_id_to_value_map_entry_candidate", 0x08)
    add_field(structs["stage1_id_to_value_map_entry_candidate"], 0x00, s32, "key_00")
    add_field(structs["stage1_id_to_value_map_entry_candidate"], 0x04, u32, "value_04")

    structs["stage1_post_message_candidate"] = StructureDataType(category_path, "stage1_post_message_candidate", 0x0c)
    add_field(structs["stage1_post_message_candidate"], 0x00, s32, "msg_type_00")
    add_field(structs["stage1_post_message_candidate"], 0x04, u32, "target_index_04")
    add_field(structs["stage1_post_message_candidate"], 0x08, undef4, "payload_08")

    structs["stage1_post_queue_node_candidate"] = StructureDataType(category_path, "stage1_post_queue_node_candidate", 0x10)
    add_field(structs["stage1_post_queue_node_candidate"], 0x00, ptr(dtm, structs["stage1_post_queue_node_candidate"]), "next_00")
    add_field(structs["stage1_post_queue_node_candidate"], 0x04, u32, "target_index_04")
    add_field(structs["stage1_post_queue_node_candidate"], 0x08, undef4, "post_arg_or_source_08")
    add_field(structs["stage1_post_queue_node_candidate"], 0x0c, undef4, "payload_0c")

    structs["stage1_post_target_slot_candidate"] = StructureDataType(category_path, "stage1_post_target_slot_candidate", 0x10)
    add_field(structs["stage1_post_target_slot_candidate"], 0x00, undef4, "field_00")
    add_field(structs["stage1_post_target_slot_candidate"], 0x04, u32, "flags_04")
    add_field(structs["stage1_post_target_slot_candidate"], 0x08, undef4, "field_08")
    add_field(structs["stage1_post_target_slot_candidate"], 0x0c, ptr(dtm, structs["stage1_post_queue_node_candidate"]), "tail_0c")

    structs["stage1_context_candidate"] = StructureDataType(category_path, "stage1_context_candidate", 0x128)
    add_field(structs["stage1_context_candidate"], 0x00, arr(undef1, 0x0c), "pad_00")
    add_field(structs["stage1_context_candidate"], 0x0c, arr(undef1, 0x0c), "context_switch_state_0c")
    add_field(structs["stage1_context_candidate"], 0x18, structs["stage1_readyq_node_candidate"], "readyq_node_18")
    add_field(structs["stage1_context_candidate"], 0x20, u32, "readyq_bucket_20")
    add_field(structs["stage1_context_candidate"], 0x24, undef4, "field_24")
    add_field(structs["stage1_context_candidate"], 0x28, ptr(dtm, ptr(dtm, structs["stage1_readyq_node_candidate"])), "owner_list_head_ref_28")
    add_field(structs["stage1_context_candidate"], 0x2c, u32, "scheduler_callback_block_count_2c_candidate")
    add_field(structs["stage1_context_candidate"], 0x30, u32, "pending_callback_flag_30")
    add_field(structs["stage1_context_candidate"], 0x34, undef4, "pending_callback_arg_34")
    add_field(structs["stage1_context_candidate"], 0x38, u32, "owned_pi_object_count_38_candidate")
    add_field(structs["stage1_context_candidate"], 0x3c, ptr(dtm, structs["stage1_owned_wait_object_candidate"]), "owned_pi_object_list_head_3c_candidate")
    add_field(structs["stage1_context_candidate"], 0x40, ptr(dtm, structs["stage1_owned_wait_object_candidate"]), "current_owned_wait_object_acquire_candidate")
    add_field(structs["stage1_context_candidate"], 0x44, undef4, "field_44")
    add_field(structs["stage1_context_candidate"], 0x48, u32, "saved_base_readyq_bucket_48_candidate")
    add_field(structs["stage1_context_candidate"], 0x4c, u32, "priority_inheritance_active_4c_candidate")
    add_field(structs["stage1_context_candidate"], 0x50, u32, "context_flags_50")
    add_field(structs["stage1_context_candidate"], 0x54, u32, "context_activation_hold_count_54_candidate")
    add_field(structs["stage1_context_candidate"], 0x58, undef4, "field_58")
    add_field(structs["stage1_context_candidate"], 0x5c, ptr(dtm, structs["stage1_event_wait_condition_candidate"]), "wait_condition_5c")
    add_field(structs["stage1_context_candidate"], 0x60, u16, "context_trace_id_60")
    add_field(structs["stage1_context_candidate"], 0x62, arr(undef1, 6), "pad_62")
    add_field(structs["stage1_context_candidate"], 0x68, arr(undef1, 0x30), "timeout_list_object_68_candidate")
    add_field(structs["stage1_context_candidate"], 0x98, u32, "wait_state_98")
    add_field(structs["stage1_context_candidate"], 0x9c, u32, "resume_status_9c")
    add_field(structs["stage1_context_candidate"], 0xa0, arr(undef4, 3), "extended_zero_area_a0_candidate")
    add_field(structs["stage1_context_candidate"], 0xac, ptr(dtm, structs["stage1_thread_record_candidate"]), "thread_record_ac_candidate")
    add_field(structs["stage1_context_candidate"], 0xb0, arr(undef4, 12), "extended_zero_area_b0_candidate")
    add_field(structs["stage1_context_candidate"], 0xe0, arr(structs["stage1_cleanup_callback_pair_candidate"], 8), "cleanup_callback_pairs_e0_candidate")
    add_field(structs["stage1_context_candidate"], 0x120, undef4, "field_120_candidate")
    add_field(structs["stage1_context_candidate"], 0x124, ptr(dtm, structs["stage1_context_candidate"]), "next_registered_context_124_candidate")

    add_field(structs["stage1_owned_wait_object_candidate"], 0x00, undef1, "active_or_locked_00")
    add_field(structs["stage1_owned_wait_object_candidate"], 0x01, arr(undef1, 3), "pad_01")
    add_field(structs["stage1_owned_wait_object_candidate"], 0x04, ptr(dtm, structs["stage1_context_candidate"]), "owner_context_04")
    add_field(structs["stage1_owned_wait_object_candidate"], 0x08, ptr(dtm, structs["stage1_readyq_node_candidate"]), "waitq_08")
    add_field(structs["stage1_owned_wait_object_candidate"], 0x0c, ptr(dtm, structs["stage1_owned_wait_object_candidate"]), "next_owned_pi_object_0c")
    add_field(structs["stage1_owned_wait_object_candidate"], 0x10, u32, "ownership_pi_mode_10")

    add_field(structs["stage1_context_candidate"], 0x3c, ptr(dtm, structs["stage1_owned_wait_object_candidate"]), "owned_pi_object_list_head_3c_candidate")
    add_field(structs["stage1_context_candidate"], 0x40, ptr(dtm, structs["stage1_owned_wait_object_candidate"]), "current_owned_wait_object_acquire_candidate")

    structs["stage1_condition_object_candidate"] = StructureDataType(category_path, "stage1_condition_object_candidate", 0x0c)
    add_field(structs["stage1_condition_object_candidate"], 0x00, ptr(dtm, structs["stage1_owned_wait_object_candidate"]), "associated_owned_wait_object_00_candidate")
    add_field(structs["stage1_condition_object_candidate"], 0x04, ptr(dtm, structs["stage1_readyq_node_candidate"]), "waitq_04")
    add_field(structs["stage1_condition_object_candidate"], 0x08, u32, "field_08")

    add_field(structs["stage1_thread_record_candidate"], 0x00, u32, "flags_00")
    add_field(structs["stage1_thread_record_candidate"], 0x04, u32, "thread_id_or_handle_04")
    add_field(structs["stage1_thread_record_candidate"], 0x08, ptr(dtm, structs["stage1_context_candidate"]), "context_08")
    add_field(structs["stage1_thread_record_candidate"], 0x0c, u32, "attr_flags_0c")
    add_field(structs["stage1_thread_record_candidate"], 0x10, u32, "attr_priority_or_class_10")
    add_field(structs["stage1_thread_record_candidate"], 0x14, u32, "attr_stack_top_or_end_14")
    add_field(structs["stage1_thread_record_candidate"], 0x18, u32, "attr_stack_size_18")
    add_field(structs["stage1_thread_record_candidate"], 0x1c, u32, "field_1c")
    add_field(structs["stage1_thread_record_candidate"], 0x20, ptr(dtm, void_dt), "entry_function_20")
    add_field(structs["stage1_thread_record_candidate"], 0x24, ptr(dtm, void_dt), "entry_arg_24")
    add_field(structs["stage1_thread_record_candidate"], 0x28, arr(ch, 0x10), "name_28")
    add_field(structs["stage1_thread_record_candidate"], 0x38, u32, "field_38")
    add_field(structs["stage1_thread_record_candidate"], 0x3c, ptr(dtm, structs["stage1_condition_object_candidate"]), "join_condition_3c_candidate")
    add_field(structs["stage1_thread_record_candidate"], 0x40, ptr(dtm, void_dt), "allocation_base_or_stack_base_40")
    add_field(structs["stage1_thread_record_candidate"], 0x44, u32, "field_44")
    add_field(structs["stage1_thread_record_candidate"], 0x48, u32, "pending_signal_or_work_mask_48_candidate")
    add_field(structs["stage1_thread_record_candidate"], 0x4c, u32, "blocked_signal_mask_or_wait_mask_4c_candidate")
    add_field(structs["stage1_thread_record_candidate"], 0x50, structs["stage1_context_candidate"], "embedded_context_50")
    add_field(structs["stage1_thread_record_candidate"], 0x178, structs["stage1_condition_object_candidate"], "embedded_join_condition_178")

    structs["dma_allocator_global_state_81848740_candidate"] = StructureDataType(category_path, "dma_allocator_global_state_81848740_candidate", 0x48)
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x00, undef4, "field_00")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x04, undef4, "header_field_04")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x08, u32, "default_pool_size_08")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x0c, ptr(dtm, void_dt), "backing_fpm_pool_base_0c")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x10, arr(undef1, 0x18), "pad_10")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x28, u32, "pool_shift_28")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x2c, ptr(dtm, void_dt), "pool_class_table_ptr_2c")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x30, u32, "max_or_largest_request_30")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x34, u32, "timer_counter_or_state_34")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x38, arr(undef1, 8), "pad_38")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x40, undef4, "default_pool_sizes_copy_40")
    add_field(structs["dma_allocator_global_state_81848740_candidate"], 0x44, undef4, "high_bits_table_48")

    structs["fap_bypass_context_candidate"] = StructureDataType(category_path, "fap_bypass_context_candidate", 0x55)
    add_field(structs["fap_bypass_context_candidate"], 0x00, arr(undef1, 0x14), "pad_00")
    add_field(structs["fap_bypass_context_candidate"], 0x14, u32, "enabled_queue_mask_14")
    add_field(structs["fap_bypass_context_candidate"], 0x18, s32, "active_queue_index_18")
    add_field(structs["fap_bypass_context_candidate"], 0x1c, s32, "data_enabled_queue_last_index_1c")
    add_field(structs["fap_bypass_context_candidate"], 0x20, s32, "bypass_queue_last_index_20")
    add_field(structs["fap_bypass_context_candidate"], 0x24, ptr(dtm, structs["host_dqm_channel_obj_candidate"]), "cmd_dqm_obj_24")
    add_field(structs["fap_bypass_context_candidate"], 0x28, ptr(dtm, structs["host_dqm_channel_obj_candidate"]), "active_queue_obj_28")
    add_field(structs["fap_bypass_context_candidate"], 0x2c, arr(ptr(dtm, structs["host_dqm_channel_obj_candidate"]), 8), "data_queue_objs_2c")
    add_field(structs["fap_bypass_context_candidate"], 0x4c, arr(ptr(dtm, structs["host_dqm_channel_obj_candidate"]), 2), "bypass_queue_objs_4c")
    add_field(structs["fap_bypass_context_candidate"], 0x54, u8, "data_mode_enabled_54")

    structs["host_downstream_dqm_queue_obj_candidate"] = StructureDataType(category_path, "host_downstream_dqm_queue_obj_candidate", 0x6c)
    add_field(structs["host_downstream_dqm_queue_obj_candidate"], 0x00, structs["host_dqm_channel_obj_candidate"], "base")
    add_field(structs["host_downstream_dqm_queue_obj_candidate"], 0x5c, u8, "active_flag_5c")
    add_field(structs["host_downstream_dqm_queue_obj_candidate"], 0x5d, arr(u8, 3), "pad_5d")
    add_field(structs["host_downstream_dqm_queue_obj_candidate"], 0x60, undef4, "field_60_unknown")
    add_field(structs["host_downstream_dqm_queue_obj_candidate"], 0x64, undef4, "field_64_unknown")
    add_field(structs["host_downstream_dqm_queue_obj_candidate"], 0x68, ptr(dtm, void_dt), "fpm_allocator_68")

    structs["stage1_bcm_sem_candidate"] = StructureDataType(category_path, "stage1_bcm_sem_candidate", 0x08)
    add_field(structs["stage1_bcm_sem_candidate"], 0x00, undef4, "count_or_state")
    add_field(structs["stage1_bcm_sem_candidate"], 0x04, undef4, "wait_queue_or_list")

    structs["stage1_semaphore_candidate"] = StructureDataType(category_path, "stage1_semaphore_candidate", 0x08)
    add_field(structs["stage1_semaphore_candidate"], 0x00, s32, "count")
    add_field(structs["stage1_semaphore_candidate"], 0x04, undef4, "waitq_04")

    structs["stage1_guarded_context_lock_candidate"] = StructureDataType(category_path, "stage1_guarded_context_lock_candidate", 0x10)
    add_field(structs["stage1_guarded_context_lock_candidate"], 0x00, s32, "refcount")
    add_field(structs["stage1_guarded_context_lock_candidate"], 0x04, s32, "waiter_count")
    add_field(structs["stage1_guarded_context_lock_candidate"], 0x08, ptr(dtm, void_dt), "owner_context")
    add_field(structs["stage1_guarded_context_lock_candidate"], 0x0c, ptr(dtm, structs["stage1_semaphore_candidate"]), "semaphore")

    order = [
        "tc7200_fpm_allocator",
        "tc7200_fpm_packet_allocator",
        "tc7200_fpm_packet_inner_header",
        "tc7200_fpm_packet_header",
        "host_dqm_register_block_1800_candidate",
        "host_dqm_channel_obj_candidate",
        "stage1_event_slot_candidate",
        "stage1_event_wait_condition_candidate",
        "stage1_readyq_node_candidate",
        "stage1_readyq_table_candidate",
        "stage1_callback_pair_candidate",
        "stage1_cleanup_callback_pair_candidate",
        "stage1_signal_select_state_candidate",
        "stage1_thread_create_attr_candidate",
        "stage1_scheduler_unlock_callback_record_candidate",
        "stage1_id_to_value_map_entry_candidate",
        "stage1_post_message_candidate",
        "stage1_post_queue_node_candidate",
        "stage1_post_target_slot_candidate",
        "stage1_context_candidate",
        "stage1_owned_wait_object_candidate",
        "stage1_condition_object_candidate",
        "stage1_thread_record_candidate",
        "dma_allocator_global_state_81848740_candidate",
        "fap_bypass_context_candidate",
        "host_downstream_dqm_queue_obj_candidate",
        "stage1_bcm_sem_candidate",
        "stage1_semaphore_candidate",
        "stage1_guarded_context_lock_candidate",
    ]

    return structs, order


def main():
    if currentProgram is None:
        printerr("No open program.")
        return

    dtm = currentProgram.getDataTypeManager()
    category_path = ensure_custom_category(dtm, currentProgram.getName())
    structs, order = build_structures(category_path, dtm)

    tx = currentProgram.startTransaction("Build TC7200 reverse structures")
    success = False
    try:
        applied = 0
        for name in order:
            monitor.checkCanceled()
            dtm.addDataType(structs[name], DataTypeConflictHandler.REPLACE_HANDLER)
            applied += 1
        success = True
    finally:
        currentProgram.endTransaction(tx, success)

    println("Applied %d structures under %s" % (len(order), category_path.getPath()))


main()
