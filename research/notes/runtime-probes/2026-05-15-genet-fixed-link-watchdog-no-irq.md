# TC7200.U runtime result: GENET fixed-link reaches link-up, then TX watchdog/no IRQ

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

## Test

BCM3383 GENET fixed-link diagnostic using:

- MAC node: `ethernet@12c00000`
- compatible: `brcm,genet-v1`
- reg: `0x12c00000` size `0x4000`
- interrupts: 16 and 17 through `periph_intc`
- `phy-mode = "rgmii"`
- no `phy-handle`
- no `mdio@600` child
- direct MAC fixed-link, 1000/full-duplex

The running device tree confirmed:

```text
phy-mode = rgmii
fixed-link exists
mdio@600 missing

Boot result

Important lines:

bcmgenet 12c00000.ethernet: GENET 1.0 EPHY: 0x0000
bcmgenet: Invalid GPHY revision detected: 0x0000
bcmgenet 12c00000.ethernet: unable to find MDIO bus node
unimac-mdio unimac-mdio.-19: Broadcom UniMAC MDIO bus
bcmgenet 12c00000.ethernet: configuring instance for external RGMII (no delay)
bcmgenet 12c00000.ethernet eth0: Link is Up - 1Gbps/Full - flow control off
bcmgenet 12c00000.ethernet eth0: NETDEV WATCHDOG: transmit queue 0 timed out
bcmgenet 12c00000.ethernet eth0: Link is Down

Runtime:

ip link show eth0
2: eth0: <BROADCAST,MULTICAST> mtu 1500 qdisc mq state DOWN qlen 1000
    link/ether 0e:b8:d3:f5:e9:e7 brd ff:ff:ff:ff:ff:ff

cat /proc/interrupts
16:          0  periph_intc@14e00048  16  eth0
17:          0  periph_intc@14e00048  17  eth0

BusyBox ip in this initramfs does not support ip -s link.

Interpretation

The fixed-link diagnostic is a useful step forward:

eth0 is created.
The MAC configures as external RGMII.
The fixed-link path reports link up at 1Gbps/full.
The previous failed to connect to PHY blocker is bypassed.

The new blocker is TX completion / interrupt / DMA:

TX watchdog fires shortly after link-up.
IRQ 16 and IRQ 17 are registered for eth0 but counters remain zero.
Packet TX does not complete.

Likely causes:

GENET interrupt names or IRQ routing are wrong/incomplete.
GENET DMA interrupts are not delivered.
BCM3383 GMAC clock/reset/pinmux init is missing.
The MAC fixed-link state is synthetic, while the real switch path is not initialized.
Next exhaustion step before changing research direction

Do one more narrow GENET test:

change interrupt-names from "irq0", "irq1" to "enet", "enet-wol"
keep fixed-link-only RGMII
keep no mdio@600, no B53 switch, and no phy-handle
rebuild, wrap, RAM boot, and check whether IRQ 16 or 17 starts incrementing

If IRQ counters remain zero and TX watchdog remains, stop GENET guessing and switch to broader platform mapping:

chipset / board mapping
memory map validation
NAND dump analysis
original firmware extraction and DTS/source comparison
vendor GMAC init reconstruction: bcm3383_pinmux_select(10) and bcm3383_init_gmac()

## 2. Update `docs/ETHERNET.md`

```sh id="gf9hza"
nano docs/ETHERNET.md

Replace the old Next test section with:

## Current GENET fixed-link result

The fixed-link-only diagnostic was reached:

- `phy-mode = "rgmii"`
- direct MAC `fixed-link`, 1000/full-duplex
- no `phy-handle`
- no `mdio@600`
- no B53/DSA switch node

Runtime result:

- `eth0` exists.
- GENET configures as external RGMII.
- Fixed-link reports `Link is Up - 1Gbps/Full`.
- TX watchdog fires.
- IRQ 16 and IRQ 17 are registered for `eth0`, but both counters remain zero.
- Ping sends no working traffic.

Conclusion: PHY attach is no longer the blocker. The current blocker is TX completion / IRQ / DMA / missing GMAC hardware init.

Runtime note:

- `research/notes/runtime-probes/2026-05-15-genet-fixed-link-watchdog-no-irq.md`

## Next test

Exhaust one more narrow GENET IRQ naming test before changing direction:

- keep `phy-mode = "rgmii"`
- keep direct fixed-link, 1000/full-duplex
- keep no `phy-handle`
- keep no MDIO child
- keep no B53/DSA switch node
- change `interrupt-names` from `"irq0", "irq1"` to `"enet", "enet-wol"`

Goal:

- Check whether the main GENET interrupt is currently missed because the wrong interrupt name is used.
- Watch whether IRQ 16 or IRQ 17 increments after `ip link set eth0 up` and ping.
- If IRQ counters stay zero and TX watchdog remains, stop GENET guessing.

## Next research direction if IRQ-name test fails

Switch from blind Ethernet DTS guessing to platform mapping:

- chipset / board mapping
- memory map validation
- NAND dump
- original firmware extraction
- vendor DTS/source comparison
- reconstruct BCM3383 GMAC init:
  - `bcm3383_pinmux_select(10)`
  - `bcm3383_init_gmac()`
