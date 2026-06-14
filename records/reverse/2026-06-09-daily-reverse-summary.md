# TC7200U reverse daily summary - 2026-06-09

## Scope

This is the daily detailed summary note after a full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse`

Preserve older logs and summaries. This note is additive and exists to freeze the current June 9 reverse state in one place.

## Control result

The full reread did not produce contradictions against the current FPM-backed GENET/MBDMA model.

It did confirm and strengthen these June 9 points:

- `0x12c00070` must no longer be treated as an unconditional `0x00003000` write
- `0x12c0004c/50/54/58/08` are best treated as FPM hardware alloc/free endpoints, not descriptor ring bases
- `0x12c00040` is worth carrying as a candidate status/ack/mask write with `status | 0xdea9`
- packet allocator storage around `0x8187bc60/68/70` is fixed/static-looking and not ordinary heap-header space
- token low bits `bits11:0` carry requested allocation-size low bits on the allocation path

## Source notes folded into this daily summary

Earlier frozen notes remain valid. The main June 9 closure came from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-08-215910-fpm-packet-allocator-heap-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-08-233251-enet-mii-static-log-stream-followup.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-09-024849-fpm-dma-packet-token-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-09-030109-fpm-token-alloc-free-path.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-09-030657-gmac-mbdma-fpm-endpoint-reinterpretation.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-09-ghidra-fpm-mbdma-packet-allocator-control-log.md`

## Frozen current model

### GENET / MBDMA

- main GENET window: `0x12c00000`
- MDIO windows:
  - `0x12c00600`
  - `0x12c02600`
- MBDMA global init function: `fn_enet_gmac_mbdma_global_init @ 0x803a8790`
- `0x12c00010 = aligned_fpm_ddr_backing_base & 0x1fffffff`
- FPM endpoint writes:
  - `0x12c0004c = 0x12200218`
  - `0x12c00050 = 0x12200210`
  - `0x12c00054 = 0x12200208`
  - `0x12c00058 = 0x12200200`
  - `0x12c00008 = 0x12200200`
- MBDMA control/config values:
  - `0x12c00004 = (old & 0xffffe000) | 0x9010`
  - `0x12c00040 = status | 0xdea9` candidate
  - `0x12c00044 = 0x02020202`
  - `0x12c00048 = 0x0000000f`
  - `0x12c0000c` final low field includes `0x0c41`

### Corrected `0x12c00070` interpretation

Current best interpretation:

- selected core/interface `0` path sets `0x00000003`
- selected nonzero core/interface path sets `0x00030000`
- disable path clears the corresponding selected pair

This supersedes the older `0x00003000` interpretation.

### Main FPM allocator

- allocator object base: `0x81848740`
- board-path FPM HW base: `0x12200000` / `0xb2200000`
- requested FPM buffer size: `0x100`
- FPM backing allocation length: `0x00800100`
- key fields:
  - `+0x00` FPM HW base
  - `+0x0c` aligned backing base
  - `+0x28` pool-size shift
  - `+0x2c` pool lookup table
  - `+0x48` token high-bits table

### Secondary packet allocator

- static state base: `0x8187bc60`
- init latch: `0x8187bc68`
- packet allocator object: `0x8187bc70`
- packet-header slot size: `0xe0`
- raw packet-header arena allocation: `0x700010`
- object `+0x20` links back to main allocator `0x81848740`

Important lifetime conclusion:

- `0x8187bc60..0x8187bc6f` is active static-state space
- therefore `0x8187bc70` should not currently be treated as a normal heap payload with ordinary heap-header bytes directly before it

### Token format

- `bit31` valid token marker
- `bits29:28` saved high bits / selector
- `bits27:12` token index
- `bits11:0` requested allocation-size low bits on allocation path
- token stride: `index * 0x100`

## Additional FPM control/status reads worth carrying

These are now high-value reverse/control addresses:

- `0x12200040`
- `0x12200044`
- `0x12200050`
- `0x12200054`
- `0x12200058`
- `0x1220005c`
- `0x12200200`
- `0x12200208`
- `0x12200210`
- `0x12200218`

Current best meanings:

- `0x12200040` buffer-size class field location
- `0x12200044` bus-visible backing-base field
- `0x12200050` overflow/underflow count
- `0x12200054` FIFO/token status
- `0x12200058` invalid token free count
- `0x1220005c` invalid token multifree count
- `0x12200200 + class * 8` alloc/free endpoints

## OpenWrt development consequences

The current reverse state still points to the same main conclusion:

- this OEM path is not a plain descriptor-only GENET bring-up
- it bridges GENET/MBDMA to Broadcom FPM token hardware
- OpenWrt must be compared against both:
  - FPM side `0x12200000`
  - GENET/MBDMA side `0x12c00000`

Most important practical consequences:

- do not interpret `0x12c0004c/50/54/58/08` as normal ring bases
- compare `0x12c00010` against FPM backing-base semantics, not allocator-object semantics
- compare `0x12c00070` against selected-core masks `0x00000003` and `0x00030000`
- include `0x12c00040` and FPM `0x12200050/54/58/5c` in runtime control reads

## Still unresolved

These items still need proof, not assumption:

- exact runtime value of the aligned FPM backing-base pointer behind allocator `+0x0c`
- exact semantic role of `0x13601c10` in channel-bank writes
- final TX/RX semantics of:
  - `0x12c00100`
  - `0x12c00120`
  - `0x12c00140`
  - `0x12c00180`
- exact final semantic meaning of the `0x14e0xxxx` profile/control block

## Canonical OpenWrt-facing document

The maintained OpenWrt-facing extraction document remains:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\openwrt-tc7200u-enet-usable-values.md`

This daily note is the dated summary snapshot for June 9.

## Addendum: DQM/CP2 return path and working packet model

This addendum was added after another full reread of the reverse-note set. It folds in:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-09-dqm-cp2-fpm-progress-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-09-ghidra-fpm-datatypes.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-09-ghidra-fpm-packet-token-rx-roundtrip.md`

### Control result

No contradiction was found against the current FPM-backed GENET/MBDMA model.

The new notes strengthen two points:

- `0x12200200` is not only a sized MBDMA endpoint value; it is also the shared token return/free port used by packet-release and DQM/CP2 token paths
- the secondary packet allocator and packet-header layout are now coherent enough to treat as a working software model

### New DQM/CP2 facts worth carrying

Confirmed DQM-side FPM endpoint mirror/programming:

- `0x16090038 = 0x12200200`
- `0x16090044 = 0x12200044 & 0x0fffffff`
- `0x16090128 = 0x12200208`
- `0x1609012c = 0x12200210`
- `0x16090130 = 0x12200218`
- `0x16090068 = 0xc0001617`

Confirmed DQM/CP2 event-side control registers:

- `0x16045740` DQM event FIFO
- `0x16045a80` DQM event/status
- `0x16045a00` CP2 event pull control
- `0x16045a04` CP2 submit trigger
- `0x16045a08` CP2 submit token
- `0x16045a0c` CP2 submit aux
- `0x16045a10` CP2 result token
- `0x16045a18` CP2 submit status
- `0x16045a1c` CP2 pull status
- `0x13401910` CP2/DQM ack write

Operationally important token facts:

- valid token is still `bit31`
- `bit30` means mailbox side handling is needed before token return
- token low12 is reused in DQM/CP2 logic for length, count, or mismatch handling

### Runtime-overlay caution

The range `0x80004040..0x800056xx` must currently be treated as mutable DQM runtime overlay or scratch RAM in this subsystem, not as immutable live boot code.

High-value overlay locations:

- `0x80004068` runtime service mask
- `0x800040e8 + queue_id*4` queue class/mode table
- `0x80004168 + queue_id*4` service timestamp/age table
- `0x800041f8` token-or-command reject counter
- `0x800041fc` invalid-token counter candidate
- `0x80004220` direct-token path count
- `0x8000423c..0x80004250` low12 mismatch patch stub words
- `0x80005628 + queue_id*4` queue backoff table

### Working packet/FPM software model

Working structure sizes:

- `tc7200_fpm_allocator = 0x20048`
- `tc7200_fpm_packet_allocator = 0x24`
- `tc7200_fpm_packet_header = 0xe0`
- `tc7200_fpm_packet_inner_header = 0x30`

Working packet-header facts:

- outer packet-header slot size remains `0xe0`
- packet-header arena allocation remains `0x700010`
- packet-header `+0x04` and `+0x08` both point at embedded inner header `+0x20`
- inner header `+0x18` points to outer header `+0x64`
- RX-side workers were seen storing halfword values `0x64` and `0x78` at outer `+0x12`
- RX-specific setup uses token low12 as payload length

### Updated daily development consequence

The first-pass OpenWrt compare set does not change: FPM `0x12200000` plus GENET/MBDMA `0x12c00000` remains the primary control target.

If those values start to match OEM behavior but RX/TX still stalls, the next control layer should be:

- whether valid tokens are actually being returned to `0x12200200`
- whether any DQM-side mirror bank is programmed with:
  - `0x16090038`
  - `0x16090044`
  - `0x16090128`
  - `0x1609012c`
  - `0x16090130`
- whether the software path assumes plain linear buffers where the OEM path reconstructs packet headers and data addresses from token index, stride `0x100`, and packet-header slot size `0xe0`

## Addendum: DQM queue-control surface closure

This addendum was added after another full reread and folds in:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-09-dqm-fpm-cp2-ghidra-progress.md`

### Control result

No contradiction was found against the current FPM-backed GENET/MBDMA model.

The new note strengthens the interpretation that the OEM packet-movement path is not only:

- GENET `0x12c00000`
- FPM `0x12200000`

It also depends on a mapped DQM/CP2 queue-control layer.

### New high-value DQM control surfaces

The DQM/CP2 path is now functionally mapped end-to-end at the control-flow level.

Highest-value additional MMIO regions to carry:

- `0x16045a00..0x16045a30` CP2 pull / submit / result / busy-status block
- `0x16045c00..0x16045d04` per-queue CP2 pull programming block
- `0x16082000 + queue_id*0x100` per-queue control region
- `0x16045000`
- `0x16045100`
- `0x16045200`
- `0x16001de0..0x16001dfc` DQM control mailbox input/output block

Additional already-confirmed DQM-side endpoint mirror values remain:

- `0x16090038 = 0x12200200`
- `0x16090044 = 0x12200044 & 0x0fffffff`
- `0x16090128 = 0x12200208`
- `0x1609012c = 0x12200210`
- `0x16090130 = 0x12200218`

### Runtime-software surfaces now worth carrying

The DQM note also closes several firmware-side runtime tables as meaningful, mutable state rather than static code:

- `0x800040c4` event07 / CP2 pull queue mask
- `0x800040e8 + queue_id*4` queue class/mode table
- `0x80004168 + queue_id*4` queue service timestamp/age table
- `0x800050a8 + queue_id*0x2c` per-queue policy/config table base
- `0x800050b8 + queue_id*0x2c` per-queue budget limit
- `0x800050bc + queue_id*0x2c` per-queue budget used
- `0x800050c0 + queue_id*0x2c` per-queue budget high-water
- `0x800050c4 + queue_id*0x2c` per-queue flags
- `0x800050c6 + queue_id*0x2c` per-queue low12 limit
- `0x800050cc + queue_id*0x2c` per-queue extended mode field
- `0x800050d0 + queue_id*0x2c` per-queue overhead field

### Updated daily development consequence

The current layered control model is now:

- first pass: FPM `0x12200000`
- second pass: GENET/MBDMA `0x12c00000`
- third pass if traffic still stalls: DQM/CP2 control surfaces under `0x1600xxxx`

Practical implication:

- if OpenWrt starts matching OEM values at `0x12200044`, `0x12c00010`, and `0x12c0004c/50/54/58/08` but packet movement still fails, the next likely missing piece is DQM/CP2 queue/token enable, pull, mailbox, or per-queue policy setup rather than plain MDIO or descriptor-ring geometry
