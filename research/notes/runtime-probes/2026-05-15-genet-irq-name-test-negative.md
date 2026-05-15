# TC7200.U runtime result: GENET interrupt-name test negative

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

## Test

GENET fixed-link RGMII diagnostic with corrected interrupt names:

- MAC: `ethernet@12c00000`
- compatible: `brcm,genet-v1`
- interrupts: `<16>, <17>`
- interrupt-names: `"enet", "enet-wol"`
- `phy-mode = "rgmii"`
- fixed-link 1000/full
- no `phy-handle`
- no `mdio@600`
- no B53/DSA switch node

## Result

Boot reaches OpenWrt shell.

GENET still reports:


bcmgenet 12c00000.ethernet: GENET 1.0 EPHY: 0x0000
bcmgenet: Invalid GPHY revision detected: 0x0000
bcmgenet 12c00000.ethernet: unable to find MDIO bus node
bcmgenet 12c00000.ethernet: configuring instance for external RGMII (no delay)
bcmgenet 12c00000.ethernet eth0: Link is Up - 1Gbps/Full - flow control off
bcmgenet 12c00000.ethernet eth0: NETDEV WATCHDOG: transmit queue 0 timed out

Manual test:

ip link set eth0 up
ping -I eth0 -c 2 -W 1 192.168.77.2

Ping result:

2 packets transmitted, 0 packets received, 100% packet loss

Interrupts before and after ping:

16:          0  periph_intc@14e00048  16  eth0
17:          0  periph_intc@14e00048  17  eth0
Interpretation

Changing interrupt names from "irq0", "irq1" to "enet", "enet-wol" did not fix the GENET path.

The current GENET DTS-only path is exhausted:

eth0 exists
external RGMII fixed-link reports up
TX watchdog fires
IRQ 16/17 stay at zero
packet I/O does not work

Next direction is no longer blind Ethernet DTS guessing. Move to platform mapping:

chipset / board mapping
memory map validation
NAND dump
original firmware extraction
vendor source / DTS comparison
reconstruct BCM3383 GMAC init:
bcm3383_pinmux_select(10)
bcm3383_init_gmac()
