# 2026-06-17 fresh OpenWrt TC7200U console success

## Confirmed image

`fresh-tc7200u-20260617-224158.bin`

## Result

Fresh OpenWrt tree + fresh raw initramfs + fresh A825 ProgramStore wrapper booted successfully to interactive OpenWrt userspace console on Technicolor TC7200U.

## Build proof

Raw image:

`~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin`

Raw size:

`5.5M`

Wrapper output:

`C:\tftp\fresh-tc7200u-20260617-224158.bin`

Wrapper verification:

`CHECK OK: size_ok=True`

## Kernel config proof

Built kernel config confirmed:

- `CONFIG_DEVTMPFS=y`
- `CONFIG_DEVTMPFS_MOUNT=y`
- `CONFIG_BCM7120_L2_IRQ=y`
- `CONFIG_TMPFS=y`

## Runtime proof

Device shell output confirmed:

- `/proc/cmdline`: `console=ttyS0,115200 earlycon`
- `uname -a`: `Linux OpenWrt 6.12.93 #0 SMP Tue Jun 16 18:36:39 2026 mips GNU/Linux`
- `earlycon: bcm63xx_uart0 at MMIO 0x14e00500`
- `Kernel command line: console=ttyS0,115200 earlycon`
- `irq_bcm7120_l2: registered BCM3380 L2 intc`
- `14e00500.serial: ttyS0 at MMIO 0x14e00500`
- `Run /init as init process`
- `kmodloader: done loading kernel modules from /etc/modules-boot.d/*`
- `procd: - early -`
- `procd: - ubus -`
- `procd: - init -`
- `kmodloader: done loading kernel modules from /etc/modules.d/*`

## Mount proof

Root filesystem is initramfs/tmpfs:

- `tmpfs on / type tmpfs`
- `proc on /proc`
- `sysfs on /sys`
- `tmpfs on /tmp`
- `tmpfs on /dev`

## Current limitations

`ip link` only shows loopback:

- Ethernet/GENET/GMAC is not active in this fresh baseline.

NAND still fails:

- `bcm6368_nand 14e02200.nand: timeout waiting for command 0x9`
- `nand: No NAND device found`

Serial input overrun warnings appeared during pasted commands, but they did not affect boot success.
