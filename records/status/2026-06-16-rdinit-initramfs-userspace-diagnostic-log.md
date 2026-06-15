# 2026-06-16 rdinit initramfs userspace diagnostic log

## Scope

This note records the current TC7200.U / BCM3383 OpenWrt console recovery and initramfs userspace investigation before the next boot of the exact patched candidate image.

The immediate work branch is **not Ethernet** and not Ghidra decompilation. It is the OpenWrt initramfs userspace path that regressed after the new ProgramStore-wrapped image family reached `/init` but failed before `procd`.

## Repository and path rules used

- Research repo: `~/tc7200u-research`.
- OpenWrt source tree: `~/src/openwrt`.
- Records should be written under `records/status/`, `records/logs/`, `records/generated/`, `records/backups/`, or another current `records/` subdirectory.
- Do **not** add new files under `records/notes/`; that is a legacy path.
- Do **not** delete old logs or old markdown files.
- For useful research runs: inspect git status, add the new records/docs, then create a local commit. Push only when explicitly requested.

## Top-level result

The new ProgramStore-wrapped image family is now proven to pass the low-level boot path:

- CFE accepts the A825 ProgramStore image.
- CFE loads the requested filename by TFTP.
- Image 4 executes.
- Linux boots.
- earlycon works at UART0 `0x14e00500`.
- real `ttyS0` binds.
- `rdinit=/bin/sh` reaches BusyBox shell.
- basic BusyBox commands, `cp`, and pipeline execution are stable when commands are sent cleanly.

The current blocker is narrowed to the generated initramfs `/init` script, especially this line:

```sh
DIRS=$(echo *)
```

That command alone can trigger a userspace SIGSEGV in the `rdinit=/bin/sh` diagnostic shell. This means the previous `cp` and `switch_root` failures were downstream symptoms of `/init` shell/glob/command-substitution behavior, not proof that the A825 wrapper, UART, or basic libc runtime is broken.

## Evidence summary

### Gate-check of new procd candidate

Candidate tested:

```text
openwrt-console-procd-20260615-232607.bin
```

Important markers:

```text
tftp_complete=1
signature_a825=1
executing_image4=1
exceptions=0
decompression_failed=0
openwrt_loader_lines=1
openwrt_decompress_kernel_lines=1
warning_initial_console_lines=0
kernel_panic_lines=1
panic_init_kill_lines=1
procd_init_lines=0
press_enter_lines=0
```

Boot log markers showed:

```text
Enter filename [tc7200-console-known-good-retest.bin]: openwrt-console-procd-20260615-232607.bin
Starting TFTP of openwrt-console-procd-20260615-232607.bin from 192.168.77.2
File Length: 7143509 bytes
Load Address: 82000000
HCS: ed29
CRC: 00000000
Bypassing CRC Verifiction on Image 4...
Linux version 6.12.87 ... r34703-aa96b3ad55
Kernel command line: console=ttyS0,115200 earlycon ignore_loglevel loglevel=8 initcall_debug clk_ignore_unused pd_ignore_unused initramfs_async=0 panic=10
14e00500.serial: ttyS0 at MMIO 0x14e00500 ... is a bcm63xx_uart
Run /init as init process
do_page_fault(): sending SIGSEGV to cp for invalid write access to 00000000
do_page_fault(): sending SIGSEGV to switch_root for invalid write access to 00000000
Kernel panic - not syncing: Attempted to kill init! exitcode=0x0000000b
```

Conclusion from this stage:

- Wrapper and UART were already good.
- `/init` reached userspace.
- `procd` did not start.
- The active blocker was somewhere in initramfs userspace before `procd`.

### musl allocator trap symbolization

Initial userspace faults in `cp` and `switch_root` were symbolized against the MIPS rootfs libc:

```text
0x35070 -> alloc_slot
0x358a8 -> __libc_malloc_impl
```

The disassembly at both locations contained intentional trap instructions:

```asm
sb zero,0(zero)
```

Interpretation at that stage:

- The visible faults were musl allocator integrity traps.
- `cp` and `switch_root` were not necessarily the root cause; they may have been the first larger commands to hit corrupted state or a shell-generated bad argument/list.

### `rdinit=/bin/sh` correction

`init=/bin/sh` did not bypass initramfs `/init`; the kernel still preferred `/init`.

Correct diagnostic bootarg:

```text
rdinit=/bin/sh
```

DTS bootargs were updated to:

```text
console=ttyS0,115200 earlycon ignore_loglevel loglevel=8 initcall_debug clk_ignore_unused pd_ignore_unused initramfs_async=0 rdinit=/bin/sh panic=10
```

The `rdinit=/bin/sh` diagnostic image reached BusyBox shell:

```text
Run /bin/sh as init process
BusyBox v1.37.0 built-in shell
/bin/sh: can't access tty; job control turned off
~ #
```

This proved that the kernel, rootfs, dynamic loader, BusyBox shell startup, and serial console path were all good enough to run an interactive shell.

### Long paste / pipeline false lead

One diagnostic paste used a long semicolon chain and pipeline. That run produced a shell crash in libc:

```text
sh invalid read from 00000003 at libc.so+0x8e174
sh invalid write to 00000000 at libc.so+0x8cfb4
```

Symbolization mapped those offsets to:

```text
0x8e174 -> strcspn
0x8cfb4 -> memcpy
0x8da9c -> mempcpy
```

At first this looked like broad BusyBox/libc corruption.

A later clean test using one command per line disproved that broad interpretation.

### Clean one-command-per-line shell diagnostic

A later `rdinit=/bin/sh` run showed the shell was stable when commands were sent cleanly:

```text
mount -t proc proc /proc        -> OK
mount -t sysfs sysfs /sys       -> OK
cat /proc/meminfo               -> OK
head -30 /proc/meminfo          -> OK
/bin/cp --help                  -> OK
/bin/cp /init /tmp/init.copy    -> OK
cat /proc/meminfo | head -30    -> OK
```

Conclusion:

```text
kernel OK
ttyS0 OK
rdinit shell OK
BusyBox OK
cp OK
pipeline OK
malloc/libc generally OK
failure is specific to OpenWrt /init / preinit / switch_root path
```

### devtmpfs discovery and fix

Runtime check showed:

```sh
grep devtmpfs /proc/filesystems || echo NO_DEVTMPFS
```

Result:

```text
NO_DEVTMPFS
```

Initial built kernel config only showed:

```text
CONFIG_TMPFS=y
```

The OpenWrt `.config` was then updated with:

```text
CONFIG_KERNEL_DEVTMPFS=y
CONFIG_KERNEL_DEVTMPFS_MOUNT=y
```

After rebuild, the built kernel config verified:

```text
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_TMPFS=y
```

Interpretation:

- Missing devtmpfs was real and would break or complicate normal device-node setup.
- It was probably not the root cause of the `DIRS=$(echo *)` crash, but it needed to be fixed before attempting a real procd boot again.

### `/init` trace and source-template discovery

The generated initramfs `/init` was traced and found to be very small:

```sh
#!/bin/sh
# Copyright (C) 2006 OpenWrt.org

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

DIRS=$(echo *)
NEW_ROOT=/new_root

mkdir -p $NEW_ROOT
mount -t tmpfs tmpfs $NEW_ROOT

cp -pr $DIRS $NEW_ROOT

exec switch_root $NEW_ROOT /sbin/init
```

Manual test in the shell showed the first problematic line could fail by itself:

```sh
DIRS=$(echo *)
```

Crash:

```text
do_page_fault(): sending SIGSEGV to sh for invalid read access from 00000000
epc = libc.so+0x7f378
```

This narrowed the root cause to the generated `/init` shell glob/command-substitution line, before `cp` and before `switch_root`.

The real source template was found by narrow search:

```text
target/linux/generic/other-files/init
```

Search output:

```text
target/linux/generic/other-files/init:6:DIRS=$(echo *)
target/linux/generic/other-files/init:7:NEW_ROOT=/new_root
target/linux/generic/other-files/init:14:exec switch_root $NEW_ROOT /sbin/init
```

Earlier attempted template path was wrong for this checkout:

```text
target/linux/generic/image/initramfs-base-files/init
```

That file does not exist in this tree.

## Changes already made

### DTS bootargs

Current diagnostic bootargs include:

```text
rdinit=/bin/sh
```

Purpose:

- Bypass initramfs `/init` for controlled shell tests.
- Keep the system in a diagnostic shell until the `/init` template is patched and tested manually.

Do not remove `rdinit=/bin/sh` until `sh -x /init` proves the patched `/init` path reaches `/sbin/init` or reveals the next exact blocker.

### Kernel config

OpenWrt `.config` contains:

```text
CONFIG_KERNEL_DEVTMPFS=y
CONFIG_KERNEL_DEVTMPFS_MOUNT=y
```

Built kernel config contains:

```text
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_TMPFS=y
```

Purpose:

- Provide devtmpfs support in the initramfs boot.
- Prevent `/dev` setup from being blocked by a missing kernel filesystem.

## Change pending before next boot test

Patch the real `/init` source template:

```text
target/linux/generic/other-files/init
```

Replace:

```sh
DIRS=$(echo *)
```

with:

```sh
DIRS="bin dev etc init lib mnt overlay rom root sbin usr var www"
```

Reason:

- Avoid command substitution and glob expansion during earliest initramfs startup.
- Avoid copying pseudo/runtime dirs such as `proc`, `sys`, and `tmp` into the new root.
- Avoid triggering the observed `sh` SIGSEGV at `DIRS=$(echo *)`.

Recommended patch command:

```sh
cd ~/src/openwrt; STAMP="$(date +%Y-%m-%d-%H%M%S)"; mkdir -p ~/tc7200u-research/records/backups/${STAMP}-generic-init-template-fixed-dirs; cp -a target/linux/generic/other-files/init ~/tc7200u-research/records/backups/${STAMP}-generic-init-template-fixed-dirs/init; python3 -c 'from pathlib import Path; p=Path("target/linux/generic/other-files/init"); s=p.read_text(); s=s.replace("DIRS=$(echo *)", "DIRS=\"bin dev etc init lib mnt overlay rom root sbin usr var www\""); p.write_text(s)'; grep -nE 'DIRS=|NEW_ROOT|cp -pr|switch_root' target/linux/generic/other-files/init
```

Expected result:

```text
6:DIRS="bin dev etc init lib mnt overlay rom root sbin usr var www"
```

Then rebuild and verify generated rootfs:

```sh
cd ~/src/openwrt; make -j"$(nproc)" target/linux/install V=s
```

```sh
cd ~/src/openwrt; grep -nE '^CONFIG_DEVTMPFS=|^CONFIG_DEVTMPFS_MOUNT=|^CONFIG_TMPFS=' build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-*/.config; grep -nE 'DIRS=|NEW_ROOT|cp -pr|switch_root' build_dir/target-mips_mips32_musl/root-bmips/init
```

Expected generated `/init` result:

```text
6:DIRS="bin dev etc init lib mnt overlay rom root sbin usr var www"
```

## Next boot test, after patch and wrap

Wrap fresh:

```sh
cd ~/tc7200u-research; BIN="openwrt-rdinit-fixed-template-devtmpfs-$(date +%Y%m%d-%H%M%S).bin"; echo "$BIN" | tee records/generated/last-console-candidate-bin.txt; RAW=~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin; ./scripts/tcbuilder.sh wrap --source-image "$RAW" --bin-name "$BIN" --fresh-header --load-addr 0x82000000 --control 0x0000
```

Expected wrapper marker:

```text
CHECK OK: size_ok=True
```

Boot exact filename recorded in:

```text
records/generated/last-console-candidate-bin.txt
```

At `~ #`, test one line at a time:

```sh
grep devtmpfs /proc/filesystems || echo NO_DEVTMPFS
```

```sh
grep -nE 'DIRS=|cp -pr|switch_root' /init
```

```sh
sh -x /init
```

Expected conditions before attempting a normal procd boot:

```text
devtmpfs appears in /proc/filesystems
/init contains fixed DIRS list
sh -x /init does not crash at DIRS=...
```

If `sh -x /init` reaches `/sbin/init`, then remove `rdinit=/bin/sh` and build the normal procd candidate.

## Normal procd candidate after diagnostic pass

Only after the patched `/init` path works under `rdinit=/bin/sh`, remove `rdinit`:

```sh
cd ~/src/openwrt; python3 -c 'from pathlib import Path; p=Path("target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts"); s=p.read_text().replace(" rdinit=/bin/sh", ""); p.write_text(s)'; grep -nE 'bootargs|rdinit|init=/bin/sh' target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts
```

Then rebuild, wrap, boot, and gate-check the normal procd path.

Gate E should only be called passing if the same serial log for the exact filename shows:

```text
Run /init as init process
procd: - init -
Please press Enter to activate this console.
```

Do not call a new image “working console” until those exact markers are present for the exact candidate filename.

## Functions and runtime components identified

### OpenWrt initramfs script functions/components

- `/init`: generated from `target/linux/generic/other-files/init`.
- `DIRS=$(echo *)`: current failing command-substitution/glob line.
- `mkdir -p $NEW_ROOT`: creates `/new_root`.
- `mount -t tmpfs tmpfs $NEW_ROOT`: creates tmpfs root target.
- `cp -pr $DIRS $NEW_ROOT`: rootfs copy step; earlier visible crash point, but now considered downstream from `DIRS`.
- `exec switch_root $NEW_ROOT /sbin/init`: final handoff into real OpenWrt init/procd path.

### BusyBox and musl functions seen in fault analysis

- BusyBox `sh` / ash: stable under clean one-line command tests; unstable when executing the original generated `DIRS=$(echo *)` in this environment.
- BusyBox `cp`: stable for simple copy tests; previously crashed while copying the full generated `DIRS` list.
- BusyBox `switch_root`: previously crashed after rootfs copy path; not yet proven with fixed `DIRS` list.
- musl `alloc_slot`: previous allocator trap point at `libc.so+0x35070`.
- musl `__libc_malloc_impl`: previous allocator trap point at `libc.so+0x358a8`.
- musl `strcspn`: later shell fault point at `libc.so+0x8e174`.
- musl `memcpy`: later shell fault point at `libc.so+0x8cfb4`.
- musl `mempcpy`: later shell-related fault context at `libc.so+0x8da9c`.

### Kernel and boot components confirmed

- `bcm63xx_uart` at MMIO `0x14e00500`: confirmed real console path.
- `CONFIG_BCM7120_L2_IRQ=y`: known requirement for UART RX remains part of the console baseline.
- `CONFIG_DEVTMPFS=y`: now present in built kernel config.
- `CONFIG_DEVTMPFS_MOUNT=y`: now present in built kernel config.
- `CONFIG_TMPFS=y`: present and required for `/new_root` tmpfs mount.
- ProgramStore/A825 wrapper path: current low-level boot path is accepted by CFE.
- TFTP/CFE load address: active new branch uses `0x82000000`.

## Structures and reverse-engineering carry-forward

No new Ghidra decompilation result is part of this initramfs-userspace branch yet. The following reverse-engineering state should be preserved for the next Ghidra pass:

### Memory blocks to keep organized in Ghidra

- `RAM_STAGE1_80004000`: loaded stage1/code image.
- `RAM_GLOBALS_81840000`: global objects / scheduler globals.
- `RAM_GLOBALS_81A00000`: thread/signal globals.
- `MMIO_FPM_B2200000`: FPM / packet allocator hardware.
- `MMIO_GENET_B2C00000`: GENET / UniMAC window.
- `MMIO_PERIPH_B4E00000`: clocks, reset, IRQ, UART, GPIO, HSSPI.
- `MMIO_IOP_DQM_B6000000`: DQM / IOP / VENET IPC.

### Stage1 structures to keep in candidate state

Keep structure names with `_candidate` unless the layout is complete and cross-checked:

- `stage1_context_candidate`
- `stage1_thread_record_candidate`
- `stage1_thread_join_condition_candidate`
- `stage1_thread_cleanup_handler_candidate`
- `stage1_thread_create_attr_candidate`
- `stage1_readyq_node_candidate`
- `stage1_readyq_table_candidate`
- `stage1_scheduler_unlock_callback_record_candidate`
- `stage1_bcm_sem_candidate`
- `stage1_condition_object_candidate`
- `stage1_event_wait_condition_candidate`
- `stage1_signal_object_candidate`
- `stage1_signal_ops_or_class_candidate`
- `stage1_signal_select_state_candidate`
- `stage1_post_message_candidate`
- `stage1_post_queue_node_candidate`

### Stage1 functions safe to treat as clear function identities

These are safe to keep without `_candidate` in function names once applied in Ghidra:

- `fn_stage1_scheduler_unlock_or_dispatch_loop_80e976a8`
- `fn_stage1_context_make_runnable_80e96154`
- `fn_stage1_wait_object_wake_all_success_80e98cd0`
- `fn_stage1_current_thread_get_thread_id_or_handle_80ef3840`
- `fn_stage1_current_thread_exit_cleanup_wake_joiners_80ef3860`

Keep `_candidate` for still-provisional signal/wait/hardware functions until caller/callee cleanup confirms exact semantics.

### Ghidra comment style to continue using

Use comments such as:

```c
/* Stage1 scheduler drain / dispatch loop.

   Behavior:
     - selects next runnable context from ready queues
     - clears dispatch-needed state
     - performs context switch path
     - drains pending scheduler callback records

   calls {@symbol fn_stage1_context_make_runnable_80e96154}
   -> {@symbol fn_stage1_current_context_cleanup_mark_dead_80e96428}
*/
```

Use address references such as:

```text
Real behavior is in the drain helper at {@address 80e96cf8}.
```

## Current blocker statement

The immediate blocker before normal procd boot is:

```text
target/linux/generic/other-files/init still contains DIRS=$(echo *)
```

Fix that template, rebuild `target/linux/install`, verify the generated `root-bmips/init` contains the fixed list, wrap the image, and then boot exact filename.

## Files to preserve / add

Recommended new record path:

```text
records/status/2026-06-16-rdinit-initramfs-userspace-diagnostic-log.md
```

Recommended backup path already used or to use:

```text
records/backups/<timestamp>-generic-init-template-fixed-dirs/init
```

Relevant logs to preserve:

```text
records/logs/serial/picocom-20260616-004109.log
records/logs/serial/picocom-20260616-005412.log
records/logs/serial/picocom-20260616-010159.log
records/logs/serial/picocom-20260616-011430.log
records/logs/builds/*check-gates*
records/logs/builds/*wrap*
records/logs/builds/*verify*
```

## Suggested commit message

```text
records: log rdinit initramfs diagnostic
```

## Suggested local commit command

Run after placing this markdown file under `records/status/` and after any related OpenWrt patch snapshots/backups are copied into the research repo:

```sh
cd ~/tc7200u-research; git status --short --branch; git add records/status/2026-06-16-rdinit-initramfs-userspace-diagnostic-log.md records/backups/ records/logs/serial/ records/logs/builds/ records/generated/ patches/; git status --short; git commit -m "records: log rdinit initramfs diagnostic"
```

If `patches/` has unrelated OpenWrt patch snapshots, inspect first and stage only the intended files.

## Next exact action

Patch:

```text
target/linux/generic/other-files/init
```

Then verify generated:

```text
build_dir/target-mips_mips32_musl/root-bmips/init
```

Then wrap:

```text
openwrt-rdinit-fixed-template-devtmpfs-YYYYMMDD-HHMMSS.bin
```

Then boot exact filename and run:

```sh
grep devtmpfs /proc/filesystems || echo NO_DEVTMPFS
```

```sh
grep -nE 'DIRS=|cp -pr|switch_root' /init
```

```sh
sh -x /init
```
