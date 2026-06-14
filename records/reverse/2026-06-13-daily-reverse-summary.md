# TC7200U reverse daily summary - 2026-06-13

## Scope

This is the daily detailed summary note after a full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse`

Preserve older logs and summaries. This note is additive and exists to freeze the current June 13 reverse state in one place.

## Control result

The full reread did not produce contradictions against the current FPM-backed GENET/MBDMA/DQM layered model carried through the June 12 summaries and the maintained OpenWrt-facing extraction note.

The current June 13 reverse-note tree does not add new MMIO, queue-control, selector, FPM, or GENET hardware facts beyond the already-carried June 12 and maintained ninth-pass state.

It did confirm and strengthen these June 13 points:

- the current new June 13 note is a Ghidra cleanup and repair plan, not a new hardware-value log
- the cleanup plan is worth carrying because it constrains how future reverse findings should be repaired, renamed, and preserved
- the plan explicitly preserves older logs, older Ghidra projects, and prior evidence rather than replacing them
- the plan keeps the current reverse-side discipline:
  - no fake functions
  - no dummy placeholders
  - no silent renames
  - `_candidate` suffix preserved for candidate names
- the plan freezes two high-value project-control facts:
  - language must remain `MIPS:BE:32:default`
  - stage1 base remains `0x80004000` unless proven otherwise
- RAM and MMIO blocks should only be added when confirmed xrefs require them
- wrong labels, wrong datatypes, wrong fake functions, and overlapping symbol names should be repaired carefully on a duplicate or clean re-import rather than by destructively rewriting the old evidence set
- control of the maintained OpenWrt note found one repository-consistency issue:
  - the ninth-pass runtime-selector section cited a June 13 source log path that is not currently present in this directory
  - this pass corrected that citation state by turning it into an explicit carry-forward control note instead of a false current-tree source reference

## Source notes folded into this daily summary

Earlier frozen notes remain valid. The current June 13 closure comes from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-13-ghidra-cleanup-repair-plan.md`

## New Ghidra cleanup and repair facts worth carrying

High-value newly-closed reverse-workspace control facts:

- preserve old logs and prior Ghidra state
- work on a duplicate or clean re-import
- verify language:
  - `MIPS:BE:32:default`
- verify base address:
  - `0x80004000`
- keep the imported firmware block initialized
- add RAM or MMIO blocks only when needed by confirmed xrefs
- remove wrong labels, types, and fake functions carefully
- reapply only confirmed labels and comments
- keep saving progress as dated notes

Practical reverse-side consequence:

- the next reverse passes should aim for a cleaner, auditable Ghidra workspace without losing the older damaged or messy project state that still serves as evidence

## OpenWrt development consequences

Current best staged model for the TC7200U port does not materially change from the earlier carried state:

- stage 1: FPM allocator and backing-base values under `0x12200000`
- stage 2: GENET or MBDMA endpoint and control values under `0x12c00000`
- stage 3: DQM or CP2 queue-control and mirror programming under the `0x16045a00..0x16082000` set
- stage 4: DQM mailbox, queue-profile, slot-commit, and CP2 or FPM service plumbing under the `0x160018xx`, `0x16001dxx`, and `0x160400xx` sets
- stage 5: DQM event `0x01800008`, selector dispatch, request-block programming, and size-selected FPM request/return behavior
- stage 6: selector lookup/context initialization, queue/profile preload state, and selector-derived `b604` command-table setup
- stage 7: request-engine submit/finalize flow, selector-gate publish rules, and mode-specific sideband output lanes
- stage 8: alternate `0x80c8` runtime-family registration/activation differences, selector-output gates, and page-translate or output-lane alias windows
- stage 9 if traffic still stalls: runtime-family selection and request-model mismatches remain worth carrying as maintained reverse-side development guidance, but current-tree June 13 evidence does not add new hardware values on top of that set

Practical implication:

- the June 13 cleanup-plan note changes reverse-workflow discipline, not the OpenWrt MMIO compare set
- the maintained OpenWrt note should therefore be controlled for source consistency and caution wording, not expanded with fake new register facts

## Repository updates recorded in this pass

Recorded modifications worth keeping:

- added the new June 13 daily summary `2026-06-13-daily-reverse-summary.md`
- refreshed the maintained OpenWrt-facing note `openwrt-tc7200u-enet-usable-values.md` to replace a false current-tree source citation with an explicit carry-forward control note

## Preservation

This note is additive. No old logs or notes were deleted. No git action is part of this command.
