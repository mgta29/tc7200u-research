# TC7200U reverse daily summary - 2026-06-14

## Scope

This is the daily detailed summary note after a full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse`

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
- the context-struct offset correction is now important enough to carry:
  - `+0x60` is a `ushort` trace id
  - `+0x98` is `wait_state`
  - `+0x9c` is `resume_status`
- two major cautions remain valid:
  - do not hardcode the Stage1 software globals as Linux-side hardware constants
  - do not assume OpenWrt must reproduce the OEM scheduler internals rather than only the resulting externally-visible hardware state

## Source notes folded into this daily summary

Earlier frozen notes remain valid. The main June 14 closure came from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-13-host-dqm-msp-comms-guarded-enable-path-updated.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-13-stage1-event-slot-wait-chain-update.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-14-stage1-scheduler-post-signal-wake-chain.md`

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
- stage 11 if traffic still stalls: the Stage1 scheduler callback, post-message, signal-pending, wake-if-waiting, and make-runnable chain as software correlation

Practical implication:

- if OpenWrt reproduces the earlier MMIO control surfaces but packet movement still fails, compare whether any OEM-equivalent runtime coordination exists for:
  - selector `3` / MSG_PROC register block `0xb8601814/1818/1820`
  - selector `1` / MSP register block `0xb8201814/1818/1820`
  - dispatch-table mapping through `0x81916fd8` and `0x819172d8`
  - Stage1 event-slot wake behavior rooted at `0x81909698`
- keep the Stage1 scheduler, context, and post/signal globals as reverse-side correlation aids only
- do not convert those software addresses into direct Linux hardware constants

## Repository updates recorded in this pass

Recorded modifications worth keeping:

- added the new June 14 daily summary `2026-06-14-daily-reverse-summary.md`
- refreshed the maintained OpenWrt-facing note `openwrt-tc7200u-enet-usable-values.md` with the June 13 and June 14 Host-DQM selector, Stage1 event-slot, and scheduler wake-chain findings

## Preservation

This note is additive. No old logs or notes were deleted. No git action is part of this command.
