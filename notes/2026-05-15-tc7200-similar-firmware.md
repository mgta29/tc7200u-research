# TC7200 / TC72xx similar firmware findings

Date: 2026-05-15

## Rule

Use stock/similar firmware only as reference material.
Do not blindly flash firmware from another TC7200 variant.
Treat TC7200, TC7200.20, TC7200.U, TC7200.d, TC7210, and TC7230 as variant-risk unless exact board compatibility is proven.

## Useful references

- jclehner/bcm2-utils
  - Has TC7200 profile.
  - Useful for Broadcom cable-modem flash / ProgramStore comparison.
  - URL: https://github.com/jclehner/bcm2-utils

- jclehner/linux-technicolor-tc7200
  - Direct TC7200 Linux-port attempt.
  - Uses Broadcom ProgramStore.
  - Builds linux.sto.
  - Documents UART, USB, NAND, reboot, and dual core as working.
  - Documents SPI, Ethernet, PCIe, and Wi-Fi as not working.
  - URL: https://github.com/jclehner/linux-technicolor-tc7200

- tch-opensrc/TC72XX_LxG1.0.10mp5_OpenSrc
  - Technicolor TC7210/TC7230 Linux-side source drop.
  - Has 3384/93383LxG target context.
  - URL: https://github.com/tch-opensrc/TC72XX_LxG1.0.10mp5_OpenSrc

- tch-opensrc/TC72XX_BFC5.5.10mp1_OpenSrc
  - Technicolor TC7210/TC7230 eCos/BFC-side source drop.
  - Reference only, not a direct OpenWrt target.
  - URL: https://github.com/tch-opensrc/TC72XX_BFC5.5.10mp1_OpenSrc

## Firmware strings to search

Closest TC7200.U / TC7200.20 strings:

- TC7200U-D6.01.12-130329-F-1C1.bin
- TC7200U-D6.01.27-131031-F-1C1.bin
- LNXD6.01.08-kernel-121128.bin
- LNXD6.02.07-kernel-20140224.bin
- STD6.02.11

TC7200 non-U strings:

- TC7200-CF.01.20
- TC7200-CF.01.23-150525-F-1C1
- TC7200-CF0144-eCos_linux-E
- STCE
- STCF

TC7200.d / possible firmware7 clue:

- STED.07.01
- TC7200d-ED.01.02-140911-F

## Current OpenWrt project rule

Always build OpenWrt first.
Always run scripts/tc7200u-wrap-current-openwrt.sh.
Only TFTP /mnt/c/tftp/openwrt-ps-irqfallback.bin after the manifest says size_ok=True.

## Compare from these references

- a825 / ProgramStore header format
- HCS and CRC behaviour
- filename handling inside ProgramStore header
- load address choices: 0x80004000, 0x84010000, current project 0x82000000
- partition offsets and image slots
- CFE TFTP messages and failure cases
- LZMA image detection and decompression target behaviour

## Do not claim from these sources alone

- exact TC7200.U board compatibility
- working Ethernet/Wi-Fi for OpenWrt
- safe flashing between TC7200, TC7200.20, TC7200.U, and TC7200.d
