# TC7200.U similar source: jclehner/tc7200 README findings

Date: 2026-05-15
Scope: research only. Do not flash.

## Repository

Repository inspected:

- https://github.com/jclehner/tc7200

The repository contains README notes, not source code or firmware binaries.

## Useful findings

The README is directly about Technicolor TC7200.20 / TC7200.U and reports:

- Broadcom BCM3383A2
- 1 MB SPI flash
- 64 MB NAND flash
- Broadcom ProgramStore image format
- CFE partition map
- firmware dump method using bcm2dump
- image1/image2 are cable modem firmware images
- linux/linuxkfs/linuxapps are separate Linux-side images
- eCos console has useful commands
- eCos has multiple IP stacks, including IP7 virtual ethernet
- port passthrough settings exist under /non-vol/thomsonBfc

## Not found

The README does not provide:

- Ethernet register addresses
- MDIO register addresses
- BCM53125/B53 switch init
- Linux DTS
- TC7200 Ethernet driver source

## Interpretation

The README is useful for partition layout, vendor/eCos console direction, and firmware dumping.

It does not directly solve OpenWrt Ethernet.

Next source target is jclehner/linux-technicolor-tc7200, especially branch differences from origin/master.
