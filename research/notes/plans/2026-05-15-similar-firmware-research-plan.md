# TC7200.U similar firmware/source research plan

Date: 2026-05-15
Scope: research only. Do not flash.

## Reason

The bcm6368-enetsw RX/TX DMA and IRQ order matrix is exhausted.

Tested:
- original IRQ/DMA: boots, eth0 exists, no packet I/O
- DMA swap only: boots, no improvement
- interrupt swap only: boots, no improvement
- combined DMA + interrupt swap: boots, no improvement
- minimal AMAC: bgmac probes, then hangs before userspace

Next work should stop guessing DMA/IRQ order and inspect similar TC7200/TC72xx firmware or source for board-specific Ethernet, switch, MDIO, and register hints.

## Public leads

GitHub repositories:
- jclehner/tc7200
- jclehner/linux-technicolor-tc7200

The jclehner/tc7200 README is directly about Technicolor TC7200.20 / TC7200.U and reports:
- Broadcom BCM3383A2
- 1 MB SPI flash
- 64 MB NAND flash
- Broadcom ProgramStore image format
- CFE partition map
- firmware dump method using bcm2dump

This aligns with our local TC7200.U evidence:
- BCM3383-class platform
- NAND512W3A2SN6E-family flash
- PKE1331 family board
- 4-port Gigabit LAN hardware

## Commands

Clone and inspect Linux source:

cd ~/src; git clone https://github.com/jclehner/linux-technicolor-tc7200.git
cd ~/src/linux-technicolor-tc7200; git branch -a
cd ~/src/linux-technicolor-tc7200; grep -RniE 'BCM3383|TC7200|14e01000|14e0|enet|ether|mdio|mii|switch|b53|53125|robosw|rgmii|gmac|amac|ephy|phy' . | head -200

Clone and inspect TC7200 notes:

cd ~/src; git clone https://github.com/jclehner/tc7200.git
cd ~/src/tc7200; find . -maxdepth 3 -type f -print
cd ~/src/tc7200; grep -RniE 'partition|image1|image2|linux|linuxkfs|ProgramStore|bcm2dump|BCM3383|ether|switch|mdio|mii|console|serial' . | head -200

## Search targets

Look for:
- Ethernet base addresses
- switch base addresses
- MDIO register addresses
- BCM53125 / RoboSwitch init
- GMAC / AMAC init
- interrupt numbers
- DMA channel numbers
- board partition map
- vendor Linux kernel config
- vendor bootargs
- hardcoded MAC source
- flash dump / ProgramStore handling

## Rule

Do not flash vendor firmware or modified vendor images.

Use firmware/source only for reverse-engineering board information.
