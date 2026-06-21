# 2026-06-21 - Net-config, heap/free-list, and NATP/GFAP Ghidra log

## Scope

This record captures the Ghidra findings and proposed changes from the 2026-06-21 TC7200U stage1 reverse-engineering session. The work focused on:

- NATP/GFAP manager thread-main and L1 cache removal logic.
- Heap/free-list wrapper and real heap block free routine.
- `0x81470000` high-half global-data anchor and nearby globals.
- Network/config cache rebuild, indexed-cache append/clear, and request-handler flow.
- Memory-block correction needed for the 32-entry `0x400`-byte net-config backing table.

Program context:

```text
Program: image.raw
Language: MIPS:BE:32:default
Image base: 0x80004000
Repo target path: records/reverse/
```

## Executive summary

The session confirmed that the NATP/GFAP ops entry at `8053d514` is not an unknown method; it is the NAT session manager thread main loop. The function drives timer/message handling, pending session processing, TCP/UDP session configuration, stale DS-Lite checks, stale-entry scans, and timer restart.

The `8053e3f0` function is now identified as the NATP/GFAP L1 cache removal helper. It removes a heap entry from a vector at manager offset `0x1eec` by matching the first word of the entry against a session/context key.

The heap-free path was traced through:

```text
80f08cbc -> 800049d0 -> 8002a280
```

The actual heap free routine starts at `8002a280`, not `8002a2f0`. It treats the incoming pointer as a heap allocation payload pointer and uses a 12-byte heap block header at `payload - 0x0c`.

The `0x81470000` symbol is not a real heap object. It should remain only a high-half anchor for `lui ...,0x8147` references. Precise globals should be labeled at their exact offsets.

The network/config cache logic now splits into two caches:

1. A small 6-entry cache at `8187bcb8`, entries of size `0x24`, counted by `81470008`.
2. A larger indexed cache at `8187bdb0`, 32 entries of size `0x400`, counted by `81470024` and backed by a registry at `81748e64`.

The existing memory block containing `8187bdb0` is too small. It must be extended before applying the full 32-entry table datatype.

---

# 1. Memory block findings and required changes

## 1.1 Existing block issue around `8187bdb0`

The memory-block export shows:

```text
RAM_FPM_TOKEN_MANAGER_STATE_8187BC60
  start: 8187bc60
  end:   8187be5f
  size:  0x200
  rw, non-exec, non-volatile, uninitialized
```

The net-config indexed backing table starts at:

```text
8187bdb0
```

The clear routine zeroes `0x8000` bytes from this address:

```text
8187bdb0..81883daf
```

The current block only covers:

```text
8187bdb0..8187be5f
```

which is `0xb0` bytes of the required `0x8000`. The rest is unmapped until the next block.

The next memory block begins at:

```text
BSS_STAGE1_FAP_BYPASS_81883E00_candidate
  start: 81883e00
  end:   81883fff
```

This does not overlap the required table end at `81883daf`.

## 1.2 Preferred block resize

Resize and rename the existing block:

```text
Old name: RAM_FPM_TOKEN_MANAGER_STATE_8187BC60
New name: RAM_STAGE1_FPM_NETCFG_RUNTIME_8187BC60_candidate
Start:    8187bc60
End:      81883daf
Size:     0x8150
Read:     yes
Write:    yes
Execute:  no
Volatile: no
Overlay:  no
Initialized: no
```

Calculation:

```text
81883daf - 8187bc60 + 1 = 0x8150
```

Block comment:

```text
Normal RAM/BSS runtime region. Contains FPM/token-manager adjacent state,
net-config cache entries at 8187bcb8, and the 0x8000 net-config backing table
starting at 8187bdb0. Not MMIO.
```

After resizing, apply:

```text
8187bdb0  net_config_indexed_cache_entry_400_candidate[32]  g_net_config_large_cache_table_8187BDB0_candidate
```

## 1.3 Fallback if block resizing is blocked

Less preferred fallback:

```text
8187bdb0  uint8_t[0x0b0]   g_net_config_large_cache_table_8187BDB0_part0_candidate
8187be60  uint8_t[0x7f50]  g_net_config_large_cache_table_8187BE60_part1_candidate
```

This is less useful for decompiler work because the logical table is split across two data objects. Prefer the block resize.

## 1.4 Do not touch this block

Leave this block intact:

```text
81883e00..81883fff  BSS_STAGE1_FAP_BYPASS_81883E00_candidate
```

The net-config table ends before it.

## 1.5 `81470000` memory status

`81470000` is mapped normal RAM/global data, not MMIO. It catches many `lui ...,0x8147` high-half references and must not be typed as a heap object or a struct.

Recommended label:

```text
81470000  anchor_8147_hi16_global_region_candidate
```

Recommended plate comment text. In Ghidra, enter this as plain plate-comment text, without wrapping it in `/* ... */`:

```text
High-half anchor for normal RAM/global data around 0x81470000.

Many XREFs here are only MIPS `lui ...,0x8147` high-half loads.
This address is not itself a single heap object or MMIO register block.

Label precise globals at their real offsets instead, for example:
  0x81470008 network config cache count candidate
  0x814709e8 heap initialized/state
  0x814709ec heap free-list head
  0x814709f0 heap allocated-list head
  0x814709f4 heap status/error
  0x81470a00 heap stats block
```

---

# 2. NATP/GFAP manager updates

## 2.1 Thread main at `8053d514`

Rename:

```text
fn_natp_gfap_manager_ops_method_0c_8053d514_candidate
```

to:

```text
fn_natp_gfap_manager_thread_main_8053d514
```

Signature:

```c
int32_t fn_natp_gfap_manager_thread_main_8053d514(
    natp_gfap_manager_candidate *mgr);
```

Reason:

- Logs or formats around the string `"ThreadMain"`.
- Runs the NAT session manager loop.
- Drains manager message/timer objects.
- Processes pending session work.
- Handles unresolved-neighbor and TCP/UDP-session configuration paths.
- Periodically checks stale DS-Lite endpoints.
- Periodically scans 64 runtime entries.
- Restarts a periodic timer object.

## 2.2 NATP/GFAP ops table update

Add:

```c
typedef int32_t natp_gfap_manager_thread_main_fn(
    natp_gfap_manager_candidate *mgr);
```

Update:

```c
typedef struct natp_gfap_manager_ops_candidate {
    natp_gfap_manager_destroy_fn_candidate *destroy_00;
    natp_gfap_manager_destroy_fn_candidate *destroy_and_free_04;
    natp_gfap_manager_runtime_init_fn_candidate *runtime_init_08;
    natp_gfap_manager_thread_main_fn *thread_main_0c;
    natp_gfap_manager_timer_release_fn_candidate *release_timer_objects_10;
} natp_gfap_manager_ops_candidate;
```

## 2.3 False function splits inside `8053d514`

Delete function definitions only, keeping labels and bytes:

```text
8053d550
8053d56c
8053d5e0
8053d984
8053da30
8053dadc
8053daf8
8053dcb0
8053df8c
8053e038
8053e150
8053e178
8053e1a0
8053e230
8053e28c
8053e338
```

Suggested labels:

```text
8053d5ac  LAB_natp_gfap_thread_loop_top_8053d5ac
8053d5e0  LAB_natp_gfap_drain_message_queue_8053d5e0
8053d704  LAB_natp_gfap_pending_session_vector_check_8053d704
8053d81c  LAB_natp_gfap_process_pending_session_entry_8053d81c
8053daf8  LAB_natp_gfap_pending_session_loop_next_8053daf8
8053db60  LAB_natp_gfap_periodic_dslite_stale_check_8053db60
8053dc5c  LAB_natp_gfap_scan_64_runtime_entries_8053dc5c
8053dca0  LAB_natp_gfap_restart_periodic_timer_8053dca0
8053dd18  LAB_natp_gfap_thread_main_return_8053dd18
```

## 2.4 Manager structure corrections

Correct middle block:

```text
0xdb0   byte[0x24]                                runtime_config_db0
0xdd4   uint32_t                                  field_dd4_candidate
0xdd8   uint32_t                                  stale_entry_scan_tick_dd8
0xddc   uint32_t                                  traffic_counter_psm_temp_out_ddc
0xde0   uint32_t                                  gfap_counter_psm_offset_de0_candidate
0xde4   uint32_t                                  traffic_counter_psm_extra_de4_candidate
0xde8   uint32_t                                  timer_interval_de8
0xdec   natp_gfap_runtime_entry_44_candidate[64]  runtime_entries_dec
0x1eec  natp_gfap_l1_cache_vector_candidate       l1_cache_vector_1eec_candidate
0x1ef8  natp_gfap_u32_vector_candidate            active_or_lookup_session_vector_1ef8_candidate
0x1f04  natp_gfap_u32_vector_candidate            pending_session_vector_1f04_candidate
0x1f10  void *                                    timer_obj_1f10
```

Additional field names now justified:

```text
0xa0   uint32_t  dslite_stale_scan_tick_a0
0xda8  uint8_t   runtime_processing_enabled_da8_candidate
0xda9  uint8_t   wan_config_ok_da9_candidate
0xdd8  uint32_t  stale_entry_scan_tick_dd8
```

## 2.5 Runtime entry datatype

Create in `/tc7200u/dqm_host_fap`:

```c
typedef struct natp_gfap_runtime_entry_44_candidate {
    uint8_t active_00;
    byte pad_01[0x43];
} natp_gfap_runtime_entry_44_candidate;
```

Apply:

```text
0x0dec  natp_gfap_runtime_entry_44_candidate[64]  runtime_entries_dec
```

The thread-main scan proves the entry stride:

```text
index * 0x44 + mgr + 0xdec
```

## 2.6 Generic vector datatype correction

Use:

```c
typedef struct natp_gfap_u32_vector_candidate {
    uint32_t *begin_00;
    uint32_t *end_04;
    uint32_t *capacity_end_08;
} natp_gfap_u32_vector_candidate;
```

The earlier `field_04_unknown` interpretation should be replaced by `end_04`.

## 2.7 Counter-table corrections

The thread-main path uses halfword load/store and `field_54 * 2` indexing into the later table regions. Update:

```text
0x623c0  uint16_t[0x10000]  nat_session_counter_table_3_623c0
0x823c0  uint16_t[0x10000]  nat_session_counter_table_4_823c0
```

Do not change earlier tables until their access width is proven.

---

# 3. NATP/GFAP L1 cache removal at `8053e3f0`

## 3.1 Function rename and signature

Rename:

```text
FUN_8053e3f0
```

to:

```text
fn_natp_gfap_l1_cache_remove_by_session_key_8053e3f0_candidate
```

Signature:

```c
int32_t fn_natp_gfap_l1_cache_remove_by_session_key_8053e3f0_candidate(
    natp_gfap_manager_candidate *mgr,
    void *session_key_or_context);
```

Return behavior:

```text
0 = not found
1 = found, removed, freed
```

## 3.2 Behavior

The function:

- Enters `mgr->guarded_lock_40`.
- Scans `mgr->l1_cache_vector_1eec_candidate` from `begin_00` to `end_04`.
- Treats each vector element as a pointer to a heap entry.
- Compares `entry->session_key_or_context_00` to `session_key_or_context`.
- On match:
  - logs `"removed from L1 cache."`
  - frees the matched heap entry via `fn_heap_free_if_nonnull_80f08cbc_candidate`
  - shifts remaining vector entries down via `fn_memmove_80ea00b0_candidate`
  - decrements `end_04` by one element
  - releases the lock
  - returns `1`
- If no match:
  - releases the lock
  - returns `0`

## 3.3 Datatypes

Create in `/tc7200u/dqm_host_fap`:

```c
typedef struct natp_gfap_l1_cache_entry_candidate {
    void *session_key_or_context_00;
} natp_gfap_l1_cache_entry_candidate;
```

Create:

```c
typedef struct natp_gfap_l1_cache_vector_candidate {
    natp_gfap_l1_cache_entry_candidate **begin_00;
    natp_gfap_l1_cache_entry_candidate **end_04;
    natp_gfap_l1_cache_entry_candidate **capacity_end_08;
} natp_gfap_l1_cache_vector_candidate;
```

Manager field:

```text
0x1eec  natp_gfap_l1_cache_vector_candidate  l1_cache_vector_1eec_candidate
```

Keep `0x1ef8` and `0x1f04` as the generic vector type until their entry types are proven.

## 3.4 Lock datatype

Use the known lock type for manager lock fields:

```text
0x3c  stage1_guarded_context_lock_candidate *  guarded_lock_3c
0x40  stage1_guarded_context_lock_candidate *  guarded_lock_40
0x44  stage1_guarded_context_lock_candidate *  guarded_lock_44
```

The function proves at least `guarded_lock_40` has:

```text
+0x00 refcount / recursion depth
+0x04 waiter_count
+0x08 owner_context
+0x0c semaphore
```

## 3.5 Helper rename

Rename:

```text
FUN_80ea00b0
```

to:

```text
fn_memmove_80ea00b0_candidate
```

Signature:

```c
void *fn_memmove_80ea00b0_candidate(
    void *dst,
    void *src,
    uint32_t len);
```

## 3.6 Plate comment for `8053e3f0`

```c
/* Remove a NATP/GFAP session entry from the L1 cache vector.

   Arguments:
     mgr = NATP/GFAP manager object
     session_key_or_context = value matched against entry->session_key_or_context_00

   Flow:
     - enters mgr->guarded_lock_40
     - scans mgr->l1_cache_vector_1eec_candidate from begin_00 to end_04
     - each vector element is a heap entry pointer
     - match condition:
         entry->session_key_or_context_00 == session_key_or_context
     - on match:
         logs "removed from L1 cache."
         frees the matched entry through
           {@symbol fn_heap_free_if_nonnull_80f08cbc_candidate}
         shifts remaining vector entries down with {@symbol fn_memmove_80ea00b0_candidate}
         decrements mgr->l1_cache_vector_1eec_candidate.end_04 by one entry
         releases mgr->guarded_lock_40
         returns 1
     - if no match:
         releases mgr->guarded_lock_40
         returns 0

   Current interpretation:
     L1 NAT session cache removal by session/context key.
*/
```

Suggested labels:

```text
8053e4c8  LAB_natp_gfap_l1_cache_scan_entry_8053e4c8
8053e538  LAB_natp_gfap_l1_cache_remove_match_8053e538
8053e5d8  LAB_natp_gfap_l1_cache_scan_next_8053e5d8
8053e644  LAB_natp_gfap_l1_cache_remove_return_8053e644
```

---

# 4. Heap/free-list path

## 4.1 Free-if-nonnull wrapper at `80f08cbc`

Keep four arguments. The wrapper tests only `ptr`, but it forwards `a1/a2/a3` to the next heap-free wrapper.

Signature:

```c
void fn_heap_free_if_nonnull_80f08cbc_candidate(
    void *ptr,
    void *free_diag_context_candidate,
    uint32_t free_diag_arg2_candidate,
    undefined4 free_diag_arg3_candidate);
```

## 4.2 Heap-free trampoline at `800049d0`

Signature:

```c
void fn_heap_free_wrapper_800049d0_candidate(
    void *ptr,
    void *free_diag_context_candidate,
    uint32_t free_diag_arg2_candidate,
    undefined4 free_diag_arg3_candidate);
```

Behavior:

```text
Forwards ptr and current a1/a2/a3 unchanged to the real free-list routine.
```

## 4.3 Real heap free routine starts at `8002a280`

Correct name:

```text
8002a280  fn_heap_free_list_block_8002a280_candidate
```

Do not use:

```text
fn_heap_free_list_block_8002a2f0_candidate
```

because `8002a2f0` is an internal branch instruction, not the function entry.

Signature:

```c
void fn_heap_free_list_block_8002a280_candidate(
    void *heap_payload_ptr,
    void *free_diag_context_candidate,
    uint32_t free_diag_arg2_candidate,
    undefined4 free_diag_arg3_candidate);
```

Keep four arguments because the function forwards `a1/a2/a3` to its diagnostic/reporting path.

## 4.4 Heap block header datatype

Create in `/tc7200u/common/heap`:

```c
typedef struct stage1_heap_block_header_candidate {
    struct stage1_heap_block_header_candidate *next_00;
    struct stage1_heap_block_header_candidate *prev_04;
    uint32_t size_08;
} stage1_heap_block_header_candidate;
```

Pointer relation:

```text
heap_payload_ptr = heap_header + 0x0c
heap_header      = heap_payload_ptr - 0x0c
```

## 4.5 Heap stats datatype

Create in `/tc7200u/common/heap`:

```c
typedef struct stage1_heap_stats_candidate {
    uint32_t field_00_unknown;
    uint32_t free_bytes_or_total_04;
    uint32_t field_08_unknown;
    uint32_t field_0c_unknown;
    uint32_t free_block_count_10;
    uint32_t alloc_block_count_14;
} stage1_heap_stats_candidate;
```

## 4.6 Heap globals

Apply precise labels and types:

```text
814709e8  uint32_t                              g_heap_initialized_or_state_814709E8_candidate
814709ec  stage1_heap_block_header_candidate *  g_heap_free_list_head_814709EC_candidate
814709f0  stage1_heap_block_header_candidate *  g_heap_allocated_list_head_814709F0_candidate
814709f4  uint32_t                              g_heap_error_or_status_814709F4_candidate
81470a00  stage1_heap_stats_candidate           g_heap_stats_base_81470A00_candidate
```

## 4.7 Plate comment for `8002a280`

```c
/* Generic heap/free-list free routine.

   Arguments:
     heap_payload_ptr = heap allocation payload pointer
     free_diag_context_candidate = forwarded diagnostic/caller context
     free_diag_arg2_candidate = forwarded diagnostic argument
     free_diag_arg3_candidate = forwarded diagnostic argument

   Layout:
     heap header is at heap_payload_ptr - 0x0c:
       +0x00 next
       +0x04 prev
       +0x08 size

   Behavior:
     - clears {@symbol g_heap_error_or_status_814709F4_candidate}
     - if heap is not initialized, records status 3 and returns
     - ignores NULL payload pointers
     - computes block header at payload - 0x0c
     - optionally validates/reports the block through diagnostics
     - removes block from allocated-list:
         {@symbol g_heap_allocated_list_head_814709F0_candidate}
     - inserts block into free-list in address order:
         {@symbol g_heap_free_list_head_814709EC_candidate}
     - updates heap counters at:
         {@symbol g_heap_stats_base_81470A00_candidate}
     - coalesces adjacent free blocks
     - records status 2 if final heap check fails

   Important:
     a1/a2/a3 are not used for normal list manipulation, but they are forwarded
     to the diagnostic path. Keep the 4-argument signature.
*/
```

---

# 5. `0x81470000` nearby globals

## 5.1 Labels and types

```text
81470000  anchor_8147_hi16_global_region_candidate        no datatype
81470008  g_net_config_cache_entry_count_81470008_candidate      uint32_t
8147001c  DAT_8147001c                                    unresolved
81470020  g_net_config_requested_flag_81470020_candidate  uint8_t
81470024  g_net_config_indexed_cache_count_81470024_candidate    uint32_t
81470028  g_net_config_context_ptr_81470028_candidate     void * candidate
```

Notes:

- `81470000` should not be typed.
- `81470008` belongs to the small 6-entry net-config cache.
- `81470020` is a byte flag set by `sb`, so it must be `uint8_t`.
- `81470024` is the count/index for the large 32-entry indexed cache.
- `81470028` is used by `800c5b38` as a context pointer candidate.
- `8147001c` should remain unresolved until the function at `800c52fc` is analyzed.

---

# 6. Small net-config cache at `8187bcb8`

## 6.1 Rebuild helper at `800bb48c`

Delete false function definitions only:

```text
800bb4f8
800bb500
```

Rename:

```text
FUN_800bb48c
```

to:

```text
fn_net_config_cache_rebuild_800bb48c_candidate
```

Signature:

```c
int32_t fn_net_config_cache_rebuild_800bb48c_candidate(
    uint8_t rebuild_existing);
```

Only `a0` is a real input here.

Behavior:

- Optionally removes existing entries by calling `FUN_800bb400` in a loop.
- Clears `g_net_config_cache_entry_count_81470008_candidate`.
- Initializes six entries at `8187bcb8`, each `0x24` bytes.
- For each entry:
  - clears `+0x00`
  - clears `+0x04`
  - clears `+0x08`
  - initializes object/subobject at `+0x0c` through `FUN_8002e11c`
- Populates entries through `FUN_80484a08`.
- Increments `g_net_config_cache_entry_count_81470008_candidate`.
- Marks selected entries active by writing `1` to `entry->active_00`.

Suggested labels:

```text
800bb4f4  LAB_net_config_remove_existing_loop_800bb4f4
800bb500  LAB_net_config_remove_existing_loop_test_800bb500
800bb50c  LAB_net_config_clear_and_init_cache_800bb50c
800bb524  LAB_net_config_init_entry_loop_800bb524
800bb5a4  LAB_net_config_accept_entry_first_pass_800bb5a4
800bb5d4  LAB_net_config_fill_first_pass_loop_800bb5d4
800bb660  LAB_net_config_accept_entry_second_pass_800bb660
800bb6a8  LAB_net_config_fill_second_pass_loop_800bb6a8
800bb6e4  LAB_net_config_cache_rebuild_return_800bb6e4
```

## 6.2 Small cache datatype

Create in `/tc7200u/common/network`:

```c
typedef struct net_config_cache_entry_24_candidate {
    uint8_t active_00;
    byte pad_01[3];
    uint32_t field_04_zeroed_or_index_candidate;
    uint32_t field_08_zeroed_or_owner_candidate;
    byte object_0c[0x18];
} net_config_cache_entry_24_candidate;
```

Apply:

```text
8187bcb8  net_config_cache_entry_24_candidate[6]  g_net_config_cache_entries_8187BCB8_candidate
```

The stride is proven by the index math:

```text
((i << 3) + i) << 2 = i * 0x24
```

---

# 7. Large indexed net-config cache

## 7.1 Clear helper at `800c5c40`

Rename:

```text
FUN_800c5c40
```

to:

```text
fn_net_config_indexed_cache_clear_800c5c40_candidate
```

Signature:

```c
void fn_net_config_indexed_cache_clear_800c5c40_candidate(void);
```

Arguments `a0..a3` are not real inputs.

Behavior:

- Uses `g_net_config_indexed_cache_count_81470024_candidate` as a descending index/count.
- For each positive count:
  - calls `FUN_8015d778(&g_net_config_index_registry_81748E64_candidate, count)`
  - if an entry exists, calls `FUN_8015d984` to remove/delete it
  - decrements count
- Clears the count to zero.
- Zeroes all 32 entries at `g_net_config_large_cache_table_8187BDB0_candidate`.

Suggested labels:

```text
800c5c70  LAB_net_config_indexed_cache_clear_loop_800c5c70
800c5c8c  LAB_net_config_indexed_cache_decrement_800c5c8c
800c5c9c  LAB_net_config_indexed_cache_zero_backing_table_800c5c9c
800c5cb8  LAB_net_config_indexed_cache_clear_return_800c5cb8
```

Plate comment:

```c
/* Clear network/config indexed cache.

   Behavior:
     - uses {@symbol g_net_config_indexed_cache_count_81470024_candidate}
       as a descending index/count
     - for each positive index:
         calls {@symbol FUN_8015d778} with
           {@symbol g_net_config_index_registry_81748E64_candidate}
         if an entry exists, calls {@symbol FUN_8015d984} to remove/delete it
     - decrements the global count each pass
     - finally clears the count to zero
     - zeroes 32 entries at:
         {@symbol g_net_config_large_cache_table_8187BDB0_candidate}
       each entry is 0x400 bytes

   Current interpretation:
     Clears an indexed network/config cache/list and its 0x8000-byte backing
     table.
*/
```

## 7.2 Append helper at `800c5bc4`

Rename:

```text
FUN_800c5bc4
```

to:

```text
fn_net_config_indexed_cache_append_800c5bc4_candidate
```

Signature:

```c
void fn_net_config_indexed_cache_append_800c5bc4_candidate(
    net_config_indexed_cache_entry_400_candidate *src_entry);
```

Behavior:

- Ignores null source pointers.
- Refuses to append if count is `>= 0x20`.
- Computes destination as:

```text
8187bdb0 + count * 0x400
```

- Copies `0x400` bytes from source entry to destination.
- Increments `g_net_config_indexed_cache_count_81470024_candidate`.
- Calls `FUN_8015d57c(&g_net_config_index_registry_81748E64_candidate, 0)`.
- If registry entry creation succeeds, stores the new count at entry `+0x0c`.

Suggested labels:

```text
800c5bd0  LAB_net_config_indexed_cache_append_null_check_800c5bd0
800c5bec  LAB_net_config_indexed_cache_copy_entry_800c5bec
800c5c10  LAB_net_config_indexed_cache_register_index_800c5c10
800c5c30  LAB_net_config_indexed_cache_append_return_800c5c30
```

Plate comment:

```c
/* Append/copy one entry into the network/config indexed cache.

   Arguments:
     src_entry = source 0x400-byte cache entry

   Behavior:
     - ignores NULL source pointers
     - refuses to append when
         {@symbol g_net_config_indexed_cache_count_81470024_candidate} >= 0x20
     - copies 0x400 bytes from src_entry into:
         {@symbol g_net_config_large_cache_table_8187BDB0_candidate}[count]
     - increments {@symbol g_net_config_indexed_cache_count_81470024_candidate}
     - allocates/registers an index entry through {@symbol FUN_8015d57c}
       using {@symbol g_net_config_index_registry_81748E64_candidate}
     - if registry entry creation succeeds, stores the new count at entry +0x0c

   Current interpretation:
     Adds one 0x400-byte network/config cache entry to the indexed backing table.
*/
```

## 7.3 Large indexed-cache datatype

Create in `/tc7200u/common/network`:

```c
typedef struct net_config_indexed_cache_entry_400_candidate {
    byte raw_00[0x400];
} net_config_indexed_cache_entry_400_candidate;
```

After the memory block is resized, apply:

```text
8187bdb0  net_config_indexed_cache_entry_400_candidate[32]  g_net_config_large_cache_table_8187BDB0_candidate
```

## 7.4 Registry and related globals

```text
81748e64  g_net_config_index_registry_81748E64_candidate
8187bda8  g_net_config_transfer_context_8187BDA8_candidate  void *
8187bdb0  g_net_config_large_cache_table_8187BDB0_candidate
```

Keep `81748e64` as a cautious object/registry candidate until `FUN_8015d778`, `FUN_8015d984`, and `FUN_8015d57c` are understood.

---

# 8. Net-config context-string helper at `800c5b38`

Rename:

```text
FUN_800c5b38
```

to:

```text
fn_net_config_build_context_string_800c5b38_candidate
```

Signature:

```c
int32_t fn_net_config_build_context_string_800c5b38_candidate(
    char **out_string);
```

Behavior:

- Clears a temporary `0x80` byte buffer at `sp+0x38`.
- Reads `g_net_config_context_ptr_81470028_candidate`.
- If that global is nonzero:
  - calls `FUN_80589a84`
  - formats/builds a string through `FUN_80e99958`
  - allocates/converts through `FUN_80f0a6f8`
  - stores the result into `*out_string`
- Returns zero in the normal path.

Caution:

```text
800c5bb4 and 800c5bbc are tiny return-2 stubs. Leave them alone until XREFs prove their role.
```

---

# 9. Network/config request handler at `800c5cd0`

Rename:

```text
FUN_800c5cd0
```

to:

```text
fn_net_config_request_handler_800c5cd0_candidate
```

Signature:

```c
int32_t fn_net_config_request_handler_800c5cd0_candidate(
    byte *message_or_state,
    undefined4 arg1,
    int arg2,
    int *arg3);
```

Keep these arguments for now because the function forwards them into `FUN_80654758`.

Behavior:

1. Calls:

```text
FUN_80654758(message_or_state, arg1, arg2, arg3)
```

2. If the call succeeds/nonzero:

```text
FUN_80653cb8(fn_net_config_indexed_cache_append_800c5bc4_candidate)
FUN_80900b34(fn_net_config_indexed_cache_append_800c5bc4_candidate)
```

3. Compares `message_or_state` to string `"Requested"` with length `0x0a`.

4. If matched:

```text
fn_net_config_indexed_cache_clear_800c5c40_candidate()
result = FUN_80654758(...)
FUN_80654b2c(result, g_net_config_transfer_context_8187BDA8_candidate)
g_net_config_requested_flag_81470020_candidate = 1
```

Suggested labels:

```text
800c5ce8  LAB_net_config_request_initial_call_failed_800c5ce8
800c5cf0  LAB_net_config_register_append_callbacks_800c5cf0
800c5d04  LAB_net_config_compare_requested_string_800c5d04
800c5d20  LAB_net_config_requested_clear_and_transfer_800c5d20
800c5d50  LAB_net_config_request_handler_return_800c5d50
```

Plate comment:

```c
/* Network/config request handler.

   Behavior:
     - calls {@symbol FUN_80654758} with the incoming message/state arguments
     - if that call succeeds/nonzero:
         registers {@symbol fn_net_config_indexed_cache_append_800c5bc4_candidate}
         through:
           {@symbol FUN_80653cb8}
           {@symbol FUN_80900b34}
     - compares the incoming message/state against "Requested"
       using length 0x0a
     - on "Requested":
         calls {@symbol fn_net_config_indexed_cache_clear_800c5c40_candidate}
         calls {@symbol FUN_80654758} again
         passes the result and
           {@symbol g_net_config_transfer_context_8187BDA8_candidate}
         to {@symbol FUN_80654b2c}
         sets {@symbol g_net_config_requested_flag_81470020_candidate} = 1

   Current interpretation:
     Handles a network/config "Requested" event and prepares the indexed
     32-entry net-config cache transfer/population path.
*/
```

---

# 10. Host-DQM/NATP caution from script errors

A prior operation attempted to create `host_dqm_object_ops_candidate` at `8173fb28`, but that address is not the Host-DQM ops table area.

Do not create Host-DQM ops at:

```text
8173fb28
```

Correct Host-DQM ops table locations remain:

```text
81826978  g_host_dqm_channel_obj_ops_81826978_candidate
81826988  g_host_downstream_dqm_command_channel_ops_81826988_candidate
81826998  g_host_downstream_dqm_queue_obj_ops_81826998_candidate
```

`8173fb24` is the NATP no-match RX manager global area, not a Host-DQM ops table.

The missing-label message for:

```text
LAB_natp_gfap_drain_message_queue_8053d5e0
```

is harmless. It means the label was not present under that exact name.

---

# 11. Current unresolved targets

Recommended next analysis targets:

```text
80654758  key API used by fn_net_config_request_handler_800c5cd0_candidate
80654b2c  transfer/context helper using g_net_config_transfer_context_8187BDA8_candidate
8015d57c  registry insertion/allocation helper
8015d778  registry lookup helper
8015d984  registry remove/delete helper
800c52fc  only known xref to DAT_8147001c
800c5d64  only known xref to DAT_81470020 read path
```

---

# 12. Change checklist for Ghidra

## 12.1 Memory map

- [ ] Resize/rename block `RAM_FPM_TOKEN_MANAGER_STATE_8187BC60` to `RAM_STAGE1_FPM_NETCFG_RUNTIME_8187BC60_candidate`.
- [ ] Set end to `81883daf`, size `0x8150`.
- [ ] Keep read/write, non-exec, non-volatile, uninitialized.
- [ ] Leave `BSS_STAGE1_FAP_BYPASS_81883E00_candidate` unchanged.

## 12.2 Functions

- [ ] `8053d514` -> `fn_natp_gfap_manager_thread_main_8053d514`.
- [ ] `8053e3f0` -> `fn_natp_gfap_l1_cache_remove_by_session_key_8053e3f0_candidate`.
- [ ] `80ea00b0` -> `fn_memmove_80ea00b0_candidate`.
- [ ] `8002a280` -> `fn_heap_free_list_block_8002a280_candidate`.
- [ ] `800bb48c` -> `fn_net_config_cache_rebuild_800bb48c_candidate`.
- [ ] `800c5c40` -> `fn_net_config_indexed_cache_clear_800c5c40_candidate`.
- [ ] `800c5bc4` -> `fn_net_config_indexed_cache_append_800c5bc4_candidate`.
- [ ] `800c5b38` -> `fn_net_config_build_context_string_800c5b38_candidate`.
- [ ] `800c5cd0` -> `fn_net_config_request_handler_800c5cd0_candidate`.

## 12.3 Globals/tables

- [ ] `81470000` -> `anchor_8147_hi16_global_region_candidate`, no datatype.
- [ ] `81470008` -> `g_net_config_cache_entry_count_81470008_candidate`, `uint32_t`.
- [ ] `81470020` -> `g_net_config_requested_flag_81470020_candidate`, `uint8_t`.
- [ ] `81470024` -> `g_net_config_indexed_cache_count_81470024_candidate`, `uint32_t`.
- [ ] `81470028` -> `g_net_config_context_ptr_81470028_candidate`, `void *` candidate.
- [ ] `81748e64` -> `g_net_config_index_registry_81748E64_candidate`.
- [ ] `8187bcb8` -> `g_net_config_cache_entries_8187BCB8_candidate`, `net_config_cache_entry_24_candidate[6]`.
- [ ] `8187bda8` -> `g_net_config_transfer_context_8187BDA8_candidate`, `void *`.
- [ ] `8187bdb0` -> `g_net_config_large_cache_table_8187BDB0_candidate`, `net_config_indexed_cache_entry_400_candidate[32]` after memory-block resize.

## 12.4 Datatypes

- [ ] `natp_gfap_runtime_entry_44_candidate`.
- [ ] `natp_gfap_u32_vector_candidate` with `begin_00/end_04/capacity_end_08`.
- [ ] `natp_gfap_l1_cache_entry_candidate`.
- [ ] `natp_gfap_l1_cache_vector_candidate`.
- [ ] `stage1_heap_block_header_candidate`.
- [ ] `stage1_heap_stats_candidate`.
- [ ] `net_config_cache_entry_24_candidate`.
- [ ] `net_config_indexed_cache_entry_400_candidate`.

---

# 13. Repository action

Requested target path:

```text
u:\home\mgta29\tc7200u-research\records\reverse\
```

Equivalent WSL path:

```text
~/tc7200u-research/records/reverse/
```

Recommended filename:

```text
2026-06-21-net-config-heap-natp-gfap-ghidra-log.md
```

Recommended commit message:

```text
reverse: document net-config heap and NATP GFAP Ghidra findings
```
