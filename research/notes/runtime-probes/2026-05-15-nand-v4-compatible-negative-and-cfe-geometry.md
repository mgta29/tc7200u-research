# NAND v4 compatible negative result and CFE geometry clue

## Test

DTS test image used:

- compatible: brcm,nand-bcm6368 + brcm,brcmnand-v4.0 + brcm,brcmnand
- interrupt-parent: periph_intc

The image booted successfully over RAM/TFTP.

## CFE evidence

CFE reported:

```text
BCM3383A2
MemSize: 128 M
Chip ID: BCM3383Z-B0
SPI flash ID 0xc22014, size 1MB, block size 64KB, write buffer 256
NAND flash: Device size 64 MB, Block size 16 KB, Page size 512 B
Switch detected: 53125
ProbePhy: Found PHY 0, MDIO on MAC 0, data on MAC 0
Using GMAC0, phy 0
OpenWrt result
brcm,nand-bcm6368
brcm,brcmnand-v4.0
brcm,brcmnand

bcm6368_nand 14e02200.nand: timeout waiting for command 0x9
bcm6368_nand 14e02200.nand: intfc status c0000000
nand: No NAND device found

cat /proc/mtd
dev:    size   erasesize  name
Conclusion

Changing the compatible string from brcm,brcmnand-v5.0 to brcm,brcmnand-v4.0 does not solve NAND detection.

The CFE geometry is now the strongest known NAND clue for this specific unit:

64 MiB total
16 KiB erase block
512 B page

This differs from the TC72XX OEM Makefile NAND image geometry observed earlier as 128 KiB block and 2048 B page.

Next NAND direction should compare OpenWrt small-page NAND handling, controller CS setup, and BCM3383 register initialization against CFE/OEM behavior.

Safety: RAM/TFTP only. No flash writes.
