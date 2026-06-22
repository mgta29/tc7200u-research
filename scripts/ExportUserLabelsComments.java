// Export user-created Ghidra labels/symbols, comments, and custom datatypes to JSON.
//@author mgta29 / ChatGPT
//@category TC7200
//@keybinding
//@menupath TC7200.Export Labels/Datatypes/Comments
//@toolbar

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.Array;
import ghidra.program.model.data.Composite;
import ghidra.program.model.data.DataType;
import ghidra.program.model.data.DataTypeComponent;
import ghidra.program.model.data.DataTypeManager;
import ghidra.program.model.data.Enum;
import ghidra.program.model.data.FunctionDefinition;
import ghidra.program.model.data.ParameterDefinition;
import ghidra.program.model.data.Pointer;
import ghidra.program.model.data.Structure;
import ghidra.program.model.data.TypeDef;
import ghidra.program.model.data.Union;
import ghidra.program.model.listing.CodeUnit;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.listing.Parameter;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolIterator;
import ghidra.program.model.symbol.SymbolTable;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class ExportUserLabelsComments extends GhidraScript {

    private static final String OUTPUT_DIR =
        "\\\\wsl.localhost\\Ubuntu\\home\\mgta29\\tc7200u-research\\records\\reverse\\exports";
    private static final String OUTPUT_FILENAME = "labels.json";

    private static final boolean EXPORT_ALL_NON_BUILTIN_DATATYPES = false;

    private static final String[] USER_DATATYPE_CATEGORY_PREFIXES = {
        "/tc7200u",
        "/custom",
    };

    private static final String[] USER_DATATYPE_NAME_PREFIXES = {
        "fn_",
        "stage1_",
        "tc7200",
        "fap_",
        "host_",
        "dqm_",
        "dma_",
        "fpm_",
        "genet_",
        "gmac_",
        "enet_",
        "unimac_",
        "bcm",
    };

    private static final String[] USER_DATATYPE_NAME_CONTAINS = {
        "_candidate",
        "TC7200",
        "GENET",
        "GMAC",
        "DQM",
        "FPM",
        "IRQ",
        "MMIO",
    };

    private static final List<String> JSON_PREFERRED_KEYS = Arrays.asList(
        "program",
        "exported_at",
        "labels",
        "datatypes",
        "address",
        "label",
        "datatype",
        "comments",
        "path",
        "category",
        "name",
        "kind",
        "length",
        "description",
        "fields",
        "members",
        "return_type",
        "arguments",
        "base_type",
        "points_to",
        "element_type",
        "element_count",
        "element_length",
        "ordinal",
        "offset",
        "value"
    );

    private static final String[] BASIC_NAMES = {
        "undefined", "undefined1", "undefined2", "undefined3", "undefined4",
        "undefined5", "undefined6", "undefined7", "undefined8",
        "byte", "word", "dword", "qword",
        "char", "uchar", "short", "ushort", "int", "uint",
        "long", "ulong", "longlong", "ulonglong",
        "float", "double", "void", "bool", "string",
    };

    private List<CommentKind> commentKinds;

    @Override
    protected void run() throws Exception {
        commentKinds = buildCommentKinds();

        String jsonPath = makeOutputPath();
        List<Map<String, Object>> labels = collectLabels();
        List<Map<String, Object>> datatypes = collectDatatypes();

        Map<String, Object> root = new LinkedHashMap<>();
        root.put("program", text(currentProgram.getName()));
        root.put("exported_at", timestampNow());
        root.put("labels", stripInternalKeys(labels));
        root.put("datatypes", stripInternalKeys(datatypes));

        writeJson(new File(jsonPath), root);

        println("Exported " + labels.size() + " USER_DEFINED labels");
        println("Exported " + datatypes.size() + " custom datatypes");
        println("JSON: " + jsonPath);
    }

    private List<CommentKind> buildCommentKinds() {
        List<CommentKind> kinds = new ArrayList<>();
        try {
            Class<?> commentTypeClass = Class.forName("ghidra.program.model.listing.CommentType");
            kinds.add(new CommentKind("plate", commentTypeClass.getField("PLATE").get(null)));
            kinds.add(new CommentKind("pre", commentTypeClass.getField("PRE").get(null)));
            kinds.add(new CommentKind("eol", commentTypeClass.getField("EOL").get(null)));
            kinds.add(new CommentKind("repeatable", commentTypeClass.getField("REPEATABLE").get(null)));
            kinds.add(new CommentKind("post", commentTypeClass.getField("POST").get(null)));
            return kinds;
        }
        catch (Exception e) {
            kinds.add(new CommentKind("plate", Integer.valueOf(CodeUnit.PLATE_COMMENT)));
            kinds.add(new CommentKind("pre", Integer.valueOf(CodeUnit.PRE_COMMENT)));
            kinds.add(new CommentKind("eol", Integer.valueOf(CodeUnit.EOL_COMMENT)));
            kinds.add(new CommentKind("repeatable", Integer.valueOf(CodeUnit.REPEATABLE_COMMENT)));
            kinds.add(new CommentKind("post", Integer.valueOf(CodeUnit.POST_COMMENT)));
            return kinds;
        }
    }

    private List<Map<String, Object>> collectLabels() throws Exception {
        SymbolTable symbolTable = currentProgram.getSymbolTable();
        SymbolIterator symbols = symbolTable.getAllSymbols(true);
        List<Map<String, Object>> rows = new ArrayList<>();

        while (symbols.hasNext()) {
            monitor.checkCanceled();
            Symbol sym = symbols.next();

            try {
                if (sym.getSource() != SourceType.USER_DEFINED) {
                    continue;
                }
            }
            catch (Exception e) {
                continue;
            }

            try {
                if (sym.isDynamic()) {
                    continue;
                }
            }
            catch (Exception e) {
                // ignore
            }

            Address addr = sym.getAddress();
            if (addr == null) {
                continue;
            }

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("_sort_offset", Long.valueOf(offsetOrZero(addr)));
            row.put("address", text(addr));
            row.put("label", symbolFullName(sym));
            row.put("datatype", datatypeAtSymbolAddress(addr));
            row.put("comments", combinedComments(addr));
            rows.add(row);
        }

        Collections.sort(rows, new Comparator<Map<String, Object>>() {
            @Override
            public int compare(Map<String, Object> a, Map<String, Object> b) {
                long ao = longValue(a.get("_sort_offset"), 0L);
                long bo = longValue(b.get("_sort_offset"), 0L);
                if (ao != bo) {
                    return Long.compare(ao, bo);
                }
                return stringValue(a.get("label")).compareTo(stringValue(b.get("label")));
            }
        });

        return rows;
    }

    private List<Map<String, Object>> collectDatatypes() throws Exception {
        List<Map<String, Object>> rows = new ArrayList<>();
        DataTypeManager dtm = currentProgram.getDataTypeManager();

        for (DataType dt : allDatatypesFromManager(dtm)) {
            monitor.checkCanceled();
            if (!isUserDatatype(dt)) {
                continue;
            }
            rows.add(datatypeRecord(dt));
        }

        Collections.sort(rows, new Comparator<Map<String, Object>>() {
            @Override
            public int compare(Map<String, Object> a, Map<String, Object> b) {
                return stringValue(a.get("_sort_path")).compareTo(stringValue(b.get("_sort_path")));
            }
        });

        return rows;
    }

    private List<DataType> allDatatypesFromManager(DataTypeManager dtm) {
        List<DataType> dts = new ArrayList<>();
        try {
            Iterator<DataType> it = dtm.getAllDataTypes();
            while (it.hasNext()) {
                dts.add(it.next());
            }
            return dts;
        }
        catch (Exception e) {
            return dts;
        }
    }

    private boolean isUserDatatype(DataType dt) {
        if (isBuiltinOrNoiseDatatype(dt)) {
            return false;
        }

        if (EXPORT_ALL_NON_BUILTIN_DATATYPES) {
            return true;
        }

        String name = datatypeName(dt);
        String lower = name.toLowerCase();
        String cat = datatypeCategory(dt);

        for (String prefix : USER_DATATYPE_CATEGORY_PREFIXES) {
            if (cat.startsWith(prefix)) {
                return true;
            }
        }

        for (String prefix : USER_DATATYPE_NAME_PREFIXES) {
            if (lower.startsWith(prefix.toLowerCase())) {
                return true;
            }
        }

        for (String token : USER_DATATYPE_NAME_CONTAINS) {
            if (lower.contains(token.toLowerCase())) {
                return true;
            }
        }

        return false;
    }

    private boolean isBuiltinOrNoiseDatatype(DataType dt) {
        String name = datatypeName(dt);
        String cat = datatypeCategory(dt);
        String path = datatypePath(dt);
        String kind = datatypeKind(dt);

        if (name.isEmpty()) {
            return true;
        }

        for (String basic : BASIC_NAMES) {
            if (basic.equals(name)) {
                return true;
            }
        }

        if (cat.startsWith("/BuiltIn") || cat.startsWith("/builtin")) {
            return true;
        }
        if (path.startsWith("/BuiltIn") || path.startsWith("/builtin")) {
            return true;
        }
        if ("BuiltInDataType".equals(kind) || "DefaultDataType".equals(kind)) {
            return true;
        }
        if (dt instanceof Pointer || dt instanceof Array) {
            return true;
        }

        return false;
    }

    private Map<String, Object> datatypeRecord(DataType dt) throws Exception {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("_sort_path", datatypePath(dt));
        row.put("path", datatypePath(dt));
        row.put("category", datatypeCategory(dt));
        row.put("name", datatypeName(dt));
        row.put("kind", datatypeKind(dt));
        row.put("length", datatypeLength(dt));
        row.put("description", datatypeDescription(dt));

        if (dt instanceof Structure || dt instanceof Union || dt instanceof Composite) {
            row.put("fields", datatypeFields(dt));
        }

        if (dt instanceof Enum) {
            row.put("members", enumMembers((Enum) dt));
        }

        if (dt instanceof FunctionDefinition) {
            FunctionDefinition fd = (FunctionDefinition) dt;
            row.put("return_type", datatypePath(fd.getReturnType()));
            row.put("arguments", functionDefArgs(fd));
        }

        if (dt instanceof TypeDef) {
            TypeDef td = (TypeDef) dt;
            row.put("base_type", datatypePath(td.getBaseDataType()));
        }

        return row;
    }

    private List<Map<String, Object>> datatypeFields(DataType dt) throws Exception {
        List<Map<String, Object>> fields = new ArrayList<>();
        DataTypeComponent[] components;
        try {
            components = ((Composite) dt).getComponents();
        }
        catch (Exception e) {
            return fields;
        }

        for (DataTypeComponent component : components) {
            monitor.checkCanceled();
            fields.add(componentRow(component));
        }

        return fields;
    }

    private Map<String, Object> componentRow(DataTypeComponent component) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("ordinal", intOrNull(call0(component, "getOrdinal")));
        row.put("offset", offsetHex(component));
        row.put("name", text(call0(component, "getFieldName")));
        row.put("datatype", datatypePath(component.getDataType()));
        row.put("length", intOrNull(call0(component, "getLength")));
        row.put("comments", text(call0(component, "getComment")));
        return row;
    }

    private String offsetHex(DataTypeComponent component) {
        Integer offset = intOrNull(call0(component, "getOffset"));
        if (offset == null) {
            return null;
        }
        return String.format("0x%x", offset.intValue());
    }

    private List<Map<String, Object>> enumMembers(Enum dt) throws Exception {
        List<Map<String, Object>> members = new ArrayList<>();
        String[] names;
        try {
            names = dt.getNames();
        }
        catch (Exception e) {
            return members;
        }

        for (String name : names) {
            Object value;
            try {
                value = Long.valueOf(dt.getValue(name));
            }
            catch (Exception e) {
                value = null;
            }

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("name", text(name));
            row.put("value", value);
            members.add(row);
        }

        Collections.sort(members, new Comparator<Map<String, Object>>() {
            @Override
            public int compare(Map<String, Object> a, Map<String, Object> b) {
                long av = longValue(a.get("value"), 0L);
                long bv = longValue(b.get("value"), 0L);
                if (av != bv) {
                    return Long.compare(av, bv);
                }
                return stringValue(a.get("name")).compareTo(stringValue(b.get("name")));
            }
        });

        return members;
    }

    private List<Map<String, Object>> functionDefArgs(FunctionDefinition dt) throws Exception {
        List<Map<String, Object>> args = new ArrayList<>();
        ParameterDefinition[] arguments;
        try {
            arguments = dt.getArguments();
        }
        catch (Exception e) {
            return args;
        }

        for (ParameterDefinition arg : arguments) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("name", text(arg.getName()));
            row.put("datatype", datatypePath(arg.getDataType()));
            row.put("comments", text(call0(arg, "getComment")));
            args.add(row);
        }

        return args;
    }

    private String datatypeAtSymbolAddress(Address address) {
        Listing listing = currentProgram.getListing();

        try {
            Function func = currentProgram.getFunctionManager().getFunctionAt(address);
            if (func != null) {
                return formatFunctionSignature(func);
            }
        }
        catch (Exception e) {
            // ignore
        }

        try {
            Data data = listing.getDataAt(address);
            if (data != null) {
                return datatypePath(data.getDataType());
            }
        }
        catch (Exception e) {
            // ignore
        }

        try {
            Data data = listing.getDataContaining(address);
            if (data != null) {
                long delta = offsetOrZero(address) - offsetOrZero(data.getAddress());
                if (delta > 0) {
                    return datatypePath(data.getDataType()) + String.format(" +0x%x", delta);
                }
                return datatypePath(data.getDataType());
            }
        }
        catch (Exception e) {
            // ignore
        }

        try {
            if (listing.getInstructionAt(address) != null) {
                return "instruction";
            }
        }
        catch (Exception e) {
            // ignore
        }

        return "";
    }

    private String combinedComments(Address address) {
        List<String> parts = new ArrayList<>();
        String listingComment = getListingComments(address);
        String functionComment = getFunctionComments(address);

        if (!listingComment.isEmpty()) {
            parts.add(listingComment);
        }
        if (!functionComment.isEmpty()) {
            parts.add(functionComment);
        }

        return String.join("\n", parts);
    }

    private String getListingComments(Address address) {
        Listing listing = currentProgram.getListing();
        List<String> out = new ArrayList<>();

        for (CommentKind kind : commentKinds) {
            String txt = invokeListingComment(listing, kind.token, address);
            if (txt != null && !txt.isEmpty()) {
                out.add(kind.name + ": " + txt);
            }
        }

        return String.join("\n", out);
    }

    private String invokeListingComment(Listing listing, Object token, Address address) {
        for (Method method : listing.getClass().getMethods()) {
            if (!"getComment".equals(method.getName()) || method.getParameterCount() != 2) {
                continue;
            }
            try {
                Object value = method.invoke(listing, token, address);
                return text(value);
            }
            catch (Exception e) {
                // try next overload
            }
        }
        return null;
    }

    private String getFunctionComments(Address address) {
        Function func;
        try {
            func = currentProgram.getFunctionManager().getFunctionAt(address);
        }
        catch (Exception e) {
            func = null;
        }

        if (func == null) {
            return "";
        }

        List<String> parts = new ArrayList<>();
        String comment = text(func.getComment());
        String repeatable = text(func.getRepeatableComment());

        if (!comment.isEmpty()) {
            parts.add("function: " + comment);
        }
        if (!repeatable.isEmpty()) {
            parts.add("function_repeatable: " + repeatable);
        }

        return String.join("\n", parts);
    }

    private String formatFunctionSignature(Function func) {
        String ret;
        try {
            ret = datatypePath(func.getReturnType());
        }
        catch (Exception e) {
            ret = "";
        }

        List<String> args = new ArrayList<>();
        Parameter[] params;
        try {
            params = func.getParameters();
        }
        catch (Exception e) {
            params = new Parameter[0];
        }

        for (Parameter p : params) {
            String pname = text(p.getName());
            String ptype;
            try {
                ptype = datatypePath(p.getDataType());
            }
            catch (Exception e) {
                ptype = "";
            }

            if (!pname.isEmpty() && !ptype.isEmpty()) {
                args.add(ptype + " " + pname);
            }
            else if (!ptype.isEmpty()) {
                args.add(ptype);
            }
            else if (!pname.isEmpty()) {
                args.add(pname);
            }
        }

        return "function: " + ret + " (" + String.join(", ", args) + ")";
    }

    private long offsetOrZero(Address address) {
        if (address == null) {
            return 0L;
        }
        try {
            return address.getOffset();
        }
        catch (Exception e) {
            return 0L;
        }
    }

    private String symbolFullName(Symbol symbol) {
        try {
            return text(symbol.getName(true));
        }
        catch (Exception e) {
            return text(symbol.getName());
        }
    }

    private String datatypeCategory(DataType dt) {
        try {
            if (dt.getCategoryPath() == null) {
                return "";
            }
            return text(dt.getCategoryPath().getPath());
        }
        catch (Exception e) {
            return "";
        }
    }

    private String datatypePath(DataType dt) {
        if (dt == null) {
            return "";
        }
        try {
            return text(dt.getPathName());
        }
        catch (Exception e) {
            String cat = datatypeCategory(dt);
            String name = datatypeName(dt);
            if (!cat.isEmpty() && !"/".equals(cat)) {
                return cat + "/" + name;
            }
            return name;
        }
    }

    private String datatypeName(DataType dt) {
        if (dt == null) {
            return "";
        }
        try {
            return text(dt.getName());
        }
        catch (Exception e) {
            return text(dt);
        }
    }

    private String datatypeKind(DataType dt) {
        try {
            return text(dt.getClass().getSimpleName());
        }
        catch (Exception e) {
            return text(dt.getClass().getName());
        }
    }

    private Integer datatypeLength(DataType dt) {
        try {
            return Integer.valueOf(dt.getLength());
        }
        catch (Exception e) {
            return null;
        }
    }

    private String datatypeDescription(DataType dt) {
        try {
            return text(dt.getDescription());
        }
        catch (Exception e) {
            return "";
        }
    }

    private List<Map<String, Object>> stripInternalKeys(List<Map<String, Object>> rows) {
        List<Map<String, Object>> clean = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            Map<String, Object> out = new LinkedHashMap<>();
            for (Map.Entry<String, Object> entry : row.entrySet()) {
                if (!entry.getKey().startsWith("_")) {
                    out.put(entry.getKey(), entry.getValue());
                }
            }
            clean.add(out);
        }
        return clean;
    }

    private String timestampNow() {
        return new SimpleDateFormat("yyyyMMdd-HHmmss").format(new Date());
    }

    private String makeOutputPath() throws Exception {
        File outDir = new File(OUTPUT_DIR);
        if (!outDir.exists() && !outDir.mkdirs()) {
            throw new Exception("Unable to create output directory: " + outDir.getPath());
        }
        return new File(outDir, OUTPUT_FILENAME).getAbsolutePath();
    }

    private void writeJson(File path, Object root) throws Exception {
        try (Writer writer = new OutputStreamWriter(new FileOutputStream(path), StandardCharsets.UTF_8)) {
            writer.write(toJson(root, 0));
            writer.write("\n");
        }
    }

    private String toJson(Object value, int indent) {
        if (value == null) {
            return "null";
        }
        if (value instanceof Boolean || value instanceof Number) {
            return String.valueOf(value);
        }
        if (value instanceof List<?>) {
            return jsonArray((List<?>) value, indent);
        }
        if (value instanceof Map<?, ?>) {
            return jsonObject((Map<?, ?>) value, indent);
        }
        return jsonEscape(stringValue(value));
    }

    private String jsonArray(List<?> values, int indent) {
        if (values.isEmpty()) {
            return "[]";
        }
        StringBuilder sb = new StringBuilder();
        sb.append("[\n");
        for (int i = 0; i < values.size(); i++) {
            sb.append(spaces(indent + 2));
            sb.append(toJson(values.get(i), indent + 2));
            if (i + 1 < values.size()) {
                sb.append(",");
            }
            sb.append("\n");
        }
        sb.append(spaces(indent));
        sb.append("]");
        return sb.toString();
    }

    private String jsonObject(Map<?, ?> obj, int indent) {
        List<String> keys = orderedKeys(obj);
        if (keys.isEmpty()) {
            return "{}";
        }

        StringBuilder sb = new StringBuilder();
        sb.append("{\n");
        for (int i = 0; i < keys.size(); i++) {
            String key = keys.get(i);
            sb.append(spaces(indent + 2));
            sb.append(jsonEscape(key));
            sb.append(": ");
            sb.append(toJson(obj.get(key), indent + 2));
            if (i + 1 < keys.size()) {
                sb.append(",");
            }
            sb.append("\n");
        }
        sb.append(spaces(indent));
        sb.append("}");
        return sb.toString();
    }

    private List<String> orderedKeys(Map<?, ?> obj) {
        List<String> keys = new ArrayList<>();
        for (String preferred : JSON_PREFERRED_KEYS) {
            if (obj.containsKey(preferred)) {
                keys.add(preferred);
            }
        }

        List<String> extra = new ArrayList<>();
        for (Object keyObj : obj.keySet()) {
            String key = String.valueOf(keyObj);
            if (!keys.contains(key) && !key.startsWith("_")) {
                extra.add(key);
            }
        }
        Collections.sort(extra);
        keys.addAll(extra);
        return keys;
    }

    private String jsonEscape(String value) {
        StringBuilder sb = new StringBuilder();
        sb.append("\"");
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            switch (c) {
                case '"':
                    sb.append("\\\"");
                    break;
                case '\\':
                    sb.append("\\\\");
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

    private String spaces(int count) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < count; i++) {
            sb.append(' ');
        }
        return sb.toString();
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

    private Integer intOrNull(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number) {
            return Integer.valueOf(((Number) value).intValue());
        }
        try {
            return Integer.valueOf(String.valueOf(value));
        }
        catch (Exception e) {
            return null;
        }
    }

    private long longValue(Object value, long defaultValue) {
        if (value == null) {
            return defaultValue;
        }
        if (value instanceof Number) {
            return ((Number) value).longValue();
        }
        try {
            return Long.parseLong(String.valueOf(value));
        }
        catch (Exception e) {
            return defaultValue;
        }
    }

    private String text(Object value) {
        if (value == null) {
            return "";
        }
        try {
            return String.valueOf(value);
        }
        catch (Exception e) {
            return "<unprintable>";
        }
    }

    private String stringValue(Object value) {
        return value == null ? "" : text(value);
    }

    private static final class CommentKind {
        private final String name;
        private final Object token;

        private CommentKind(String name, Object token) {
            this.name = name;
            this.token = token;
        }
    }
}
