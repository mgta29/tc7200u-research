# TC7200U try5 status: initramfs-none reaches `/init`, then userspace SIGSEGV

Date: 2026-06-15  
Status record name: `2026-06-15-try5-initramfs-none-userspace-sigsegv`  
Source serial log: `records/logs/serial/picocom-20260615-013645.log`

## Scope

This note records the result of the `openwrt-try5.bin` RAM-boot test after moving the new-image console/debug family away from the previous `populate_rootfs` stall.

The test goal was to determine whether forcing both OpenWrt target initramfs compression and kernel initramfs compression to `none` changes the boot failure point.

## Short conclusion

`openwrt-try5.bin` is a real change and a useful result.

The kernel no longer hangs inside `populate_rootfs`. The built-in rootfs unpack path returns successfully, the kernel frees init memory, and Linux starts `/init`.

The new blocker is userspace:

- `/init` runs.
- `cp` segfaults in `libc.so`.
- `switch_root` then segfaults in `libc.so`.
- PID 1 dies and the kernel panics.

Therefore this is no longer a serial-console failure and no longer the previous `populate_rootfs` hang. The next diagnostic should bypass OpenWrt `/init` with `rdinit=/bin/sh` or `rdinit=/bin/ash` to separate shell/libc viability from the OpenWrt init/switch_root path.

## Direct evidence from serial log

```text
Enter filename [tc7200-console-known-good-retest.bin]: openwrt-try5.bin
Starting TFTP of openwrt-try5.bin from 192.168.77.2
Getting openwrt-try5.bin using octet mode
File Length: 7143516 bytes
Load Address: 82000000
[    0.000000] Linux version 6.12.87 (mgta29@CerberusNB) (mips-openwrt-linux-musl-gcc (OpenWrt GCC 14.3.0 r34703-aa96b3ad55) 14.3.0, GNU ld (GNU Binutils) 2.44) #0 SMP Tue May 12 23:59:29 2026
[    0.000000] Kernel command line: console=ttyS0,115200 earlycon ignore_loglevel loglevel=8 initcall_debug clk_ignore_unused pd_ignore_unused initramfs_async=0 init=/bin/sh panic=10
[    0.000000] Initrd not found or empty - disabling initrd
[   17.463718] calling  populate_rootfs+0x0/0x68 @ 1
[   71.560497] initcall populate_rootfs+0x0/0x68 returned 0 after 54087647 usecs
[   76.098729] 14e00500.serial: ttyS0 at MMIO 0x14e00500 (irq = 8, base_baud = 1687500) is a bcm63xx_uart
[   76.115005] printk: legacy console [ttyS0] enabled
[   87.590665] Freeing unused kernel image (initmem) memory: 16116K
[   87.611808] Run /init as init process
[   95.730544] do_page_fault(): sending SIGSEGV to cp for invalid write access to 00000000
[   96.282062] do_page_fault(): sending SIGSEGV to switch_root for invalid write access to 00000000
[   96.323178] Kernel panic - not syncing: Attempted to kill init! exitcode=0x0000000b
[  107.162852] Reboot failed -- System halted
Immediate interpretation

The important transition is:

calling  populate_rootfs
initcall populate_rootfs returned
Freeing unused kernel image
Run /init as init process

That proves the previous rootfs-unpack stop was bypassed in this test family.

The later crash proves the active failure moved into userspace startup:

do_page_fault(): sending SIGSEGV to cp
do_page_fault(): sending SIGSEGV to switch_root
Kernel panic - not syncing: Attempted to kill init
Change log
2026-06-15: created first status note from picocom-20260615-013645.log.
