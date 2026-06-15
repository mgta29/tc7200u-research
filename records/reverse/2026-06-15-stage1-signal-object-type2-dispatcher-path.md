# Stage1 signal-object type2 dispatcher path log

Date: 2026-06-15  
Project: TC7200U / BCM3383 Stage1 reverse engineering  
Focus range: `80ef7374..80ef8088`  
Output file: `2026-06-15-stage1-signal-object-type2-dispatcher-path.md`

## Scope

This log captures the current reverse-engineering pass over the Stage1 signal-object provider/create/clone/type2-dispatcher path.

Covered functions:

- `80ef7374`
- `80ef74ec`
- `80ef767c`
- `80ef7760`
- `80ef7844`
- `80ef792c`
- `80ef7a14`
- `80ef7b18`
- `80ef7bec`
- `80ef7ce8`
- `80ef7e30`
- `80ef7e50`
- `80ef7f48`
- `80ef8088`

Primary work completed:

- Function labeling and improved signatures.
- Type2 ops table layout expansion.
- Callback typedef creation.
- Signal-object structure corrections.
- Provider/create path correction.
- Clone path correction.
- Stack request wrapper analysis.
- Identification of bogus Ghidra-created function boundaries.

No firmware behavior was changed. This is Ghidra labeling, datatype, signature, and documentation work only.

## Status

Estimated progress on this subpath: **about 75%**.

| Area | Status | Estimate |
|---|---:|---:|
| Signal-object table/ref/unref/insert/release helpers | Mostly resolved | 90% |
| Provider-table create path `80ef7374` | Good working model | 80% |
| Clone-from-existing type2 path `80ef74ec` | Good working model | 85% |
| Type2 pre/post lock helper signatures | Good enough | 75% |
| Type2 ops dispatcher wrappers | Mostly mapped | 80% |
| `stage1_signal_object_candidate` structure | Good but still partial | 75% |
| `stage1_signal_object_type2_ops_candidate` structure | Partial but useful | 70% |
| Real callback implementation semantics | Mostly unresolved | 20% |
| Request-record semantic meaning | Provisional | 25% |

High confidence:

- Invalid signal-object index status is `9`.
- Signal-object allocation failure status is `0x17`.
- Signal-object table index reservation failure status is `0x18`.
- Type2 dispatcher wrappers gate on `stage1_signal_object_candidate.type_or_mode_06_candidate == 2`.
- Type2 dispatchers use `stage1_signal_object_candidate.type2_ops_18_candidate`.
- Callback return `0` means success; nonzero callback status is copied into errno/status slot and wrapper returns `-1`.
- Non-type2 objects are usually treated as no-op success by dispatcher wrappers.
- Several wrappers use nonstandard MIPS register inputs (`t0`, `t1`) and these must not be modeled as normal C arguments without a custom calling convention.

Still provisional:

- Exact public/API names.
- Semantic meaning of individual callback slots.
- Complete object family represented by type2 signal objects.
- Exact request-record field meanings.
- Complete type2 ops layout beyond observed offsets.
- Whether offsets `+0x14`, `+0x1c`, and offsets beyond `+0x24` are callbacks, fields, or unused holes.

## Important Ghidra cleanup

Two bogus Ghidra function boundaries were identified.

Delete these as **Function only**, not bytes/code:

```text
80ef7840
80ef7d80
```

Reason:

- `80ef7840` is the delay-slot instruction after `80ef7760`'s `jr ra`.
- `80ef7d80` is an internal branch target inside `80ef7ce8`.

Do not patch bytes. Do not delete code. Only remove the incorrect function definitions.

## Structure updates

### `stage1_signal_object_candidate`

Important confirmed/provisional fields:

```c
typedef struct stage1_signal_object_candidate {
    uint flags_00;                                              /* +0x00 */
    ushort refcount_04;                                         /* +0x04 */
    ushort type_or_mode_06_candidate;                           /* +0x06 */
    uint flags_08_candidate;                                    /* +0x08 */
    stage1_signal_ops_or_class_candidate *ops_or_class_0c;      /* +0x0c */
    undefined4 field_10;                                        /* +0x10 */
    undefined4 field_14;                                        /* +0x14 */
    stage1_signal_object_type2_ops_candidate *type2_ops_18_candidate; /* +0x18 */
    void *provider_or_related_entry_1c_candidate;               /* +0x1c */
} stage1_signal_object_candidate; /* size 0x20 */
```

Notes:

- `+0x06 == 2` gates the type2 dispatcher family.
- `+0x18` is used as a type2 ops table pointer when `+0x06 == 2`.
- `+0x1c` must stay broad as `provider_or_related_entry_1c_candidate`; the provider create path stores a provider-table pointer there, while older analysis had treated it too narrowly.

### `stage1_signal_object_provider_entry_candidate`

Provider table range proven in this pass:

```text
start  = 8183fbf8
end    = 8183fc18
stride = 0x20
count  = 1 currently proven by loop bounds
```

Working layout:

```c
typedef struct stage1_signal_object_provider_entry_candidate {
    undefined4 field_00_candidate;       /* +0x00 */
    uint flags_or_mode_04_candidate;     /* +0x04 copied into signal_object +0x08 on success */
    undefined1 pad_08[0x10];             /* +0x08..+0x17 */
    undefined4 create_callback_18;       /* +0x18 call target, receives new object in t0 */
    undefined1 pad_1c[0x04];             /* +0x1c..+0x1f */
} stage1_signal_object_provider_entry_candidate; /* size 0x20 */
```

Memory labels:

```text
8183fbf8 -> g_stage1_signal_object_provider_table_8183fbf8_candidate
8183fc18 -> g_stage1_signal_object_provider_table_end_8183fc18_candidate
```

Apply as:

```c
stage1_signal_object_provider_entry_candidate[1]
```

Do not expand the array until another loop/xref proves more entries.

### `stage1_signal_object_type2_ops_candidate`

Current working map:

```c
typedef struct stage1_signal_object_type2_ops_candidate {
    stage1_signal_object_type2_callback_00_cb *callback_00_candidate;       /* +0x00 */
    stage1_signal_object_type2_callback_04_cb *callback_04_candidate;       /* +0x04 */
    stage1_signal_object_type2_clone_callback_08_cb *clone_callback_08;     /* +0x08 */
    stage1_signal_object_type2_callback_0c_cb *callback_0c_candidate;       /* +0x0c */
    stage1_signal_object_type2_callback_10_cb *callback_10_candidate;       /* +0x10 */
    undefined4 field_14_candidate;                                         /* +0x14 */
    stage1_signal_object_type2_callback_18_cb *callback_18_t0_candidate;    /* +0x18 */
    undefined4 field_1c_candidate;                                         /* +0x1c */
    stage1_signal_object_type2_callback_20_cb *callback_20_out_candidate;   /* +0x20 */
    stage1_signal_object_type2_callback_24_cb *callback_24_out_candidate;   /* +0x24 */
} stage1_signal_object_type2_ops_candidate; /* size at least 0x28 */
```

Unresolved fields:

```text
+0x14
+0x1c
possible offsets beyond +0x24
```

Do not guess names for these yet.

## Callback typedefs

```c
typedef int stage1_signal_object_type2_callback_00_cb
        (stage1_signal_object_candidate *signal_object,
         char *op_arg0,
         int *op_arg1);

typedef int stage1_signal_object_type2_callback_04_cb
        (stage1_signal_object_candidate *signal_object,
         char *op_arg0,
         int *op_arg1);

typedef int stage1_signal_object_type2_clone_callback_08_cb
        (stage1_signal_object_candidate *source_object,
         stage1_signal_object_candidate *new_signal_object,
         undefined4 clone_arg0,
         undefined4 clone_arg1);

typedef int stage1_signal_object_type2_callback_0c_cb
        (stage1_signal_object_candidate *signal_object,
         char *op_arg0);

typedef int stage1_signal_object_type2_callback_10_cb
        (stage1_signal_object_candidate *signal_object,
         char *op_arg0,
         int *op_arg1,
         uint flag_or_mode);

typedef int stage1_signal_object_type2_callback_18_cb
        (stage1_signal_object_candidate *signal_object,
         char *op_arg0,
         int *op_arg1,
         undefined4 op_arg2);

typedef int stage1_signal_object_type2_callback_20_cb
        (stage1_signal_object_candidate *signal_object,
         void *arg0_or_request,
         void *arg1_or_aux,
         int *out_result);

typedef int stage1_signal_object_type2_callback_24_cb
        (stage1_signal_object_candidate *signal_object,
         stage1_signal_object_type2_callback_24_request_candidate *request,
         void *optional_aux_arg,
         int *out_result);
```

Notes:

- `callback_18_t0_candidate` receives an extra value through nonstandard register input `t0`. Do not model it as a normal five-argument C callback unless a custom MIPS calling convention is created.
- `callback_20_out_candidate` is intentionally generic because the same callback slot is called both with normal arguments and with a stack-built request.
- `callback_24_out_candidate` is used by both simple and stack-built request wrappers.
- Where typedefs conflict with exact wrappers, prioritize keeping the decompile understandable and record the nonstandard register behavior in comments.

## Request candidate datatypes

### `stage1_signal_object_type2_callback_24_request_candidate`

Used by `80ef7ce8`.

```c
typedef struct stage1_signal_object_type2_callback_24_request_candidate {
    undefined4 field_00_from_t0_candidate;                 /* +0x00 */
    undefined4 field_04_from_optional_aux_deref_candidate; /* +0x04 */
    undefined4 *payload_pair_ptr_08_candidate;             /* +0x08 -> stack +0x20 */
    undefined4 field_0c_const1_candidate;                  /* +0x0c = 1 */
    undefined4 field_10_zero_candidate;                    /* +0x10 = 0 */
    undefined4 field_14_candidate;                         /* +0x14 not initialized here */
    undefined4 field_18_candidate;                         /* +0x18 = request_field18 */
    undefined4 field_1c_candidate;                         /* +0x1c not initialized here */
    undefined4 payload_arg0_20_candidate;                  /* +0x20 */
    undefined4 payload_arg1_24_candidate;                  /* +0x24 */
} stage1_signal_object_type2_callback_24_request_candidate; /* size 0x28 */
```

`80ef7ce8` request construction:

```text
request +0x00 = saved incoming t0
request +0x04 = 0 or *(undefined4 *)t1
request +0x08 = &payload pair at stack +0x20
request +0x0c = 1
request +0x10 = 0
request +0x18 = request_field18
request +0x20 = payload_arg0
request +0x24 = payload_arg1
```

### `stage1_signal_object_type2_callback_20_request_candidate`

Used by `80ef7f48`.

```c
typedef struct stage1_signal_object_type2_callback_20_request_candidate {
    undefined4 field_00_from_t0_candidate;          /* +0x00 */
    undefined4 field_04_from_t1_candidate;          /* +0x04 */
    undefined4 *payload_pair_ptr_08_candidate;      /* +0x08 -> stack +0x20 */
    undefined4 field_0c_const1_candidate;           /* +0x0c = 1 */
    undefined4 field_10_zero_candidate;             /* +0x10 = 0 */
    undefined4 field_14_candidate;                  /* +0x14 not initialized here */
    undefined4 field_18_zero_candidate;             /* +0x18 = 0 */
    undefined4 field_1c_candidate;                  /* +0x1c not initialized here */
    undefined4 payload_arg0_20_candidate;           /* +0x20 */
    undefined4 payload_arg1_24_candidate;           /* +0x24 */
} stage1_signal_object_type2_callback_20_request_candidate; /* size 0x28 */
```

`80ef7f48` request construction:

```text
request +0x00 = saved incoming t0
request +0x04 = saved incoming t1
request +0x08 = &payload pair at stack +0x20
request +0x0c = 1
request +0x10 = 0
request +0x18 = 0
request +0x20 = payload_arg0
request +0x24 = payload_arg1
```

## Function findings

### `80ef7374`

Recommended name/signature:

```c
int fn_stage1_signal_object_create_from_provider_table_80ef7374_candidate
        (int *create_arg0,
         int *create_arg1,
         int *create_arg2,
         int *create_arg3);
```

Finding:

- Enters Stage1 critical section.
- Reserves a signal-object table index from `0`.
- Allocates a new `stage1_signal_object_candidate`.
- Scans provider/registry entries from `8183fbf8` to `8183fc18`, stride `0x20`.
- Calls provider callback at provider entry `+0x18`.
- Callback receives new signal object through nonstandard register `t0`.
- First provider callback returning `0` wins.
- On success:
  - copies provider entry `+0x04` into signal object `+0x08`.
  - stores provider entry pointer into signal object `+0x1c`.
  - inserts signal object into reserved table index.
  - returns new signal index.
- On failure:
  - releases table index.
  - frees object when allocated.
  - stores status into errno/status slot.
  - returns `-1`.

Status values:

```text
0x18 = table index reservation failed
0x17 = signal-object slot allocation failed
provider callback nonzero = provider create failure status
```

### `80ef74ec`

Recommended name/signature:

```c
int fn_stage1_signal_object_clone_from_index_type2_80ef74ec_candidate
        (uint source_signal_index,
         undefined4 clone_arg0,
         undefined4 clone_arg1,
         undefined4 unused_arg2);
```

Finding:

- Refs source object by index.
- Reserves a fresh table index.
- Allocates a new signal-object slot.
- Requires `source_object->type_or_mode_06_candidate == 2`.
- Reads `source_object->type2_ops_18_candidate`.
- Calls `clone_callback_08`.
- On success:
  - copies `flags_08_candidate`.
  - copies `provider_or_related_entry_1c_candidate`.
  - inserts new object into reserved table index.
  - returns new signal index.
- On failure:
  - unrefs source.
  - releases reserved index.
  - frees new object if allocated.
  - stores error/status.
  - returns `-1`.

### `80ef767c`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_00_dispatch_80ef767c_candidate
        (uint signal_index,
         char *op_arg0,
         int *op_arg1,
         undefined4 unused_arg2);
```

Finding:

- Dispatches type2 ops `+0x00`.
- Calls with `a0 = signal_object`, `a1 = op_arg0`, `a2 = op_arg1`.

### `80ef7760`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_04_dispatch_80ef7760_candidate
        (uint signal_index,
         char *op_arg0,
         int *op_arg1,
         undefined4 unused_arg2);
```

Finding:

- Dispatches type2 ops `+0x04`.
- Calls with `a0 = signal_object`, `a1 = op_arg0`, `a2 = op_arg1`.

### `80ef7844`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_10_flag1_dispatch_80ef7844_candidate
        (uint signal_index,
         char *op_arg0,
         int *op_arg1,
         undefined4 unused_arg2);
```

Finding:

- Dispatches type2 ops `+0x10`.
- Calls with `a3 = 1`.

### `80ef792c`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_10_flag0_dispatch_80ef792c_candidate
        (uint signal_index,
         char *op_arg0,
         int *op_arg1,
         undefined4 unused_arg2);
```

Finding:

- Dispatches type2 ops `+0x10`.
- Calls with `a3 = 0`.

### `80ef7a14`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_18_t0_dispatch_80ef7a14_candidate
        (uint signal_index,
         char *op_arg0,
         int *op_arg1,
         undefined4 op_arg2);
```

Finding:

- Dispatches type2 ops `+0x18`.
- Preserves incoming `t0`.
- Calls callback with normal `a0..a3` plus nonstandard `t0`.

### `80ef7b18`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_0c_dispatch_80ef7b18_candidate
        (uint signal_index,
         char *op_arg0);
```

Finding:

- Dispatches type2 ops `+0x0c`.
- Calls with `a0 = signal_object`, `a1 = op_arg0`.
- Does not use normal `param_3` or `param_4`.

Fallback signature if caller decompile becomes confusing:

```c
int fn_stage1_signal_object_type2_callback_0c_dispatch_80ef7b18_candidate
        (uint signal_index,
         char *op_arg0,
         undefined4 unused_arg1,
         undefined4 unused_arg2);
```

### `80ef7bec`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_24_out_dispatch_80ef7bec_candidate
        (uint signal_index,
         undefined1 *op_record,
         undefined4 record_field18_value,
         undefined4 unused_arg2);
```

Finding:

- Writes `record_field18_value` into `op_record +0x18`.
- Dispatches type2 ops `+0x24`.
- Calls with:
  - `a0 = signal_object`
  - `a1 = op_record`
  - `a2 = 0`
  - `a3 = &out_result`
- Returns `out_result` on success.

### `80ef7ce8`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_24_stack_request_dispatch_80ef7ce8_candidate
        (uint signal_index,
         char *payload_arg0,
         int *payload_arg1,
         undefined4 request_field18);
```

Finding:

- Builds a stack request record.
- Dispatches type2 ops `+0x24`.
- Uses incoming `t0` and `t1`.
- `t0` stored into request `+0x00`.
- If `t1 != NULL`, request `+0x04 = *(undefined4 *)t1`; otherwise `0`.
- Passes `a2 = t1`.
- Passes `a3 = &out_result`.
- Returns `out_result` on success.

### `80ef7e30`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_24_stack_request_no_aux_80ef7e30_candidate
        (uint signal_index,
         char *payload_arg0,
         int *payload_arg1,
         undefined4 request_field18);
```

Finding:

- Thin wrapper around `80ef7ce8`.
- Clears `t0 = 0`.
- Clears `t1 = 0`.

### `80ef7e50`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_20_out_dispatch_80ef7e50_candidate
        (uint signal_index,
         char *op_arg0,
         int *op_arg1);
```

Finding:

- Dispatches type2 ops `+0x20`.
- Calls with:
  - `a0 = signal_object`
  - `a1 = op_arg0`
  - `a2 = op_arg1`
  - `a3 = &out_result`
- Returns `out_result` on success.

Fallback signature if caller decompile becomes confusing:

```c
int fn_stage1_signal_object_type2_callback_20_out_dispatch_80ef7e50_candidate
        (uint signal_index,
         char *op_arg0,
         int *op_arg1,
         undefined4 unused_arg2);
```

### `80ef7f48`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_20_stack_request_dispatch_80ef7f48_candidate
        (uint signal_index,
         char *payload_arg0,
         int *payload_arg1,
         void *callback_aux_arg);
```

Finding:

- Builds a stack request record.
- Dispatches type2 ops `+0x20`.
- Uses incoming `t0` and `t1`.
- Stores `t0` into request `+0x00`.
- Stores `t1` directly into request `+0x04`.
- Passes `a2 = callback_aux_arg`.
- Passes `a3 = &out_result`.
- Returns `out_result` on success.

### `80ef8088`

Recommended name/signature:

```c
int fn_stage1_signal_object_type2_callback_20_stack_request_no_aux_80ef8088_candidate
        (uint signal_index,
         char *payload_arg0,
         int *payload_arg1,
         void *callback_aux_arg);
```

Finding:

- Thin wrapper around `80ef7f48`.
- Clears `t0 = 0`.
- Clears `t1 = 0`.

## Common wrapper behavior

Most dispatcher wrappers use the same outer pattern:

```text
enter critical section
ref signal object by index
if ref fails:
    leave critical
    errno/status = 9
    return -1
if object type_or_mode_06_candidate == 2:
    read type2_ops_18_candidate
    run type2 pre-op lock helper
    call selected callback
    run type2 post-op unlock helper
unref signal object
if callback status != 0:
    leave critical
    errno/status = callback status
    return -1
leave critical
return 0 or callback-produced out_result
```

Important detail:

- Existing but non-type2 objects usually skip callback and return success (`0`, or initialized out result `0`).
- Invalid signal index is error `9`.
- Callback nonzero status is stored into errno/status slot and wrapper returns `-1`.

## Function comments to keep

Use Ghidra annotation syntax in comments, for example:

```text
calls {@symbol fn_stage1_signal_object_type2_pre_op_lock_80ef8320_candidate}
calls {@symbol fn_stage1_signal_object_type2_post_op_unlock_80ef8390_candidate}
calls {@address 80ef7ce8}
calls {@address 80ef7f48}
```

Do not rename raw registers or assembly-only temporaries. Only rename actual decompiler-visible parameters, locals, globals, functions, fields, and datatypes.

## Memory labels

No new global memory labels were proven in this dispatcher group.

Current memory/data work in this pass:

- Provider table label at `8183fbf8`.
- Provider table end label at `8183fc18`.
- `stage1_signal_object_candidate` field updates.
- `stage1_signal_object_type2_ops_candidate` field updates.
- Callback typedefs.
- Stack request candidate datatypes.

## Ghidra operation summary

Apply or verify:

1. Rename functions listed above.
2. Apply improved signatures.
3. Update `stage1_signal_object_candidate`.
4. Add/extend `stage1_signal_object_type2_ops_candidate`.
5. Add callback typedefs.
6. Add request candidate datatypes if useful.
7. Delete bogus functions `80ef7840` and `80ef7d80`.
8. Keep `_candidate` suffix on this family because the public semantic names are still provisional.
9. Do not add fake callback names based on guessed API purpose.
10. Continue to `80ef80a8`.

## Git commit guidance

Recommended path in repo:

```text
records/reverse/2026-06-15-stage1-signal-object-type2-dispatcher-path.md
```

Recommended commit message:

```text
records: log stage1 signal-object type2 dispatcher path
```

Recommended one-line WSL commands after placing this file into the repo:

```sh
cd ~/tc7200u-research; mkdir -p records/reverse; cp /mnt/data/2026-06-15-stage1-signal-object-type2-dispatcher-path.md records/reverse/2026-06-15-stage1-signal-object-type2-dispatcher-path.md; git status --short -M; git add records/reverse/2026-06-15-stage1-signal-object-type2-dispatcher-path.md; git commit -m "records: log stage1 signal-object type2 dispatcher path"; git status --short -M
```

Do not delete or overwrite old logs.
Do not commit unrelated changes unless intentionally reviewed.

## Next reverse targets

Continue at:

```text
80ef80a8
```

Watch for:

- remaining type2 ops offsets `+0x14` and `+0x1c`.
- callback slots beyond `+0x24`.
- concrete callers that reveal exact callback semantics.
- repeated use of the stack request records.
- functions that identify the real type2 object family.
