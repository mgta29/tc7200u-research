// Organize Data Type Manager categories
//@author mgta29 / ChatGPT
//@category TC7200
//@keybinding
//@menupath TC7200.Organize Data Type
//@toolbar

import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.Category;
import ghidra.program.model.data.CategoryPath;
import ghidra.program.model.data.DataType;
import ghidra.program.model.data.DataTypeConflictHandler;
import ghidra.program.model.data.DataTypeManager;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public class OrganizeDatatypes extends GhidraScript {

    private static final String[] CATEGORY_PATHS = {
        "/tc7200u",
        "/tc7200u/common",
        "/tc7200u/mmio",

        "/tc7200u/dqm_host_fap",
        "/tc7200u/fpm_dma",

        "/tc7200u/stage1",
        "/tc7200u/stage1/context",
        "/tc7200u/stage1/thread",
        "/tc7200u/stage1/scheduler",
        "/tc7200u/stage1/wait_sync",
        "/tc7200u/stage1/timeout",
        "/tc7200u/stage1/signal",
        "/tc7200u/stage1/post",
        "/tc7200u/stage1/lifecycle",
        "/tc7200u/stage1/socket",
        "/tc7200u/stage1/netif",
    };

    private static final Map<String, String> EXACT_TYPE_TO_CATEGORY = new HashMap<>();

    static {
        addExact("/tc7200u/common", new String[] {
            "stage1_callback_pair_candidate",
            "stage1_cleanup_callback_pair_candidate",
            "stage1_id_to_value_map_entry_candidate",
            "stage1_iovec_candidate",
            "bcm_irq_encoded_id_decode_entry_candidate",
            "bcm_periph_irq_handler_entry_candidate",
            "mta_interrupt_id_map_entry_candidate",
        });

        addExact("/tc7200u/mmio", new String[] {
            "bcm_periph_irq_child_bank_regs_candidate",
            "bcm_periph_irq_handler_fn_candidate",
            "vuint8_t",
            "vuint16_t",
            "vuint32_t",
        });

        addExact("/tc7200u/stage1/context", new String[] {
            "stage1_context_candidate",
            "stage1_context_cleanup_callback_pair_candidate",
            "stage1_context_flags",
        });

        addExact("/tc7200u/stage1/thread", new String[] {
            "stage1_thread_record_candidate",
            "stage1_thread_join_condition_candidate",
            "stage1_thread_cleanup_handler_candidate",
            "stage1_thread_create_attr_candidate",
        });

        addExact("/tc7200u/stage1/scheduler", new String[] {
            "stage1_readyq_node_candidate",
            "stage1_readyq_table_candidate",
            "stage1_scheduler_unlock_callback_record_candidate",
        });

        addExact("/tc7200u/stage1/wait_sync", new String[] {
            "stage1_bcm_sem_candidate",
            "stage1_condition_object_candidate",
            "stage1_event_slot_candidate",
            "stage1_event_wait_condition_candidate",
            "stage1_owned_wait_object_candidate",
            "stage1_guarded_context_lock_candidate",
            "stage1_semaphore_candidate",
        });

        addExact("/tc7200u/stage1/timeout", new String[] {
            "stage1_timeout_object_candidate",
            "stage1_timeout_queue_candidate",
            "stage1_timeout_scale_table_candidate",
            "stage1_timeval32_candidate",
        });

        addExact("/tc7200u/stage1/signal", new String[] {
            "stage1_signal_object_candidate",
            "stage1_signal_ops_or_class_candidate",
            "stage1_signal_object_type2_ops_candidate",
            "stage1_signal_iovec_io_request_candidate",
            "stage1_signal_handler_entry_candidate",
            "stage1_signal_object_provider_entry_candidate",
            "stage1_related_object_pool_a_entry_candidate",
            "stage1_related_object_pool_b_entry_candidate",
            "stage1_signal_object_type2_callback_20_request_candidate",
            "stage1_signal_object_type2_callback_24_request_candidate",
            "stage1_signal_select_state_candidate",
        });

        addExact("/tc7200u/stage1/post", new String[] {
            "stage1_post_message_candidate",
            "stage1_post_queue_node_candidate",
            "stage1_post_target_slot_candidate",
        });

        addExact("/tc7200u/dqm_host_fap", new String[] {
            "fap_bypass_context_candidate",
            "host_dqm_channel_obj_candidate",
            "host_dqm_register_block_1800_candidate",
            "host_downstream_dqm_queue_obj_candidate",
        });

        addExact("/tc7200u/fpm_dma", new String[] {
            "dma_allocator_global_state_81848740_candidate",
            "tc7200_fpm_allocator",
            "tc7200_fpm_packet_allocator",
            "tc7200_fpm_packet_header",
            "tc7200_fpm_packet_inner_header",
        });

        addExact("/tc7200u/stage1/context", new String[] {
            "stage1_context_cleanup_callback_fn",
        });

        addExact("/tc7200u/stage1/thread", new String[] {
            "stage1_thread_cleanup_callback_candidate",
            "stage1_tsd_key_destructor_callback_candidate",
        });

        addExact("/tc7200u/stage1/timeout", new String[] {
            "fn_stage1_signal_timeout_arg_to_ticks64_80ef6a54_candidate",
        });

        addExact("/tc7200u/stage1/lifecycle", new String[] {
            "stage1_shutdown_cleanup_cb",
            "stage1_shutdown_cleanup_cb *",
        });

        addExact("/tc7200u/stage1/signal", new String[] {
            "stage1_related_object_callback_1c_cb",
            "stage1_related_object_callback_2c_cb",
            "stage1_related_object_callback_34_cb",
            "stage1_related_object_path_context_cb_30",

            "stage1_signal_object_callback_08_cb",
            "stage1_signal_object_callback_0c_cb",
            "stage1_signal_object_callback_14_cb",
            "stage1_signal_object_callback_1c_cb",
            "stage1_signal_object_final_release_cb",
            "stage1_signal_object_iovec_io_cb",
            "stage1_signal_object_test_callback_10_cb",

            "stage1_signal_object_type2_callback_00_cb",
            "stage1_signal_object_type2_callback_04_cb",
            "stage1_signal_object_type2_callback_0c_cb",
            "stage1_signal_object_type2_callback_10_cb",
            "stage1_signal_object_type2_callback_18_cb",
            "stage1_signal_object_type2_callback_20_cb",
            "stage1_signal_object_type2_callback_24_cb",
            "stage1_signal_object_type2_clone_callback_08_cb",
        });
    }

    private static void addExact(String targetPath, String[] names) {
        for (String name : names) {
            EXACT_TYPE_TO_CATEGORY.put(name, targetPath);
        }
    }

    @Override
    protected void run() throws Exception {
        if (currentProgram == null) {
            throw new Exception("Open a program before running this script.");
        }

        DataTypeManager dtm = currentProgram.getDataTypeManager();
        DataTypeConflictHandler handler = getConflictHandler();

        int tx = dtm.startTransaction("TC7200U organize Data Type Manager categories v3.2");
        boolean commit = false;

        int categoriesEnsured = 0;
        MoveStats exactStats = null;
        MoveStats inferredStats = null;

        try {
            Map<String, Category> categoryByPath = new HashMap<>();
            for (String path : CATEGORY_PATHS) {
                monitor.checkCanceled();
                categoryByPath.put(path, ensureCategory(dtm, path));
                categoriesEnsured++;
            }

            Map<String, List<DataType>> nameIndex = buildNameIndex(dtm);
            exactStats = moveExactKnownTypes(nameIndex, categoryByPath, handler, EXACT_TYPE_TO_CATEGORY);
            inferredStats = moveInferredFutureTypes(dtm, categoryByPath, handler);

            commit = true;
        }
        finally {
            dtm.endTransaction(tx, commit);
        }

        List<String> failedMoves = new ArrayList<>();
        failedMoves.addAll(exactStats.failed);
        failedMoves.addAll(inferredStats.failed);

        println("");
        println("TC7200U datatype category organization v3.2 finished");
        println("conflict handler:                  " + String.valueOf(handler));
        println("categories ensured:               " + categoriesEnsured);
        println("exact known types moved:          " + exactStats.moved);
        println("exact known types already placed: " + exactStats.inPlace);
        println("inferred future types moved:      " + inferredStats.moved);
        println("inferred future types placed:     " + inferredStats.inPlace);
        println("missing exact known types:        " + exactStats.missing.size());
        println("unmatched custom tc7200u/stage1:  " + inferredStats.unmatchedCustom.size());
        println("failed moves:                     " + failedMoves.size());

        if (!exactStats.missing.isEmpty()) {
            println("");
            println("Missing exact known datatypes, probably not imported/created yet:");
            Collections.sort(exactStats.missing);
            for (String name : exactStats.missing) {
                println("  " + name);
            }
        }

        if (!inferredStats.unmatchedCustom.isEmpty()) {
            println("");
            println("Unmatched /custom TC7200U-like datatypes; inspect and add exact/prefix rule if needed:");
            Collections.sort(inferredStats.unmatchedCustom);
            for (String name : inferredStats.unmatchedCustom) {
                println("  " + name);
            }
        }

        if (!failedMoves.isEmpty()) {
            println("");
            println("Failed moves:");
            for (String item : failedMoves) {
                println("  " + item);
            }
        }
    }

    private DataTypeConflictHandler getConflictHandler() throws Exception {
        for (String handlerName : new String[] {
            "DEFAULT_HANDLER",
            "KEEP_HANDLER",
            "REPLACE_HANDLER",
            "RENAME_HANDLER",
        }) {
            try {
                Field field = DataTypeConflictHandler.class.getField(handlerName);
                Object value = field.get(null);
                if (value instanceof DataTypeConflictHandler) {
                    return (DataTypeConflictHandler) value;
                }
            }
            catch (Exception e) {
                // try next handler
            }
        }
        throw new Exception("No compatible DataTypeConflictHandler constant found in this Ghidra build");
    }

    private Category ensureCategory(DataTypeManager dtm, String path) {
        CategoryPath cp = new CategoryPath(path);
        Category cat = dtm.getCategory(cp);
        if (cat == null) {
            cat = dtm.createCategory(cp);
        }
        return cat;
    }

    private String normalizeTypeName(String typeName) {
        String name = typeName.trim();

        while (name.endsWith("*")) {
            name = name.substring(0, name.length() - 1).trim();
        }

        int bracket = name.indexOf("[");
        if (bracket >= 0) {
            name = name.substring(0, bracket).trim();
        }

        return name;
    }

    private String inferCategoryForFutureType(String typeName) {
        String name = normalizeTypeName(typeName);

        if (name.startsWith("fap_bypass_")) {
            return "/tc7200u/dqm_host_fap";
        }
        if (name.startsWith("host_dqm_")) {
            return "/tc7200u/dqm_host_fap";
        }
        if (name.startsWith("host_downstream_dqm_")) {
            return "/tc7200u/dqm_host_fap";
        }
        if (name.startsWith("dqm_host_")) {
            return "/tc7200u/dqm_host_fap";
        }

        if (name.startsWith("tc7200_fpm_")) {
            return "/tc7200u/fpm_dma";
        }
        if (name.startsWith("dma_allocator_")) {
            return "/tc7200u/fpm_dma";
        }
        if (name.startsWith("fpm_")) {
            return "/tc7200u/fpm_dma";
        }

        if (name.startsWith("stage1_shutdown_")) {
            return "/tc7200u/stage1/lifecycle";
        }
        if (name.startsWith("fn_stage1_shutdown_")) {
            return "/tc7200u/stage1/lifecycle";
        }
        if (name.startsWith("stage1_lifecycle_")) {
            return "/tc7200u/stage1/lifecycle";
        }
        if (name.startsWith("fn_stage1_lifecycle_")) {
            return "/tc7200u/stage1/lifecycle";
        }

        if (name.startsWith("stage1_socket_")) {
            return "/tc7200u/stage1/socket";
        }
        if (name.startsWith("fn_stage1_socket_")) {
            return "/tc7200u/stage1/socket";
        }

        if (name.startsWith("stage1_netif_")) {
            return "/tc7200u/stage1/netif";
        }
        if (name.startsWith("fn_stage1_netif_")) {
            return "/tc7200u/stage1/netif";
        }
        if (name.startsWith("stage1_default_gateway_")) {
            return "/tc7200u/stage1/netif";
        }

        if (name.startsWith("stage1_iovec")) {
            return "/tc7200u/common";
        }
        if (name.startsWith("stage1_id_to_value_map")) {
            return "/tc7200u/common";
        }
        if (name.startsWith("stage1_callback_pair")) {
            return "/tc7200u/common";
        }
        if (name.startsWith("stage1_cleanup_callback_pair")) {
            return "/tc7200u/common";
        }

        if (name.startsWith("stage1_context_")) {
            return "/tc7200u/stage1/context";
        }
        if ("stage1_context_candidate".equals(name)) {
            return "/tc7200u/stage1/context";
        }
        if (name.startsWith("fn_stage1_context_")) {
            return "/tc7200u/stage1/context";
        }
        if (name.startsWith("fn_stage1_current_context_")) {
            return "/tc7200u/stage1/context";
        }

        if (name.startsWith("stage1_thread_")) {
            return "/tc7200u/stage1/thread";
        }
        if (name.startsWith("stage1_tsd_")) {
            return "/tc7200u/stage1/thread";
        }
        if (name.startsWith("fn_stage1_current_thread_")) {
            return "/tc7200u/stage1/thread";
        }
        if (name.startsWith("fn_stage1_thread_")) {
            return "/tc7200u/stage1/thread";
        }

        if (name.startsWith("stage1_readyq_")) {
            return "/tc7200u/stage1/scheduler";
        }
        if (name.startsWith("stage1_scheduler_")) {
            return "/tc7200u/stage1/scheduler";
        }
        if (name.startsWith("fn_stage1_scheduler_")) {
            return "/tc7200u/stage1/scheduler";
        }
        if (name.startsWith("fn_stage1_readyq_")) {
            return "/tc7200u/stage1/scheduler";
        }

        if (name.startsWith("stage1_bcm_sem")) {
            return "/tc7200u/stage1/wait_sync";
        }
        if (name.startsWith("stage1_condition_")) {
            return "/tc7200u/stage1/wait_sync";
        }
        if (name.startsWith("stage1_event_")) {
            return "/tc7200u/stage1/wait_sync";
        }
        if (name.startsWith("stage1_owned_wait_")) {
            return "/tc7200u/stage1/wait_sync";
        }
        if (name.startsWith("stage1_guarded_context_lock")) {
            return "/tc7200u/stage1/wait_sync";
        }
        if (name.startsWith("stage1_semaphore")) {
            return "/tc7200u/stage1/wait_sync";
        }
        if (name.startsWith("fn_stage1_wait_")) {
            return "/tc7200u/stage1/wait_sync";
        }

        if (name.startsWith("stage1_timeout_")) {
            return "/tc7200u/stage1/timeout";
        }
        if (name.startsWith("stage1_timeval")) {
            return "/tc7200u/stage1/timeout";
        }
        if (name.startsWith("fn_stage1_timeout_")) {
            return "/tc7200u/stage1/timeout";
        }
        if (name.startsWith("fn_stage1_signal_timeout_")) {
            return "/tc7200u/stage1/timeout";
        }

        if (name.startsWith("stage1_signal_")) {
            return "/tc7200u/stage1/signal";
        }
        if (name.startsWith("stage1_related_object_")) {
            return "/tc7200u/stage1/signal";
        }
        if (name.startsWith("fn_stage1_signal_")) {
            return "/tc7200u/stage1/signal";
        }
        if (name.startsWith("fn_stage1_current_thread_record_") && name.contains("signal")) {
            return "/tc7200u/stage1/signal";
        }
        if (name.startsWith("fn_stage1_select_")) {
            return "/tc7200u/stage1/signal";
        }

        if (name.startsWith("stage1_post_")) {
            return "/tc7200u/stage1/post";
        }
        if (name.startsWith("fn_stage1_post_")) {
            return "/tc7200u/stage1/post";
        }

        if (name.startsWith("bcm_irq_encoded_id_decode_")) {
            return "/tc7200u/common";
        }
        if (name.startsWith("bcm_periph_irq_handler_entry_")) {
            return "/tc7200u/common";
        }
        if (name.startsWith("mta_interrupt_id_map_")) {
            return "/tc7200u/common";
        }
        if (name.startsWith("bcm_periph_irq_child_bank_")) {
            return "/tc7200u/mmio";
        }
        if (name.startsWith("bcm_periph_irq_handler_fn_")) {
            return "/tc7200u/mmio";
        }
        if (name.startsWith("vuint")) {
            return "/tc7200u/mmio";
        }

        return null;
    }

    private Map<String, List<DataType>> buildNameIndex(DataTypeManager dtm) {
        Map<String, List<DataType>> index = new HashMap<>();
        Iterator<DataType> it = dtm.getAllDataTypes();
        while (it.hasNext()) {
            DataType dt = it.next();
            String name = dt.getName();
            if (!index.containsKey(name)) {
                index.put(name, new ArrayList<DataType>());
            }
            index.get(name).add(dt);
        }
        return index;
    }

    private List<DataType> allProgramDatatypes(DataTypeManager dtm) {
        List<DataType> out = new ArrayList<>();
        Iterator<DataType> it = dtm.getAllDataTypes();
        while (it.hasNext()) {
            out.add(it.next());
        }
        return out;
    }

    private boolean isTc7200uLikeCustomName(String typeName) {
        String name = normalizeTypeName(typeName);

        return name.startsWith("stage1_")
            || name.startsWith("fn_stage1_")
            || name.startsWith("tc7200_")
            || name.startsWith("vuint")
            || name.startsWith("bcm_irq_")
            || name.startsWith("bcm_periph_irq_")
            || name.startsWith("host_dqm_")
            || name.startsWith("dqm_host_")
            || name.startsWith("mta_interrupt_")
            || name.startsWith("fap_")
            || name.startsWith("dma_allocator_")
            || name.startsWith("fpm_");
    }

    private void moveDatatype(
        DataType dt,
        String targetPath,
        Map<String, Category> categoryByPath,
        DataTypeConflictHandler handler,
        String groupLabel,
        MoveStats stats
    ) {
        String typeName = dt.getName();

        try {
            if (String.valueOf(dt.getCategoryPath()).equals(targetPath)) {
                stats.inPlace++;
                return;
            }

            Category targetCat = categoryByPath.get(targetPath);
            targetCat.moveDataType(dt, handler);
            stats.moved++;
            println(String.format("moved %-70s -> %s [%s]", typeName, targetPath, groupLabel));
        }
        catch (Exception e) {
            stats.failed.add(typeName + " -> " + targetPath + " : " + e.toString());
        }
    }

    private MoveStats moveExactKnownTypes(
        Map<String, List<DataType>> nameIndex,
        Map<String, Category> categoryByPath,
        DataTypeConflictHandler handler,
        Map<String, String> mapping
    ) throws Exception {
        MoveStats stats = new MoveStats();
        List<String> typeNames = new ArrayList<>(mapping.keySet());
        Collections.sort(typeNames);

        for (String typeName : typeNames) {
            monitor.checkCanceled();
            List<DataType> found = nameIndex.get(typeName);
            if (found == null || found.isEmpty()) {
                stats.missing.add(typeName);
                continue;
            }

            for (DataType dt : found) {
                moveDatatype(dt, mapping.get(typeName), categoryByPath, handler, "exact", stats);
            }
        }

        return stats;
    }

    private MoveStats moveInferredFutureTypes(
        DataTypeManager dtm,
        Map<String, Category> categoryByPath,
        DataTypeConflictHandler handler
    ) throws Exception {
        MoveStats stats = new MoveStats();

        for (DataType dt : allProgramDatatypes(dtm)) {
            monitor.checkCanceled();
            String typeName = dt.getName();

            if (EXACT_TYPE_TO_CATEGORY.containsKey(typeName)) {
                continue;
            }

            String targetPath = inferCategoryForFutureType(typeName);
            if (targetPath == null) {
                if ("/custom".equals(String.valueOf(dt.getCategoryPath())) && isTc7200uLikeCustomName(typeName)) {
                    stats.unmatchedCustom.add(typeName);
                }
                continue;
            }

            moveDatatype(dt, targetPath, categoryByPath, handler, "inferred", stats);
        }

        return stats;
    }

    private static final class MoveStats {
        private int moved;
        private int inPlace;
        private final List<String> missing = new ArrayList<>();
        private final List<String> failed = new ArrayList<>();
        private final List<String> unmatchedCustom = new ArrayList<>();
    }
}
