# TC7200.U research finding: Ethernet is likely BCM3383 GENET, not bcm6368-enetsw

Date: 2026-05-15
Scope: research only. Do not flash.

## Source inspected

Repository:

- jclehner/linux-technicolor-tc7200

Branch:

- tc7200_v4.11-rc1

## Important finding

The TC7200 Linux source maps 14e01000 as SPI/HSSPI, not Ethernet.

In arch/mips/boot/dts/brcm/bcm3383.dtsi:

- spi@14e01000 uses compatible brcm,bcm6328-hsspi
- ethernet@12c00000 uses compatible brcm,genet-v1

The Ethernet node uses:

- reg 0x12c00000 size 0x4000
- interrupts 16 and 17 via periph_intc
- phy-mode internal
- phy-handle phy0
- embedded GENET MDIO at offset 0x600
- hardcoded MAC 00:10:95:de:ad:07

## GMAC init finding

arch/mips/bmips/setup.c contains bcm3383_init_gmac().

It performs:

- clear soft_resetb_low bits 6 and 8
- set clk_ctrl_low bit 6
- set clk_ctrl_high bit 8
- delay 200 ms
- set soft_resetb_low bits 6 and 8

The same source also calls bcm3383_pinmux_select(10) before bcm3383_init_gmac().

## Interpretation

The previous OpenWrt bcm6368-enetsw node at 14e01000 likely targeted the wrong hardware block. It could bind and create eth0, but packet I/O never completed because 14e01000 is not the TC7200 Ethernet MAC in the matching source tree.

This explains the exhausted negative matrix:

- original bcm6368-enetsw: no packet I/O
- DMA swap only: no improvement
- interrupt swap only: no improvement
- combined DMA and interrupt swap: no improvement

## New direction

Stop testing bcm6368-enetsw on 14e01000.

Next technical direction:

1. Check whether OpenWrt kernel has BCMGENET support available.
2. Replace the temporary 14e01000 enetsw node with a BCM3383 GENET node at 12c00000.
3. Add or port the minimal BCM3383 GMAC clock/reset init before testing.
4. RAM boot only. Do not flash.
