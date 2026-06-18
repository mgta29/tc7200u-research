# 2026-06-16 — Stage1 Socket Object + Type2 `setsockopt` Reverse Log

## Summary

This reverse-engineering pass identified and typed a Stage1 socket-object wrapper family around `808381b4`, `808381f4`, and `808385f4`. The work also promoted the previously generic Stage1 signal-object type2 callback at `80ef80a8` into a socket-provider `setsockopt`-like dispatcher, and created enough socket object/vtable datatypes for Ghidra to decompile the main create/configure and close/cleanup paths cleanly.

Main result:

```text
808381f4 = Stage1 socket-object create/configure helper
808385f4 = Stage1 socket-object close/cleanup helper
808381b4 = Stage1 socket-object destroy/free wrapper
80ef80a8 = Stage1 signal-object type2 setsockopt-like dispatcher, hidden t0 = optlen
```

This is Stage1 software object work, not GENET/DQM/FPM MMIO work. No memory-map/MMIO block changes were required in this pass.

---

## Source Inputs Used

The pass was based on the pasted Ghidra Listing and Decompiler output for:

```text
FUN_808381b4
FUN_808381f4
FUN_808385f4
fn_stage1_signal_object_type2_callback_1c_t0_dispatch_80ef80a8
fn_stage1_signal_object_type2_callback_14_dispatch_80ef81ac
```

Important source evidence included:

- `FUN_808381b4` writes `DAT_81825d98` into object offset `+0x00`, then calls `FUN_808385f4`, `FUN_80127754`, and `fn_heap_free_if_nonnull_80f08cbc_candidate`.
- `FUN_808381f4` creates a signal-object/provider handle, stores it at object offset `+0x04`, stores hidden incoming `t0` at object offset `+0x0c`, configures socket-like options through the type2 `+0x1c` callback, and stores `fn_get_stage1_global_boot_context_base_80e952c0_candidate()` at object offset `+0x10` when successful.
- `FUN_808385f4` calls object vtable slot `+0x38` with `level=0xffff`, `option_name=0x1008`, an output stack word, and hidden `t0 = &optlen`; if the returned value is `1`, it calls `FUN_800c53c8`, then closes the signal-object handle through `fn_stage1_signal_object_close_index_80ef629c`.
- `80ef80a8` forwards original incoming `t0` into the type2 `+0x1c` callback, proving that a normal C signature alone does not represent the full ABI.

---

## High-Value Findings

### 1. `80ef80a8` is `setsockopt`-like in the socket provider path

Previous name:

```text
fn_stage1_signal_object_type2_callback_1c_t0_dispatch_80ef80a8
```

Updated interpretation:

```text
fn_stage1_signal_object_type2_setsockopt_t0_dispatch_80ef80a8
```

Reason:

`808381f4` calls this dispatcher with classic socket-option shaped arguments:

```text
signal/socket handle
level
option_name
option_value pointer
hidden t0 = option length
```

Observed calls:

```text
level 0xffff, option normalized from create flags, optlen 4
level 0x29,   option 0x2e,                       optlen 0x14
level 0xffff, option 0x04,                       optlen 4
level 0,      option 0x13,                       optlen 4
level 0x29,   option 0x0e,                       optlen 4
```

Associated strings in the create/configure path confirm the socket interpretation:

```text
"SOCKET_ERROR: "
"Failed to set IPV6_PKTINFO socket..."
"Failed to clear SO_REUSEADDR..."
"Failed to set IP_PORTRANGE..."
```

### 2. Hidden `t0` is an ABI input, not a normal decompiler parameter

For `80ef80a8`, the wrapper saves original incoming `t0`, calls the type2 callback, and forwards that saved value into the callback through register `t0`.

For the socket path, this hidden `t0` behaves as `optlen` for `setsockopt`-like calls:

```text
t0 = 0x04 -> 4-byte option value
t0 = 0x14 -> 20-byte IPv6 packet-info option block
```

For the socket close path, the vtable `+0x38` method receives hidden `t0 = &optlen`, so it is `getsockopt`-like rather than `setsockopt`-like.

### 3. Socket-object layout is now known enough to type

`808381f4`, `808385f4`, and `808381b4` all point at the same object shape:

```text
+0x00 vtable pointer
+0x04 signal object index / socket handle
+0x08 unknown object field
+0x0c hidden t0 / create flags
+0x10 boot-context/base pointer
```

### 4. Socket-object vtable slots are partially identified

Two vtable slots were proven:

```text
+0x10 close_or_reset_10_candidate
+0x38 getsockopt_t0_method_38_candidate
```

`+0x10` is called by `808381f4` before creating a new socket handle if the object already has an active handle.

`+0x38` is called by `808385f4` with `level=0xffff`, `option_name=0x1008`, an output value buffer, and hidden `t0 = &optlen`.

### 5. The global at `81825d98` is the socket-object vtable

`808381b4` writes the address of `DAT_81825d98` into object field `+0x00` before cleanup/free. This is a vtable restoration step in a destructor/free wrapper.

New label:

```text
g_stage1_socket_object_vtable_81825d98_candidate
```

---

## Ghidra Changes Made / Recommended

### Function renames

| Address | Old name | New name | Status |
|---:|---|---|---|
| `80ef80a8` | `fn_stage1_signal_object_type2_callback_1c_t0_dispatch_80ef80a8` | `fn_stage1_signal_object_type2_setsockopt_t0_dispatch_80ef80a8` | confirmed socket-provider role |
| `80ef81ac` | `FUN_80ef81ac` / callback wrapper | `fn_stage1_signal_object_type2_callback_14_dispatch_80ef81ac` | wrapper confirmed, exact semantics unknown |
| `808381f4` | `FUN_808381f4` | `fn_stage1_socket_object_create_and_configure_808381f4` | confirmed enough to drop `_candidate` |
| `808385f4` | `FUN_808385f4` | `fn_stage1_socket_object_close_cleanup_808385f4` | confirmed enough to drop `_candidate` |
| `808381b4` | `FUN_808381b4` | `fn_stage1_socket_object_destroy_free_808381b4` | confirmed enough to drop `_candidate` |
| `8006111c` | `FUN_8006111c` | `fn_stage1_socket_option_normalize_from_create_flags_8006111c_candidate` | candidate until opened |
| `800611b0` | `FUN_800611b0` | `fn_stage1_socket_option_requires_initial_sol_socket_800611b0_candidate` | candidate until opened |

### Function signatures

#### `80ef80a8`

```c
int fn_stage1_signal_object_type2_setsockopt_t0_dispatch_80ef80a8
        (uint signal_index,
         int level,
         int option_name,
         void *option_value);
```

Comment note:

```text
hidden incoming t0 = option length; normal C prototype does not model this register input.
```

#### `808381f4`

```c
int fn_stage1_socket_object_create_and_configure_808381f4
        (stage1_socket_object_candidate *socket_object,
         int address_family,
         int socket_type,
         int protocol);
```

Comment note:

```text
hidden incoming t0 = create flags / option input; saved at socket_object +0x0c.
```

#### `808385f4`

```c
int fn_stage1_socket_object_close_cleanup_808385f4
        (stage1_socket_object_candidate *socket_object);
```

#### `808381b4`

```c
void fn_stage1_socket_object_destroy_free_808381b4
        (stage1_socket_object_candidate *socket_object);
```

#### `80ef7374`

The provider-create function had an incorrect decompiler signature that made the caller pass junk as a fourth argument. Assembly showed only three real arguments.

Use:

```c
uint fn_stage1_signal_object_create_from_provider_table_80ef7374_candidate
        (int address_family,
         int socket_type,
         int protocol);
```

#### `8006111c`

```c
uint fn_stage1_socket_option_normalize_from_create_flags_8006111c_candidate
        (uint create_flags_or_t0);
```

#### `800611b0`

```c
bool fn_stage1_socket_option_requires_initial_sol_socket_800611b0_candidate
        (uint normalized_option);
```

---

## Datatypes / Structures

### `stage1_socket_object_candidate`

Create under:

```text
/tc7200u/stage1/signal
```

Layout:

```c
typedef struct stage1_socket_object_candidate {
    stage1_socket_object_vtable_candidate *vtable_00;   /* +0x00 */
    uint signal_index_or_socket_handle_04;              /* +0x04 */
    undefined4 field_08;                                /* +0x08 */
    uint create_flags_or_t0_0c_candidate;               /* +0x0c */
    undefined4 boot_context_base_10_candidate;          /* +0x10 */
} stage1_socket_object_candidate; /* size at least 0x14 */
```

Notes:

- Keep `_candidate` on the struct because the layout is partial.
- `boot_context_base_10_candidate` belongs to `stage1_socket_object_candidate`, not to the vtable.
- `vtable_00` can temporarily be `undefined4` if Ghidra cannot resolve the pointer type, but the final target type is `stage1_socket_object_vtable_candidate *`.

### `stage1_socket_object_vtable_candidate`

Create under:

```text
/tc7200u/stage1/signal
```

Layout:

```c
typedef struct stage1_socket_object_vtable_candidate {
    undefined4 field_00;                                             /* +0x00 */
    undefined4 field_04;                                             /* +0x04 */
    undefined4 field_08;                                             /* +0x08 */
    undefined4 field_0c;                                             /* +0x0c */
    stage1_socket_close_or_reset_10_cb *close_or_reset_10_candidate; /* +0x10 */
    undefined1 pad_14[0x24];                                         /* +0x14 */
    stage1_socket_getsockopt_t0_method_38_cb *getsockopt_t0_method_38_candidate; /* +0x38 */
} stage1_socket_object_vtable_candidate; /* size at least 0x3c */
```

Critical Ghidra result after fixing the vtable size/layout:

```c
(*socket_object->vtable_00->close_or_reset_10_candidate)(socket_object);
```

and:

```c
(*socket_object->vtable_00->getsockopt_t0_method_38_candidate)
        (socket_object, 0xffff, 0x1008, opt_value_and_len);
```

Before the vtable-size fix, Ghidra produced incorrect array-style output like:

```c
socket_object->vtable_00[1].field0_0x0
socket_object->vtable_00[3].field2_0x8
```

That was datatype damage, not code logic.

### `stage1_socket_close_or_reset_10_cb`

Function definition:

```c
void stage1_socket_close_or_reset_10_cb
        (stage1_socket_object_candidate *socket_object);
```

### `stage1_socket_getsockopt_t0_method_38_cb`

Function definition:

```c
int stage1_socket_getsockopt_t0_method_38_cb
        (stage1_socket_object_candidate *socket_object,
         int level,
         int option_name,
         void *option_value);
```

Comment note:

```text
hidden incoming t0 = option-length pointer; normal C prototype does not model this register input.
```

### `stage1_signal_object_type2_ops_candidate` update

Update the type2 ops field at `+0x1c`.

Old field:

```text
callback_1c_t0_candidate
```

Better socket-provider-aware field:

```text
setsockopt_t0_callback_1c_candidate
```

Callback typedef/function definition:

```c
int stage1_signal_object_type2_setsockopt_t0_cb
        (stage1_signal_object_candidate *signal_object,
         int level,
         int option_name,
         void *option_value);
```

Comment note:

```text
hidden incoming t0 = option length; normal C prototype does not model this register input.
```

Keep the structure name as:

```text
stage1_signal_object_type2_ops_candidate
```

Do not remove `_candidate` from this structure yet.

---

## Detailed Function Behavior

### `fn_stage1_socket_object_create_and_configure_808381f4`

Role:

```text
Create a Stage1 socket/provider signal object, apply initial socket options, and store the resulting handle/context into the wrapper object.
```

Behavior:

1. If `socket_object->signal_index_or_socket_handle_04` is nonzero, calls vtable `+0x10` close/reset method first.
2. Calls `fn_stage1_signal_object_create_from_provider_table_80ef7374_candidate(address_family, socket_type, protocol)`.
3. Stores the returned handle/index at `socket_object->signal_index_or_socket_handle_04`.
4. On create failure (`0xffffffff`):
   - clears `+0x04`,
   - optionally logs through the BcmEcosSocket log path,
   - returns `-1`.
5. Saves hidden incoming `t0` into `socket_object->create_flags_or_t0_0c_candidate`.
6. Normalizes the saved flags through `FUN_8006111c` / renamed candidate `fn_stage1_socket_option_normalize_from_create_flags_8006111c_candidate`.
7. Tests whether an initial SOL_SOCKET-like option is required through `FUN_800611b0` / renamed candidate `fn_stage1_socket_option_requires_initial_sol_socket_800611b0_candidate`.
8. If required, calls `fn_stage1_signal_object_type2_setsockopt_t0_dispatch_80ef80a8` with:

```text
level       = 0xffff
option_name = normalized option
option_value = &initial_option_value
hidden t0   = 4
```

9. For `address_family == 0x1c` and nonzero saved create flags:
   - zeroes a `0x14` byte stack block,
   - stores saved flags at option block `+0x10`,
   - calls the type2 setsockopt dispatcher with:

```text
level       = 0x29
option_name = 0x2e
option_value = ipv6_pktinfo_option
hidden t0   = 0x14
```

10. Clears or applies a SO_REUSEADDR-like option:

```text
level       = 0xffff
option_name = 4
option_value = &reuseaddr_option_value
hidden t0   = 4
```

11. For `address_family == 2`, applies a portrange-like option:

```text
level       = 0
option_name = 0x13
option_value = &portrange_option_value
hidden t0   = 4
```

12. For `address_family == 0x1c`, applies an IPv6 portrange-like option:

```text
level       = 0x29
option_name = 0x0e
option_value = &portrange_option_value
hidden t0   = 4
```

13. If the handle is nonzero at the end, stores `fn_get_stage1_global_boot_context_base_80e952c0_candidate()` into `socket_object->boot_context_base_10_candidate`.
14. Returns the socket/signal handle or `-1` on create failure.

Recommended comment:

```c
/* Stage1 socket-object create/configure helper.

   Arguments:
     socket_object  = wrapper object receiving the created signal/socket handle
     address_family = socket address family; observed 2 and 0x1c
     socket_type    = socket type passed to provider create
     protocol       = protocol passed to provider create
     hidden t0      = create flags / option input; saved at socket_object +0x0c

   Behavior:
     - if socket_object->signal_index_or_socket_handle_04 is already nonzero,
       calls the vtable +0x10 cleanup/reset method first
     - creates a Stage1 signal object through
       {@symbol fn_stage1_signal_object_create_from_provider_table_80ef7374_candidate}
     - stores the created handle/index at socket_object +0x04
     - on create failure:
         clears +0x04
         logs "SOCKET_ERROR: "
         returns -1
     - saves hidden incoming t0 to socket_object +0x0c
     - converts or normalizes hidden t0 through
       {@symbol fn_stage1_socket_option_normalize_from_create_flags_8006111c_candidate}
     - conditionally applies a SOL_SOCKET-like option through
       {@symbol fn_stage1_signal_object_type2_setsockopt_t0_dispatch_80ef80a8}
       with level 0xffff and optlen 4
     - for AF_INET6 / 0x1c with nonzero saved t0:
         builds a 0x14-byte stack option block
         stores saved t0 at option_block +0x10
         applies IPV6_PKTINFO-like option:
           level 0x29, option 0x2e, optlen 0x14
     - clears/applies SO_REUSEADDR-like option:
         level 0xffff, option 4, optlen 4
     - for AF_INET / 2:
         applies IP_PORTRANGE-like option:
           level 0, option 0x13, optlen 4
     - for AF_INET6 / 0x1c:
         applies IPv6 portrange-like option:
           level 0x29, option 0x0e, optlen 4
     - if a handle exists at the end, stores
       {@symbol fn_get_stage1_global_boot_context_base_80e952c0_candidate} result at +0x10
     - returns socket_object->signal_index_or_socket_handle_04 or -1 on create failure

   Notes:
     - this proves type2 ops +0x1c is setsockopt-like in the socket provider path
     - do not treat hidden t0 as a normal C argument unless a custom calling convention is added
*/
```

### `fn_stage1_socket_object_close_cleanup_808385f4`

Role:

```text
Close/cleanup an active Stage1 socket object handle.
```

Behavior:

1. If the object has an active handle at `+0x04`, builds a getsockopt-like query:

```text
level        = 0xffff
option_name  = 0x1008
option_value = stack output word
hidden t0    = pointer to optlen word
optlen       = 4
```

2. Calls `socket_object->vtable_00->getsockopt_t0_method_38_candidate`.
3. If returned option value is `1`, calls `FUN_800c53c8`.
4. Closes the signal-object handle through `fn_stage1_signal_object_close_index_80ef629c`.
5. Clears `socket_object->signal_index_or_socket_handle_04`.
6. Returns close status, or `0` when there was no handle.

Recommended comment:

```c
/* Stage1 socket-object close/cleanup helper.

   Behavior:
     - if socket_object->signal_index_or_socket_handle_04 is nonzero:
         builds a getsockopt-like query:
           level       = 0xffff
           option_name = 0x1008
           option_value = stack int[0]
           optlen ptr  = hidden t0 = &stack int[1]
           stack int[1] = 4
         calls socket_object->vtable_00->getsockopt_t0_method_38_candidate
     - if returned option value is 1:
         calls {@symbol FUN_800c53c8} with the socket/signal handle
     - closes the handle through
       {@symbol fn_stage1_signal_object_close_index_80ef629c}
     - clears socket_object->signal_index_or_socket_handle_04
     - returns close status, or 0 if there was no handle

   Notes:
     - vtable +0x38 is getsockopt-like.
     - option 0x1008 meaning is not finalized.
     - hidden t0 is an option-length pointer.
*/
```

### `fn_stage1_socket_object_destroy_free_808381b4`

Role:

```text
Destructor/free wrapper for the Stage1 socket object.
```

Behavior:

1. Restores `socket_object->vtable_00` to `g_stage1_socket_object_vtable_81825d98_candidate`.
2. Calls `fn_stage1_socket_object_close_cleanup_808385f4(socket_object)`.
3. Calls `FUN_80127754(&socket_object->vtable_00)` / effectively base-object or secondary cleanup; this needs to be opened next.
4. Calls `fn_heap_free_if_nonnull_80f08cbc_candidate(socket_object, ...)`.

Recommended comment:

```c
/* Stage1 socket-object destroy/free wrapper.

   Behavior:
     - restores socket_object->vtable_00 to
       {@symbol g_stage1_socket_object_vtable_81825d98_candidate}
     - closes/cleans the active socket handle through
       {@symbol fn_stage1_socket_object_close_cleanup_808385f4}
     - runs secondary object cleanup through {@symbol FUN_80127754}
     - frees the socket object through
       {@symbol fn_heap_free_if_nonnull_80f08cbc_candidate}
*/
```

---

## Ghidra Decompiler Cleanup Results

Before the vtable struct was fixed, Ghidra showed array-style vtable access:

```c
socket_object->vtable_00[1].field0_0x0
socket_object->vtable_00[3].field2_0x8
```

After creating/fixing the vtable datatype and using size `0x3c`, Ghidra produced the desired output:

```c
(*socket_object->vtable_00->close_or_reset_10_candidate)(socket_object);
```

and:

```c
(*socket_object->vtable_00->getsockopt_t0_method_38_candidate)
        (socket_object,0xffff,0x1008,opt_value_and_len);
```

The provider-create call also cleaned up after its signature was reduced to three real arguments:

```c
uVar1 = fn_stage1_signal_object_create_from_provider_table_80ef7374_candidate
          (address_family, socket_type, protocol);
```

---

## Local Variables Worth Renaming

### In `808381f4`

Rename only useful decompiler-visible variables:

```text
uVar1      -> socket_handle_or_result
in_t0      -> create_flags_or_t0
local_38   -> initial_option_value
local_34   -> reuseaddr_option_value
local_30   -> portrange_option_value
auStack_50 -> ipv6_pktinfo_option
uStack_40  -> ipv6_pktinfo_saved_flags
```

Optional:

```text
iVar2       -> status
option_name -> option_name
```

Do not waste time renaming logging temporaries:

```text
piVar3
piVar4
uVar8
pcVar9
```

### In `808385f4`

Rename if visible:

```text
opt_value_and_len -> opt_value_and_len
socket_handle     -> socket_handle
close_status      -> close_status
```

### Do not rename Listing registers

Do not rename raw registers such as `s0`, `s1`, `s2`, `s3`, `s4`, or `t0` directly in Listing. Rename only decompiler-visible parameters, locals, globals, fields, functions, and datatypes.

---

## Comment Formatting Fix

Several copied comments had duplicated delimiters:

```c
/* /*
...
*/ */
```

Fix them to normal C block comments before exporting or adding to notes:

```c
/*
...
*/
```

Also replace stale copied text like:

```text
No symbol: fn_stage1_signal_object_create_from_provider_t
No symbol: fn_get_stage1_global_boot_context_base_80e952c0 result at +0x10
```

with real Ghidra annotation syntax:

```text
{@symbol fn_stage1_signal_object_create_from_provider_table_80ef7374_candidate}
{@symbol fn_get_stage1_global_boot_context_base_80e952c0_candidate}
```

---

## Memory Block / Address Label Notes

No new memory blocks were needed in this pass.

Keep these as RAM/software-object items, not MMIO:

```text
stage1_socket_object_candidate
stage1_socket_object_vtable_candidate
g_stage1_socket_object_vtable_81825d98_candidate
```

The vtable global belongs in the initialized image/RAM region around `0x81825d98`; it must not be moved into GENET/DQM/FPM MMIO blocks.

Existing memory-block organization remains valid:

```text
ram / initialized Stage1 image area for 0x81825d98
RAM_STAGE1_SIGNAL_GLOBALS_81a68000 for signal-object globals
RAM_STAGE1_SIGNAL_OBJECT_AREAS_81a78000_candidate for signal-object area arrays/pools
```

---

## Current Open Items / Next Work

### 1. Open `FUN_80127754`

Reason:

`808381b4` calls it after socket close cleanup and before heap free. It likely cleans an embedded/base object or shared parent-object state.

Paste next:

```text
FUN_80127754
```

### 2. Open `FUN_8006111c`

Reason:

It normalizes hidden create flags / `t0` into an option value used as the `option_name` for the initial SOL_SOCKET-like call.

Candidate name:

```text
fn_stage1_socket_option_normalize_from_create_flags_8006111c_candidate
```

### 3. Open `FUN_800611b0`

Reason:

It tests whether the normalized option requires the initial SOL_SOCKET-like call.

Candidate name:

```text
fn_stage1_socket_option_requires_initial_sol_socket_800611b0_candidate
```

### 4. Do not over-clean log-format helpers yet

Do not rename these until opened:

```text
FUN_804ec798
FUN_80f95470
FUN_80f94728
FUN_80f944fc
FUN_80f94244
FUN_800c53c8
```

Current safe notes:

```text
FUN_804ec798 / FUN_80f95470 / FUN_80f94728 / FUN_80f944fc / FUN_80f94244 are logging/formatting chain helpers.
FUN_800c53c8 is called during socket close when getsockopt-like option 0x1008 returns value 1.
```

---

## Suggested Commit

Recommended repository path:

```text
~/tc7200u-research/records/reverse/2026-06-16-stage1-socket-object-type2-setsockopt.md
```

Suggested commit message:

```text
records: document stage1 socket object reverse pass
```

WSL command sequence:

```sh
cd ~/tc7200u-research; mkdir -p records/reverse; cp /mnt/c/Users/mgta29/Downloads/2026-06-16-stage1-socket-object-type2-setsockopt.md records/reverse/2026-06-16-stage1-socket-object-type2-setsockopt.md; git status --short --branch; git add records/reverse/2026-06-16-stage1-socket-object-type2-setsockopt.md; git commit -m "records: document stage1 socket object reverse pass"; git status --short --branch
```

If the downloaded file is elsewhere, adjust only the `cp` source path.

---

## Result State

Completed in this pass:

```text
[done] Type2 +0x1c callback promoted to setsockopt-like dispatcher in socket path.
[done] Socket object structure created and applied.
[done] Socket object vtable structure created and corrected to 0x3c bytes.
[done] Vtable +0x10 and +0x38 slots identified.
[done] `808381f4` create/configure path named and typed.
[done] `808385f4` close/cleanup path named and typed.
[done] `808381b4` destroy/free wrapper named and typed.
[done] Provider-create signature corrected to three real args.
[done] Ghidra decompiler output improved from raw offsets/array vtable damage to named field calls.
```

Still pending:

```text
[pending] Open and analyze `FUN_80127754`.
[pending] Open and analyze `FUN_8006111c`.
[pending] Open and analyze `FUN_800611b0`.
[pending] Determine exact meaning of getsockopt-like option `0x1008`.
[pending] Determine exact role of `FUN_800c53c8`.
[pending] Decide whether `stage1_socket_object_candidate` should move to another category later; keep in /tc7200u/stage1/signal for now because it wraps Stage1 signal-object handles.
```
