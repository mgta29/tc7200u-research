# TC72XX OEM BCM3383 NAND source found

OEM source tree checked: ~/src/tc72xx-oem-lxg1

Important hits:
```text
./targets/93383LxGNand
./targets/93383LxGTP1Nand
./kernel/linux/arch/mips/defconfig.3383Nand
./kernel/linux/arch/mips/defconfig.3383TP1Nand
./kernel/linux/arch/mips/bcm963xx/bcm93383-platform-devs.c
./kernel/linux/drivers/mtd/brcmnand/bcm3383-nand.c
./kernel/linux/drivers/mtd/brcmnand/bcm63xx-nand.c
```

Why this matters:
- The OpenWrt NAND node currently probes as bcm6368_nand at 14e02200 and times out.
- OEM source contains a BCM3383-specific NAND driver path.
- Next step should compare OpenWrt DTS/driver assumptions against OEM bcm3383-nand.c and bcm93383 platform device setup.

Safety: evidence only. Do not flash OEM firmware.
