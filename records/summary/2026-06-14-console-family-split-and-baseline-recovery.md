# 2026-06-14 Console Family Split and Baseline Recovery

## Scope

This summary records the 2026-06-14 TC7200U OpenWrt console recovery session, including the failed rebuild attempts, the confirmed working known-good image, the payload-family split, unsafe grep incident, and the corrected next direction.

This is a summary record, not a replacement for the raw serial/build logs.

## Confirmed working baseline

The pinned known-good rescue image was retested and confirmed working:

- `records/artifacts/rescue/tc7200-console-good-20260601-193010.bin`
- copied/retested as `tc7200-console-known-good-retest.bin`
- booted through CFE/TFTP
- reached OpenWrt userspace
- reached interactive serial console

Known PASS markers for this family:

- `OpenWrt kernel loader for BMIPS`
- `Decompressing kernel... done!`
- `Run /init as init process`
- `procd: - init -`
- `Please press Enter to activate this console.`
- `BusyBox v1.37.0 ...`

Known gate result:

- Gate A PASS
- Gate B PASS
- Gate C PASS clean
- Gate D PASS
- Gate E PASS / `console_ready`

## Important correction

The working console was not recovered by the latest rebuild path. It was recovered by retesting the pinned known-good payload.

The current/new rebuild family must not be treated as equivalent to the known-good family.

## High-level result

The board, CFE mode, TFTP path, serial adapter, terminal setup, and pinned rescue binary are working.

The failure is in the rebuilt payload family/provenance, not in the physical console path.

## Failed/rebuilt image findings

Several newer rebuilt images were tested or inspected during the session.

Observed rebuilt-family sizes and hashes included:

- `raw_size=8893909`, `wrapped_size=8894001`
- `raw_size=7992916`, `wrapped_size=7993008`
- `raw_size=7992922`, `wrapped_size=7993014`
- `raw_size=7992990`, `wrapped_size=7993082`
- later package-clean candidate:
  - `raw_size=7373275`
  - `wrapped_size=7373367`
  - `load_address=0x82000000`
  - `size_ok=True`
  - `raw_sha256=9d986b2a09d49d56f39fa8aa0119eadaf73b537641b097f96c48464210642f32`
  - `wrapped_sha256=7417dac46b80feda79a73858f2ebd577d6ee269bf56314601a863770869bcce5`

The package-clean candidate was close in raw size to the old target-size class but did not reproduce the known-good behavior.

## Console failure path observed

A bad candidate showed early kernel output through earlycon, but the real UART console did not register.

Important failure marker:

- `bcm63xx_uart 14e00500.serial: probe with driver bcm63xx_uart failed with error -16`

Interpretation:

- earlycon alone can print kernel logs
- usable interactive console requires the real `ttyS0` driver registration
- without the real `ttyS0` registration, OpenWrt can print early boot text but cannot provide the expected interactive serial shell

## NAND-side false lead

One candidate stalled through NAND scanning before userspace. NAND was disabled in the board DTS for a follow-up candidate.

This was a useful isolation step, but it was not sufficient to recover the known-good console behavior.

## UART/L2/DEVTMPFS work

Changes and checks performed:

- confirmed/added `CONFIG_BCM7120_L2_IRQ=y`
- attempted to add:
  - `CONFIG_DEVTMPFS=y`
  - `CONFIG_DEVTMPFS_MOUNT=y`
  - `CONFIG_DEVTMPFS_SAFE=y`
- generated kernel config still kept:
  - `# CONFIG_DEVTMPFS is not set`
- generated kernel config did keep:
  - `CONFIG_BCM7120_L2_IRQ=y`

Important interpretation:

- `CONFIG_BCM7120_L2_IRQ=y` is relevant to UART RX/console interrupt behavior
- `DEVTMPFS` is not the first blocker for UART probe registration
- `/dev` and initial-console failures are later-stage userspace/device-node concerns
- real UART probe failure must be solved before chasing `/dev/console`

## DTS/provenance correction

The session explored UART DTS variants around:

- `uart0: serial@14e00500`
- `reg = <0x14e00500 0x18>`
- `console=ttyS0,115200 earlycon`
- `nand status = "disabled"`
- `ethernet_test status = "okay"`

The later safe provenance search showed many historical candidate UART patches and confirmed the live diagnostic/research tree contains multiple UART-order/name variants.

Important correction:

- The known-good working image cannot be explained only by the current staged DTS.
- The key issue is payload/source/build family provenance.
- The known-good binary family must be treated as separate until exact provenance is recovered.

## Payload family split

### Known-good family

Known-good/pinned rescue family:

- `records/artifacts/rescue/tc7200-console-good-20260601-193010.bin`
- `records/artifacts/rescue/tc7200-stage2-console-good.bin`
- confirmed by `picocom-20260601-193010.log`
- gate report: `2026-06-01-195304-check-gates-picocom-20260601-193010.txt`
- reaches userspace
- reaches `procd`
- reaches interactive shell prompt

Known-good markers to require before further Ethernet work:

- exact CFE filename
- file length
- raw SHA256 where available
- wrapped SHA256
- load address
- kernel version line
- `Run /init as init process`
- `procd: - init -`
- `Please press Enter to activate this console.`
- Gate E PASS / `console_ready`

### Broken/current rebuild family

Current rebuilt candidates are not equivalent to the pinned known-good family.

Observed failure classes:

- real UART driver probe failure: `bcm63xx_uart ... error -16`
- NAND scan/stall path before userspace
- userspace/init panic paths in previous current-family builds
- size-class similarity without behavioral equivalence

The current rebuilt image family must be treated as a separate, broken/provenance-unknown family until it independently passes Gate E.

## Unsafe command incident

A recursive provenance grep was run across `records/` while `tee` wrote the output into `records/logs/builds/`.

Result:

- grep began matching the file it was writing
- output became self-feeding
- terminal/PC load became dangerous
- command was interrupted

Corrected rule:

- never recursively grep `records/` while writing output inside `records/`
- exclude `records/logs`
- exclude `.git`
- exclude large reverse/generated/log areas unless explicitly bounded
- prefer targeted path lists such as `docs`, `patches`, `records/status`, and `records/generated`

The runaway file must be preserved, not deleted. If large, compress it.

## Correct next technical direction

Stop trying to make the current rebuilt image behave like the pinned good image by random toggles.

Next work must be:

1. Keep pinned known-good rescue images unchanged.
2. Use the pinned known-good image as the console control.
3. Recover exact known-good source/build/wrapper provenance.
4. Require Gate E PASS for every new candidate before Ethernet debugging.
5. Do not mix payload families between tests.
6. Record image identity for every boot:
   - filename
   - file length
   - raw SHA256
   - wrapped SHA256
   - load address
   - kernel version line
   - serial log path
   - gate report path
7. After Gate E PASS is stable, return to Ethernet/GENET TDMA work.

## Current bottom line

Console is not globally broken.

Confirmed working:

- CFE/TFTP boot
- serial adapter
- terminal
- known-good OpenWrt userspace console
- Gate E PASS on pinned known-good image

Still broken:

- current rebuilt payload family
- exact source/provenance reproduction of the known-good image
- Ethernet TX/RX path, especially GENET TDMA descriptor consumption

## Files/records touched or relevant

Relevant working/pinned files:

- `records/artifacts/rescue/tc7200-console-good-20260601-193010.bin`
- `records/artifacts/rescue/tc7200-stage2-console-good.bin`
- `records/logs/serial/picocom-20260601-193010.log`
- `records/logs/builds/2026-06-01-195304-check-gates-picocom-20260601-193010.txt`
- `records/status/2026-06-14-guideline-next-better-working-image.md`
- `records/status/2026-06-14-working-settings-modes-compression-build-summary.md`
- `docs/STATUS.md`
- `docs/START_HERE.md`
- `docs/MEMORY_MAP.md`

New summary record:

- `records/summary/2026-06-14-console-family-split-and-baseline-recovery.md`

