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
