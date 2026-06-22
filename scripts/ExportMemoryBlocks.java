// TC7200U memory-block exporter
//@author mgta29 / ChatGPT
//@category TC7200
//@keybinding
//@menupath TC7200.Export memory blocks
//@toolbar

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryBlock;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class ExportMemoryBlocks extends GhidraScript {

    private static final String OUTPUT_DIR =
        "\\\\wsl.localhost\\Ubuntu\\home\\mgta29\\tc7200u-research\\records\\reverse\\exports";
    private static final String OUTPUT_NAME = "memoryblock.json";
    private static final String SCHEMA = "tc7200u-ghidra-memoryblock-export-v1";

    @Override
    protected void run() throws Exception {
        try {
            main();
        }
        catch (Exception e) {
            println("TC7200U memory-block export FAILED");
            println(stackTraceText(e));
            throw e;
        }
    }

    private void main() throws Exception {
        File outDir = new File(OUTPUT_DIR);
        if (!outDir.isDirectory() && !outDir.mkdirs()) {
            throw new Exception("Unable to create output directory: " + outDir.getPath());
        }

        List<Map<String, Object>> blocks = collectMemoryBlocks();
        File outputPath = new File(outDir, OUTPUT_NAME);

        Map<String, Object> report = new LinkedHashMap<>();
        report.put("schema", SCHEMA);
        report.put(
            "generated_at",
            LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss"))
        );
        report.put("program", collectProgramInfo());
        report.put("output_path", outputPath.getPath());
        report.put("block_count", blocks.size());
        report.put("blocks", blocks);

        writeJson(outputPath, report);

        println("");
        println("TC7200U memory-block export finished");
        println("output:      " + outputPath.getPath());
        println("block_count: " + blocks.size());
        println("");
    }

    private Map<String, Object> collectProgramInfo() {
        Map<String, Object> info = new LinkedHashMap<>();
        Address imageBase = currentProgram.getImageBase();

        info.put("name", toText(currentProgram.getName()));
        info.put("executable_path", toText(call0(currentProgram, "getExecutablePath")));
        info.put("image_base", addrText(imageBase));
        info.put("image_base_offset", addrOffset(imageBase));

        try {
            info.put("language_id", toText(currentProgram.getLanguageID()));
        }
        catch (Exception e) {
            info.put("language_id", null);
        }

        try {
            info.put("compiler_spec_id", toText(currentProgram.getCompilerSpec().getCompilerSpecID()));
        }
        catch (Exception e) {
            info.put("compiler_spec_id", null);
        }

        return info;
    }

    private List<Map<String, Object>> collectMemoryBlocks() throws Exception {
        Memory memory = currentProgram.getMemory();
        MemoryBlock[] blocks = memory.getBlocks();
        List<MemoryBlock> sortedBlocks = new ArrayList<>(Arrays.asList(blocks));
        Collections.sort(sortedBlocks, new Comparator<MemoryBlock>() {
            @Override
            public int compare(MemoryBlock a, MemoryBlock b) {
                return Long.compare(addrOffset(a.getStart()), addrOffset(b.getStart()));
            }
        });

        List<Map<String, Object>> rows = new ArrayList<>();
        for (int index = 0; index < sortedBlocks.size(); index++) {
            monitor.checkCanceled();

            MemoryBlock block = sortedBlocks.get(index);
            Address start = block.getStart();
            Address end = block.getEnd();
            Long startOffset = addrOffset(start);
            Long endOffset = addrOffset(end);
            Object sizeValue = call0(block, "getSize");
            Long size = longOrNull(sizeValue);

            String addressSpace = null;
            try {
                addressSpace = toText(start.getAddressSpace().getName());
            }
            catch (Exception e) {
                addressSpace = null;
            }

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("index", index);
            row.put("name", toText(block.getName()));
            row.put("start", addrText(start));
            row.put("end", addrText(end));
            row.put("start_offset", startOffset);
            row.put("end_offset", endOffset);
            row.put("start_hex", hexOrNone(startOffset));
            row.put("end_hex", hexOrNone(endOffset));
            row.put("size", size == null ? sizeValue : size);
            row.put("size_hex", size == null ? null : hexOrNone(size));
            row.put("address_space", addressSpace);
            row.put("permissions", blockPermissions(block));
            row.put("read", safeBool(block, "isRead"));
            row.put("write", safeBool(block, "isWrite"));
            row.put("execute", safeBool(block, "isExecute"));
            row.put("volatile", safeBool(block, "isVolatile"));
            row.put("artificial", safeBool(block, "isArtificial"));
            row.put("initialized", safeBool(block, "isInitialized"));
            row.put("loaded", safeBool(block, "isLoaded"));
            row.put("overlay", safeBool(block, "isOverlay"));
            row.put("mapped", safeBool(block, "isMapped"));
            row.put("type", toText(call0(block, "getType")));
            row.put("source_name", toText(call0(block, "getSourceName")));
            row.put("comment", toText(call0(block, "getComment")));
            row.put("source_infos", sourceInfosForBlock(block));

            rows.add(row);
        }

        return rows;
    }

    private String blockPermissions(MemoryBlock block) {
        StringBuilder sb = new StringBuilder();
        if (Boolean.TRUE.equals(safeBool(block, "isRead"))) {
            sb.append("r");
        }
        if (Boolean.TRUE.equals(safeBool(block, "isWrite"))) {
            sb.append("w");
        }
        if (Boolean.TRUE.equals(safeBool(block, "isExecute"))) {
            sb.append("x");
        }
        if (Boolean.TRUE.equals(safeBool(block, "isVolatile"))) {
            sb.append("v");
        }
        return sb.toString();
    }

    private List<Map<String, Object>> sourceInfosForBlock(MemoryBlock block) {
        List<Map<String, Object>> rows = new ArrayList<>();
        Object infosObj = call0(block, "getSourceInfos");
        if (infosObj == null) {
            return rows;
        }

        try {
            for (Object info : toObjectList(infosObj)) {
                Map<String, Object> row = new LinkedHashMap<>();
                Object fileBytesOffset = call0(info, "getFileBytesOffset");
                Object length = call0(info, "getLength");

                row.put("description", toText(info));
                row.put("file_bytes", toText(call0(info, "getFileBytes")));
                row.put("file_bytes_offset", longOrNull(fileBytesOffset));
                row.put("length", longOrNull(length));
                row.put("mapped", safeBool(info, "isMapped"));
                row.put("file_bytes_offset_hex", hexOrNone(longOrNull(fileBytesOffset)));
                row.put("length_hex", hexOrNone(longOrNull(length)));
                rows.add(row);
            }
        }
        catch (Exception e) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("description", toText(infosObj));
            row.put("parse_error", stackTraceText(e));
            rows.add(row);
        }

        return rows;
    }

    private String toText(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return String.valueOf(value);
        }
        catch (Exception e) {
            return "<unprintable>";
        }
    }

    private String addrText(Address addr) {
        if (addr == null) {
            return null;
        }
        return toText(addr);
    }

    private Long addrOffset(Address addr) {
        if (addr == null) {
            return null;
        }
        try {
            return Long.valueOf(addr.getOffset());
        }
        catch (Exception e) {
            return null;
        }
    }

    private String hexOrNone(Long value) {
        if (value == null) {
            return null;
        }
        return String.format("0x%08x", value.longValue());
    }

    private Object call0(Object obj, String methodName) {
        if (obj == null) {
            return null;
        }
        try {
            Method method = obj.getClass().getMethod(methodName);
            method.setAccessible(true);
            return method.invoke(obj);
        }
        catch (Exception e) {
            return null;
        }
    }

    private Boolean safeBool(Object obj, String methodName) {
        Object value = call0(obj, methodName);
        if (value == null) {
            return null;
        }
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        if (value instanceof Number) {
            return ((Number) value).intValue() != 0;
        }
        return null;
    }

    private Long longOrNull(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number) {
            return Long.valueOf(((Number) value).longValue());
        }
        try {
            return Long.valueOf(String.valueOf(value));
        }
        catch (Exception e) {
            return null;
        }
    }

    private List<Object> toObjectList(Object value) {
        List<Object> out = new ArrayList<>();
        if (value == null) {
            return out;
        }
        if (value instanceof Iterable<?>) {
            for (Object item : (Iterable<?>) value) {
                out.add(item);
            }
            return out;
        }
        if (value.getClass().isArray()) {
            int len = java.lang.reflect.Array.getLength(value);
            for (int i = 0; i < len; i++) {
                out.add(java.lang.reflect.Array.get(value, i));
            }
            return out;
        }
        out.add(value);
        return out;
    }

    private void writeJson(File path, Object obj) throws Exception {
        try (Writer writer = new OutputStreamWriter(new FileOutputStream(path), StandardCharsets.UTF_8)) {
            writer.write(toJson(obj, 0));
            writer.write("\n");
        }
    }

    private String toJson(Object value, int indentLevel) {
        if (value == null) {
            return "null";
        }
        if (value instanceof String) {
            return jsonString((String) value);
        }
        if (value instanceof Number || value instanceof Boolean) {
            return String.valueOf(value);
        }
        if (value instanceof Map<?, ?>) {
            return mapToJson((Map<?, ?>) value, indentLevel);
        }
        if (value instanceof List<?>) {
            return listToJson((List<?>) value, indentLevel);
        }
        return jsonString(String.valueOf(value));
    }

    private String mapToJson(Map<?, ?> map, int indentLevel) {
        if (map.isEmpty()) {
            return "{}";
        }

        List<String> keys = new ArrayList<>();
        for (Object key : map.keySet()) {
            keys.add(String.valueOf(key));
        }
        Collections.sort(keys);

        StringBuilder sb = new StringBuilder();
        sb.append("{\n");
        for (int i = 0; i < keys.size(); i++) {
            String key = keys.get(i);
            sb.append(indent(indentLevel + 1));
            sb.append(jsonString(key));
            sb.append(": ");
            sb.append(toJson(map.get(key), indentLevel + 1));
            if (i + 1 < keys.size()) {
                sb.append(",");
            }
            sb.append("\n");
        }
        sb.append(indent(indentLevel));
        sb.append("}");
        return sb.toString();
    }

    private String listToJson(List<?> list, int indentLevel) {
        if (list.isEmpty()) {
            return "[]";
        }

        StringBuilder sb = new StringBuilder();
        sb.append("[\n");
        for (int i = 0; i < list.size(); i++) {
            sb.append(indent(indentLevel + 1));
            sb.append(toJson(list.get(i), indentLevel + 1));
            if (i + 1 < list.size()) {
                sb.append(",");
            }
            sb.append("\n");
        }
        sb.append(indent(indentLevel));
        sb.append("]");
        return sb.toString();
    }

    private String indent(int level) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < level; i++) {
            sb.append("  ");
        }
        return sb.toString();
    }

    private String jsonString(String value) {
        StringBuilder sb = new StringBuilder();
        sb.append("\"");
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            switch (c) {
                case '\\':
                    sb.append("\\\\");
                    break;
                case '"':
                    sb.append("\\\"");
                    break;
                case '\b':
                    sb.append("\\b");
                    break;
                case '\f':
                    sb.append("\\f");
                    break;
                case '\n':
                    sb.append("\\n");
                    break;
                case '\r':
                    sb.append("\\r");
                    break;
                case '\t':
                    sb.append("\\t");
                    break;
                default:
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    }
                    else {
                        sb.append(c);
                    }
                    break;
            }
        }
        sb.append("\"");
        return sb.toString();
    }

    private String stackTraceText(Exception exception) {
        StringBuilder sb = new StringBuilder();
        sb.append(exception.toString()).append("\n");
        for (StackTraceElement element : exception.getStackTrace()) {
            sb.append("    at ").append(element.toString()).append("\n");
        }
        return sb.toString();
    }
}
