# TC7200U - organize Data Type Manager categories only
# v3: exact known datatype map + safe prefix/pattern routing for future TC7200U datatypes.
# Moves existing structure, callback, and function-definition datatypes into /tc7200u categories.
# Does not edit datatype fields, function signatures, symbols, comments, memory blocks, or functions.
# Does not delete /custom.
#@author ChatGPT
#@category TC7200U
#@keybinding
#@menupath
#@toolbar

from ghidra.program.model.data import CategoryPath
from ghidra.program.model.data import DataTypeConflictHandler

CATEGORY_PATHS = [
    "/tc7200u",
    "/tc7200u/stage1",
    "/tc7200u/stage1/context",
    "/tc7200u/stage1/thread",
    "/tc7200u/stage1/scheduler",
    "/tc7200u/stage1/wait_sync",
    "/tc7200u/stage1/timeout",
    "/tc7200u/stage1/signal",
    "/tc7200u/stage1/post",
    "/tc7200u/dqm_host_fap",
    "/tc7200u/fpm_dma",
    "/tc7200u/mmio",
    "/tc7200u/common",
]

# Exact known structure datatypes from the current TC7200U Ghidra work.
STRUCT_TYPE_TO_CATEGORY = {
    # common/simple helper types
    "stage1_callback_pair_candidate": "/tc7200u/common",
    "stage1_cleanup_callback_pair_candidate": "/tc7200u/common",
    "stage1_id_to_value_map_entry_candidate": "/tc7200u/common",
    "stage1_iovec_candidate": "/tc7200u/common",

    # stage1/context
    "stage1_context_candidate": "/tc7200u/stage1/context",
    "stage1_context_cleanup_callback_pair_candidate": "/tc7200u/stage1/context",
    "stage1_context_flags": "/tc7200u/stage1/context",

    # stage1/thread
    "stage1_thread_record_candidate": "/tc7200u/stage1/thread",
    "stage1_thread_join_condition_candidate": "/tc7200u/stage1/thread",
    "stage1_thread_cleanup_handler_candidate": "/tc7200u/stage1/thread",
    "stage1_thread_create_attr_candidate": "/tc7200u/stage1/thread",

    # stage1/scheduler
    "stage1_readyq_node_candidate": "/tc7200u/stage1/scheduler",
    "stage1_readyq_table_candidate": "/tc7200u/stage1/scheduler",
    "stage1_scheduler_unlock_callback_record_candidate": "/tc7200u/stage1/scheduler",

    # stage1/wait_sync
    "stage1_bcm_sem_candidate": "/tc7200u/stage1/wait_sync",
    "stage1_condition_object_candidate": "/tc7200u/stage1/wait_sync",
    "stage1_event_slot_candidate": "/tc7200u/stage1/wait_sync",
    "stage1_event_wait_condition_candidate": "/tc7200u/stage1/wait_sync",
    "stage1_owned_wait_object_candidate": "/tc7200u/stage1/wait_sync",
    "stage1_guarded_context_lock_candidate": "/tc7200u/stage1/wait_sync",
    "stage1_semaphore_candidate": "/tc7200u/stage1/wait_sync",

    # stage1/timeout
    "stage1_timeout_object_candidate": "/tc7200u/stage1/timeout",
    "stage1_timeout_queue_candidate": "/tc7200u/stage1/timeout",
    "stage1_timeout_scale_table_candidate": "/tc7200u/stage1/timeout",
    "stage1_timeval32_candidate": "/tc7200u/stage1/timeout",

    # stage1/signal
    "stage1_signal_object_candidate": "/tc7200u/stage1/signal",
    "stage1_signal_ops_or_class_candidate": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_ops_candidate": "/tc7200u/stage1/signal",
    "stage1_signal_iovec_io_request_candidate": "/tc7200u/stage1/signal",
    "stage1_signal_handler_entry_candidate": "/tc7200u/stage1/signal",
    "stage1_signal_object_provider_entry_candidate": "/tc7200u/stage1/signal",
    "stage1_related_object_pool_a_entry_candidate": "/tc7200u/stage1/signal",
    "stage1_related_object_pool_b_entry_candidate": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_callback_20_request_candidate": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_callback_24_request_candidate": "/tc7200u/stage1/signal",
    "stage1_signal_select_state_candidate": "/tc7200u/stage1/signal",

    # stage1/post
    "stage1_post_message_candidate": "/tc7200u/stage1/post",
    "stage1_post_queue_node_candidate": "/tc7200u/stage1/post",
    "stage1_post_target_slot_candidate": "/tc7200u/stage1/post",

    # dqm_host_fap
    "fap_bypass_context_candidate": "/tc7200u/dqm_host_fap",
    "host_dqm_channel_obj_candidate": "/tc7200u/dqm_host_fap",
    "host_dqm_register_block_1800_candidate": "/tc7200u/dqm_host_fap",
    "host_downstream_dqm_queue_obj_candidate": "/tc7200u/dqm_host_fap",

    # fpm_dma
    "dma_allocator_global_state_81848740_candidate": "/tc7200u/fpm_dma",
    "tc7200_fpm_allocator": "/tc7200u/fpm_dma",
    "tc7200_fpm_packet_allocator": "/tc7200u/fpm_dma",
    "tc7200_fpm_packet_header": "/tc7200u/fpm_dma",
    "tc7200_fpm_packet_inner_header": "/tc7200u/fpm_dma",
}

# Exact known callback/function-definition datatypes from /custom.
CALLBACK_FUNCTIONDEF_TO_CATEGORY = {
    # stage1/context callback typedefs / function-definition datatypes
    "stage1_context_cleanup_callback_fn": "/tc7200u/stage1/context",

    # stage1/thread callback typedefs / function-definition datatypes
    "stage1_thread_cleanup_callback_candidate": "/tc7200u/stage1/thread",
    "stage1_tsd_key_destructor_callback_candidate": "/tc7200u/stage1/thread",

    # stage1/timeout function-definition datatypes
    "fn_stage1_signal_timeout_arg_to_ticks64_80ef6a54_candidate": "/tc7200u/stage1/timeout",

    # stage1/signal related-object callback typedefs / function-definition datatypes
    "stage1_related_object_callback_1c_cb": "/tc7200u/stage1/signal",
    "stage1_related_object_callback_2c_cb": "/tc7200u/stage1/signal",
    "stage1_related_object_callback_34_cb": "/tc7200u/stage1/signal",
    "stage1_related_object_path_context_cb_30": "/tc7200u/stage1/signal",

    # stage1/signal object callback typedefs / function-definition datatypes
    "stage1_signal_object_callback_08_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_callback_0c_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_callback_14_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_callback_1c_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_final_release_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_iovec_io_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_test_callback_10_cb": "/tc7200u/stage1/signal",

    # stage1/signal type2 callback typedefs / function-definition datatypes
    "stage1_signal_object_type2_callback_00_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_callback_04_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_callback_0c_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_callback_10_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_callback_18_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_callback_20_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_callback_24_cb": "/tc7200u/stage1/signal",
    "stage1_signal_object_type2_clone_callback_08_cb": "/tc7200u/stage1/signal",
}

EXACT_TYPE_TO_CATEGORY = {}
EXACT_TYPE_TO_CATEGORY.update(STRUCT_TYPE_TO_CATEGORY)
EXACT_TYPE_TO_CATEGORY.update(CALLBACK_FUNCTIONDEF_TO_CATEGORY)


def get_conflict_handler():
    """Pick a conflict handler that exists in this Ghidra build."""
    for handler_name in ("DEFAULT_HANDLER", "KEEP_HANDLER", "REPLACE_HANDLER", "RENAME_HANDLER"):
        if hasattr(DataTypeConflictHandler, handler_name):
            return getattr(DataTypeConflictHandler, handler_name)
    raise Exception("No compatible DataTypeConflictHandler constant found in this Ghidra build")


def ensure_category(dtm, path):
    cp = CategoryPath(path)
    cat = dtm.getCategory(cp)
    if cat is None:
        cat = dtm.createCategory(cp)
    return cat


def infer_category_for_future_type(type_name):
    """
    Conservative future-proof routing by datatype name.
    Returns None when the name is not clearly TC7200U/Stage1/DQM/FPM related.
    """
    name = type_name

    # DQM / FAP family
    if name.startswith("fap_bypass_"):
        return "/tc7200u/dqm_host_fap"
    if name.startswith("host_dqm_"):
        return "/tc7200u/dqm_host_fap"
    if name.startswith("host_downstream_dqm_"):
        return "/tc7200u/dqm_host_fap"

    # FPM / DMA allocator family
    if name.startswith("tc7200_fpm_"):
        return "/tc7200u/fpm_dma"
    if name.startswith("dma_allocator_"):
        return "/tc7200u/fpm_dma"
    if name.startswith("fpm_"):
        return "/tc7200u/fpm_dma"

    # Stage1 common helpers
    if name.startswith("stage1_iovec"):
        return "/tc7200u/common"
    if name.startswith("stage1_id_to_value_map"):
        return "/tc7200u/common"
    if name.startswith("stage1_callback_pair"):
        return "/tc7200u/common"
    if name.startswith("stage1_cleanup_callback_pair"):
        return "/tc7200u/common"

    # Stage1 context family
    if name.startswith("stage1_context_"):
        return "/tc7200u/stage1/context"
    if name.startswith("fn_stage1_context_"):
        return "/tc7200u/stage1/context"

    # Stage1 thread / TSD family
    if name.startswith("stage1_thread_"):
        return "/tc7200u/stage1/thread"
    if name.startswith("stage1_tsd_"):
        return "/tc7200u/stage1/thread"
    if name.startswith("fn_stage1_current_thread_"):
        return "/tc7200u/stage1/thread"
    if name.startswith("fn_stage1_thread_"):
        return "/tc7200u/stage1/thread"

    # Stage1 scheduler / readyq family
    if name.startswith("stage1_readyq_"):
        return "/tc7200u/stage1/scheduler"
    if name.startswith("stage1_scheduler_"):
        return "/tc7200u/stage1/scheduler"
    if name.startswith("fn_stage1_scheduler_"):
        return "/tc7200u/stage1/scheduler"
    if name.startswith("fn_stage1_readyq_"):
        return "/tc7200u/stage1/scheduler"

    # Stage1 wait/sync family
    if name.startswith("stage1_bcm_sem"):
        return "/tc7200u/stage1/wait_sync"
    if name.startswith("stage1_condition_"):
        return "/tc7200u/stage1/wait_sync"
    if name.startswith("stage1_event_"):
        return "/tc7200u/stage1/wait_sync"
    if name.startswith("stage1_owned_wait_"):
        return "/tc7200u/stage1/wait_sync"
    if name.startswith("stage1_guarded_context_lock"):
        return "/tc7200u/stage1/wait_sync"
    if name.startswith("stage1_semaphore"):
        return "/tc7200u/stage1/wait_sync"
    if name.startswith("fn_stage1_wait_"):
        return "/tc7200u/stage1/wait_sync"

    # Stage1 timeout family
    if name.startswith("stage1_timeout_"):
        return "/tc7200u/stage1/timeout"
    if name.startswith("stage1_timeval"):
        return "/tc7200u/stage1/timeout"
    if name.startswith("fn_stage1_timeout_"):
        return "/tc7200u/stage1/timeout"
    if name.startswith("fn_stage1_signal_timeout_"):
        return "/tc7200u/stage1/timeout"

    # Stage1 signal/select family
    if name.startswith("stage1_signal_"):
        return "/tc7200u/stage1/signal"
    if name.startswith("stage1_related_object_"):
        return "/tc7200u/stage1/signal"
    if name.startswith("fn_stage1_signal_"):
        return "/tc7200u/stage1/signal"
    if name.startswith("fn_stage1_current_thread_record_") and "signal" in name:
        return "/tc7200u/stage1/signal"
    if name.startswith("fn_stage1_select_"):
        return "/tc7200u/stage1/signal"

    # Stage1 post/message family
    if name.startswith("stage1_post_"):
        return "/tc7200u/stage1/post"
    if name.startswith("fn_stage1_post_"):
        return "/tc7200u/stage1/post"

    # Keep unknown future names unmoved.
    return None


def build_name_index(dtm):
    index = {}
    it = dtm.getAllDataTypes()
    while it.hasNext():
        dt = it.next()
        name = dt.getName()
        if name not in index:
            index[name] = []
        index[name].append(dt)
    return index


def all_program_datatypes(dtm):
    out = []
    it = dtm.getAllDataTypes()
    while it.hasNext():
        out.append(it.next())
    return out


def move_datatype(dt, target_path, category_by_path, handler, group_label, stats):
    type_name = dt.getName()
    try:
        if str(dt.getCategoryPath()) == target_path:
            stats["in_place"] += 1
            return
        target_cat = category_by_path[target_path]
        target_cat.moveDataType(dt, handler)
        stats["moved"] += 1
        print("moved %-70s -> %s [%s]" % (type_name, target_path, group_label))
    except Exception as e:
        stats["failed"].append("%s -> %s : %s" % (type_name, target_path, str(e)))


def move_exact_known_types(name_index, category_by_path, handler, mapping):
    stats = {"moved": 0, "in_place": 0, "missing": [], "failed": []}

    for type_name in sorted(mapping.keys()):
        monitor.checkCanceled()
        target_path = mapping[type_name]
        found = name_index.get(type_name, [])
        if len(found) == 0:
            stats["missing"].append(type_name)
            continue
        for dt in found:
            move_datatype(dt, target_path, category_by_path, handler, "exact", stats)

    return stats


def move_inferred_future_types(dtm, category_by_path, handler):
    stats = {"moved": 0, "in_place": 0, "missing": [], "failed": [], "unmatched_custom": []}

    for dt in all_program_datatypes(dtm):
        monitor.checkCanceled()
        type_name = dt.getName()

        # Exact known names already handled above. Skip them here to keep report clean.
        if type_name in EXACT_TYPE_TO_CATEGORY:
            continue

        target_path = infer_category_for_future_type(type_name)
        if target_path is None:
            if str(dt.getCategoryPath()) == "/custom" and (
                type_name.startswith("stage1_") or
                type_name.startswith("fn_stage1_") or
                type_name.startswith("tc7200_") or
                type_name.startswith("host_dqm_") or
                type_name.startswith("fap_") or
                type_name.startswith("dma_allocator_") or
                type_name.startswith("fpm_")
            ):
                stats["unmatched_custom"].append(type_name)
            continue

        move_datatype(dt, target_path, category_by_path, handler, "inferred", stats)

    return stats


def main():
    if currentProgram is None:
        raise Exception("Open a program before running this script.")

    dtm = currentProgram.getDataTypeManager()
    handler = get_conflict_handler()

    tx = dtm.startTransaction("TC7200U organize Data Type Manager categories v3")
    commit = False

    categories_ensured = 0
    exact_stats = None
    inferred_stats = None

    try:
        category_by_path = {}
        for path in CATEGORY_PATHS:
            monitor.checkCanceled()
            category_by_path[path] = ensure_category(dtm, path)
            categories_ensured += 1

        name_index = build_name_index(dtm)
        exact_stats = move_exact_known_types(name_index, category_by_path, handler, EXACT_TYPE_TO_CATEGORY)
        inferred_stats = move_inferred_future_types(dtm, category_by_path, handler)

        commit = True
    finally:
        dtm.endTransaction(tx, commit)

    failed_moves = []
    failed_moves.extend(exact_stats["failed"])
    failed_moves.extend(inferred_stats["failed"])

    print("")
    print("TC7200U datatype category organization v3 finished")
    print("conflict handler:                  %s" % str(handler))
    print("categories ensured:               %d" % categories_ensured)
    print("exact known types moved:          %d" % exact_stats["moved"])
    print("exact known types already placed: %d" % exact_stats["in_place"])
    print("inferred future types moved:      %d" % inferred_stats["moved"])
    print("inferred future types placed:     %d" % inferred_stats["in_place"])
    print("missing exact known types:        %d" % len(exact_stats["missing"]))
    print("unmatched custom tc7200u/stage1:  %d" % len(inferred_stats["unmatched_custom"]))
    print("failed moves:                     %d" % len(failed_moves))

    if exact_stats["missing"]:
        print("")
        print("Missing exact known datatypes, probably not imported/created yet:")
        for name in sorted(exact_stats["missing"]):
            print("  " + name)

    if inferred_stats["unmatched_custom"]:
        print("")
        print("Unmatched /custom TC7200U-like datatypes; inspect and add exact/prefix rule if needed:")
        for name in sorted(inferred_stats["unmatched_custom"]):
            print("  " + name)

    if failed_moves:
        print("")
        print("Failed moves:")
        for item in failed_moves:
            print("  " + item)


main()
