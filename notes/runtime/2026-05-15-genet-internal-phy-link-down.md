# TC7200.U runtime result: GENET probes, internal PHY invalid/link down

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

## Test

First BCM3383 GENET test using:

- compatible: brcm,genet-v1
- reg: 0x12c00000 size 0x4000
- interrupts: 16, 17
- phy-mode: internal
- UniMAC MDIO child at offset 0x600
- PHY address 0

## Result

Boot reached userspace and shell.

Important boot lines:

- bcmgenet 12c00000.ethernet: GENET 1.0 EPHY: 0x0000
- bcmgenet: Invalid GPHY revision detected: 0x0000
- unimac-mdio unimac-mdio.-19: Broadcom UniMAC MDIO bus
- bcmgenet 12c00000.ethernet: configuring instance for internal PHY
- bcmgenet 12c00000.ethernet eth0: Link is Down

Runtime:

- eth0 exists
- MAC address is 86:8a:92:10:80:4b
- /proc/iomem shows 12c00000-12c03fff assigned to ethernet@12c00000
- /proc/iomem shows unimac-mdio region inside GENET
- /proc/interrupts does not show eth0 IRQ lines
- ERR counter is high
- ip link set eth0 up keeps link down
- ping produces no TX packets because carrier/link is down

## Interpretation

GENET is the correct MAC path. The old bcm6368-enetsw node at 14e01000 was wrong for Ethernet.

The current failure is PHY/switch/link configuration, not basic MAC discovery.

The internal PHY mode appears wrong or incomplete on this board. CFE previously detected a BCM53125 switch, so the next diagnostic should use GENET with RGMII/fixed-link and no internal PHY, then later add proper BCM53125/B53 switch description.

## Next test

Replace internal PHY/MDIO with a fixed-link RGMII diagnostic node:

- phy-mode = rgmii
- no phy-handle
- no mdio child
- fixed-link speed 1000 full-duplex

Purpose: prove whether GENET can start TX/DMA/IRQs when Linux is not blocked by the invalid internal PHY.
