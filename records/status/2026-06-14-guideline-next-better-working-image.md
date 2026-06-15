# TC7200U guideline: build the next better-working OpenWrt image (2026-06-14)

## Purpose

This note defines the safest current procedure for producing a new TC7200U
OpenWrt image that is more useful than the current control image without
breaking the already-working boot path.

This guideline is based on:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-working-settings-modes-compression-build-summary.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\important-openwrt-tc7200u-enet-usable-values.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-05-31-openwrt-port-checklist.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-02-canonical-a825-wrapped-flow.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\docs\WORKFLOW.md`

## What "better working" means

A new image is only "better working" if it preserves the current boot baseline
and improves Ethernet behavior in a measurable way.

Minimum boot baseline that must stay true:

- CFE accepts the image.
- A825 header parse is clean.
- OpenWrt kernel loader runs.
- Early console appears on `bcm63xx_uart0` and the main console binds to
  `ttyS0`.
- Kernel reaches userspace shell on ttyS0.
- No new early boot crash, exception dump, or immediate return to CFE.

Only these outcomes count as real improvement:

1. OpenWrt RX counters become nonzero.
2. Host capture sees at least one router-originated frame on the target path.
3. GMAC MIB or RX queue evidence moves in a way that proves ingress reached the
   hardware even if Linux netdev RX is still zero.
4. Watchdog frequency drops materially while TX or RX progress improves.
5. Bidirectional ARP or ping starts working, even if unstable.

These do not count as "better" by themselves:

- smaller image size
- different compression mode
- different wrapper fields
- link-up only
- TX submit growth without host-visible egress
- the same watchdog and zero-RX signature under a new filename

## Freeze the known-good control path

Do not change these unless the goal is explicitly wrapper experimentation:

- preserve-from template:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\artifacts\rescue\tc7200-stage2-console-good.bin`
- canonical A825 wrapped flow
- current helper entrypoint:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tcbuilder.sh`
- RAM/TFTP boot only
- no SPI or NAND writes

Current control image family to keep available for A/B comparison:

- `tc7200-stage2-console-good.bin`
- `tc7200-next-control.bin`

Rule:

- every new candidate must be judged against the control image, not against
  memory of an earlier run

### Load-address rule

For new image work, treat these addresses differently:

- current canonical wrapped-image load address:
  - `0x82000000`
- historical proven experimental/header-profile load address:
  - `0x80004000`
- post-loader kernel start address:
  - `0x80010000`

Meaning:

- use `0x82000000` for new wrapped builds by default
- treat `0x80004000` as a historical working path, not the default for new
  candidate images
- do not confuse `0x80010000` with the A825 header load address; it is the
  kernel start after the OpenWrt BMIPS loader decompresses the kernel

Operator rule:

- if the goal is "next better working image," stay on the canonical
  `0x82000000` path
- only use `0x80004000` when intentionally re-running older header or loader
  experiments

### Console rule

For a working image, keep the currently proven console configuration:

- early boot console:
  - `earlycon` on `bcm63xx_uart0`
- normal kernel and userspace console:
  - `ttyS0`
- UART block:
  - `0x14e00500`
- serial driver type:
  - `bcm63xx_uart`
- working bootarg form:
  - `console=ttyS0,115200 earlycon`

Meaning:

- do not treat console settings as an open experiment while the goal is a
  better Ethernet image
- if a candidate changes console behavior unexpectedly, treat that as a boot
  regression before judging Ethernet behavior

Expected good runtime markers:

- `earlycon: bcm63xx_uart0 at MMIO 0x14e00500`
- `Kernel command line: console=ttyS0,115200 earlycon`
- `14e00500.serial: ttyS0 ... is a bcm63xx_uart`
- `Please press Enter to activate this console.`
- `root login on ttyS0`

## Working assumptions for the next image

The boot/container side is already good enough. The next better image should
come from Ethernet-path work, not from another wrapper-format experiment.

Current strongest technical direction:

- keep the proven boot path
- keep the proven `0x14e000ec |= 0x100` link-enable related behavior
- compare and then move toward OEM-like FPM plus GENET programming
- do not jump straight to late-pass Host-DQM or Stage1 software correlation
  unless the earlier FPM and GENET surfaces already look OEM-like

## Candidate build rules

### Rule 1: change one variable at a time

Per candidate image, change only one of these categories:

- DTS memory or reserved-memory layout
- GENET driver logic
- FPM-side programming
- debug instrumentation
- package profile

Do not combine:

- wrapper changes
- compression changes
- FPM changes
- GENET logic changes
- DQM or Stage1 software-correlation changes

in the same first-pass candidate.

### Rule 2: keep the wrapper canonical

For Ethernet work:

- do not change A825 signature policy
- do not switch back to OEM compressed-mode wrapper fields
- do not change load-address policy just because the image is new
- do not switch from canonical `0x82000000` to historical `0x80004000` unless
  the test is explicitly about header or loader behavior

If the goal is a better Ethernet image, wrapper churn is noise.

### Rule 3: keep diagnostics available

Use the debug-capable package profile for candidate work unless image size
forces a temporary exception.

Preferred operator behavior:

- keep `devmem`, `ethtool`, and debug tooling available
- prefer a slightly larger image that proves the failure mode over a smaller
  image that hides it

## Recommended image ladder

Build the next images in this order.

### Candidate 1: control-plus-trace

Purpose:

- prove the current control image can be rebuilt from the current tree
- add only passive tracepoints or debug dumps around the frozen compare set

Allowed changes:

- debug prints
- debug register dumps
- no new active MMIO writes except already-proven required ones

Success condition:

- boots like control
- captures high-value compare data without creating a new regression

### Candidate 2: FPM-visible-values

Purpose:

- test the first OEM-like FPM and GENET control surfaces that are most likely to
  affect packet movement

First compare set to prioritize:

- `0x12200040`
- `0x12200044`
- `0x12200200`
- `0x12200208`
- `0x12200210`
- `0x12200218`
- `0x12c00004`
- `0x12c00008`
- `0x12c0000c`
- `0x12c00010`
- `0x12c00044`
- `0x12c00048`
- `0x12c0004c`
- `0x12c00050`
- `0x12c00054`
- `0x12c00058`
- `0x12c00070`

Success condition:

- boot baseline preserved
- at least one Ethernet signal improves:
  - RX counters
  - host-visible ingress
  - MIB movement
  - lower watchdog rate with meaningful traffic progress

### Candidate 3: backing-base and endpoint-focused

Purpose:

- if Candidate 2 still shows zero RX, focus specifically on OEM-like backing
  base and pool endpoint behavior

Highest-value targets from the current reverse model:

- `0x12200044`
- `0x12c00010`
- `0x12c0004c`
- `0x12c00050`
- `0x12c00054`
- `0x12c00058`
- `0x12c00008`

Do not hardcode speculative values blindly.

Goal:

- make OpenWrt produce values structurally equivalent to OEM behavior
- not just print them

### Candidate 4 and later: deeper queue/runtime layers

Only move to deeper layers if:

- the FPM and GENET control set already looks close to OEM
- but packets still do not move

Only then move on to:

- DQM/CP2 queue-control surfaces
- mailbox and slot-service surfaces
- selector/request-model paths
- Host-DQM selector blocks
- Stage1 event-slot wake behavior
- later thread-record and signal/work correlation layers

## Build procedure

Open a WSL shell rooted in:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research`

Use the canonical helper surface from `docs/WORKFLOW.md`.

### Preferred path

Run:

```sh
tcbuild auto
```

Or, in an interactive TTY:

```sh
tcbuild
```

then choose the auto build/wrap/verify path.

### Preferred diagnostic profile

For candidate images:

```sh
TC7200U_PACKAGE_PROFILE=debug tcbuild auto
```

Only use `--skip-precheck` when the pre-check is the known blocker and the
actual build logic is still intended.

### Output discipline

For each new image, record:

- candidate filename
- raw SHA256
- wrapped SHA256
- build log path
- verify log path
- serial log path

Do not test unnamed or ambiguously renamed images.

## Naming guideline

Use filenames that encode function, not hope.

Good examples:

- `tc7200-stage2-enet-trace-r1.bin`
- `tc7200-stage2-fpm-compare-r2.bin`
- `tc7200-stage2-fpm-endpoint-r3.bin`
- `tc7200-stage2-genet-fpm-r4.bin`

Avoid names like:

- `new.bin`
- `fixed.bin`
- `best.bin`
- `try2.bin`

The name should reveal what changed.

## Boot and validation procedure

### Step 1: boot the control image first

Before testing a new candidate:

- boot the current control image
- confirm the environment still behaves as expected

This prevents blaming the candidate for a host-side or setup-side drift.

### Step 2: boot the new candidate

Collect:

- full serial log under
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial`
- build and verify logs under
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds`

### Step 3: apply gate checks

Use the existing gate model:

- Gate A: transport and header acceptance
- Gate B: runtime stability
- Gate C: NAND replacement health
- Gate D: TP handshake health
- Gate E: userspace console readiness

If the new image regresses an earlier gate, it is not a better image.

### Step 4: run Ethernet validation in the current best test mode

Primary validation mode:

- forced `10 Mbps Half Duplex` on both ends

Reason:

- this mode gives the cleanest current reproduction of the real datapath
  failure without confusing link-mismatch noise

Secondary validation mode:

- `1Gbps/Full` with the already-proven `0x14e000ec |= 0x100` behavior

Reason:

- it checks whether the candidate improved more than just the forced `10/half`
  test case

### Step 5: judge only with measurable signals

Check:

- host capture:
  - any router-originated frame
  - any ARP reply
  - any ICMP echo reply
- OpenWrt stats:
  - `rx_packets`
  - `rx_bytes`
  - RX queue counters
  - RX MIB movement if instrumented
- watchdog pattern:
  - fewer watchdog events
  - or the same watchdog count but new RX evidence

## Decision matrix

### Keep and branch from this candidate if

- it preserves the full boot baseline
- it preserves the control wrapper discipline
- it adds new evidence on RX, ingress, or MIB movement
- it reduces watchdog severity while keeping or improving traffic signs

### Keep only as a diagnostic image if

- it boots well
- but only adds debug visibility
- and does not improve packet movement

This is still useful, but it is not yet the next better working image.

### Reject and revert if

- Gate A or Gate B regresses
- boot returns to CFE unexpectedly
- the candidate only changes wrapper behavior
- the candidate adds noise without any new Ethernet evidence

## Strong do-not-do list

Do not do these while chasing a better Ethernet image:

- do not change wrapper and Ethernet logic in the same candidate
- do not switch to a new compression format just because the image got smaller
- do not hardcode speculative late-pass Stage1 software values into Linux
- do not skip the control-image boot before candidate testing
- do not mark link-up-only as success
- do not call a candidate "better" if RX is still hard zero and the host still
  sees no router-originated frames

## Current best practical target

The next image should aim to be:

- boot-identical in stability to `tc7200-stage2-console-good.bin`
- still built through the canonical A825 wrapped flow
- instrumented enough to compare FPM and GENET against OEM
- changed in only one meaningful Ethernet-control area
- validated first under forced `10 Mbps Half Duplex`

If one image can do all of these and produce the first reproducible ingress
signal, that is the correct branch point for the next round.

## Short operator recipe

1. Boot the control image and confirm the baseline.
2. Make one Ethernet-focused code change only.
3. Build with `TC7200U_PACKAGE_PROFILE=debug tcbuild auto`.
4. Keep the canonical preserve-from and wrapper discipline.
5. Capture hashes, build logs, verify logs, and serial logs.
6. Test first in forced `10 Mbps Half Duplex`.
7. Promote the image only if RX, host-visible ingress, or GMAC ingress evidence
   improves without losing boot stability.

## Preservation

Created as a new dated guideline note.

- No old logs were edited.
- No old notes were overwritten.
