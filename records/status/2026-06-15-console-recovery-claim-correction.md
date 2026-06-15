# TC7200U correction: June 14 "new working console image" claim was mixed-log wrong

Date: 2026-06-15

## Scope

This note corrects the status interpretation around whether a newly rebuilt
TC7200U OpenWrt image had already reproduced the known-good working userspace
console.

This is a new correction record. Older logs and older notes are preserved
unchanged.

## Short conclusion

The current status logs support this statement:

- we still do **not** have a newly rebuilt image that reproduces the full
  known-good OpenWrt userspace console baseline

What **is** true now:

- newer rebuilt images can reach earlycon
- newer rebuilt images can bind the real `ttyS0` console in some runs
- the `populate_rootfs` hang was moved in the latest `try5` family
- but the new image family still dies in userspace before reaching the known
  good `procd` / login-prompt state

So the earlier statement "a new rebuilt image recovered a usable console" was
too strong and was based on a mixed log mapping.

## What was wrong

The incorrect claim was recorded in:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-console-root-cause-local-git-search.md`

That note linked these together as if they described one successful rebuilt
image test:

- build:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\2026-06-14-205815-build-provenance.log`
- verify:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\2026-06-14-205815-verify.log`
- serial:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\picocom-20260614-212432.log`

That mapping is wrong.

## Direct correction evidence

### 1. The 205815 build really produced `tc7200u-uart500-l2-nandoff.bin`

From:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\2026-06-14-205815-build-provenance.log`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\2026-06-14-205815-verify.log`

Recorded identity:

- filename:
  - `tc7200u-uart500-l2-nandoff.bin`
- `raw_sha256=9d0fc5958a37bae4348fa293287e340ad0ba6bc5936afbabb35fbf61e9646921`
- `wrapped_sha256=b5448b778f204383ea0586aeedfa70c39f81ab0e72ed820c3317d858a381ffaa`
- `load_address=0x82000000`

### 2. The `212432` serial log did **not** boot that image

From:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\picocom-20260614-212432.log`

The serial log explicitly shows:

- `Enter filename [tc7200u.bin]: tc7200-console-known-good-retest.bin`
- `Starting TFTP of tc7200-console-known-good-retest.bin from 192.168.77.2`
- later:
  - `Please press Enter to activate this console.`
  - `login[376]: root login on 'ttyS0'`

So that successful userspace-console run was a retest of
`tc7200-console-known-good-retest.bin`, not a boot of
`tc7200u-uart500-l2-nandoff.bin`.

### 3. The repo already contains binary-proof files for that retest

From:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\tc7200-console-known-good-retest-20260614-212418-sha256.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\tc7200-known-good-retest-binary-proof-20260614-213533.txt`

Both files record:

- `a2b9fa164d092387dc0382698cbdff940bb97cce6c41a029ac70c1b357497c4b  records/artifacts/rescue/tc7200-console-good-20260601-193010.bin`
- `a2b9fa164d092387dc0382698cbdff940bb97cce6c41a029ac70c1b357497c4b  /mnt/c/tftp/tc7200-console-known-good-retest.bin`

That proves the successful `212432` boot belonged to the pinned known-good
payload family.

## What the status dir says now

The strongest current new-image notes are:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-15-new-image-initramfs-none-init-segv-status.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-15-try5-initramfs-none-userspace-sigsegv.md`

These notes show the latest new image:

- filename:
  - `openwrt-try5.bin`
- is a real newly built image, not the pinned rescue payload
- reaches:
  - earlycon
  - real `ttyS0`
  - end of `populate_rootfs`
  - `Run /init as init process`
- but then fails with:
  - `do_page_fault(): sending SIGSEGV to cp`
  - `do_page_fault(): sending SIGSEGV to switch_root`
  - `Kernel panic - not syncing: Attempted to kill init!`

Meaning:

- the current new-image family is no longer blocked on the old UART `-16`
  failure in this latest branch
- but it still does **not** reach the known-good userspace baseline

## Corrected project status

As of 2026-06-15, the current status should be read this way:

1. The pinned known-good family still reaches full userspace console:
   - `tc7200-console-good-20260601-193010.bin`
   - `tc7200-stage2-console-good.bin`
2. The newer rebuilt family still has **not** reproduced that result.
3. The active new-image blocker has moved:
   - earlier branch:
     - real UART bind failure (`bcm63xx_uart ... error -16`)
   - latest `try5` branch:
     - userspace `cp` / `switch_root` SIGSEGV after `/init`
4. Therefore:
   - "new image reaches real ttyS0" is now plausible and evidenced in the
     latest branch
   - "new image reaches working OpenWrt shell / console-ready baseline" is
     still **not** proven

## Rule going forward

Do not mark a rebuilt image as "working console image" unless the serial log for
that exact non-control filename shows:

- TFTP filename matches the new candidate
- `procd: - init -`
- `Please press Enter to activate this console.`
- login prompt or root login on `ttyS0`

and the image identity is pinned with:

- filename
- file length
- raw SHA256
- wrapped SHA256
- load address
- serial log path

## Affected note

This correction specifically supersedes the following claim in:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-console-root-cause-local-git-search.md`

Superseded claim:

- that by the end of 2026-06-14 a newly rebuilt image had already recovered a
  usable working console

Corrected claim:

- by the end of 2026-06-14 the known-good rescue image was retested
  successfully, while rebuilt-image status remained unresolved
- by 2026-06-15 rebuilt-image status improved to "real ttyS0 plus `/init` then
  userspace SIGSEGV," but still not to a working console baseline

## Change log

- 2026-06-15: created this correction note after re-checking the status notes,
  the `205815` build/verify logs, the `212432` serial log, and the new `try5`
  status notes.
- 2026-06-15: no older logs or older notes were edited by this correction
  record.
