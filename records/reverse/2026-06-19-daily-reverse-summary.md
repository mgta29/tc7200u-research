# TC7200U reverse daily summary - 2026-06-19

## Scope

This is the daily detailed summary note after a full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse`

Control result for the requested path:

- no live `records\notes\reverse` tree is present in the current repository
- the live reverse-note tree remains `records\reverse`

Preserve older logs and summaries. This note is additive and freezes the June 19 reverse state in one place.

## Control result

The full reread did not add new GENET, MDIO, FPM, DQM, or Host-DQM MMIO constants.

The new reverse input for this pass is:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-19-stage1-netif-aux-context-route-output.md`

That pass adds a higher Stage1 software correlation layer above the already-carried socket-provider layer:

- socket create-flag indexes `1..8` map to static interface names `bcm0` through `bcm7`
- the static interface-name records live at `0x80f99618`
- the pointer table for those names lives at `0x8146f660`
- the runtime create-flag netif pointer table lives at `0x8146f690`
- the netif global list head lives at `0x81840370`
- `0x81802fb8` is a pointer variable to a heap netif pointer array, not an embedded netif-object array
- the aux/keyclass dispatch table lives at `0x81c0cf10`
- route-output processing is now tied to netif aux event contexts, key blobs, aux object rebinding, and callback/refcount handling

All of these are Stage1 software/runtime correlation values. They are not OpenWrt-safe hardware constants.

## New Stage1 netif, aux-context, and route-output facts worth carrying

High-value facts:

- `fn_stage1_netif_find_by_name_unit_suffix_80eac7f4_candidate` resolves `"bcm0"` as base name `"bcm"` plus unit `0`; it is not just a full literal string compare
- `fn_stage1_netif_register_insert_initialize_80eab9b0_candidate` inserts and initializes runtime netif objects
- `fn_stage1_netif_aux_lookup_by_key_and_netif_80eac374_candidate` searches aux objects by key and parent netif
- `fn_stage1_netif_aux_select_by_flags_and_key_80eb005c_candidate` selects or repairs the aux object using lookup and fallback key blobs
- `fn_stage1_netif_aux_context_acquire_by_key_80eafa94_candidate` uses `lookup_key_blob[1]` to index the keyclass ops table at `0x81c0cf10`
- `fn_stage1_netif_aux_context_release_80eafc24_candidate` decrements context refs, releases current aux, releases parent contexts, and frees key/context storage
- `fn_stage1_netif_aux_object_release_80eafd6c_candidate` decrements or frees aux objects but does not unlink them from the parent netif aux list
- `fn_stage1_route_output_aux_context_process_80eae390_candidate` validates route/key blobs, uses keyclass callbacks at `+0x1c/+0x20`, rebinds `current_aux_40_candidate`, updates route state, and writes route-output status

New software globals worth keeping for correlation:

- `0x81840370 = g_stage1_netif_list_head_81840370_candidate`
- `0x81840378 = g_stage1_netif_aux_object_array_81840378_candidate`
- `0x818403b4 = g_stage1_ip_id_counter_818403b4_candidate`
- `0x81802fb4 = g_stage1_netif_registered_count_81802fb4_candidate`
- `0x81802fb8 = g_stage1_netif_object_array_81802fb8_candidate`
- `0x81802fbc = g_stage1_netif_table_capacity_81802fbc_candidate`
- `0x81a60b70 = g_stage1_netif_list_initialized_81a60b70_candidate`
- `0x81a60b98 = g_stage1_netif_aux_context_stats_81a60b98_candidate`
- `0x81a60ba4 = g_stage1_netif_aux_active_context_count_81a60ba4_candidate`
- `0x81bfcf00 = g_stage1_route_output_global_level_81bfcf00_candidate`
- `0x81c0cf10 = g_stage1_netif_aux_keyclass_ops_table_81c0cf10_candidate`

Route-output status values now worth preserving:

- `0x16 = invalid key/blob or parse failure`
- `0x145 = unexpected route packet type`
- `0x147 = unsupported operation selector`
- `0x149 = missing keyclass ops entry`
- `0x163 = allocation or packet normalization failure`

Important cautions:

- keep `0x81840370`, `0x81802fb8`, `0x81a60b98`, `0x81a60ba4`, `0x81bfcf00`, and `0x81c0cf10` as software/runtime state, not MMIO
- do not apply an embedded `stage1_netif_object_candidate *[8]` at `0x81802fb8`; the value stored there points to the actual array
- do not treat `bcm0` through `bcm7` as Linux interface names to force into OpenWrt; they are OEM Stage1 names used to correlate the vendor control path
- keep false Ghidra functions `80eb0108`, `80eae9e8`, and `caseD_0` cleared as internal blocks, not standalone functions

## OpenWrt-facing implication

Current best staged model for the TC7200U port now extends one layer further:

- stage 13: signal-object table state, select or wait generation flow, provider or related-object callback dispatch, and timeout-to-ticks conversion
- stage 14: socket-object wrapper state, type2 setsockopt/getsockopt dispatch, and socket close/cleanup behavior
- stage 15: socket create-flag to `bcm0..bcm7` netif mapping, netif aux-object lookup, keyclass ops, route-output aux-context rebinding, and route-status writeback

Practical implication:

- if OpenWrt comparison reaches the OEM Stage1 socket-provider abstraction and still diverges, the next software correlation layer is:
  - create-flag index `1..8` to `bcm0..bcm7`
  - `0x8146f690` runtime create-flag netif pointer table
  - `0x81840370` netif list head
  - `stage1_netif_object_candidate +0x10/+0x14`
  - `stage1_netif_aux_object_candidate +0x00/+0x04/+0x08/+0x5c/+0x68/+0x70`
  - `stage1_netif_aux_event_context_candidate +0x34/+0x38/+0x40/+0x44/+0x4c`
  - `0x81c0cf10` keyclass ops table
- this layer is useful for reverse-side explanation of OEM control flow
- it still does not add new OpenWrt-safe MMIO constants

## Repository updates recorded here

Recorded modifications worth keeping:

- created this new June 19 daily summary instead of editing older daily summaries
- folded the June 19 netif/aux-context/route-output note into the maintained reverse state
- updated the OpenWrt carry note with a fifteenth-pass Stage1 netif/aux route-output software correlation layer
- updated the structure reference with the socket build/create-flag, netif, aux-object, aux-context, keyclass ops, and aux-context stats layouts
