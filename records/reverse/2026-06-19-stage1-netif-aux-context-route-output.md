# 2026-06-19 — Stage1 netif aux context / route output reverse log

## Scope

This log records the current Ghidra reverse-engineering progress around the Stage1 network-interface (`netif`) object list, socket create-flag interface mapping, binary aux-key lookup, aux event/context acquisition and release, aux-object reference management, and the route-output aux-context processing path.

The work is focused on TC7200U / BCM3383 Stage1 code paths around:

- `80eac7f4` — netif lookup by base name plus numeric unit suffix.
- `80eab9b0` — netif registration/list insertion and aux-object initialization.
- `80eac4c8` — aux-object event-1 rebind callback.
- `80eac374` — aux-object lookup by binary key blob and parent netif.
- `80ea96d0` — length-limited byte compare helper.
- `80eb005c` — aux-object selector by flags and key blobs.
- `80eafa94` — aux context acquire/lookup by binary key blob.
- `80eafc24` — aux context release/free helper.
- `80eafd6c` — aux object release/free helper.
- `80eae390` — route-output aux-context processing/rebind path.

This log also records Ghidra structure/datatype work, memory block fixes, false-function cleanup, and remaining warning cleanup.

---

## High-level result

A previously vague `route_context`/socket-create-flag path is now understood as a route/netif/aux context pipeline:

```text
create_flag_index 1..8
  -> static interface-name record: "bcm0".."bcm7"
  -> netif lookup by base name + unit suffix
  -> runtime stage1_netif_object_candidate *
  -> socket create-flag netif table
  -> source-address table
  -> route-output / aux-context processing
  -> binary key-blob lookup and aux object rebinding
```

The Stage1 netif system uses:

- A global tail-queue-style netif list head at `81840370`.
- A dynamically allocated global netif pointer array stored through `81802fb8`.
- Per-netif aux-object lists at `netif +0x10/+0x14`.
- Binary key blobs with class/type at byte `+0x01`.
- A key-class ops table at `81c0cf10` indexed by key class/type.
- Aux event contexts with reference/hold count at `+0x34`, flags at `+0x38`, current aux object at `+0x40`, and route state around `+0x44/+0x4c`.
- Aux objects with primary/secondary/mask key blobs at `+0x00/+0x04/+0x08`, parent netif at `+0x5c`, callback at `+0x68`, and hold count at `+0x70`.

---

## Ghidra memory block changes

### Existing/new RAM blocks used

#### `RAM_STAGE1_NETIF_GLOBALS_81840370_candidate`

Created earlier to cover netif globals:

```text
Start:  0x81840370
End:    0x818403bf
Length: 0x50
Type:   Uninitialized RAM
R/W:    yes
où X:    no
MMIO:   no
```

Important symbols inside:

```text
81840370  g_stage1_netif_list_head_81840370_candidate
81840374  tail_next_slot_04_candidate field
81840378  g_stage1_netif_aux_object_array_81840378_candidate
818403b4  g_stage1_ip_id_counter_818403b4_candidate
```

#### `RAM_STAGE1_NETIF_INIT_81a60b70_candidate`

Existing small block:

```text
Start: 0x81a60b70
End:   0x81a60b7f
```

Important symbol:

```text
81a60b70  g_stage1_netif_list_initialized_81a60b70_candidate
```

#### `RAM_STAGE1_NETIF_AUX_STATS_81a60b80_candidate`

Added to avoid conflict with the existing `81a60b70..81a60b7f` block and to cover aux context statistics/counters:

```text
Start:  0x81a60b80
End:    0x81a60baf
Length: 0x30
Type:   Uninitialized RAM
R/W:    yes
X:      no
MMIO:   no
```

Important symbols inside:

```text
81a60b98  g_stage1_netif_aux_context_stats_81a60b98_candidate
81a60b9e  acquire_fail_or_reject_count_06_candidate field
81a60ba4  g_stage1_netif_aux_active_context_count_81a60ba4_candidate
```

#### `RAM_STAGE1_ROUTE_OUTPUT_GLOBAL_81bfcf00_candidate`

Recommended/needed if `0x81bfcf00` is not mapped. This fixes the visible `_DAT_81bfcf00` warning in `80eae390`.

```text
Start:  0x81bfcf00
Length: 0x04
Type:   Uninitialized RAM
R/W:    yes
X:      no
MMIO:   no
```

Symbol/type:

```text
81bfcf00  g_stage1_route_output_global_level_81bfcf00_candidate  uint
```

### Memory block rule used

No new MMIO blocks were created for these findings. All addresses above are software/global RAM or image data, not MMIO.

---

## Static socket create-flag tables and records

### Interface-name records at `80f99618`

Confirmed fixed records:

```text
80f99618  "bcm0\0\0\0\0"
80f99620  "bcm1\0\0\0\0"
80f99628  "bcm2\0\0\0\0"
80f99630  "bcm3\0\0\0\0"
80f99638  "bcm4\0\0\0\0"
80f99640  "bcm5\0\0\0\0"
80f99648  "bcm6\0\0\0\0"
80f99650  "bcm7\0\0\0\0"
```

Datatype:

```c
typedef struct stage1_socket_create_flag_iface_name_record_candidate {
    char iface_name_00[4];
    undefined1 nul_pad_04[4];
} stage1_socket_create_flag_iface_name_record_candidate; /* size 0x08 */
```

Apply:

```text
80f99618  g_stage1_socket_create_flag_iface_name_records_80f99618_candidate
          stage1_socket_create_flag_iface_name_record_candidate[8]
```

### Interface-name pointer table at `8146f660`

Renamed from a vague “config object” table to interface-name pointer table:

```text
8146f660  g_stage1_socket_create_flag_iface_name_ptr_table_8146f660_candidate
          stage1_socket_create_flag_iface_name_record_candidate *[8]
```

Mapping:

| Create flag index | Table entry | Record | String |
|---:|---:|---:|---|
| 1 | `8146f660` | `80f99618` | `bcm0` |
| 2 | `8146f664` | `80f99620` | `bcm1` |
| 3 | `8146f668` | `80f99628` | `bcm2` |
| 4 | `8146f66c` | `80f99630` | `bcm3` |
| 5 | `8146f670` | `80f99638` | `bcm4` |
| 6 | `8146f674` | `80f99640` | `bcm5` |
| 7 | `8146f678` | `80f99648` | `bcm6` |
| 8 | `8146f67c` | `80f99650` | `bcm7` |

### Runtime netif table at `8146f690`

Renamed from route/context table to netif table:

```text
8146f690  g_stage1_socket_create_flag_netif_table_8146f690_candidate
          stage1_netif_object_candidate *[8]
```

This table is populated through the create-flag netif/source-address configure helper after resolving `bcm0..bcm7` to runtime netif objects.

---

## Netif global list findings

### `g_stage1_netif_list_head_81840370_candidate`

Confirmed not a bare pointer. It is a two-field tail-queue/list-head structure:

```c
typedef struct stage1_netif_list_head_candidate {
    stage1_netif_object_candidate *first_00;
    stage1_netif_object_candidate **tail_next_slot_04_candidate;
} stage1_netif_list_head_candidate; /* size 0x08 */
```

Apply at:

```text
81840370  g_stage1_netif_list_head_81840370_candidate
          stage1_netif_list_head_candidate
```

Observed initialization pattern:

```text
first_00 = NULL
tail_next_slot_04_candidate = &first_00
```

Observed insertion pattern:

```text
old_tail_next_slot = list_head.tail_next_slot_04_candidate
netif->prev_next_slot_0c_candidate = old_tail_next_slot
*old_tail_next_slot = netif
list_head.tail_next_slot_04_candidate = &netif->next_08_candidate
```

### `g_stage1_netif_object_array_81802fb8_candidate`

Confirmed pointer variable to heap-allocated global netif pointer array, not an embedded array at `81802fb8`:

```c
stage1_netif_object_candidate **g_stage1_netif_object_array_81802fb8_candidate;
```

Apply at:

```text
81802fb8  g_stage1_netif_object_array_81802fb8_candidate
          stage1_netif_object_candidate **
```

Do not apply `stage1_netif_object_candidate *[8]` directly at `81802fb8`.

Related globals:

```text
81802fb4  g_stage1_netif_registered_count_81802fb4_candidate       uint
81802fb8  g_stage1_netif_object_array_81802fb8_candidate           stage1_netif_object_candidate **
81802fbc  g_stage1_netif_table_capacity_81802fbc_candidate         uint
81840378  g_stage1_netif_aux_object_array_81840378_candidate       undefined4 / pointer
```

---

## Datatypes established/refined

### `stage1_netif_object_candidate`

Current candidate layout:

```c
typedef struct stage1_netif_object_candidate {
    undefined1 pad_00[0x04];
    char *base_name_04_candidate;
    struct stage1_netif_object_candidate *next_08_candidate;
    struct stage1_netif_object_candidate **prev_next_slot_0c_candidate;

    stage1_netif_aux_object_candidate *aux_list_first_10_candidate;
    stage1_netif_aux_object_candidate **aux_list_tail_slot_14_candidate;

    undefined1 pad_18[0x18];
    ushort registration_index_30_candidate;
    short unit_index_32_candidate;
    undefined1 pad_34[0x02];
    ushort flags_36_candidate;
    undefined1 pad_38[0x0c];

    byte field_44_candidate;
    undefined1 field_45_candidate;
    byte name_extra_len_46_candidate;
    undefined1 pad_47[0x45];

    undefined1 lock_or_state_8c_candidate[0x08];
    undefined4 field_94_candidate;
    undefined1 pad_98[0x3c];
    uint default_or_timeout_d4_candidate;
    undefined1 pad_d8[0x08];

    undefined4 embedded_list2_first_e0_candidate;
    undefined4 embedded_list2_tail_slot_e4_candidate;
} stage1_netif_object_candidate; /* size at least 0xe8 */
```

Confirmed fields:

```text
+0x04  base_name_04_candidate
+0x08  next_08_candidate
+0x0c  prev_next_slot_0c_candidate
+0x10  aux_list_first_10_candidate
+0x14  aux_list_tail_slot_14_candidate
+0x30  registration_index_30_candidate
+0x32  unit_index_32_candidate
+0x36  flags_36_candidate; bit 0x10 affects masked aux lookup behavior
+0x44  copied into aux/header records
+0x46  name_extra_len_46_candidate used for aux record sizing
+0x8c  initialized by `FUN_80ea9518`
+0x94  cleared by netif registration path
+0xd4  defaulted from `81802fac` when zero
+0xe0/+0xe4 second embedded list head/tail-slot
```

### `stage1_netif_aux_object_candidate`

Current candidate layout:

```c
typedef void stage1_netif_aux_event_callback_68_cb
        (int event_code,
         stage1_netif_aux_event_context_candidate *event_context,
         undefined4 event_arg);

typedef struct stage1_netif_aux_object_candidate {
    byte *primary_key_blob_00_candidate;
    byte *secondary_key_blob_04_candidate;
    byte *key_mask_blob_08_candidate;
    undefined1 pad_0c[0x50];
    stage1_netif_object_candidate *parent_netif_5c_candidate;
    struct stage1_netif_aux_object_candidate *next_60_candidate;
    struct stage1_netif_aux_object_candidate **prev_next_slot_64_candidate;
    stage1_netif_aux_event_callback_68_cb *callback_68_candidate;
    undefined1 pad_6c[0x04];
    uint hold_count_70_candidate;
} stage1_netif_aux_object_candidate; /* size at least 0x74 */
```

Confirmed fields:

```text
+0x00  primary_key_blob_00_candidate
+0x04  secondary_key_blob_04_candidate
+0x08  key_mask_blob_08_candidate
+0x5c  parent_netif_5c_candidate
+0x60  next_60_candidate
+0x64  prev_next_slot_64_candidate
+0x68  callback_68_candidate
+0x70  hold_count_70_candidate
```

Callback event code meanings now confirmed:

```text
1 = new/current aux became active / post-bind event
2 = old/current aux is about to be replaced / pre-unbind event
```

### `stage1_netif_aux_event_context_candidate`

Current candidate layout:

```c
typedef struct stage1_netif_aux_event_context_candidate {
    undefined1 pad_00[0x0b];
    byte state_flags_0b_candidate;
    byte *lookup_key_blob_0c_candidate;

    undefined4 field_10_candidate;
    undefined1 pad_14[0x1c];

    undefined4 field_30_candidate;
    uint hold_count_or_ref_34_candidate;
    uint flags_38_candidate;

    stage1_netif_object_candidate *parent_netif_3c_candidate;
    stage1_netif_aux_object_candidate *current_aux_40_candidate;

    byte *field_44_key_or_route_blob_candidate;
    undefined4 field_48_candidate;
    uint route_mask_or_state_4c_candidate;

    undefined1 route_state_copy_50_candidate[0x3c];
    struct stage1_netif_aux_event_context_candidate *parent_or_related_ctx_8c_candidate;
} stage1_netif_aux_event_context_candidate; /* size at least 0x90 */
```

Confirmed fields:

```text
+0x0b  state_flags_0b_candidate
+0x0c  lookup_key_blob_0c_candidate
+0x30  field_30_candidate
+0x34  hold_count_or_ref_34_candidate
+0x38  flags_38_candidate
+0x3c  parent_netif_3c_candidate
+0x40  current_aux_40_candidate
+0x44  field_44_key_or_route_blob_candidate
+0x4c  route_mask_or_state_4c_candidate
+0x50  route_state_copy_50_candidate
+0x8c  parent_or_related_ctx_8c_candidate
```

### `stage1_netif_aux_keyclass_ops_candidate`

Updated with `+0x20` callback confirmed by `80eae390`:

```c
typedef stage1_netif_aux_event_context_candidate *
stage1_netif_aux_keyclass_lookup_or_acquire_1c_cb
        (byte *lookup_key_blob,
         void *ops);

typedef stage1_netif_aux_event_context_candidate *
stage1_netif_aux_keyclass_create_or_lookup_20_cb
        (byte *lookup_key_blob,
         ushort *arg_or_key_aux);

typedef struct stage1_netif_aux_keyclass_ops_candidate {
    undefined1 pad_00[0x1c];
    stage1_netif_aux_keyclass_lookup_or_acquire_1c_cb *lookup_or_acquire_1c_candidate;
    stage1_netif_aux_keyclass_create_or_lookup_20_cb *create_or_lookup_20_candidate;
    undefined1 pad_24[0x0c];
    undefined4 release_zero_ref_30_candidate;
} stage1_netif_aux_keyclass_ops_candidate; /* size at least 0x34 */
```

Key-class table:

```text
81c0cf10  g_stage1_netif_aux_keyclass_ops_table_81c0cf10_candidate
          stage1_netif_aux_keyclass_ops_candidate *[0x21]
```

If Ghidra resists pointer array typing, fallback is `undefined4[0x21]` while keeping the label.

### `stage1_netif_aux_context_stats_81a60b98_candidate`

Used to fix `_DAT_81a60b9e` overlap warning:

```c
typedef struct stage1_netif_aux_context_stats_81a60b98_candidate {
    undefined1 pad_00[0x06];
    ushort acquire_fail_or_reject_count_06_candidate;
} stage1_netif_aux_context_stats_81a60b98_candidate; /* size at least 0x08 */
```

Apply:

```text
81a60b98  g_stage1_netif_aux_context_stats_81a60b98_candidate
          stage1_netif_aux_context_stats_81a60b98_candidate
```

---

## Function findings and naming

### `80eac7f4`

Rename:

```text
FUN_80eac7f4
-> fn_stage1_netif_find_by_name_unit_suffix_80eac7f4_candidate
```

Signature:

```c
stage1_netif_object_candidate *
fn_stage1_netif_find_by_name_unit_suffix_80eac7f4_candidate(char *ifname_with_unit);
```

Behavior:

```text
Input: "bcm0".."bcm7" style string.
- Compute string length.
- Require length 2..16.
- Parse trailing decimal unit suffix.
- Copy non-numeric prefix to stack buffer.
- Walk g_stage1_netif_list_head_81840370_candidate.first_00.
- Match netif->base_name_04_candidate against prefix.
- Match netif->unit_index_32_candidate against parsed unit.
- Return matching netif or NULL.
```

Important correction:

```text
"bcm0" is resolved as base name "bcm" plus unit 0.
It is not a full literal string compare against "bcm0".
```

### `80eab9b0`

Rename:

```text
FUN_80eab9b0
-> fn_stage1_netif_register_insert_initialize_80eab9b0_candidate
```

Signature:

```c
void fn_stage1_netif_register_insert_initialize_80eab9b0_candidate
        (stage1_netif_object_candidate *netif);
```

Behavior:

```text
- Lazily initializes global netif list head.
- Sets default netif +0xd4 from 81802fac when zero.
- Clears netif->next_08_candidate.
- Inserts netif at tail of global list.
- Increments global registration count at 81802fb4.
- Stores new index into netif->registration_index_30_candidate.
- Initializes embedded list heads at +0x10/+0x14 and +0xe0/+0xe4.
- Initializes netif +0x8c through FUN_80ea9518.
- Grows two dynamic pointer arrays when count reaches capacity.
- Stores netif into g_stage1_netif_object_array_81802fb8_candidate.
- Builds display/name string from base name and unit.
- Allocates and links an auxiliary per-netif object.
- Installs 80eac4c8 as aux callback at aux +0x68.
```

### `80eac4c8`

Rename:

```text
FUN_80eac4c8
-> fn_stage1_netif_aux_event1_rebind_callback_80eac4c8_candidate
```

Signature:

```c
void fn_stage1_netif_aux_event1_rebind_callback_80eac4c8_candidate
        (int event_code,
         stage1_netif_aux_event_context_candidate *event_context,
         undefined4 event_arg);
```

Behavior:

```text
- Handles only event_code == 1.
- Reads current aux from event_context->current_aux_40_candidate.
- Gets parent netif from current_aux->parent_netif_5c_candidate.
- Resolves replacement aux through fn_stage1_netif_aux_lookup_by_key_and_netif_80eac374_candidate.
- Releases/decrements old aux hold count.
- Stores replacement aux in event_context->current_aux_40_candidate.
- Increments replacement aux hold count.
- Chains to replacement->callback_68_candidate if present and not itself.
```

### `80eac374`

Rename:

```text
FUN_80eac374
-> fn_stage1_netif_aux_lookup_by_key_and_netif_80eac374_candidate
```

Signature:

```c
stage1_netif_aux_object_candidate *
fn_stage1_netif_aux_lookup_by_key_and_netif_80eac374_candidate
        (byte *lookup_key_blob,
         stage1_netif_object_candidate *netif);
```

Binary key blob format:

```text
+0x00 = key/blob length used by memcmp helper
+0x01 = key class/type selector, must be < 0x21
+0x02.. = key payload
```

Behavior:

```text
- Rejects key blobs whose class/type is >= 0x21.
- Walks netif->aux_list_first_10_candidate.
- Considers only aux objects whose primary_key_blob_00_candidate[1] matches lookup_key_blob[1].
- For unmasked aux objects:
  - Records first same-class unmasked aux as fallback.
  - Compares lookup against primary key.
  - If secondary key exists, compares lookup against secondary key.
- For masked aux objects:
  - If netif->flags_36_candidate bit 0x10 is set, compares against secondary key.
  - Otherwise performs masked payload compare:
    ((lookup[i] ^ primary[i]) & mask[i]) == 0.
- Returns exact/masked match first.
- If no match, returns first same-class unmasked fallback aux.
- Returns NULL if no candidate exists.
```

### `80ea96d0`

Rename:

```text
FUN_80ea96d0
-> fn_memcmp_len_80ea96d0_candidate
```

Signature:

```c
int fn_memcmp_len_80ea96d0_candidate(byte *a, byte *b, uint len);
```

Behavior:

```text
- Compares len bytes from a and b.
- Returns 0 when all compared bytes match.
- Returns a[i] - b[i] at first mismatch.
- Returns 0 for len == 0.
```

### `80eb005c`

Rename:

```text
FUN_80eb005c
-> fn_stage1_netif_aux_select_by_flags_and_key_80eb005c_candidate
```

Signature:

```c
stage1_netif_aux_object_candidate *
fn_stage1_netif_aux_select_by_flags_and_key_80eb005c_candidate
        (uint select_flags,
         byte *lookup_key_blob,
         byte *fallback_key_blob);
```

Behavior:

```text
select_flags bit 0x2 set:
  - Try FUN_80eac108(fallback_key_blob).

select_flags bit 0x2 clear:
  - If select_flags bit 0x4 set, try FUN_80eac108(lookup_key_blob).
  - If not found, try FUN_80eac040(fallback_key_blob).

If still not found:
  - Try FUN_80eac1b4(fallback_key_blob).

If still not found:
  - Acquire aux context through fn_stage1_netif_aux_context_acquire_by_key_80eafa94_candidate.
  - Immediately decrement acquired context ref count.
  - Use ctx->current_aux_40_candidate.

Final correction:
  - If selected_aux->primary_key_blob_00_candidate[1] does not match lookup_key_blob[1],
    re-run fn_stage1_netif_aux_lookup_by_key_and_netif_80eac374_candidate using
    selected_aux->parent_netif_5c_candidate.
  - Return replacement if found; otherwise return original selected aux.
```

Important Ghidra cleanup:

```text
80eb0108 was a bad function split / tail block inside 80eb005c.
It should remain cleared as a standalone function.
```

### `80eafa94`

Rename:

```text
FUN_80eafa94
-> fn_stage1_netif_aux_context_acquire_by_key_80eafa94_candidate
```

Signature:

```c
stage1_netif_aux_event_context_candidate *
fn_stage1_netif_aux_context_acquire_by_key_80eafa94_candidate
        (byte *lookup_key_blob,
         void *notify_or_event_arg,
         uint suppress_flags);
```

Behavior:

```text
- Enters protected section through FUN_80eaadec.
- Indexes key-class ops table by lookup_key_blob[1].
- Calls ops +0x1c lookup/acquire callback.
- Rejects if ops is NULL, ctx is NULL, or ctx->state_flags_0b_candidate bit 0x2 is set.
- On failure/reject, increments stats counter at 81a60b9e and may post event 0x07.
- On valid ctx:
  - If notify_or_event_arg is NULL, increments ctx->hold_count_or_ref_34_candidate.
  - If notify_or_event_arg is non-NULL, checks ctx->flags_38_candidate against ~suppress_flags and mask 0x10100.
  - May call FUN_80eb02a4 with event code 0x0b.
  - May post event 0x0b or 0x07 through FUN_80eaf0d8.
- Exits protected section through FUN_80eaaf48.
- Returns acquired ctx or NULL.
```

Confirmed note:

```text
Decompiler may show key-class table base as signed -0x7e4030f0.
This is address 0x81c0cf10.
```

### `80eafc24`

Rename:

```text
FUN_80eafc24
-> fn_stage1_netif_aux_context_release_80eafc24_candidate
```

Signature:

```c
void fn_stage1_netif_aux_context_release_80eafc24_candidate
        (stage1_netif_aux_event_context_candidate *ctx);
```

Behavior:

```text
- Uses ctx->lookup_key_blob_0c_candidate[1] to find key-class ops entry.
- Decrements ctx->hold_count_or_ref_34_candidate.
- If ref count remains positive, returns.
- If ctx->flags_38_candidate bit 0x1 is set, returns without freeing.
- Validates state_flags_0b_candidate does not contain bits 0x2/0x4.
- Decrements global active context count at 81a60ba4.
- Releases ctx->current_aux_40_candidate:
  - If aux hold count is zero, calls fn_stage1_netif_aux_object_release_80eafd6c_candidate.
  - Otherwise decrements aux hold count.
- Releases parent_or_related_ctx_8c_candidate recursively or decrements its ref.
- Frees ctx->lookup_key_blob_0c_candidate.
- Frees ctx.
```

### `80eafd6c`

Rename:

```text
FUN_80eafd6c
-> fn_stage1_netif_aux_object_release_80eafd6c_candidate
```

Signature:

```c
void fn_stage1_netif_aux_object_release_80eafd6c_candidate
        (stage1_netif_aux_object_candidate *aux);
```

Behavior:

```text
- If aux is NULL, reports/asserts through FUN_80ea88d0 with string "ifafree".
- If aux->hold_count_70_candidate is zero, frees aux through FUN_80ea89ec(aux, 9).
- Otherwise decrements aux->hold_count_70_candidate.
```

Confirmed:

```text
aux +0x70 = hold_count_70_candidate
```

Important:

```text
This function does not unlink aux from netif->aux_list_first_10_candidate.
Unlink/removal is handled elsewhere or callers only invoke this once unreachable.
```

### `80eae390`

Rename:

```text
FUN_80eae390
-> fn_stage1_route_output_aux_context_process_80eae390_candidate
```

Signature:

```c
int fn_stage1_route_output_aux_context_process_80eae390_candidate
        (int *route_packet,
         int route_output_ctx,
         byte *fallback_key_blob,
         ushort *work_arg);
```

Behavior summary:

```text
- Validates and normalizes route packet.
- Asserts/checks route packet output state through string "route_output".
- Allocates/copies route buffer.
- Parses route/key blobs through FUN_80eaebe0.
- Validates binary key class/type bytes are below 0x21.
- Handles route operation selector at route buffer +0x03.
- Uses key-class ops table at 81c0cf10.
- Calls FUN_80eb02a4 with event codes 1 and 2.
- May acquire/create aux event contexts through key-class callbacks at +0x1c/+0x20.
- May rebind event_context->current_aux_40_candidate.
- Calls old aux callback with event code 2 before replacement.
- Releases/decrements old aux hold count.
- Stores new aux into current_aux_40_candidate.
- Increments new aux hold count.
- Stores parent netif into context +0x3c.
- Calls new aux callback with event code 1 after replacement.
- Updates context route-mask/state fields around +0x4c.
- Releases acquired aux context through fn_stage1_netif_aux_context_release_80eafc24_candidate.
- Writes success/error status back into route buffer before final packet output.
```

Observed error/status values:

```text
0x16   invalid key/blob or parse failure
0x145  unexpected route packet type
0x147  unsupported operation selector
0x149  missing key-class ops entry
0x163  allocation/packet normalization failure
```

Important Ghidra repair result:

```text
False functions FUN_80eae9e8 and caseD_0 should remain cleared.
They are internal cleanup/error blocks inside 80eae390, not standalone functions.
```

---

## Ghidra cleanup performed/required

### Bad comment delimiter issue

Several comments were accidentally pasted as:

```c
/* /* ... */ */
```

Correct style:

```c
/* ... */
```

### False functions / bad flow overrides

For `80eae390`, these were false internal blocks and should not be named functions:

```text
FUN_80eae9e8
caseD_0 at 80eae9e4
```

Flow override repairs were needed around internal branches that Ghidra had marked with:

```text
-- Flow Override: CALL_RETURN (CALL_TERMINATOR)
```

Affected branch sites included:

```text
80eae488
80eae4ec
80eae60c
80eae678
80eae694
80eae6cc
80eae6dc
80eae788
80eae818
80eae9dc
```

After clearing the overrides and false functions, `80eae390` decompiled as one parent function.

### Warning cleanup

Resolved/targeted warning pattern:

```text
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */
```

Known causes:

1. `_DAT_81a60b9e`
   - Fixed by creating/applying `stage1_netif_aux_context_stats_81a60b98_candidate` at `81a60b98`.
   - `81a60b9e` becomes field `acquire_fail_or_reject_count_06_candidate`.

2. `_DAT_81bfcf00`
   - Remaining/next fix in `80eae390`.
   - Label/type as `g_stage1_route_output_global_level_81bfcf00_candidate` with type `uint`.

Do not create globals for artifacts such as:

```text
pbRam0000000c
uRam00000070
```

Those are decompiler value-tracking artifacts, not real mapped globals.

---

## Function comments prepared for Ghidra

### `fn_stage1_netif_aux_context_acquire_by_key_80eafa94_candidate`

```c
/* Stage1 netif aux context acquire/lookup by binary key blob.

   Input:
     lookup_key_blob:
       +0x01 selects a key-class ops entry from the table at
       {@address 81c0cf10}.

   Behavior:
     - enters protected section through {@symbol FUN_80eaadec}
     - indexes the key-class ops table by lookup_key_blob[1]
     - if an ops entry exists, calls its +0x1c lookup/acquire callback
       with lookup_key_blob
     - rejects the result if:
         ops is NULL
         callback returns NULL
         ctx->state_flags_0b_candidate has bit 0x2 set
     - on reject/failure:
         increments failure/stat counter at {@address 81a60b9e}
         optionally posts event 0x07 when notify_or_event_arg is non-NULL
     - on valid ctx:
         stores it as return_ctx
         if notify_or_event_arg is NULL:
           increments ctx->hold_count_or_ref_34_candidate
         otherwise:
           checks ctx->flags_38_candidate against ~suppress_flags and mask 0x10100
           may call {@symbol FUN_80eb02a4} with event code 0x0b
           if event call succeeds:
             increments ctx->hold_count_or_ref_34_candidate
           may post event 0x0b or 0x07 through {@symbol FUN_80eaf0d8}
     - exits protected section through {@symbol FUN_80eaaf48}
     - returns return_ctx or NULL

   Confirmed fields:
     ctx +0x0b = state_flags_0b_candidate
     ctx +0x34 = hold_count_or_ref_34_candidate
     ctx +0x38 = flags_38_candidate
     ctx +0x40 = current_aux_40_candidate, used by aux selector paths

   Notes:
     - the decompiler may show the key-class table as signed address
       -0x7e4030f0; this is {@address 81c0cf10}.
     - hidden t1 is used by {@symbol FUN_80eb02a4} as a pointer to the local
       return slot in the original assembly path.
*/
```

### `fn_stage1_route_output_aux_context_process_80eae390_candidate`

```c
/* Stage1 route_output aux-context processing path.

   Behavior:
     - validates and normalizes the route packet
     - asserts/checks route packet output state through "route_output"
     - copies the packet payload into a temporary route buffer
     - parses route/key blobs through {@symbol FUN_80eaebe0}
     - validates binary key class/type bytes are below 0x21
     - handles route operation selector at route buffer +0x03
     - uses key-class ops table at {@symbol g_stage1_netif_aux_keyclass_ops_table_81c0cf10_candidate}
     - may acquire/create aux event contexts through key-class callbacks at +0x1c/+0x20
     - may call {@symbol FUN_80eb02a4} with event codes 1 or 2
     - may rebind event_context->current_aux_40_candidate:
         old aux receives event callback code 2 before replacement
         old aux hold_count_70_candidate is released/decremented
         new aux becomes current_aux_40_candidate
         new aux hold_count_70_candidate is incremented
         new aux receives event callback code 1 after replacement
     - updates context route-mask/state fields around +0x4c
     - releases any acquired aux context through
       {@symbol fn_stage1_netif_aux_context_release_80eafc24_candidate}
     - writes success/error status back into the route buffer before final packet output

   Error/status values observed:
     0x16  invalid key/blob or parse failure
     0x145 unexpected route packet type
     0x147 unsupported operation selector
     0x149 missing key-class ops entry
     0x163 allocation/packet normalization failure

   Notes:
     - this function owns the main aux-context route update/rebind flow.
     - do not split internal cleanup labels into standalone functions.
*/
```

---

## Remaining open targets

### Immediate next function

```text
FUN_80eb02a4
```

Reason:

```text
It is central to event dispatch and receives event codes 1, 2, and 0x0b.
It uses hidden t1 as a pointer to the local return slot in at least some call paths.
It likely defines the event dispatch contract for aux contexts.
```

### Other future targets

```text
FUN_80eac108   likely direct/fast aux lookup by key
FUN_80eac040   alternate aux lookup by key
FUN_80eac1b4   lookup/default aux path
FUN_80eaebe0   route/key blob parser
FUN_80eaef28   route operation/key size helper
FUN_80eaf0d8   event post/dispatch helper
FUN_80eb09bc   context/key validation helper
```

---

## Git/repo note

This file was generated as a standalone Markdown artifact. The repository was not mounted in the sandbox, so the git commit could not be performed here.

Recommended repo destination:

```text
~/tc7200u-research/records/reverse/2026-06-19-stage1-netif-aux-context-route-output.md
```

Recommended commit message:

```text
records: log stage1 netif aux context route output findings
```

One-line WSL command:

```bash
cd ~/tc7200u-research; mkdir -p records/reverse; cp /mnt/data/2026-06-19-stage1-netif-aux-context-route-output.md records/reverse/2026-06-19-stage1-netif-aux-context-route-output.md; git status --short; git add records/reverse/2026-06-19-stage1-netif-aux-context-route-output.md; git commit -m "records: log stage1 netif aux context route output findings"; git status --short
```
