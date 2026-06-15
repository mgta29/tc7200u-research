# TC7200U reverse daily summary - 2026-06-14

## Scope

This is the daily detailed summary note after a full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse`

Preserve older logs and summaries. This note is additive and exists to freeze the current June 14 reverse state in one place.

## Control result

The full reread did not produce contradictions against the current FPM-backed GENET/MBDMA/DQM layered model.

It did confirm and strengthen these June 14 points:

- the reverse model now extends more cleanly from DQM pending bits into the Host-DQM selector blocks and then into the generic Stage1 event-slot wake path
- the MSP comms guarded-enable path correction is now concrete:
  - the created channel object is selector `3` / MSG_PROC, not selector `1` / MSP
  - the object uses Host-DQM base `0xb8600000`
  - the object uses register block `0xb8601800`
  - the object uses `channel_index = 0x1f`, therefore enable-path bit `0x80000000`
- the guarded enable path now clearly waits for `reg20` bit31 clear, then sets bit31 in:
  - `0xb8601818`
  - `0xb8601814`
- the generic Host-DQM selector map is now clear enough to carry across selectors `0..5`, including selector base, register block, and event/status code
- the Host-DQM dispatch tables are now materially clearer:
  - table A at `0x81916fd8` carries `raise_mask`
  - table B at `0x819172d8` carries a `1`-based Stage1 event-slot id
- the Stage1 event-slot bridge and waiter wakeup chain are now structurally closed enough to carry:
  - selector pending bit
  - dispatch table lookup
  - Stage1 event-slot raise
  - waiter wakeup
  - outer wait-side clear of observed bits
- the Stage1 event-slot wait wrapper is now substantially clearer:
  - slot ids are `1`-based
  - blocking and timed/deadline wait paths are separated
  - wake-side observed bits are returned to the waiter
  - outer wait-side clear is `slot->pending_mask_00 &= ~observed_mask`
- the generic Stage1 scheduler callback, post-message, signal-pending, wake-if-waiting, and make-runnable chain is now connected enough to treat as the next software wake layer behind the event-slot path
- the late June 14 datatype correction closes the software-ownership side of that wake layer enough to carry:
  - `stage1_context_candidate +0xac` is `stage1_thread_record_candidate *thread_record_ac_candidate`, not a detached signal-select-state pointer
  - per-thread pending and blocked signal or work masks live at `stage1_thread_record_candidate +0x48` and `+0x4c`
  - the embedded context inside `stage1_thread_record_candidate` points back to its owning thread record through `+0xac`
- the later June 14 thread-exit cleanup pass closes the terminal lifecycle side of that same software layer enough to carry:
  - `stage1_thread_record_candidate +0x1c` is `exit_value_or_status_1c_candidate`
  - `stage1_thread_record_candidate +0x44` is `cleanup_handler_head_44_candidate`
  - `stage1_thread_record_candidate +0x178` is a thread-specific embedded join object
  - absolute thread-record offset `+0x180` is `embedded_join_condition_178.tsd_value_slots_base_08_candidate`
  - TSD destructors are called with the old slot value in `a0`
- the later June 14 readyq, PI, owner-list, timeout, and timeslice passes close more of the scheduler-side software correlation layer:
  - lower `readyq_bucket_20` means higher scheduler priority
  - `owner_list_head_ref_28` is a pointer to the exact external list-head slot that currently owns `readyq_node_18`
  - `base_readyq_bucket_48_candidate` is the tracked base/requested bucket during PI handling
  - `resume_status_9c = 7` now reads as the normal success/wake status in wait-object and PI wake paths
  - `stage1_context_candidate +0x68` is better carried as a structured `stage1_timeout_object_candidate`, not a raw `0x30` byte block
  - `stage1_context_candidate +0x24` is now a provisional scheduler/timeslice eligibility field
  - the scheduler globals at `0x819dcc50`, `0x819dcc58`, and `0x819dcce0` plus the static idle area at `0x819dc308`, `0x819dc310`, and `0x819dc438` are now worth carrying as correlation-only software values
- the context-struct offset correction is now important enough to carry:
  - `+0x60` is a `ushort` trace id
  - `+0x98` is `wait_state`
  - `+0x9c` is `resume_status`
- two major cautions remain valid:
  - do not hardcode the Stage1 software globals as Linux-side hardware constants
  - do not assume OpenWrt must reproduce the OEM scheduler internals rather than only the resulting externally-visible hardware state

## Source notes folded into this daily summary

Earlier frozen notes remain valid. The main June 14 closure came from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-13-host-dqm-msp-comms-guarded-enable-path-updated.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-13-stage1-event-slot-wait-chain-update.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-scheduler-post-signal-wake-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-thread-record-datatype-correction.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-thread-exit-tsd-cleanup.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-pi-owned-wait-object-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-owner-list-wakeup-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-static-idle-timeslice.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-timeout-signal-dispatch.md`

## New Host-DQM selector and dispatch facts worth carrying

High-value newly-closed Host-DQM facts:

- selector map now worth carrying:
  - selector `0` -> UTP -> event/status `0x88` -> base `0xb8000000` -> register block `0xb8001800`
  - selector `1` -> MSP -> event/status `0x7e` -> base `0xb8200000` -> register block `0xb8201800`
  - selector `2` -> FAP -> event/status `0x74` -> base `0xb8400000` -> register block `0xb8401800`
  - selector `3` -> MSG_PROC -> event/status `0x6a` -> base `0xb8600000` -> register block `0xb8601800`
  - selector `4` -> MPEG_PROC -> event/status `0x60` -> base `0xb8a00000` -> register block `0xb8a01800`
  - selector `5` -> PMC -> event/status `0x56` -> base `0xb8800000` -> register block `0xb8801800`
- the MSP comms channel object path now closes as:
  - `queue_index_a_08 = 0x1e`
  - `channel_index = 0x1f`
  - `selector = 3`
  - `register_block = 0xb8601800`
  - guarded enable waits for `0xb8601820` bit31 clear, then sets bit31 in `0xb8601818` and `0xb8601814`
- Host-DQM global tables now worth carrying:
  - `0x81916fd8`
  - `0x819172d8`
  - `0x819175d8`
- current best meanings:
  - `0x81916fd8` = dispatch table A = raise masks
  - `0x819172d8` = dispatch table B = `1`-based Stage1 event-slot ids
  - `0x819175d8` = object list
- selector dispatcher paths now worth carrying:
  - selector `3` / MSG_PROC pending dispatcher reads `0xb8601814` and `0xb8601818`
  - selector `1` / MSP pending dispatcher reads `0xb8201814` and `0xb8201820`

Important closure:

- Host-DQM pending-bit dispatch is now better treated as:
  - selector-specific register block read
  - dispatch table A/B lookup
  - Stage1 event-slot raise
  - worker wake

## New Stage1 event-slot wait and wake facts worth carrying

High-value newly-closed Stage1 facts:

- Stage1 event-slot table base:
  - `0x81909698`
- stage1 event-slot struct now worth carrying:
  - `+0x00` pending mask
  - `+0x04` waitq head
- wait/clear wrapper now worth carrying:
  - `fn_stage1_event_slot_wait_mask_clear_8002ac7c_candidate`
- immediate wait-mask test now worth carrying:
  - `fn_stage1_event_slot_test_wait_mask_80e985d4_candidate`
- blocking wait path now worth carrying:
  - `fn_stage1_event_slot_wait_mask_blocking_impl_80e98258_candidate`
- raise/wake path now worth carrying:
  - `fn_stage1_event_slot_raise_mask_wake_waiters_80e98110_candidate`

Current best behavior model:

- Host-DQM-side bridge uses a `1`-based slot id
- raising a dispatch-table mask ORs into the selected slot pending mask
- wake path stores the full observed pending snapshot for the waiter
- if the wake path does not auto-clear, the outer wait wrapper clears:
  - `slot->pending_mask_00 &= ~observed_mask`

Operationally important closure:

- the Host-DQM dispatch path is no longer just a vague callback model
- it is now a concrete `pending bit -> dispatch table -> event slot -> wait/wake` path

## New Stage1 post, signal, and runnable-transition facts worth carrying

High-value newly-closed scheduler/runtime facts:

- callback-pair global:
  - `0x819dcc38`
- unlock-callback-list head:
  - `0x819dcc4c`
- post/signal state surfaces:
  - `0x81a67cd0`
  - `0x81a67cec`
  - `0x81a67cf0`
  - `0x81803acc`
- context wake helper:
  - `fn_stage1_context_wake_if_waiting_make_runnable_80e963a0_candidate`
- make-runnable helper:
  - `fn_stage1_context_make_runnable_80e96154_candidate`

Current best behavior model:

- post-message path can set a pending signal bit
- wake helper can turn:
  - `wait_state_98 -> 0`
  - `resume_status_9c -> 4`
- make-runnable then clears runnable-block flags, detaches from owner/list state, and returns the context to readyq when blocking flags drop to zero

Important software-layout correction:

- context struct offsets now worth carrying:
  - `+0x28` waitq owner or link owner
  - `+0x30` pending callback flag
  - `+0x50` context flags
  - `+0x60` trace id as `ushort`
  - `+0x98` wait state
  - `+0x9c` resume status

Important caution:

- these Stage1 scheduler and post/signal globals are software/runtime correlation values, not Linux MMIO constants

## Late June 14 thread-record ownership and signal-mask correction facts worth carrying

High-value newly-closed datatype and ownership facts:

- current-context ownership anchor now worth carrying:
  - `0x819dcc54`
- the prior detached `signal_select_state_ac_candidate` interpretation should no longer be used for the current context carry set:
  - `stage1_context_candidate +0xac = stage1_thread_record_candidate *thread_record_ac_candidate`
- carried thread-record signal or work fields now worth carrying:
  - `+0x48` pending signal or work mask
  - `+0x4c` blocked signal mask or wait mask
- current-thread helpers now read better as:
  - current-context getter returns `g_stage1_current_context_819dcc54_candidate->thread_record_ac_candidate`
  - unmasked pending-signal computation combines global signal state `0x81a67cec` with thread-record-local pending and blocked masks
  - current-thread id or handle comes from `thread_record->thread_id_or_handle_04`
- embedded ownership relation now worth carrying:
  - `stage1_thread_record_candidate +0x50` embeds the owning `stage1_context_candidate`
  - `embedded_context_50.thread_record_ac_candidate` points back to the containing thread record

Practical reverse-side consequence:

- if the Host-DQM or event-slot path already looks OEM-like but the worker still does not continue, the next software correlation layer is not a detached signal-select object
- it is the `current_context -> thread_record -> pending or blocked signal/work-mask` ownership path

## Late June 14 thread-exit, join-wake, and TSD cleanup facts worth carrying

High-value newly-closed lifecycle and teardown facts:

- terminal current-thread exit path now worth carrying:
  - `fn_stage1_current_thread_exit_cleanup_wake_joiners_80ef3860_candidate`
- current best high-level behavior:
  - drains cleanup-handler list
  - runs TSD or TLS destructors for populated per-thread slots
  - stores thread exit value or status
  - wakes join waiters
  - marks the current context dead
  - enters a final no-return safety spin
- thread-record lifecycle fields now worth carrying:
  - `+0x1c = exit_value_or_status_1c_candidate`
  - `+0x44 = cleanup_handler_head_44_candidate`
  - `+0x178 = embedded_join_condition_178`
  - absolute `+0x180 = embedded_join_condition_178.tsd_value_slots_base_08_candidate`
- thread-specific embedded join datatype now matters:
  - the embedded join object inside the thread record is not just the generic `stage1_condition_object_candidate`
  - its `+0x08` field is used as the per-thread TSD or TLS slot-base pointer
- TSD globals now worth keeping only as reverse-side correlation values when diagnosing worker teardown:
  - `0x81a64f18`
  - `0x81a64f28`

## Late June 14 readyq, owner-list, PI, timeout, and timeslice facts worth carrying

High-value newly-closed scheduler and wait-side facts:

- readyq and owner-list priority model now worth carrying:
  - lower `readyq_bucket_20` means higher Stage1 scheduler priority
  - `owner_list_head_ref_28` is not an owner object; it is a pointer to the exact external list-head slot that currently owns `context->readyq_node_18`
  - `resume_status_9c = 7` now reads as the normal success/wake path in wait-object and PI wake flows
- PI/owned-wait-object carry facts now worth keeping:
  - `base_readyq_bucket_48_candidate` replaces the older saved-only interpretation at `+0x48`
  - `owned_pi_object_list_head_3c_candidate` and `next_owned_pi_object_0c_candidate` are now part of a mostly-closed owned-PI-object chain
- static idle and timeslice scheduler globals now worth carrying as software correlation values:
  - `0x819dcc50`
  - `0x819dcc58`
  - `0x819dcc5c`
  - `0x819dcce0`
  - `0x819dc308`
  - `0x819dc310`
  - `0x819dc438`
- current best meanings:
  - `0x819dcc50 = g_stage1_scheduler_timeslice_or_budget_reload_819dcc50`
  - `0x819dcc58 = g_stage1_scheduler_dispatch_needed_flag_819dcc58`
  - `0x819dcc5c = g_stage1_scheduler_readyq_table_819dcc5c`
  - `0x819dcce0 = g_stage1_context_switch_counter_819dcce0`
  - `0x819dc310` is the static idle/bootstrap context record
  - `0x819dc438` is the static idle stack/work area base for slot 0
- context-structure refinements now worth carrying:
  - `+0x24 = scheduler_timeslice_flag_24_candidate` (still provisional)
  - `+0x68 = timeout_object_68_candidate`, a structured `0x30`-byte timeout/list object
- timeout and signal object model now worth carrying:
  - the global signal/post-state cluster is better treated as objects rooted at `0x81a67cd0`, `0x81a67ce4`, `0x81a67cec`, and `0x81a67cf0`
  - the timeout helper chain is now structurally decoded enough to carry timeout object init, cancel/unlink, re-arm, and due-fire behavior

## OpenWrt development consequences

The current staged control model is now:

- stage 1: FPM allocator and backing-base values under `0x12200000`
- stage 2: GENET or MBDMA endpoint and control values under `0x12c00000`
- stage 3: DQM or CP2 queue-control and mirror programming under the `0x16045a00..0x16082000` set
- stage 4: DQM mailbox, queue-profile, slot-commit, and CP2 or FPM service plumbing under the `0x160018xx`, `0x16001dxx`, and `0x160400xx` sets
- stage 5: DQM event `0x01800008`, selector dispatch, request-block programming, and size-selected FPM request/return behavior
- stage 6: selector lookup/context initialization, queue/profile preload state, and selector-derived `b604` command-table setup
- stage 7: request-engine submit/finalize flow, selector-gate publish rules, and mode-specific sideband output lanes
- stage 8: alternate `0x80c8` runtime-family registration/activation differences, selector-output gates, and page-translate or output-lane alias windows
- stage 9: runtime-family selection and request-model mismatches
- stage 10 if traffic still stalls: Host-DQM selector register blocks, dispatch tables, and Stage1 event-slot bridge behavior
- stage 11 if traffic still stalls: the Stage1 scheduler callback, post-message, signal-pending, wake-if-waiting, make-runnable, thread-record-owned signal/work-mask chain, and worker exit/join lifecycle are the next software correlation layer
- stage 12 if traffic still stalls: readyq ownership, PI requeue/restore behavior, timeout object state, same-bucket timeslice rotation, and static idle context setup become the next software correlation layer

Practical implication:

- if OpenWrt reproduces the earlier MMIO control surfaces but packet movement still fails, compare whether any OEM-equivalent runtime coordination exists for:
  - selector `3` / MSG_PROC register block `0xb8601814/1818/1820`
  - selector `1` / MSP register block `0xb8201814/1818/1820`
  - dispatch-table mapping through `0x81916fd8` and `0x819172d8`
  - Stage1 event-slot wake behavior rooted at `0x81909698`
- if the Host-DQM and Stage1 event-slot surfaces already match OEM behavior but workers still stall, compare the `current_context -> thread_record` ownership path and per-thread pending or blocked masks using `0x819dcc54` and `0x81a67cec` only as reverse-side correlation globals
- if workers appear to terminate, fail to rejoin, or never complete teardown after wakeup, also compare thread-record lifecycle fields `+0x1c`, `+0x44`, `+0x178`, absolute `+0x180`, and the TSD correlation globals `0x81a64f18` and `0x81a64f28`
- if wakeups appear to happen but runnable ordering, requeue behavior, or timeout-driven follow-through still diverge, compare `0x819dcc50`, `0x819dcc58`, `0x819dcc5c`, `0x819dcce0`, `0x819dc310`, `0x819dc438`, `context +0x24`, and `context +0x68` only as reverse-side scheduler correlation values
- keep the Stage1 scheduler, context, thread-record, and post/signal globals as reverse-side correlation aids only
- do not convert those software addresses into direct Linux hardware constants

## Repository updates recorded in this pass

Recorded modifications worth keeping:

- added the new June 14 daily summary `2026-06-14-daily-reverse-summary.md`
- refreshed the maintained OpenWrt-facing note `important-openwrt-tc7200u-enet-usable-values.md` with the June 13 and June 14 Host-DQM selector, Stage1 event-slot, scheduler wake-chain, thread-record ownership, worker-exit/join-lifecycle, PI/owner-list, timeout, and timeslice correlation findings
- refreshed `important-reverse-structure-reference.md` to keep the carried thread-record, readyq/owner-list, timeout, and embedded join/TSD structure corrections aligned with the extracted structure set and local header cross-checks

## Preservation

This note is additive. No old logs or notes were deleted. No git action is part of this command.
