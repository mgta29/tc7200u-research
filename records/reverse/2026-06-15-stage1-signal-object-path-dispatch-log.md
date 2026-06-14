# 2026-06-15 Stage1 signal-object, path-context, and dispatch reverse log

## Scope

This record documents the latest TC7200U / BCM3383 Stage1 Ghidra reverse-engineering pass.

Primary address range covered:

- `80ef5328..80ef6930`

Main subsystem area:

- Stage1 signal-object table
- Signal-object pool
- Per-slot wait objects
- Signal-object ops/class callback table
- Related-object pool callback dispatch
- Path normalization/default context handling
- I/O-vector dispatch wrappers
- Signal-object close, duplicate, status-query, and create paths

This record is additive. It does not replace earlier reverse notes.

## High-level result

The current pass turned the `80ef53xx..80ef69xx` region from mostly generic
`FUN_...` code into a coherent Stage1 signal-object API family.

The model now appears to be an indexed object table similar to a descriptor or
handle table:

- table index values are user-visible handles or signal indexes
- table entry `0` means free
- table entry `1` means reserved sentinel
- table entry `>= 2` is a `stage1_signal_object_candidate *`
- object lifetime is managed by `refcount_04`
- final release is delegated through `ops_or_class_0c->final_release_18`
- table replacement uses reserve -> unref old -> install new
- close releases the table index and drops the old table reference
- dup-like helpers alias the same object into a new table slot

The pass also connected this table API to:

- iovec-style I/O callbacks
- generic callback dispatchers at ops offsets `0x08`, `0x0c`, `0x14`, `0x1c`
- path/default-context callbacks in the related-object pool
- global path normalization buffer at `81a7b908`
- default related-object/context globals at `81802a7c` and `81802a80`

## Important interpretation changes

### 1. Signal-object ops table is now a real callback table

The object field:

- `signal_object->ops_or_class_0c`

is not a random object pointer. It is an ops/class callback table with confirmed
callback slots at:

- `+0x00`
- `+0x04`
- `+0x08`
- `+0x0c`
- `+0x14`
- `+0x18`
- `+0x1c`

The already-known `+0x18` slot is the final-release callback.

### 2. Related-object pool A also contains callback slots

The structure behind:

- `related_object_or_group->pool_a_entry_14_candidate`

now has confirmed callback offsets:

- `+0x1c`
- `+0x2c`
- `+0x30`
- `+0x34`

These are not signal-object ops callbacks. They belong to
`stage1_related_object_pool_a_entry_candidate`.

### 3. Path helper is not signal-specific

The globals originally named around signal creation are broader than the
signal-create path.

Renamed or broadened labels:

- `g_stage1_default_related_object_or_path_context_81802a7c_candidate`
- `g_stage1_default_resolved_context_81802a80_candidate`

Reason: path normalization and context-setting code also use them.

### 4. `80ef59e4` is a bad auto-split

`80ef59e4` is not an independent function. It is an auto-created split inside
`80ef59a8`.

Required Ghidra action:

- delete function at `80ef59e4`
- re-decompile `80ef59a8`

### 5. `0xc350` lifecycle magic is decimal `50000`

`80ef5848` accepts a magic value:

- hex: `0xc350`
- decimal: `50000`

For this Ghidra setup, scalar searches should use decimal input.

## Memory / global labels

No new memory block was required in this pass.

The existing Stage1 signal-object memory area remains valid:

- block: `RAM_STAGE1_SIGNAL_OBJECT_AREAS_81a78000_candidate`
- start: `81a78000`
- length: `0x4000`
- end: `81a7bfff`
- type: uninitialized RAM
- read/write: yes
- execute: no

Confirmed globals:

| Address | Name | Type |
|---:|---|---|
| `81a68120` | `g_stage1_signal_object_table_lock_81a68120` | `stage1_owned_wait_object_candidate` |
| `81a6b508` | `g_stage1_signal_object_table_81a6b508` | `uint[0xff]` |
| `81a78138` | `g_stage1_signal_object_per_slot_wait_objects_81a78138_candidate` | `stage1_owned_wait_object_candidate[0xff]` |
| `81a79528` | `g_stage1_signal_object_pool_81a79528` | `stage1_signal_object_candidate[0xff]` |
| `8184fa18` | `g_stage1_related_object_pool_a_8184fa18_candidate` | `stage1_related_object_pool_a_entry_candidate[]` |
| `8184fa58` | `g_stage1_related_object_pool_b_8184fa58_candidate` | `stage1_related_object_pool_b_entry_candidate[]` |
| `819ec1dc` | `g_stage1_related_object_lock_table_a_819ec1dc_candidate` | `stage1_owned_wait_object_candidate[]` |
| `819ec22c` | `g_stage1_related_object_lock_table_b_819ec22c_candidate` | `stage1_owned_wait_object_candidate[]` |
| `81802a7c` | `g_stage1_default_related_object_or_path_context_81802a7c_candidate` | `stage1_related_object_pool_b_entry_candidate *` |
| `81802a80` | `g_stage1_default_resolved_context_81802a80_candidate` | `void *` |
| `81a7b908` | `g_stage1_path_normalize_buffer_81a7b908_candidate` | `char[0x6f8]` candidate |
| `81803ad8` | `g_stage1_path_normalize_buffer_used_len_81803ad8_candidate` | `uint` |
| `813a7f74` | `s_stage1_path_dot_813a7f74` | `TerminatedCString` |
| `813a7f78` | `s_stage1_path_dotdot_813a7f78` | `TerminatedCString` |

## Table states

`g_stage1_signal_object_table_81a6b508[index]` states:

| Value | Meaning |
|---:|---|
| `0` | free |
| `1` | reserved sentinel |
| `>= 2` | `stage1_signal_object_candidate *` |

## Error/status values seen in this pass

| Value | Meaning in current context |
|---:|---|
| `0x02` | related-object/context resolution failure |
| `0x09` | bad or invalid signal index |
| `0x16` | invalid argument |
| `0x17` | signal-object slot allocation failure |
| `0x18` | table index reservation failure / no free slot |
| `0x5f` | unsupported command/mode in duplicate helper |



# Structures and datatypes

## `stage1_signal_object_candidate`

Current working layout:

~~~c
typedef struct stage1_signal_object_candidate {
    uint flags_00;
    ushort refcount_04;
    ushort field_06;
    uint flags_08_candidate;
    stage1_signal_ops_or_class_candidate *ops_or_class_0c;
    undefined4 field_10;
    undefined4 field_14;
    undefined4 field_18;
    stage1_related_object_pool_b_entry_candidate *related_object_or_group_1c_candidate;
} stage1_signal_object_candidate; /* size 0x20 */
~~~

Known `flags_00` bits:

| Bit/value | Meaning |
|---:|---|
| `0x80000000` | slot allocated / in use |
| `0x01000000` | final-release lock active |
| `0x00020000` | set by create-from-related-callback path |
| `0x00000001` | mode/capability bit set by create-from-related-callback path |

The create-from-related-callback path sets:

- `flags_00 |= 0x00020001`

This happens in `fn_stage1_signal_object_create_from_related_callback_2c_80ef67b0_candidate`.

## `stage1_signal_ops_or_class_candidate`

Current working layout:

~~~text
0x00  stage1_signal_object_iovec_io_cb *       io_mode1_callback_00_candidate
0x04  stage1_signal_object_iovec_io_cb *       io_mode2_callback_04_candidate
0x08  stage1_signal_object_callback_08_cb *    callback_08_candidate
0x0c  stage1_signal_object_callback_0c_cb *    callback_0c_candidate
0x10  undefined4                               test_callback_10
0x14  stage1_signal_object_callback_14_cb *    callback_14_candidate
0x18  stage1_signal_object_final_release_cb *  final_release_18
0x1c  stage1_signal_object_callback_1c_cb *    callback_1c_candidate
~~~

Callback function definitions:

~~~c
int stage1_signal_object_iovec_io_cb
        (stage1_signal_object_candidate *signal_object,
         stage1_signal_iovec_io_request_candidate *io_request);

int stage1_signal_object_callback_08_cb
        (stage1_signal_object_candidate *signal_object,
         void **inout_value,
         void *op_arg);

int stage1_signal_object_callback_0c_cb
        (stage1_signal_object_candidate *signal_object,
         void *op_arg1,
         void *op_arg2);

int stage1_signal_object_callback_14_cb
        (stage1_signal_object_candidate *signal_object,
         uint flag_or_mode);

int stage1_signal_object_final_release_cb
        (stage1_signal_object_candidate *signal_object);

int stage1_signal_object_callback_1c_cb
        (stage1_signal_object_candidate *signal_object,
         void *op_arg);
~~~

## `stage1_related_object_pool_a_entry_candidate`

Current working layout:

~~~text
0x00  0x08  undefined1[8]                                pad_00
0x08  0x04  uint                                         lock_flags_08_candidate
0x0c  0x08  undefined1[8]                                pad_0c
0x14  0x04  undefined4                                   create_or_init_callback_14
0x18  0x04  undefined4                                   field_18
0x1c  0x04  stage1_related_object_callback_1c_cb *        callback_1c_candidate
0x20  0x0c  undefined1[12]                               pad_20
0x2c  0x04  stage1_related_object_callback_2c_cb *        callback_2c_candidate
0x30  0x04  stage1_related_object_path_context_cb_30 *    path_context_callback_30_candidate
0x34  0x04  stage1_related_object_callback_34_cb *        callback_34_candidate
0x38  0x08  undefined1[8]                                pad_38
~~~

Size remains:

- `0x40`

Important warning:

- `create_or_init_callback_14` is still `undefined4`
- do not force a normal C callback typedef on it yet
- one known callsite passes a hidden argument through register `t0`

Related-object callback function definitions:

~~~c
int stage1_related_object_callback_1c_cb
        (stage1_related_object_pool_b_entry_candidate *related_object_or_group,
         void *resolved_context_or_arg,
         void *op_arg);

int stage1_related_object_callback_2c_cb
        (stage1_related_object_pool_b_entry_candidate *related_object_or_group,
         void *resolved_context_or_arg,
         void *create_arg_or_handle_resolved,
         stage1_signal_object_candidate *new_signal_object);

int stage1_related_object_path_context_cb_30
        (stage1_related_object_pool_b_entry_candidate *related_object_or_group,
         void *resolved_context_or_arg,
         char *path,
         void **out_new_resolved_context);

int stage1_related_object_callback_34_cb
        (stage1_related_object_pool_b_entry_candidate *related_object_or_group,
         void *resolved_context_or_arg,
         void *op_arg,
         uint op_value);
~~~

## `stage1_related_object_pool_b_entry_candidate`

Current working layout:

~~~text
0x00  0x14  undefined1[20]                              pad_00
0x14  0x04  stage1_related_object_pool_a_entry_candidate * pool_a_entry_14_candidate
0x18  0x08  undefined1[8]                               pad_18
~~~

Size remains:

- `0x20`

## `stage1_iovec_candidate`

New working datatype:

~~~c
typedef struct stage1_iovec_candidate {
    void *base_00;
    uint length_04;
} stage1_iovec_candidate; /* size 0x08 */
~~~

## `stage1_signal_iovec_io_request_candidate`

New working datatype:

~~~c
typedef struct stage1_signal_iovec_io_request_candidate {
    stage1_iovec_candidate *iov_00;
    int iov_count_04;
    undefined4 field_08;
    uint remaining_or_total_len_0c;
    uint field_10_zero_init;
    uint mode_index_14;
} stage1_signal_iovec_io_request_candidate; /* size 0x18 */
~~~

`mode_index_14` values seen:

| Value | Meaning |
|---:|---|
| `0` | mode1 callback selected |
| `1` | mode2 callback selected |

# Function labels and signatures

## Signal-object allocation, table, and lifetime

### `80ef5328`

~~~c
stage1_signal_object_candidate *
fn_stage1_signal_object_slot_alloc_80ef5328(void);
~~~

Behavior:

- locks `g_stage1_signal_object_table_lock_81a68120`
- scans `g_stage1_signal_object_pool_81a79528`
- pool has `0xff` entries
- object stride is `0x20`
- free if `flags_00` bit31 is clear
- allocation writes `flags_00 = 0x80000000`
- initializes `refcount_04 = 0`
- returns object pointer or `NULL`

### `80ef53a8`

~~~c
void fn_stage1_signal_object_slot_free_80ef53a8
        (stage1_signal_object_candidate *signal_object);
~~~

Behavior:

- raw slot free helper
- locks table lock
- clears `flags_00`
- unlocks
- not the same as public unref

### `80ef53e8`

~~~c
int fn_stage1_signal_object_unref_locked_80ef53e8
        (stage1_signal_object_candidate *signal_object);
~~~

Behavior:

- caller already holds table lock
- decrements `refcount_04`
- if refcount remains nonzero, returns `0`
- if refcount reaches zero:
  - pre-final-release lock helper runs
  - `ops_or_class_0c->final_release_18(signal_object)` runs
  - post-final-release unlock helper runs
  - clears `flags_00` only if final release returns `0`
- returns final-release status or `0`

### `80ef545c`

~~~c
int fn_stage1_signal_object_table_reserve_slot_unref_old_locked_80ef545c
        (int signal_index);
~~~

Behavior:

- caller already holds table lock
- reads table entry
- if old entry is `>= 2`, treats it as `stage1_signal_object_candidate *`
- calls locked unref on old object
- writes sentinel value `1` into the table slot
- returns old-object unref result or `0`

### `80ef54bc`

~~~c
int fn_stage1_signal_object_table_index_reserve_from_80ef54bc
        (uint start_index);
~~~

Behavior:

- scans table from `start_index` through `0xfe`
- first free entry `0` becomes reserved entry `1`
- returns selected index
- returns `-1` if no free slot

### `80ef5544`

~~~c
void fn_stage1_signal_object_table_insert_80ef5544
        (int signal_index,
         stage1_signal_object_candidate *signal_object);
~~~

Behavior:

- locks table lock
- reserves/replaces target slot
- increments `signal_object->refcount_04`
- writes object pointer into table
- unlocks

### `80ef55b4`

~~~c
int fn_stage1_signal_object_table_index_release_80ef55b4
        (int signal_index);
~~~

Behavior:

- locks table lock
- reserves/replaces old slot
- unrefs old live object if present
- writes table slot back to `0`
- unlocks
- returns old-object unref result

### `80ef561c`

~~~c
stage1_signal_object_candidate *
fn_stage1_signal_object_ref_by_index_80ef561c
        (uint signal_index);
~~~

Behavior:

- locks table lock
- reads table entry
- `0` and `1` are invalid/sentinel values
- live pointer entries are `>= 2`
- increments `refcount_04`
- unlocks
- returns referenced object or `NULL`

### `80ef5684`

~~~c
void fn_stage1_signal_object_unref_80ef5684
        (stage1_signal_object_candidate *signal_object);
~~~

Behavior:

- public unref wrapper
- locks table lock
- calls locked unref helper
- unlocks

### `80ef56c8`

~~~c
void fn_stage1_signal_object_pre_final_release_lock_80ef56c8
        (stage1_signal_object_candidate *signal_object,
         uint flags_08_value);
~~~

Behavior:

- acquires related-object locks based on `flags_08_value >> 4`
- if `flags_08_value & 0x10`:
  - sets `signal_object->flags_00 |= 0x01000000`
  - computes object pool index
  - acquires corresponding per-slot wait object

### `80ef5748`

~~~c
void fn_stage1_signal_object_post_final_release_unlock_80ef5748
        (stage1_signal_object_candidate *signal_object,
         uint flags_08_value);
~~~

Behavior:

- releases related-object locks based on `flags_08_value >> 4`
- if `flags_08_value & 0x10`:
  - clears `signal_object->flags_00 &= 0xfeffffff`
  - releases/wakes corresponding per-slot wait object

### `80ef57cc`

~~~c
int fn_stage1_signal_object_table_dup2_index_80ef57cc
        (uint old_signal_index,
         uint new_signal_index);
~~~

Behavior:

- if old index equals new index, returns new index
- validates `new_signal_index < 0xff`
- refs source object
- inserts same object into destination index
- drops temporary reference
- returns new index
- on invalid source/destination, stores errno/status `9` and returns `-1`

## Wait-object lifecycle

### `80ef5848`

~~~c
void fn_stage1_signal_object_wait_objects_lifecycle_80ef5848
        (int lifecycle_mode,
         uint magic_0xc350);
~~~

Behavior:

- requires `magic_0xc350 == 0xc350`
- decimal scalar search value: `50000`
- `lifecycle_mode == 1`:
  - initializes table lock wait object
  - initializes all `0xff` per-slot wait objects
- `lifecycle_mode == 0`:
  - drains/unlinks all per-slot wait objects in reverse order
  - drains/unlinks table lock wait object

### `80ef594c`

~~~c
void fn_stage1_signal_object_wait_objects_init_80ef594c(void);
~~~

Wrapper for:

~~~c
fn_stage1_signal_object_wait_objects_lifecycle_80ef5848(1, 0xc350);
~~~

### `80ef596c`

~~~c
void fn_stage1_signal_object_wait_objects_shutdown_80ef596c(void);
~~~

Wrapper for:

~~~c
fn_stage1_signal_object_wait_objects_lifecycle_80ef5848(0, 0xc350);
~~~

## String and path helpers

### `80ef598c`

~~~c
char *fn_stage1_stpcpy_80ef598c
        (char *dst,
         char *src);
~~~

Behavior:

- copies NUL-terminated `src` to `dst`
- returns pointer to written NUL byte in destination
- source is behaviorally read-only, but Ghidra signature uses `char *`

### `80ef59a8`

~~~c
int fn_stage1_path_component_match_80ef59a8
        (char *path_cursor,
         char *component);
~~~

Behavior:

- returns `1` if `component` matches at `path_cursor`
- match must be followed by NUL or `/`
- returns `0` otherwise
- used for `"."` and `".."` path-segment checks

### `80ef5a34`

~~~c
void fn_stage1_path_normalize_to_global_buffer_80ef5a34_candidate
        (char **base_path_slot,
         void *resolved_context_or_arg,
         char *input_path);
~~~

Behavior:

- normalizes `input_path` into global buffer `81a7b908`
- handles:
  - `.`
  - `..`
  - repeated `/`
  - component copying
- updates `g_stage1_path_normalize_buffer_used_len_81803ad8_candidate`

## Related-object callback dispatch

### `80ef5d90`

~~~c
int fn_stage1_related_object_callback_1c_dispatch_80ef5d90_candidate
        (void *op_arg);
~~~

Behavior:

- enters critical section
- resolves default related object/context
- acquires related locks
- calls `pool_a_entry_14_candidate->callback_1c_candidate`
- releases locks
- leaves critical section
- returns `0` on callback success
- on error, stores callback status in errno/status slot and returns `-1`

### `80ef5e68`

~~~c
int fn_stage1_path_set_default_context_80ef5e68_candidate
        (char *path);
~~~

Behavior:

- likely current-path or default-path-context setter
- resolves related object/context
- calls `pool_a_entry_14_candidate->path_context_callback_30_candidate`
- on callback success:
  - normalizes path into global path buffer
  - possibly probes existing default context
  - updates:
    - `g_stage1_default_related_object_or_path_context_81802a7c_candidate`
    - `g_stage1_default_resolved_context_81802a80_candidate`
- returns `0` on success
- returns `-1` and stores errno/status on failure

### `80ef5fd0`

~~~c
int fn_stage1_related_object_callback_34_dispatch_80ef5fd0_candidate
        (void *op_arg,
         uint op_value);
~~~

Behavior:

- enters critical section
- resolves related object/context
- acquires related locks
- calls `pool_a_entry_14_candidate->callback_34_candidate`
- releases locks
- leaves critical section
- returns `0` on callback success
- returns `-1` and stores callback status on failure

## Signal-object I/O and dispatch wrappers

### `80ef60b0`

~~~c
int fn_stage1_signal_object_iovec_io_dispatch_80ef60b0_candidate
        (uint signal_index,
         stage1_iovec_candidate *iov,
         int iov_count,
         uint io_mode_mask);
~~~

Behavior:

- validates `iov_count < 0x11`
- copies up to 16 iovec entries to stack
- sums original total length
- refs signal object by index
- checks `signal_object->flags_00 & io_mode_mask`
- builds `stage1_signal_iovec_io_request_candidate`
- chooses ops callback:
  - mode mask `1` -> `io_mode1_callback_00_candidate`
  - mode mask `2` -> `io_mode2_callback_04_candidate`
- calls selected callback under pre/post final-release lock helpers
- unrefs object
- returns consumed/transferred length style result:
  - original total minus remaining field
- returns `-1` and stores errno/status on error

### `80ef6244`

~~~c
int fn_stage1_signal_object_io_mode1_single_80ef6244_candidate
        (uint signal_index,
         void *buffer,
         uint length);
~~~

Wrapper:

~~~c
fn_stage1_signal_object_iovec_io_dispatch_80ef60b0_candidate
        (signal_index, &single_iov, 1, 1);
~~~

### `80ef6270`

~~~c
int fn_stage1_signal_object_io_mode2_single_80ef6270_candidate
        (uint signal_index,
         void *buffer,
         uint length);
~~~

Wrapper:

~~~c
fn_stage1_signal_object_iovec_io_dispatch_80ef60b0_candidate
        (signal_index, &single_iov, 1, 2);
~~~

### `80ef629c`

~~~c
int fn_stage1_signal_object_close_index_80ef629c
        (uint signal_index);
~~~

Behavior:

- enters critical section
- refs object by index to validate it exists
- drops temporary ref
- releases table index
- leaves critical section
- returns `0` on success
- returns `-1` and errno/status on failure

### `80ef6338`

~~~c
void *fn_stage1_signal_object_callback_08_inout_ptr_80ef6338_candidate
        (uint signal_index,
         void *initial_value,
         void *op_arg);
~~~

Behavior:

- refs object by index
- calls `ops_or_class_0c->callback_08_candidate`
- passes address of local `initial_value`
- returns possibly modified pointer value
- returns `(void *)-1` on error

### `80ef6404`

~~~c
int fn_stage1_signal_object_callback_0c_dispatch_80ef6404_candidate
        (uint signal_index,
         void *op_arg1,
         void *op_arg2);
~~~

Behavior:

- refs object by index
- calls `ops_or_class_0c->callback_0c_candidate`
- returns `0` on success
- returns `-1` and stores errno/status on failure

### `80ef64cc`

~~~c
int fn_stage1_signal_object_callback_14_flag1_80ef64cc_candidate
        (uint signal_index);
~~~

Behavior:

- refs object by index
- calls `ops_or_class_0c->callback_14_candidate(signal_object, 1)`
- returns `0` on success
- returns `-1` and stores errno/status on failure

### `80ef6590`

~~~c
int fn_stage1_signal_object_callback_1c_dispatch_80ef6590_candidate
        (uint signal_index,
         void *op_arg);
~~~

Behavior:

- refs object by index
- calls `ops_or_class_0c->callback_1c_candidate(signal_object, op_arg)`
- returns `0` on success
- returns `-1` and stores errno/status on failure

### `80ef6648`

~~~c
int fn_stage1_signal_object_dup_index_from_min_80ef6648_candidate
        (uint source_signal_index,
         uint command_or_mode,
         uint min_new_signal_index);
~~~

Behavior:

- refs source object by index
- only command/mode `1` is supported
- validates `min_new_signal_index < 0xff`
- reserves first free table index at or above `min_new_signal_index`
- inserts same object into the new table index
- drops temporary source reference
- returns `0` on success in current decompile shape
- returns `-1` and stores errno/status on failure

Notes:

- mode not equal to `1` stores status `0x5f`
- reserve failure stores status `0x18`
- invalid destination stores status `9`
- keep `_candidate` until callers confirm exact return convention

### `80ef6758`

~~~c
bool fn_stage1_signal_object_query_status_bit1_80ef6758_candidate
        (uint signal_index);
~~~

Behavior:

- enters critical section
- calls `fn_stage1_signal_object_callback_1c_dispatch_80ef6590_candidate`
- callback fills a stack output buffer
- returns true if output word bit `0x2` is set
- returns false if dispatch fails

### `80ef67b0`

~~~c
int fn_stage1_signal_object_create_from_related_callback_2c_80ef67b0_candidate
        (void *create_arg_or_handle);
~~~

Behavior:

- reserves signal-object table index starting from `1`
- allocates signal-object slot
- resolves related object/context
- acquires related-object locks
- calls `pool_a_entry_14_candidate->callback_2c_candidate`
- on success:
  - sets `signal_object->flags_00 |= 0x00020001`
  - sets `signal_object->related_object_or_group_1c_candidate`
  - sets `signal_object->flags_08_candidate`
  - inserts object into table
  - returns signal index
- on failure:
  - releases reserved table index
  - frees signal-object slot
  - stores errno/status
  - returns `0` in current decompile shape

# Local-variable naming deltas

## `80ef60b0`

~~~text
param_1 -> signal_index
param_2 -> iov
param_3 -> iov_count
param_4 -> io_mode_mask
s1      -> signal_object
s2      -> original_total_len
s3      -> status
s4      -> io_mode_mask
~~~

## `80ef6338`

~~~text
param_1  -> signal_index
param_2  -> initial_value
param_3  -> op_arg
s0       -> signal_object
s1       -> status
local_20 -> inout_value
~~~

## `80ef5e68`

~~~text
local_18 -> related_object_or_group
local_20 -> resolved_context_or_arg
local_1c -> path_resolved
local_14 -> new_resolved_context
s0       -> status
~~~

## `80ef6758`

~~~text
local_30 -> callback_status_flags
~~~



# Ghidra actions applied / to apply

## Function cleanup

Delete this bad auto-split:

~~~text
80ef59e4
~~~

Reason:

- it is inside `80ef59a8`
- it is not an independent callable function
- after deletion, re-decompile `80ef59a8`

## Function definitions to create in Data Type Manager

Create these as **Function Definition** datatypes, not structs:

~~~text
stage1_signal_object_iovec_io_cb
stage1_signal_object_callback_08_cb
stage1_signal_object_callback_0c_cb
stage1_signal_object_callback_14_cb
stage1_signal_object_final_release_cb
stage1_signal_object_callback_1c_cb
stage1_related_object_callback_1c_cb
stage1_related_object_callback_2c_cb
stage1_related_object_path_context_cb_30
stage1_related_object_callback_34_cb
~~~

## Structure fields to update

### In `stage1_signal_ops_or_class_candidate`

~~~text
0x00  stage1_signal_object_iovec_io_cb *       io_mode1_callback_00_candidate
0x04  stage1_signal_object_iovec_io_cb *       io_mode2_callback_04_candidate
0x08  stage1_signal_object_callback_08_cb *    callback_08_candidate
0x0c  stage1_signal_object_callback_0c_cb *    callback_0c_candidate
0x10  undefined4                               test_callback_10
0x14  stage1_signal_object_callback_14_cb *    callback_14_candidate
0x18  stage1_signal_object_final_release_cb *  final_release_18
0x1c  stage1_signal_object_callback_1c_cb *    callback_1c_candidate
~~~

### In `stage1_related_object_pool_a_entry_candidate`

~~~text
0x1c  stage1_related_object_callback_1c_cb *        callback_1c_candidate
0x2c  stage1_related_object_callback_2c_cb *        callback_2c_candidate
0x30  stage1_related_object_path_context_cb_30 *    path_context_callback_30_candidate
0x34  stage1_related_object_callback_34_cb *        callback_34_candidate
~~~

Do not force `create_or_init_callback_14` into a normal function pointer yet.

# Ghidra comments worth applying

## `80ef5848`

~~~c
/* Stage1 signal-object wait-object lifecycle helper.

   Arguments:
     lifecycle_mode = 1 for init, 0 for shutdown/drain
     magic_0xc350 = must equal 0xc350

   Behavior:
     - if magic_0xc350 != 0xc350, returns
     - if lifecycle_mode == 1:
         initializes {@symbol g_stage1_signal_object_table_lock_81a68120}
         initializes all 0xff per-slot wait objects at
           {@symbol g_stage1_signal_object_per_slot_wait_objects_81a78138_candidate}
     - if lifecycle_mode == 0:
         drains/unlinks all 0xff per-slot wait objects in reverse order
         drains/unlinks {@symbol g_stage1_signal_object_table_lock_81a68120}

   0xc350 decimal = 50000. */
~~~

## `80ef60b0`

~~~c
/* Stage1 signal-object iovec I/O dispatch helper.

   Behavior:
     - validates iov_count < 0x11
     - copies iovec entries to a stack-local request
     - sums original total length
     - references signal object by table index
     - checks signal_object->{@field flags_00} against io_mode_mask
     - dispatches through signal_object->{@field ops_or_class_0c}:
         mode 1 -> {@field io_mode1_callback_00_candidate}
         mode 2 -> {@field io_mode2_callback_04_candidate}
     - wraps callback with pre/post final-release lock helpers
     - unreferences the signal object
     - returns transferred/consumed length style result

   Error paths store errno/status and return -1. */
~~~

## `80ef67b0`

~~~c
/* Stage1 signal-object create helper using related-object callback +0x2c.

   Behavior:
     - reserves a signal-object table index starting at 1
     - allocates a signal-object slot
     - resolves related object/context
     - calls related_object_or_group->{@field pool_a_entry_14_candidate}
       ->{@field callback_2c_candidate}
     - on success:
         sets signal_object->{@field flags_00} |= 0x00020001
         stores related object at signal_object->{@field related_object_or_group_1c_candidate}
         stores related lock flags at signal_object->{@field flags_08_candidate}
         inserts signal object into the table
         returns the new signal index

   Error paths release the reserved table index and free the allocated slot. */
~~~

# Results

## Confirmed

- signal-object table/pool lifetime model is coherent
- table reserve/insert/ref/unref/release/close paths are mapped
- dup2-style table alias helper is mapped
- wait-object lifecycle init/shutdown is mapped
- path normalization helper is mapped
- default related object/context pair is broader than signal creation
- signal-object ops callback table now has confirmed fields through `0x1c`
- related-object pool A callback table now has confirmed fields through `0x34`
- iovec dispatch supports up to 16 iovec entries
- close helper returns success/error through errno/status pattern
- create-from-related-callback path creates a signal object and inserts it into the table

## Still provisional

Keep `_candidate` on:

- callback dispatch wrappers where exact syscall/API name is not known
- path context setter until caller naming confirms current-working-directory semantics
- I/O mode1/mode2 wrappers until callers prove read/write direction
- duplicate-from-min helper until return convention is confirmed from callers
- create-from-related-callback helper until object kind is known

## Next open

Open next address after this pass:

~~~text
80ef6934
~~~

Expected next work:

- continue after `80ef67b0`
- check whether the next function wraps create/open behavior
- look for additional ops offsets beyond `0x1c`
- look for related-object callback offsets beyond `0x34`
- continue updating only new signatures/datatypes, not repeating settled ones

# Git / provenance

This file was written under:

~~~text
records/reverse/2026-06-15-stage1-signal-object-path-dispatch-log.md
~~~

Commit intent:

~~~text
records: add 2026-06-15 stage1 signal reverse log
~~~

