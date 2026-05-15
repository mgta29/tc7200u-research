# OEM BCM3383 NAND v4 clue

OEM TC72XX source contains BCM3383-specific NAND support:
```text
kernel/linux/drivers/mtd/brcmnand/bcm3383-nand.c
kernel/linux/arch/mips/defconfig.3383Nand
kernel/linux/arch/mips/defconfig.3383TP1Nand
kernel/linux/arch/mips/bcm963xx/bcm93383-platform-devs.c
```

Important clue:
```text
CONFIG_MTD_BRCMNAND=y
CONFIG_BRCMNAND_MAJOR_VERS=4
CONFIG_BRCMNAND_MINOR_VERS=0
```

Current OpenWrt DTS used brcm,brcmnand-v5.0 and probes as bcm6368_nand at 14e02200, then times out on command 0x9.

Next hypothesis: BCM3383 NAND controller should be described/tested as Broadcom NAND controller v4.0, not v5.0.

Safety: evidence only. RAM/TFTP boot only. No flash writes.
