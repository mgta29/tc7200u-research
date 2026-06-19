# 2026-06-16 initramfs corruption diagnostic log

## Scope

This record captures the TC7200.U / BCM3383 OpenWrt initramfs/userspace console-recovery work completed after the earlier `rdinit=/bin/sh` shell proof. It stops at the point where the OpenWrt tree has been configured for an uncompressed initramfs and the generated diagnostic `/init` has been verified, but the uncompressed image has not yet been wrapped and booted.

This phase is **not Ethernet** and **not Ghidra decompilation**. It is the userspace/initramfs path that must work before the new ProgramStore-wrapped image can be called a real console-capable candidate.

## Repository and evidence rules used

- Local research repo: `~/tc7200u-research`.
- Local OpenWrt tree: `~/src/openwrt`.
- Current records belong under `records/`, especially `records/status/`, `records/logs/serial/`, `records/logs/builds/`, `records/generated/`, and `records/backups/`.
- Do **not** add new records under `records/notes/`; that is a wrong legacy path.
- Do **not** delete old logs or markdown files.
- For this branch, do **not** use `--preserve-from`; the branch is testing a fresh new raw OpenWrt initramfs wrapped with a fresh A825/ProgramStore header.
- Do **not** call a new image “working console” unless the exact serial log for the exact candidate filename proves: filename, load/file identity, `/init`, `procd: - init -`, `Please press Enter to activate this console.`, and usable root/login prompt.

## Current top-level conclusion

The investigation has moved past UART, CFE wrapping, `rdinit=/bin/sh`, `devtmpfs`, and module-autoload as the primary blocker. The current blocker is **localized corruption of at least one live initramfs file after boot/unpack**:

```text
/usr/share/libubox/jshn.sh
```

The same file is valid in the WSL build root, but corrupt in the live booted initramfs. Other nearby files and key ELF binaries are valid in the live image, so this is not a general userspace failure.

Current best next test:

```text
Boot an uncompressed initramfs candidate and check whether /usr/share/libubox/jshn.sh starts with valid text instead of 00 00 00 01...
```

## Known-good/positive path proven in this phase

The new image family has already proven:

- A825/ProgramStore wrapping can be accepted by CFE.
- TFTP load can complete for exact short filenames.
- CFE executes Image 4.
- Linux boots.
- earlycon and real `ttyS0` work.
- `rdinit=/bin/sh` reaches BusyBox shell.
- `devtmpfs` is now present when `/proc` is mounted.
- Direct `/sbin/init` execution from a patched diagnostic `/init` reaches OpenWrt `preinit` after module autoload is disabled.

Still not proven:

- Full `/init` as PID 1 without `rdinit=/bin/sh`.
- `procd: - init -`.
- `Please press Enter to activate this console.`
- Root/login prompt on `ttyS0` for a new candidate filename.

## Chronology and evidence

### 1. Devtmpfs was missing, then fixed

Initial kernel config grep showed only:

```text
CONFIG_TMPFS=y
```

Absent at that point:

```text
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
```

The OpenWrt `.config` was then edited to include:

```text
CONFIG_KERNEL_DEVTMPFS=y
CONFIG_KERNEL_DEVTMPFS_MOUNT=y
```

Built kernel config later verified:

```text
1131:CONFIG_DEVTMPFS=y
1132:CONFIG_DEVTMPFS_MOUNT=y
3363:CONFIG_TMPFS=y
```

A live shell check initially printed `NO_DEVTMPFS` only because `/proc` was not mounted. After mounting `/proc`, the device showed:

```text
nodev   devtmpfs
```

Conclusion: `devtmpfs` is now enabled and available.

### 2. Real OpenWrt initramfs `/init` template found

The generated rootfs `/init` was overwritten by `target/linux/install`. A broad grep over `build_dir`/`staging_dir` froze, so the search was narrowed.

The real template was located at:

```text
target/linux/generic/other-files/init
```

The original template contained:

```sh
DIRS=$(echo *)
NEW_ROOT=/new_root
mkdir -p $NEW_ROOT
mount -t tmpfs tmpfs $NEW_ROOT
cp -pr $DIRS $NEW_ROOT
exec switch_root $NEW_ROOT /sbin/init
```

The generated rootfs kept reverting until this template was patched.

### 3. `DIRS=$(echo *)` was proven unsafe on this target

Running the original line manually in the live `rdinit=/bin/sh` shell caused a shell SIGSEGV:

```text
~ # DIRS=$(echo *)
do_page_fault(): sending SIGSEGV to sh for invalid read access from 00000000
epc = ... libc.so+0x7f378
ra  = ... libc.so+0x7f36c
Segmentation fault
```

The template was patched to a fixed directory list:

```sh
DIRS="bin dev etc init lib mnt overlay rom root sbin usr var www"
```

Generated `/init` then verified as:

```text
6:DIRS="bin dev etc init lib mnt overlay rom root sbin usr var www"
12:cp -pr $DIRS $NEW_ROOT
14:exec switch_root $NEW_ROOT /sbin/init
```

Conclusion: the glob/command-substitution bug was real, but not the final blocker.

### 4. `cp -pr` still failed after fixed `DIRS`

With the fixed-list `/init`, running `sh -x /init` still failed at the full-root copy step:

```text
+ cp -pr bin dev etc init lib mnt overlay rom root sbin usr var www /new_root
do_page_fault(): sending SIGSEGV to cp for invalid write access to 00000000
epc = libc.so+0x35070
ra  = libc.so+0x351d4
Segmentation fault
```

Individual tests showed:

```text
cp -pr bin -> OK
cp -pr lib -> SIGSEGV, RC=139
cp -pr etc -> SIGSEGV, RC=139
```

Then `cp -r` was tested:

```text
cp -r lib /tmp/cptest/lib -> OK
cp -r etc /tmp/cptest/etc -> OK
cp -r bin etc init lib mnt overlay rom root sbin usr var www /new_root -> Bus error, RC=138
```

One-by-one copy into mounted `/new_root` still failed on `etc` after `bin`:

```text
cp -r bin /new_root/bin -> OK
cp -r etc /new_root/etc -> SIGSEGV, libc.so+0x35070
```

Conclusion: the initramfs-to-new-root copy/switch-root shim itself is unsafe on this boot path. It is not just the fixed-list/glob bug.

### 5. Direct-procd/no-copy `/init` bypass was introduced

To test `procd` without the broken `cp`/`switch_root` shim, the template was rewritten to execute `/sbin/init` directly from the current initramfs root:

```sh
#!/bin/sh
export INITRAMFS=1

mkdir -p /proc /sys /dev /tmp
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null
exec /sbin/init
```

A diagnostic image was booted:

```text
openwrt-rdinit-direct-procd-no-copy-20260616-023331.bin
File Length: 7141964 bytes
Load Address: 82000000
HCS: 851a
```

The patched `/init` was present and `sh -x /init` reached:

```text
+ exec /sbin/init
kmodloader: loading kernel modules from /etc/modules-boot.d/*
```

Conclusion: direct `/sbin/init` execution works far enough to reach OpenWrt boot logic.

### 6. Module autoload caused a kernel panic, then was bypassed

The direct-procd/no-copy image initially panicked inside module loading:

```text
CPU: 0 UID: 0 PID: 213 Comm: kmodloader
epc: free_percpu+0xb8/0x4c0
Call Trace:
free_percpu
load_module
sys_init_module
syscall_common
Kernel panic - not syncing: Fatal exception
```

Modules observed before/around the crash included:

```text
crc32c_generic
air_en8811h
usb_common
usbcore
gpio_button_hotplug
```

Unresolved-symbol spam pointed toward USB/XHCI/debugfs-related modules.

`/etc/modules-boot.d` and `/etc/modules.d` were then disabled by a diagnostic `/init` patch. The first version moved module files one by one. Later this was simplified to dir-level disabling:

```sh
mv /etc/modules-boot.d /etc/modules-boot.d.disabled 2>/dev/null
mkdir -p /etc/modules-boot.d
mv /etc/modules.d /etc/modules.d.disabled 2>/dev/null
mkdir -p /etc/modules.d
```

With modules disabled, `/sbin/init` progressed beyond kmodloader:

```text
kmodloader: loading kernel modules from /etc/modules-boot.d/*
kmodloader: done loading kernel modules from /etc/modules-boot.d/*
init: - preinit -
```

Conclusion: module autoload was a real secondary blocker, but not the final blocker.

### 7. New blocker: `jshn.sh` parse failure in preinit

Once preinit was reached, the next failure was:

```text
/etc/preinit: /usr/share/libubox/jshn.sh: line 1: syntax error: unexpected ")"
```

The WSL build-root file was checked:

```text
build_dir/target-mips_mips32_musl/root-bmips/usr/share/libubox/jshn.sh: ASCII text
```

First bytes in WSL build root:

```text
23 20 66 75 6e 63 74 69 6f 6e 73 20 66 6f 72 20
# functions for
```

So the build-root source file is valid.

### 8. Runtime `jshn.sh` dump proved live initramfs corruption

A diagnostic `/init` was added to print `jshn.sh` information before `/sbin/init`:

```sh
echo INIT_DIAG_JSHN_BEGIN
ls -l /usr/share/libubox/jshn.sh 2>&1
sed -n "1,8p" /usr/share/libubox/jshn.sh 2>&1
od -An -tx1 -N96 /usr/share/libubox/jshn.sh 2>&1
/bin/sh -n /usr/share/libubox/jshn.sh 2>&1; echo JSHN_SH_N_RC=$?
echo INIT_DIAG_JSHN_END
```

The first attempted long filename failed wrapper validation:

```text
filename too long for 64-byte CFE field
```

This confirmed the A825/CFE filename field limit is enforced by the wrapper helper.

A shorter name was used later. Runtime evidence showed `jshn.sh` present with the correct size, but content was corrupt:

```text
-rw-r--r--    1 root     root          7569 Jan  1 00:01 /usr/share/libubox/jshn.sh
```

Runtime `sed` output printed blank/control content, and syntax check failed:

```text
/bin/sh -n /usr/share/libubox/jshn.sh
/usr/share/libubox/jshn.sh: line 1: syntax error: unexpected word (expecting ")")
JSHN_SH_N_RC=2
```

The direct hexdump in live shell proved the corruption:

```text
00000000  00 00 00 01 00 00 00 01  00 00 00 01 00 00 00 00  |................|
00000010  00 00 40 00 00 00 00 00  00 00 00 00 00 00 1e 00  |..@.............|
*
00000080
```

### 9. Corruption appears localized, not general

Live hexdumps for nearby files and core binaries were good:

```text
/etc/preinit                OK text, starts #!/bin/sh
/lib/functions.sh           OK text
/lib/functions/preinit.sh   OK text
/etc/inittab                OK text
/sbin/init                  OK ELF
/usr/bin/jshn               OK ELF
/bin/busybox                OK ELF
/lib/libc.so                OK ELF
```

Only observed bad file so far:

```text
/usr/share/libubox/jshn.sh  BAD, starts 00 00 00 01...
```

Conclusion: this is not a general shell or filesystem failure. It is at least one localized wrong/corrupt file in the live initramfs view.

### 10. Uncompressed initramfs test has been configured but not booted

OpenWrt `.config` was changed to disable initramfs compression:

```text
123:CONFIG_TARGET_INITRAMFS_COMPRESSION_NONE=y
124:# CONFIG_TARGET_INITRAMFS_COMPRESSION_GZIP is not set
125:# CONFIG_TARGET_INITRAMFS_COMPRESSION_BZIP2 is not set
126:# CONFIG_TARGET_INITRAMFS_COMPRESSION_LZMA is not set
127:# CONFIG_TARGET_INITRAMFS_COMPRESSION_LZO is not set
128:# CONFIG_TARGET_INITRAMFS_COMPRESSION_LZ4 is not set
129:# CONFIG_TARGET_INITRAMFS_COMPRESSION_XZ is not set
130:# CONFIG_TARGET_INITRAMFS_COMPRESSION_ZSTD is not set
```

After rebuild, generated diagnostic `/init` was still present:

```text
5:mount -t proc proc /proc 2>/dev/null
6:mount -t sysfs sysfs /sys 2>/dev/null
7:mount -t devtmpfs devtmpfs /dev 2>/dev/null
9:echo INIT_DIAG_JSHN_BEGIN
10:ls -l /usr/share/libubox/jshn.sh 2>&1
11:sed -n "1,8p" /usr/share/libubox/jshn.sh 2>&1
12:od -An -tx1 -N96 /usr/share/libubox/jshn.sh 2>&1
13:/bin/sh -n /usr/share/libubox/jshn.sh 2>&1; echo JSHN_SH_N_RC=$?
14:echo INIT_DIAG_JSHN_END
16:mv /etc/modules-boot.d /etc/modules-boot.d.disabled 2>/dev/null
17:mkdir -p /etc/modules-boot.d
18:mv /etc/modules.d /etc/modules.d.disabled 2>/dev/null
19:mkdir -p /etc/modules.d
21:exec /sbin/init
```

Stop point: uncompressed candidate still needs wrapping and booting.

## Files and components changed

### OpenWrt `.config`

Added/verified:

```text
CONFIG_KERNEL_DEVTMPFS=y
CONFIG_KERNEL_DEVTMPFS_MOUNT=y
CONFIG_TARGET_INITRAMFS_COMPRESSION_NONE=y
```

Disabled compression choices:

```text
CONFIG_TARGET_INITRAMFS_COMPRESSION_GZIP
CONFIG_TARGET_INITRAMFS_COMPRESSION_BZIP2
CONFIG_TARGET_INITRAMFS_COMPRESSION_LZMA
CONFIG_TARGET_INITRAMFS_COMPRESSION_LZO
CONFIG_TARGET_INITRAMFS_COMPRESSION_LZ4
CONFIG_TARGET_INITRAMFS_COMPRESSION_XZ
CONFIG_TARGET_INITRAMFS_COMPRESSION_ZSTD
```

### OpenWrt initramfs template

Changed file:

```text
target/linux/generic/other-files/init
```

Current diagnostic shape:

```sh
#!/bin/sh
export INITRAMFS=1

mkdir -p /proc /sys /dev /tmp
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo INIT_DIAG_JSHN_BEGIN
ls -l /usr/share/libubox/jshn.sh 2>&1
sed -n "1,8p" /usr/share/libubox/jshn.sh 2>&1
od -An -tx1 -N96 /usr/share/libubox/jshn.sh 2>&1
/bin/sh -n /usr/share/libubox/jshn.sh 2>&1; echo JSHN_SH_N_RC=$?
echo INIT_DIAG_JSHN_END

mv /etc/modules-boot.d /etc/modules-boot.d.disabled 2>/dev/null
mkdir -p /etc/modules-boot.d
mv /etc/modules.d /etc/modules.d.disabled 2>/dev/null
mkdir -p /etc/modules.d

exec /sbin/init
```

Note: `od` was not present in the live BusyBox image, so the live shell fallback used `hexdump -C` manually. The template can still keep `od` for now, but `hexdump` is more useful on this image.

### Research repo backup paths created

Backups were created under timestamped `records/backups/` directories before template edits, including variants for:

- fixed `DIRS` list,
- direct-procd/no-copy,
- disabling boot modules,
- disabling all modules,
- `jshn.sh` dump diagnostics.

Do not delete these; they are useful for reconstruction and commit evidence.

## Functions, scripts, and runtime paths of interest

No Ghidra function labels or datatypes were changed in this phase. The relevant “functions” here are shell/runtime components:

| Component | Role | Result |
|---|---|---|
| `target/linux/generic/other-files/init` | Source template for initramfs `/init` | Patched repeatedly for diagnostics |
| `/init` | First userspace script in initramfs | Current version mounts proc/sys/devtmpfs, dumps `jshn.sh`, disables module dirs, execs `/sbin/init` |
| `/sbin/init` | OpenWrt/procd init binary | Executes and reaches preinit with module autoload disabled |
| `kmodloader` | Loads modules from `/etc/modules-boot.d` and `/etc/modules.d` | Previously panicked in `free_percpu`; bypassed by disabling module dirs |
| `/etc/preinit` | OpenWrt preinit shell script | Valid text, syntax check passes |
| `/usr/share/libubox/jshn.sh` | Shell library sourced by preinit scripts | Valid in WSL build root, corrupt in live initramfs |
| `/usr/bin/jshn` | ELF helper binary | Live ELF header looks valid |
| BusyBox `cp` | Used by generic initramfs copy shim | `cp -pr` and full-tree `cp -r` trigger SIGSEGV/SIGBUS on this path |
| musl `libc.so+0x35070` | Allocator trap location | Seen repeatedly in `cp` failures |
| kernel `free_percpu` | Module-load panic site | Seen during kmodloader before modules were disabled |

## A825 / CFE wrapper notes from this phase

Canonical tested load address remains:

```text
0x82000000
```

The helper enforces the CFE filename field limit:

```text
filename too long for 64-byte CFE field
```

Use short candidate names for future tests, for example:

```text
rdjshn-nomod-nocmp-YYYYMMDD-HHMMSS.bin
```

Required success marker from wrapper remains:

```text
CHECK OK: size_ok=True
```

## Current exact stop state

OpenWrt `.config` is set for uncompressed initramfs.

Generated rootfs `/init` still has the `jshn.sh` diagnostic and module-dir-disabling logic.

Next step is to wrap and boot the uncompressed raw initramfs:

```sh
cd ~/tc7200u-research; BIN="rdjshn-nomod-nocmp-$(date +%Y%m%d-%H%M%S).bin"; echo "$BIN" | tee records/generated/last-console-candidate-bin.txt; RAW=~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin; ./scripts/tcbuilder.sh wrap --source-image "$RAW" --bin-name "$BIN" --fresh-header --load-addr 0x82000000 --control 0x0000
```

At the live shell, check first bytes:

```sh
mount -t proc proc /proc
```

```sh
mount -t sysfs sysfs /sys
```

```sh
mount -t devtmpfs devtmpfs /dev
```

```sh
hexdump -C -n 128 /usr/share/libubox/jshn.sh
```

Good expected first bytes:

```text
00000000  23 20 66 75 6e 63 74 69  6f 6e 73 20 66 6f 72 20
```

Bad repeated corruption:

```text
00000000  00 00 00 01 00 00 00 01  00 00 00 01 00 00 00 00
```

Then run:

```sh
sh -x /init
```

## Next branch decisions

### If uncompressed initramfs fixes `jshn.sh`

Then the likely root cause is:

```text
compressed initramfs unpack/decompression corruption on this BCM3383 boot path
```

Continue with uncompressed initramfs and try the no-modules direct-procd path through preinit again. If it reaches `Please press Enter to activate this console.`, then build a real candidate without `rdinit=/bin/sh`.

### If uncompressed initramfs still corrupts `jshn.sh`

Then the next suspect is memory placement / load-address overlap, not compression alone.

Test alternate load address after the uncompressed result:

```sh
cd ~/tc7200u-research; BIN="rdjshn-nomod-8280-$(date +%Y%m%d-%H%M%S).bin"; echo "$BIN" | tee records/generated/last-console-candidate-bin.txt; RAW=~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin; ./scripts/tcbuilder.sh wrap --source-image "$RAW" --bin-name "$BIN" --fresh-header --load-addr 0x82800000 --control 0x0000
```

Only test `0x82800000` after the uncompressed result so variables remain isolated.

## Git commit recommendation

Suggested local commit message:

```text
records: log initramfs corruption diagnostic
```

Suggested files to include:

- this status report under `records/status/`,
- new `records/backups/` created during the `/init` template edits,
- relevant `records/logs/builds/` wrap/build logs,
- relevant `records/generated/` last-candidate state files,
- relevant `records/logs/serial/` picocom logs if they were copied into the repo.

Do not push unless explicitly requested.
