# TC7200U reverse daily summary - 2026-06-12

## Scope

This is the daily detailed summary note after a full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse`

Preserve older logs and summaries. This note is additive and exists to freeze the current June 12 reverse state in one place.

## Control result

The full reread did not produce contradictions against the current FPM-backed GENET/MBDMA/DQM layered model.

It did confirm and strengthen these June 12 points:

- the selector record-field normalization helper is now mechanically proven:
  - record field `0x0d..0x1c -> lookup index 0..15`
  - out-of-range values return `0xff`
- the queue/profile `0x1c` and `0x1d` preload helpers are now mechanically proven rather than only inferred
- the selector lookup/context table at `0x8000714c`, stride `0x18`, is now clear enough to carry as a working runtime model
- `0x16040010` is confirmed as a simple packed three-enable-bit write, not a wider opaque setup helper
- the DQM/CP2 `b604` setup chain is now clearer at the global level:
  - `0x1604007c = 0x11001cef`
  - `0x16040080 = 1`
  - `0x16040084 = 0x12200200`
- the repeated command word `0x04208000` and address mask `0x1fffffff` are now strong cross-path constants in the selector/CP2 path
- the primary event1800008 helper chain is now locally cleaned enough to treat as a stable working model
- the direct request engine block at `0x16001300..0x1600133c` is now substantially clearer across direct, shared-finalize, and selector-finalize paths
- the mode1/mode2 output lanes and gate rules are now clearer, including the signed-positive halfword gate rule and the post-publish `0xffff` writeback pattern
- the alternate `0x80c8` event1800008 runtime family is now structurally mapped and matches the earlier `0x80c7` family at the dispatcher level
- the registered alternate handler address is now corrected to `0x80c8a118`, not `0x80c9a118`
- the alternate runtime arm/final-activation path now clearly includes:
  - `0x16001640 = 0x8000003f`
  - `0x1600163c = 0x14`
  - `0x16001818 = 0x40383c08`
  - `0x16001014 = 0x000c0000`
- selector output gates and output-port bases are now explicit compare points in the alternate family
- two major cautions remain valid:
  - do not over-interpret the full table body at `0x16040400..0x160406c4`
  - do not force a final hardware identity for `0x12200224`
  - do not force a final identity for `0x80008014 + selector * 4`
  - do not rewrite the suspicious decompiler condition `(0x80008160 & 0x10) != 1` without assembly proof

## Source notes folded into this daily summary

Earlier frozen notes remain valid. The main June 12 closure came from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-12-dqm-cp2-fpm-selector-cleanup-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-12-dqm-event1800008-cleanup-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-12-dqm-event1800008-80c8-family-cleanup-log.md`

## New selector lookup and preload facts worth carrying

High-value newly-closed software/runtime facts:

- final helper names now safe to carry:
  - `fn_dqm_record_field_to_lookup_index_80c7d5f4`
  - `fn_dqm_queue1c_preload_8_entries_80c7c008`
  - `fn_dqm_b6040010_set_three_enable_bits_80c7c068`
  - `fn_dqm_queue1d_preload_50_entries_80c7bf70`
- selector record-field normalization rule:
  - input is unsigned 16-bit
  - valid input `0x0d..0x1c` maps to `0..15`
  - invalid input returns `0xff`
- queue/profile preload behavior:
  - queue/profile `0x1c` preloads `8` entries through `0x16001dc0`
  - queue/profile `0x1d` preloads `0x50` backing addresses through `0x16001dd0`
  - queue/profile `0x1d` entry values are:
    - `0x16010000 + entry_index * 0x140`
- selector lookup/context table model:
  - base `0x8000714c`
  - stride `0x18`
  - `+0x04` mapped context A pointer
  - `+0x08` mapped context B pointer
  - `+0x0c` per-entry counter
  - `+0x10` context A backing address
  - `+0x14` context B backing address
- selector runtime state:
  - `0x80007124` selector context allocation cursor
  - `0x80007128` selector lookup enable gate
  - counters `0x8000712c..0x80007148` now have consistent selector/FPM-attempt, fallback, wait, and busy-return interpretations

Important behavioral closure:

- the DQM runtime setup path is now readable as:
  - queue/profile preload
  - selector lookup/context table build
  - `b604` CP2/DQM table setup
  - `0x16040010` enable-bit write
  - event handler registration
  - event mask `0x01800008` enable

## New CP2 and b604 table facts worth carrying

Highest-value newly-closed physical/global facts:

- `0x16040010` packs three enable bits:
  - bit2 from arg2
  - bit1 from arg1
  - bit0 from arg0
- `0x1604007c = 0x11001cef`
- `0x16040080 = 1`
- `0x16040084 = 0x12200200`
- selector-derived `b604` entries now clearly include:
  - `0x16040564 = ((selector_a & 0x1f) << 8) | 0x50002000`
  - `0x160405c0 = genet_target_a & 0x1fffffff`
  - `0x16040640 = 0x04208000`
  - `0x16040568 = ((selector_b & 0x1f) << 8) | 0x50002001`
  - `0x160405c4 = genet_target_b & 0x1fffffff`
  - `0x16040644 = 0x04208000`

Current best meanings:

- `0x04208000` is a stable CP2-side command word in both:
  - direct `f801` push path
  - selector-derived `b604` table entries
- `0x1fffffff` is the stable low29 bus-visible address conversion used across the selector/CP2 path
- `0x16040084` remains the shared FPM pool0 endpoint carried into the DQM/CP2 global setup

Important caution:

- the table body `0x16040400..0x160406c4` is clearly real and important
- but exact row and column semantics are still not proven enough to mass-label or hardcode as final meanings

## New event1800008 finalize and lane-routing facts worth carrying

High-value newly-closed event-chain facts:

- event path status estimate is now roughly:
  - event `0x01800008` path `~94-96%`
  - DQM/CP2/FPM subsystem `~78-80%`
  - OpenWrt-useful hardware map `~60%`
- direct request engine block is now clearer:
  - `0x16001300`
  - `0x16001304`
  - `0x16001308`
  - `0x1600130c`
  - `0x1600131c`
- selector request block and result path are now clearer:
  - `0x16001320`
  - `0x16001324`
  - `0x16001328`
  - `0x1600132c`
  - `0x16001330`
  - `0x16001334`
  - `0x1600133c`
- shared request metadata is now clearer:
  - `0x16001da0`
  - `0x16001da4`
  - `0x16001da8`
  - `0x16001dac`
- direct request submit words are now clearer:
  - `0x16001c30`
  - `0x16001c34`

Dispatcher and finalize closure:

- pending bit routes are now stable enough to carry:
  - `0x00080000 -> selector-record dispatcher`
  - `0x00100000 -> record route helper`
  - `0x00200000 -> mode2 record route helper`
  - `0x00000008 -> direct request submit helper`
- finalize waits are now stable enough to carry:
  - service-state bit2 path through `fn_dqm_finalize_request_result_publish_or_return_80c7d99c_candidate`
  - service-state bit6 path through `fn_dqm_finalize_selector_request_result_or_return_80c7da84_candidate`
- selector pending bits are now stable enough to carry:
  - `0x00000400 -> selector 0x0a`
  - `0x00000800 -> selector 0x0b`
  - `0x00001000 -> selector 0x0c`
  - `0x00002000 -> selector 0x0d`

### New output-lane and gate facts

Newly-closed route and publish surfaces:

- default event100000 output words:
  - `0x16001d60`
  - `0x16001d64`
  - `0x16001d70`
  - `0x16001d74`
- mode1 lane gates and outputs:
  - gates:
    - `0x16001902`
    - `0x16001906`
  - outputs:
    - `0x13401ca0`
    - `0x13401ca4`
    - `0x13401cd0`
    - `0x13401cd4`
- mode2 lane gates and outputs:
  - gates:
    - `0x1600190a`
    - `0x1600190e`
  - outputs:
    - `0x14201c00`
    - `0x14201c04`
    - `0x14201c10`
    - `0x14201c14`
- selector16/17 special gates and outputs:
  - gates:
    - `0x16001912`
    - `0x16001916`
  - outputs:
    - `0x14201c80`
    - `0x14201c90`

Gate rule now worth carrying:

- `0x0001..0x7fff = pass`
- `0x0000 = fail`
- `0x8000..0xffff = fail`
- several helpers then write `0xffff` after publish, likely as a consumed/busy/closed marker

### Current remaining cautions

These now matter more than ordinary name cleanup:

- `0x80008014 + selector * 4` should still be described only as a selector gate expression or value, not as a proven enable/context table
- `0x12200224` remains endpoint-like but not fully identified
- the dispatcher condition `(0x80008160 & 0x10) != 1` remains suspicious and still needs assembly verification
- forced gate mode still needs assembly proof around the decompiler-emitted per-index update when lookup index may remain `0xff`

## New alternate 0x80c8 family facts worth carrying

High-value newly-closed alternate-family facts:

- the alternate runtime init path remains:
  - `fn_dqm_alt_runtime_init_register_event1800008_genet500_510_80c89cb4_candidate`
- the registered handler address is now corrected:
  - correct: `0x80c8a118`
  - rejected: `0x80c9a118`
- the alternate service wrapper remains the same structural pattern:
  - mask event
  - run dispatcher
  - queue/global rearm or ack writes
  - re-enable event

Alternate-family activation writes now worth carrying:

- lane-gate initialization:
  - `0x16001902 = 0x40`
  - `0x16001906 = 0x40`
  - `0x1600190a = 0x40`
  - `0x1600190e = 0x40`
- request/status clear:
  - `0x16001028 = 0xffffffff`
- queue-control pair:
  - `0x16001640 = 0x8000003f`
  - `0x1600163c = 0x14`
- queue pending/IRQ mask arm:
  - `0x16001818 = 0x40383c08`
  - `0x16001810 |= 0x40383c08`
- global DQM IRQ arm:
  - `0x16001014 = 0x000c0000`
  - `0x16001010 |= 0x000c0000`

Important alternate-family closure:

- the `0x80c8` family services the same major pending bits as the `0x80c7` family:
  - `0x00000008`
  - `0x00080000`
  - `0x00100000`
  - `0x00200000`
  - `0x40000000`
- selector A priority is now explicit:
  - pending `0x800 -> selector 0x0b`
  - pending `0x400 -> selector 0x0a`
  - if both pending, `0x0b` wins
- selector B priority is now explicit:
  - pending `0x2000 -> selector 0x0d`
  - pending `0x1000 -> selector 0x0c`
  - if both pending, `0x0d` wins

### New selector output and page-translate surfaces

Newly-closed alternate-family compare surfaces:

- selector output gate table:
  - `0x80008014 + selector * 4`
- selector output base words:
  - `0x16001c00 + selector * 0x10`
  - `0x16001c04 + selector * 0x10`
- selector-specific output addresses now explicit:
  - `0x16001ca0`
  - `0x16001cb0`
  - `0x16001cc0`
  - `0x16001cd0`
  - `0x16001d80`
  - `0x16001d90`
- page-translation pair:
  - `0x16001408`
  - `0x1600140c`

Current best meanings:

- `0x80008014 + selector * 4` is still a cautious selector output gate expression, not a final table identity
- `0x16001c00 + selector * 0x10` and `0x16001c04 + selector * 0x10` are now clearer as selector output word0/word1 bases in publish paths
- `0x16001408` and `0x1600140c` form the page-translate input/result pair used by direct request and selector10/11 request paths

### MMIO alias note worth carrying

The alternate-family cleanup strengthens these alias windows as active MMIO targets rather than random constants:

- `0x1340xxxx`
- `0x1420xxxx`

Practical reverse-side note:

- do not create code/functions in those regions
- treat them as candidate output-lane MMIO windows until hardware mapping is proven

## OpenWrt development consequences

The current staged control model is now:

- stage 1: FPM allocator and backing-base values under `0x12200000`
- stage 2: GENET or MBDMA endpoint and control values under `0x12c00000`
- stage 3: DQM or CP2 queue-control and mirror programming under the `0x16045a00..0x16082000` set
- stage 4: DQM mailbox, queue-profile, slot-commit, and CP2 or FPM service plumbing under the `0x160018xx`, `0x16001dxx`, and `0x160400xx` sets
- stage 5: DQM event `0x01800008`, selector dispatch, request-block programming, and size-selected FPM request/return behavior
- stage 6 if traffic still stalls: selector lookup/context initialization, queue/profile preload state, and selector-derived `b604` command-table setup
- stage 7 if traffic still stalls: request-engine submit/finalize flow, selector-gate publish rules, and mode-specific sideband output lanes
- stage 8 if traffic still stalls: alternate `0x80c8` runtime-family registration/activation differences, selector-output gates, and page-translate/output-lane alias windows

Practical implication:

- if OpenWrt reproduces the earlier control surfaces but packet movement still fails, compare whether anything OEM-equivalent exists for:
  - queue/profile preload to `0x16001dc0` and `0x16001dd0`
  - selector lookup/context table setup around `0x80007124`, `0x80007128`, and `0x8000714c + index * 0x18`
  - `0x16040010` three-bit enable programming
  - selector-derived `b604` globals at `0x1604007c`, `0x16040080`, and `0x16040084`
  - repeated use of command word `0x04208000`
  - repeated low29 address conversion with `& 0x1fffffff`
  - request-engine words around `0x16001300..0x1600133c`
  - selector gate-dependent publish behavior around `0x16001c00`, `0x16001d60/64/70/74`, `0x13401ca0/a4/cd0/cd4`, and `0x14201c00/04/10/14/80/90`
  - alternate-family activation writes around `0x1600163c`, `0x16001640`, `0x16001810/18`, and `0x16001010/14`
  - selector output gates around `0x80008014 + selector * 4`
  - page translation via `0x16001408/0x1600140c`

## Repository updates recorded in this pass

Recorded modifications worth keeping:

- updated the existing June 12 daily summary `2026-06-12-daily-reverse-summary.md` with the event1800008 cleanup closure
- refreshed the maintained OpenWrt-facing note `openwrt-tc7200u-enet-usable-values.md` with the June 12 selector lookup, preload, and `b604` setup findings
- refreshed the same OpenWrt-facing note with the June 12 event1800008 finalize/publish/lane-routing findings
- refreshed both with the June 12 alternate `0x80c8` family registration/activation and selector-output findings

## Preservation

This note is additive. No old logs or notes were deleted. No git action is part of this command.
