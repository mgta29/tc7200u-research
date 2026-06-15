# TC7200U reverse daily summary - 2026-06-16

## Scope

This is the daily detailed summary note after a full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse`

Control correction carried forward from today:

- the live reverse-note tree is `records\reverse`
- older `records\notes\reverse` wording should be treated as legacy wording only

Preserve older logs and summaries. This note is additive and exists to freeze the current June 16 reverse state in one place.

## Control result

The full reread did not produce contradictions against the current layered OEM model.

It did close the next Stage1 software layer above the already-carried readyq, event-slot, and thread-record work:

- June 15 materially closed the Stage1 signal-object table model:
  - table entry `0` means free
  - table entry `1` means reserved sentinel
  - table entry `>= 2` is a live `stage1_signal_object_candidate *`
  - object lifetime is managed through `refcount_04` and `ops_or_class_0c->final_release_18`
- the signal-object family is now coherent enough to carry:
  - `stage1_signal_object_candidate`
  - `stage1_signal_ops_or_class_candidate`
  - `stage1_related_object_pool_a_entry_candidate`
  - `stage1_related_object_pool_b_entry_candidate`
  - `stage1_signal_object_provider_entry_candidate`
  - `stage1_signal_object_type2_ops_candidate`
  - the two stack-built type2 request records at `+0x20` and `+0x24`
- the June 15 type2 dispatcher pass closed a second important interpretation:
  - `stage1_signal_object_candidate +0x06 == 2` gates the type2 callback family
  - `stage1_signal_object_candidate +0x18` is a type2 ops table in that path
  - `stage1_signal_object_candidate +0x1c` must stay broad as `provider_or_related_entry_1c_candidate`
- the select or wait layer above those objects is now clearer:
  - `stage1_signal_ops_or_class_candidate +0x10` is a readiness-test callback
  - the main helper at `80ef6ccc` is a three-class bitset select or wait engine
  - the thin public wrapper at `80ef71c8` clears `t1` and calls that helper
- timeout conversion is now much cleaner:
  - `stage1_timeval32_candidate` is the public timeout argument shape
  - `0x81a6ba70` and `0x81a6ba90` are the timeout scale tables
  - those tables must not be confused with the path-normalization area around `0x81a7b908`
- the select or wait synchronization area is now worth carrying as software correlation only:
  - `0x81a6ba50` is the global select-wait mutex
  - `0x81a6ba68` is the adjacent condition-object candidate area
  - `0x81803adc` is the select-wait generation counter
- the new June 15 layer remains software/runtime state, not Linux-visible MMIO:
  - it explains how OEM wait, signal, dispatch, and timeout flow continue after the Host-DQM and event-slot bridge
  - it does not yet produce new OpenWrt-safe hardware constants

## Source notes folded into this daily summary

The main June 16 closure came from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-pi-owned-wait-object-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-owner-list-wakeup-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-static-idle-timeslice.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-timeout-signal-dispatch.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-signal-object-path-dispatch-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-signal-object-type2-dispatcher-path.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-timeout-select-wait-reverse-log.md`

## New Stage1 signal-object and select-wait facts worth carrying

High-value new June 15 facts:

- signal-object globals now worth carrying:
  - `0x81a68120 = g_stage1_signal_object_table_lock_81a68120`
  - `0x81a6b508 = g_stage1_signal_object_table_81a6b508`
  - `0x81a78138 = g_stage1_signal_object_per_slot_wait_objects_81a78138_candidate`
  - `0x81a79528 = g_stage1_signal_object_pool_81a79528`
- related-object and path-context globals now worth carrying:
  - `0x8184fa18 = g_stage1_related_object_pool_a_8184fa18_candidate`
  - `0x8184fa58 = g_stage1_related_object_pool_b_8184fa58_candidate`
  - `0x81802a7c = g_stage1_default_related_object_or_path_context_81802a7c_candidate`
  - `0x81802a80 = g_stage1_default_resolved_context_81802a80_candidate`
  - `0x81a7b908 = g_stage1_path_normalize_buffer_81a7b908_candidate`
  - `0x81803ad8 = g_stage1_path_normalize_buffer_used_len_81803ad8_candidate`
- timeout and select-wait globals now worth carrying:
  - `0x81803ae0 = g_stage1_timeout_scale_tables_initialized_81803ae0`
  - `0x81802ab4 = g_stage1_timeout_tick_scale_base_81802ab4_candidate`
  - `0x81a6ba50 = g_stage1_select_wait_global_mutex_81a6ba50_candidate`
  - `0x81a6ba68 = g_stage1_select_wait_global_condition_81a6ba68_candidate`
  - `0x81803adc = g_stage1_select_wait_generation_81803adc_candidate`
  - `0x813a7f80 = g_stage1_signal_wait_class_modes_813a7f80_candidate`
- provider and registry surface now worth carrying:
  - `0x8183fbf8 = g_stage1_signal_object_provider_table_8183fbf8_candidate`
  - `0x8183fc18 = g_stage1_signal_object_provider_table_end_8183fc18_candidate`

Current best behavior model:

- Stage1 has a descriptor-like signal-object table with explicit free, reserved, and live-pointer states
- object creation can come from a provider table or from a related-object callback path
- type2 signal objects have a second callback table at `signal_object +0x18`
- the select or wait helper walks three class bitsets, refs signal objects, tests readiness through the ops table, then either returns ready bits or waits
- relative timeout arguments are converted into scheduler ticks through the corrected scale-table globals at `0x81a6ba70` and `0x81a6ba90`

Important cautions:

- do not create false overlap between `0x81a6ba68` and the timeout tables starting at `0x81a6ba70`
- do not treat the June 15 globals as ENET, MDIO, GENET, or Host-DQM hardware constants
- do not force normal C signatures where the current reverse evidence still depends on nonstandard register inputs through `t0` or `t1`

## OpenWrt-facing implication

Current best staged model for the TC7200U port now extends one layer further:

- stage 10: Host-DQM selector register blocks, dispatch-table mapping, and Stage1 event-slot wake behavior
- stage 11: current-context ownership, thread-record linkage, per-thread pending or blocked signal or work masks, and worker exit or join lifecycle
- stage 12: readyq ownership, PI restore or requeue behavior, timeout object state, same-bucket timeslice rotation, and static idle context setup
- stage 13: signal-object table state, select or wait generation flow, provider or related-object callback dispatch, and timeout-to-ticks conversion

Practical implication:

- if OpenWrt reproduces the earlier MMIO, DQM, Host-DQM, event-slot, and thread or readyq surfaces but an OEM worker still waits forever, misses a wake, or diverges after a signal-style handoff, the next comparison layer is no longer hardware
- the next comparison layer is the Stage1 signal-object and select-wait runtime rooted at:
  - `0x81a6b508`
  - `0x81a79528`
  - `0x81a6ba50`
  - `0x81803adc`
  - `0x81a6ba70`
  - `0x81a6ba90`

## Repository updates recorded here

Recorded modifications worth keeping:

- created this new June 16 daily summary instead of overwriting the June 14 summary
- carried forward the control correction that the live reverse-note tree is `records\reverse`
- folded the June 15 signal-object, type2-dispatch, and timeout-select-wait notes into the maintained reverse state
- matched the maintained carry notes against the current live `records\reverse\structures.h` export before promoting new structures
