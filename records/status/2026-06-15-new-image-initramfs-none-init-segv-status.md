# TC7200U manual new-image status: initramfs NONE reaches /init, then SIGSEGV

Date: 2026-06-15

## Scope

This note records the result of the latest manual OpenWrt TC7200U image test using the uploaded serial log:

- source serial log: `picocom-20260615-013645.log`
- intended repository path: `records/status/2026-06-15-new-image-initramfs-none-init-segv-status.md`
- target device: Technicolor TC7200.U / BCM3383
- flow used: fresh OpenWrt image build, manual A825 wrap, then CFE/TFTP RAM boot
- helper policy for this run: no `tcbuild`; manual build/wrap only

Older notes/logs must remain unchanged. This is a new dated status record.

## Short conclusion

The latest `openwrt-try5.bin` result is a major change from the previous `populate_rootfs` hang:

1. CFE/TFTP transport worked.
2. A825 ProgramStore header passed enough for CFE to load and execute the image.
3. Kernel console worked: earlycon and real `ttyS0` both came up on `0x14e00500`.
4. The built-in rootfs path no longer hung at `populate_rootfs`.
5. The kernel reached `Run /init as init process`.
6. Userspace then crashed in `cp` and `switch_root` with SIGSEGV in `libc.so`.
7. Because `switch_root`/`init` died, the kernel panicked with `Attempted to kill init!`.

Therefore, the active blocker moved from "no console" / "rootfs unpack hang" to a userspace init crash after successful rootfs population.

## Image and CFE evidence

The serial log shows CFE requested and loaded the current test filename:

```text
Enter filename [tc7200-console-known-good-retest.bin]: openwrt-try5.bin
```

CFE reported TFTP noise but completed the transfer:

```text
Tftp complete
Received 7143608 bytes
```

ProgramStore/A825 header fields from the boot log:

```text
Signature: a825
Control: 0000
Major Rev: 0100
Minor Rev: 04ff
Build Time: 2026/5/18 20:22:53 Z
File Length: 7143516 bytes
Load Address: 82000000
Filename: openwrt-initramfs.bin
HCS: 79f5
CRC: 00000000
```

Size relationship:

```text
wrapped transfer size = 7143608
payload File Length   = 7143516
header size           = 92
7143516 + 92          = 7143608
```

This is internally consistent with the 92-byte A825 ProgramStore wrapper.

CFE then loaded and executed the payload:

```text
Bypassing CRC Verifiction on Image 4...
Loading non-compressed image 4...
Target Address: 0x82000000
Length: 7143516
Executing Image 4...
```

## Kernel loader and kernel start

The OpenWrt BMIPS loader ran:

```text
OpenWrt kernel loader for BMIPS
Decompressing kernel... done!
blasting from 0x80010000 to 0x0197a977 (0x80010000 - 0x8198a980)
Starting kernel at 80010000...
```

Kernel identity from the log:

```text
Linux version 6.12.87 (mgta29@CerberusNB) (mips-openwrt-linux-musl-gcc (OpenWrt GCC 14.3.0 r34703-aa96b3ad55) 14.3.0, GNU ld (GNU Binutils) 2.44) #0 SMP Tue May 12 23:59:29 2026
MIPS: machine is Technicolor TC7200.U
CPU0 revision is: 0002a080 (Broadcom BMIPS4350)
```

Notable early boot line:

```text
Kernel sections are not in the memory maps
```

This warning existed in the test log and should continue to be tracked, but it did not prevent this image from reaching `/init`.

## Console result

The serial console path worked. This is not a UART bind failure.

Early console:

```text
earlycon: bcm63xx_uart0 at MMIO 0x14e00500 (options '')
printk: legacy bootconsole [bcm63xx_uart0] enabled
```

Real console:

```text
14e00500.serial: ttyS0 at MMIO 0x14e00500 (irq = 8, base_baud = 1687500) is a bcm63xx_uart
printk: legacy console [ttyS0] enabled
```

The earlier failure class `bcm63xx_uart ... failed with error -16` is not present in this log.

## Bootargs and init behavior

Kernel command line from the log:

```text
console=ttyS0,115200 earlycon ignore_loglevel loglevel=8 initcall_debug clk_ignore_unused pd_ignore_unused initramfs_async=0 init=/bin/sh panic=10
```

Important observation:

- despite `init=/bin/sh`, the kernel still ran `/init`:

```text
Run /init as init process
  with arguments:
    /init
  with environment:
    HOME=/
    TERM=linux
```

Interpretation:

- for this initramfs path, `init=/bin/sh` did not bypass OpenWrt `/init`;
- the next bypass test should use `rdinit=/bin/sh` as well, because `rdinit=` is the initramfs-specific override path.

## Initramfs/rootfs result

Previous diagnostic images stopped in or around `populate_rootfs`. This run did not.

Relevant lines:

```text
calling  populate_rootfs+0x0/0x68 @ 1
initcall populate_rootfs+0x0/0x68 returned 0 after 54087647 usecs
```

Result:

- `populate_rootfs` completed successfully;
- rootfs population took about 54.09 seconds;
- this confirms the top-level OpenWrt initramfs compression setting was relevant.

The user-side configuration check before this run showed both layers set to no compression:

```text
.config:CONFIG_TARGET_ROOTFS_INITRAMFS=y
.config:CONFIG_TARGET_INITRAMFS_COMPRESSION_NONE=y
target/linux/bmips/bcm63268/config-6.12:CONFIG_INITRAMFS_COMPRESSION_NONE=y
```

The important state transition is:

```text
before: XZ target initramfs -> hang at populate_rootfs
now:    target + kernel initramfs NONE -> populate_rootfs returns and /init starts
```

## End of kernel initcalls

The log continued past the initramfs stage and completed late initcall cleanup:

```text
initcall clk_disable_unused+0x0/0x128 returned 0 after 7426 usecs
initcall genpd_power_off_unused+0x0/0xb0 returned 0 after 8906 usecs
initcall of_platform_sync_state_init+0x0/0x20 returned 0 after 47 usecs
Freeing unused kernel image (initmem) memory: 16116K
This architecture does not have kernel memory protection.
Run /init as init process
```

This proves the kernel is no longer stuck before userspace.

## Userspace failure

After `/init` started, the log shows userspace faults:

```text
do_page_fault(): sending SIGSEGV to cp for invalid write access to 00000000
epc = 77e45070 in libc.so[35070,77e10000+b9000]
ra  = 77e451d4 in libc.so[351d4,77e10000+b9000]
Segmentation fault
```

Then `switch_root` faulted in `libc.so` too:

```text
do_page_fault(): sending SIGSEGV to switch_root for invalid write access to 00000000
epc = 77d6d8a8 in libc.so[358a8,77d38000+b9000]
ra  = 77d6d718 in libc.so[35718,77d38000+b9000]
```

Final panic:

```text
Kernel panic - not syncing: Attempted to kill init! exitcode=0x0000000b
Rebooting in 10 seconds..
Reboot failed -- System halted
```

Interpretation:

- the immediate failing programs are userspace `cp` and `switch_root`;
- both crash on invalid write access to address `0x00000000`;
- both crashes land inside `libc.so`, not in a kernel driver call trace;
- this looks like a userspace runtime/ABI/rootfs/init-script problem, not a serial driver failure.

## What changed in this pass

### Build/config change

The important configuration correction was at the OpenWrt top-level `.config` layer:

```text
CONFIG_TARGET_INITRAMFS_COMPRESSION_XZ=y      -> removed
CONFIG_TARGET_INITRAMFS_COMPRESSION_NONE=y    -> enabled
```

Kernel target config already had:

```text
CONFIG_INITRAMFS_COMPRESSION_NONE=y
```

Before this correction, the top-level OpenWrt image/rootfs setting still used XZ, even though the kernel config said initramfs compression none. That mismatch explains why changing only `target/linux/bmips/bcm63268/config-6.12` was insufficient.

### Bootargs used

```text
console=ttyS0,115200 earlycon ignore_loglevel loglevel=8 initcall_debug clk_ignore_unused pd_ignore_unused initramfs_async=0 init=/bin/sh panic=10
```

These flags were useful because they proved:

- console still works;
- unused clocks/power domains were not being disabled;
- initcall tracing reached the end;
- `populate_rootfs` returned;
- the remaining panic is after `/init` starts.

### Wrapper/header state

For this run the wrapper was generated from a current A825 preserve source, not from the obsolete helper-template path. The serial log confirms:

- A825 signature valid;
- payload load address preserved as `0x82000000`;
- CFE loaded and executed the image;
- wrapped size matched payload length plus 92-byte header.

## Current status after this log

### Solved/confirmed in this pass

- CFE can load `openwrt-try5.bin`.
- A825 wrapper size/header relationship is correct.
- Kernel decompresses and starts.
- earlycon works at `0x14e00500`.
- real `ttyS0` works at `0x14e00500`.
- `CONFIG_BCM7120_L2_IRQ=y` remains active enough for serial RX/TX path.
- target/kernel initramfs compression NONE lets `populate_rootfs` return.
- kernel reaches `/init`.

### Still failing

- OpenWrt userspace init is not stable.
- `/init` runs and triggers `cp` and `switch_root` SIGSEGVs.
- `init=/bin/sh` did not bypass `/init` in this boot.
- boot ends in `Kernel panic - not syncing: Attempted to kill init!`.
- no `procd`, login prompt, or shell is reached in this run.

## Recommended next tests

### 1. Use `rdinit=/bin/sh` to bypass OpenWrt `/init`

Next bootargs candidate:

```text
console=ttyS0,115200 earlycon ignore_loglevel loglevel=8 initcall_debug clk_ignore_unused pd_ignore_unused initramfs_async=0 rdinit=/bin/sh init=/bin/sh panic=10
```

Purpose:

- verify whether BusyBox `/bin/sh` and musl can run directly;
- separate `/init` script/switch_root logic from base userspace execution;
- if `/bin/sh` also SIGSEGVs, focus on musl/ABI/rootfs/toolchain/kernel-user ABI;
- if `/bin/sh` works, focus on OpenWrt `/init`, `cp`, `switch_root`, and rootfs staging.

### 2. Inspect extracted initramfs contents

After the build, extract/inspect the generated initramfs and compare these files with the known-good family:

```text
/init
/bin/busybox
/lib/libc.so
/sbin/procd
/sbin/switch_root or busybox switch_root applet
/etc/preinit
/lib/preinit/*
```

Record exact hashes of these files.

### 3. Compare known-good and try5 userspace payloads

High-value comparison targets:

```text
file size
raw SHA256
wrapped SHA256
kernel command line
OpenWrt revision string
musl libc hash
busybox hash
/init script hash
package profile differences
```

### 4. Check whether `CONFIG_CMDLINE_FORCE` or init override behavior is involved

Because command line contains `init=/bin/sh` but the kernel still runs `/init`, check:

```text
CONFIG_CMDLINE
CONFIG_CMDLINE_BOOL
CONFIG_CMDLINE_FORCE
CONFIG_INITRAMFS_SOURCE
```

Also test `rdinit=/bin/sh`, because this is the more relevant override for initramfs.

## Practical bottom line

The current image is no longer blocked on serial console or rootfs unpack.

The new blocker is:

```text
initramfs userspace starts, then musl/busybox/OpenWrt init path segfaults during cp/switch_root.
```

Do not spend the next pass on UART, A825 wrapping, or `populate_rootfs` compression unless a new log contradicts this one. The next useful split is `rdinit=/bin/sh` versus normal OpenWrt `/init`.

## Files to preserve

Keep all of these as evidence:

```text
records/logs/serial/picocom-20260615-013645.log
records/generated/<try5 manifest>.json
records/logs/builds/<try5 build/wrap logs>
records/artifacts/test-images/<dated>-openwrt-try5.bin
```

## Suggested git commit

After copying this note into the repository and adding the associated serial/build/generated artifacts:

```sh
cd ~/tc7200u-research; git status --short --branch; git add records/status/2026-06-15-new-image-initramfs-none-init-segv-status.md records/logs/serial/picocom-20260615-013645.log records/generated records/logs/builds records/artifacts/test-images; git commit -m "Record try5 initramfs none boot reaching init segv"
```

Do not push unless explicitly requested.
