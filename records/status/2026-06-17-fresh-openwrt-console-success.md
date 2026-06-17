# 2026-06-17 fresh OpenWrt TC7200U console success

## Confirmed image

`fresh-tc7200u-20260617-224158.bin`

## Build source

Fresh OpenWrt tree at `~/src/openwrt`.

Raw initramfs:

`~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin`

Raw size:

`5.5M`

Wrapper:

Fresh A825 ProgramStore header, load address `0x82000000`, control `0x0000`.

Wrapper verification:

`CHECK OK: size_ok=True`

## Kernel config proof

Built kernel config included:

- `CONFIG_DEVTMPFS=y`
- `CONFIG_DEVTMPFS_MOUNT=y`
- `CONFIG_BCM7120_L2_IRQ=y`
- `CONFIG_TMPFS=y`

## Serial boot proof

CFE requested and loaded the exact file:

`fresh-tc7200u-20260617-224158.bin`

CFE ProgramStore header reported:

- Signature: `a825`
- Control: `0000`
- File Length: `5688320`
- Load Address: `82000000`
- Filename: `fresh-tc7200u-20260617-224158.bin`

Boot reached:

- `Executing Image 4`
- `OpenWrt kernel loader for BMIPS`
- `Linux version 6.12.93`
- `MIPS: machine is Technicolor TC7200.U`
- `earlycon: bcm63xx_uart0 at MMIO 0x14e00500`
- `Kernel command line: console=ttyS0,115200 earlycon`
- `irq_bcm7120_l2: registered BCM3380 L2 intc`
- `14e00500.serial: ttyS0 at MMIO 0x14e00500`
- `Run /init as init process`
- `init: Console is alive`
- `procd: - init -`
- `Please press Enter to activate this console.`
- `root@OpenWrt:~#`

## Result

This is the first confirmed fresh-tree, fresh-wrapper, full userspace console boot for the TC7200U path.

## Remaining issue

NAND still does not probe:

- `bcm6368_nand 14e02200.nand: timeout waiting for command 0x9`
- `nand: No NAND device found`

This does not block initramfs console and should be tracked separately.
