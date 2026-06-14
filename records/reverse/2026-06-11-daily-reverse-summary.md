# TC7200U reverse daily summary - 2026-06-11

## Scope

This is the daily detailed summary note after a full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse`

Preserve older logs and summaries. This note is additive and exists to freeze the current June 11 reverse state in one place.

## Control result

The full reread did not produce contradictions against the current FPM-backed GENET/MBDMA/DQM layered model.

It did confirm and strengthen these June 11 points:

- DQM queue profiles are real installed records at `0x16001a00 + queue_id * 0x10`
- `0x16001804/0x16001810/0x1600180c/0x16001818` form the queue bitmap, update, and IRQ or ack cluster used by both profile installers and vector handling
- `0x16040084 = 0x12200200` carries the shared FPM pool0 token endpoint into DQM static block init
- `0x1604008c` is the key DQM control submit or busy register with observed `0x580`, `0x780`, and `0x880` opcodes
- the mailbox dispatcher around `0x16001d00..0x16001d24` now closes commands `0x64`, `0x65`, `0x6f`, and `0x70` into slot select, slot update, and service flows
- the slot service path can feed CP2 results back into `0x12200200`, which further strengthens the token-return interpretation of that endpoint
- DQM event `0x01800008` is a real installed and re-armed service path rather than a loose side helper
- selectors `0x0a..0x0d` route through CP2 `f801` toward GENET targets `0x12c00510` and `0x12c00500`
- the selector/FPM request gate uses size-selected FPM endpoints `0x12200218`, `0x12200210`, `0x12200208`, and `0x12200200`
- the same selector/event path also programs `0x12200224` from page bits plus flag `0x801`

## Source notes folded into this daily summary

Earlier frozen notes remain valid. The main June 11 closure came from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-11-ghidra-dqm-fpm-cp2-progress-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-11-ghidra-dqm-mailbox-region-progress-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-11-dqm-event1800008-path-progress-log.md`

## New DQM queue-profile facts worth carrying

High-value newly-closed software and MMIO facts:

- runtime bump allocator state:
  - `0x80007000` allocation cursor
  - `0x80007004` remaining free byte count
- backing address to DQM word index:
  - `((addr - 0x80004000) >> 2) & 0xffff`
- queue profile entry base:
  - `0x16001a00 + queue_id * 0x10`
- queue bitmap or trigger cluster:
  - `0x16001804`
  - `0x1600180c`
  - `0x16001810`
  - `0x16001818`
- static DQM block also carries the shared FPM pool0 endpoint:
  - `0x16040084 = 0x12200200`

Important behavioral closure:

- the direct installer and packed-record installer are real queue-profile writers, not fake decompiler splits
- the fixed batch initializer at `0x80c7b95c` is a queue-layout recipe, not a generic helper
- queue profile install and later mailbox or slot-control paths now line up cleanly instead of looking like disconnected subsystems

## New mailbox and slot-control surfaces

Highest-value newly-closed physical control surfaces:

- mailbox and command block:
  - `0x16001d00..0x16001d0c`
  - `0x16001d10`
  - `0x16001d14`
  - `0x16001d20`
  - `0x16001d24`
  - `0x16001028`
- slot-control block:
  - `0x1604008c`
  - `0x16040090`
  - `0x16040198`
  - `0x160401a0`
  - `0x16040500`
  - `0x16040510`
- per-slot hardware region banks:
  - `0x16040700 + slot*4`
  - `0x16041000 + slot*0x20`
  - `0x16042000 + slot*0x40`
  - `0x16043000 + slot*0x40`
  - `0x16046000 + slot*0x10`
- service-path control values:
  - `0x160400c0`
  - `0x160400c4`
  - `0x160400e0`
  - `0x160400e4`
  - `0x16040120`
  - `0x16040144`

Current best meanings:

- `0x1604008c` is the main DQM submit or busy register for the slot-status, commit, and service path
- `0x16040090` returns the ctrl580 status word consumed by slot-selection logic
- `0x16040198` and `0x160401a0` are the slot commit request and completion bitmasks
- `0x16040500` low 16 bits act like a free-slot bitmap
- `0x16040510` acts like a slot validation or service bitmap
- `0x16040144` can feed the FPM pool0 endpoint path during DQM or CP2 service

## New event1800008 service-path surfaces

### Runtime init and event install path

Newly-closed runtime setup facts:

- runtime selector state:
  - `0x80007110`
  - `0x80007114`
  - `0x80007118 = 0x12c00510`
  - `0x8000711c = 0x12c00500`
- pair-copy window load:
  - `0x16052000`
- queue/event halfword setup:
  - `0x16001902 = 0x40`
  - `0x16001906 = 0x40`
  - `0x1600190a = 0x40`
  - `0x1600190e = 0x40`
- queue/event mask and global event setup:
  - `0x16001818 = 0x40383c08`
  - `0x16001810 = 0x40383c08`
  - `0x16001014 = 0x000c0000`
  - `0x16001010 = 0x000c0000`

Current best interpretation:

- the OEM runtime init does more than install queue profiles
- it also seeds the event and selector path that later feeds CP2/GENET/FPM service work

### Event handler and central dispatcher

Newly-closed handler and dispatcher facts:

- event handler:
  - masks and re-enables event `0x01800008`
  - acknowledges queue/event mask at `0x16001818`
  - acknowledges or enables the global DQM mask at `0x16001014`
- central pending-bit dispatcher watches:
  - `0x8000800c & 0x40383c08`
- direct pending-bit source slots:
  - `0x16001d30`
  - `0x16001d40`
  - `0x16001d50`
- selector publish or ack base:
  - `0x16001c00 + selector * 0x10`

Operationally important closure:

- the event path is now structurally mapped from runtime init through handler, dispatcher, selector wrapper, and FPM request gate
- this makes the DQM event layer an OpenWrt-relevant control surface, not only a reverse-side curiosity

### Selector and FPM request path

Newly-closed hardware request surfaces:

- selector request block:
  - `0x16001320`
  - `0x16001324`
  - `0x16001328`
  - `0x1600132c`
  - `0x16001dbc`
- size-selected FPM endpoints:
  - `0x12200218`
  - `0x12200210`
  - `0x12200208`
  - `0x12200200`
- additional FPM or b220-family programmed endpoint:
  - `0x12200224`

Current best meanings:

- `0x16001320` request word B
- `0x16001324` selected FPM token or value
- `0x16001328` selected context pointer
- `0x1600132c` payload size with flags `| 0x16000`
- `0x16001dbc` request selector
- `0x12200224 = (record_word_b & 0xfffff000) | 0x801` in several event-driven record-routing paths

Important behavior:

- selector helper chooses FPM endpoint by payload size plus `4`
- if the FPM path cannot issue immediately, the code may return the token or value to `0x12200200`
- unexpected selector IDs also fall back to `0x12200200`

## OpenWrt development consequences

The current staged control model is now:

- stage 1: FPM allocator and backing-base values under `0x12200000`
- stage 2: GENET or MBDMA endpoint and control values under `0x12c00000`
- stage 3: DQM or CP2 queue-control and mirror programming under the already-carried `0x16045a00..0x16082000` set
- stage 4: DQM mailbox, queue-profile, slot-commit, and CP2 or FPM service plumbing under `0x160018xx`, `0x16001dxx`, `0x1604008c/90`, `0x16040198/a0`, and `0x16040500/10`
- stage 5 if traffic still stalls: DQM event `0x01800008`, selector dispatch, request-block programming, and size-selected FPM request/return behavior

Practical implication:

- do not stop at matching `0x12200044`, `0x12c00010`, and `0x12c0004c/50/54/58/08`
- also check whether anything OpenWrt-side ever programs queue profiles, applies queue bitmaps, commits slots, or returns tokens through `0x12200200`
- if OEM-equivalent earlier-stage values match but packet movement still fails, the next likely missing layer is DQM event/selector/request-block state rather than plain MDIO or descriptor-ring geometry

## Repository updates recorded in this pass

Recorded modifications worth keeping:

- consolidated the June 11 reverse findings into this single daily summary `2026-06-11-daily-reverse-summary.md`
- refreshed the maintained OpenWrt-facing note `openwrt-tc7200u-enet-usable-values.md` with the June 11 DQM mailbox and slot-control findings
- refreshed the same OpenWrt-facing note with the June 11 event `0x01800008` selector/FPM request path

## Preservation

This note is additive. No old logs or notes were deleted. No git action is part of this command.
