# 2026-06-18 GENET fixed-link probe reaches eth0 but TX watchdogs

## Scope

This log records the first successful Linux BCMGENET probe on the TC7200U OpenWrt initramfs path, before applying additional GENET TX/DMA debug patches.

The goal of this pass was not to make Ethernet fully usable. The goal was to verify that the DTS node and BCMGENET driver bind, then capture the next failure layer.

## Build / DTS state

Kernel configuration proof:

- `CONFIG_BCMGENET=y`
- `CONFIG_PHYLIB=y`
- `CONFIG_FIXED_PHY=y`
- `CONFIG_DEVMEM=y`
- `CONFIG_BCM7120_L2_IRQ=y`

DTS state:

- `ethernet_test: ethernet@12c00000`
- `compatible = "brcm,genet-v1"`
- `reg = <0x12c00000 0x4000>`
- `interrupt-parent = <&periph_intc>`
- `interrupts = <16>, <17>`
- `phy-mode = "rgmii"`
- `status = "okay"`
- fixed-link 1000/full
- NAND node disabled for Ethernet-only testing

## Runtime boot/probe evidence

BCMGENET now binds and creates `eth0`.

Observed dmesg:

```text
bcmgenet 12c00000.ethernet: GENET 1.0 EPHY: 0x0000
bcmgenet: Invalid GPHY revision detected: 0x0000
bcmgenet 12c00000.ethernet: using random Ethernet MAC
bcmgenet 12c00000.ethernet: unable to find MDIO bus node
unimac-mdio unimac-mdio.-19: Broadcom UniMAC MDIO bus
bcmgenet 12c00000.ethernet: configuring instance for external RGMII (no delay)
bcmgenet 12c00000.ethernet eth0: Link is Up - 1Gbps/Full - flow control off
bcmgenet 12c00000.ethernet eth0: NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out
bcmgenet 12c00000.ethernet eth0: Link is Down
Interpretation:

Driver probe succeeds.
Fixed-link path succeeds.
eth0 is created.
TX path starts, but TX completion does not happen.
The current failure is TX DMA / interrupt completion / GENET-MBDMA/FPM integration, not missing driver binding.
Interface state

ip link showed:

1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000
2: eth0: <BROADCAST,MULTICAST> mtu 1500 qdisc mq state DOWN qlen 1000
    link/ether 06:38:aa:9c:a0:62 brd ff:ff:ff:ff:ff:ff

Sysfs path:

/sys/class/net/eth0 -> ../../devices/platform/ubus/12c00000.ethernet/net/eth0

MAC:

06:38:aa:9c:a0:62
Interrupt evidence

Before eth0 up:

CPU0
0:          0      MIPS   0  smp_ipi0
1:          0      MIPS   1  smp_ipi1
7:     148782      MIPS   7  timer
8:      13266  periph_intc@14e00048   2  14e00500.serial
ERR:       9734

While eth0 was up:

CPU0
0:          0      MIPS   0  smp_ipi0
1:          0      MIPS   1  smp_ipi1
7:     150554      MIPS   7  timer
8:      13384  periph_intc@14e00048   2  14e00500.serial
16:          0  periph_intc@14e00048  16  eth0
17:          0  periph_intc@14e00048  17  eth0
ERR:      11215

Interpretation:

IRQs 16 and 17 are allocated to eth0 while the interface is up.
IRQ mapping is not absent.
IRQ counts remain zero during the TX watchdog window.
The ERR count increases.
Do not treat this as a simple missing interrupt-names issue yet.
Statistics after watchdog/down
tx_packets = 10
tx_errors  = 8
tx_dropped = 0
rx_packets = 0
rx_errors  = 0

Interpretation:

The kernel attempted TX.
TX failed repeatedly.
RX never received anything.
No packet drop path was counted; this looks like TX timeout/completion failure.
Runtime device-tree proof

/proc/device-tree/ubus/ethernet@12c00000/interrupts:

00000000  00 00 00 10 00 00 00 11

Decoded:

interrupts = <16>, <17>

/proc/device-tree/ubus/ethernet@12c00000/interrupt-parent:

00000000  00 00 00 02

/proc/device-tree/ubus/ethernet@12c00000/compatible:

brcm,genet-v1
GENET register snapshot after probe

All sampled GENET/MBDMA offsets still returned 0x00000001:

GENET1
0x12c00004 = 0x00000001
0x12c00008 = 0x00000001
0x12c0000c = 0x00000001
0x12c00010 = 0x00000001

GENET2
0x12c00040 = 0x00000001
0x12c00044 = 0x00000001
0x12c00048 = 0x00000001
0x12c0004c = 0x00000001

GENET3
0x12c00050 = 0x00000001
0x12c00054 = 0x00000001
0x12c00058 = 0x00000001
0x12c00070 = 0x00000001

Compared to the carried OEM/ENET reverse reference, these do not yet match the expected useful MBDMA/FPM-programmed values, especially the high-value compare points:

0x12c00010
0x12c0004c
0x12c00050
0x12c00054
0x12c00058
0x12c00008
0x12c00070
FPM baseline from prior devmem pass

FPM was readable and nonzero:

0x12200010 = 0x00000000
0x12200014 = 0x00000001
0x12200040 = 0x06000000
0x12200044 = 0x00010000
0x12200050 = 0x00000000
0x12200054 = 0x18007F10
0x12200058 = 0x00000000
0x1220005c = 0x00000000
0x12200200 = 0x80130800
0x12200208 = 0x90064400
0x12200210 = 0xA01B8200
0x12200218 = 0xB01C4100

Interpretation:

FPM address space is readable.
GENET/MBDMA side is the current suspicious area.
The current Linux GENET driver is not reproducing the OEM-style MBDMA/FPM setup yet.
Current conclusion

The project moved from:

no Ethernet interface

to:

BCMGENET binds, eth0 exists, fixed-link comes up, TX watchdogs

This is a real forward step.

The current blocker is not:

missing CONFIG_BCMGENET
missing DTS node
missing fixed-link
missing IRQ allocation
NAND probe noise

The current blocker is likely one of:

incorrect GENET v1 register-layout assumption for BCM3383/TC7200U
missing TC7200U-specific GENET/MBDMA/FPM initialization
wrong GENET IRQ completion behavior despite IRQ allocation
missing clock/profile/gating setup
DMA descriptor programming not matching OEM expectations
MBDMA/FPM endpoint setup not matching OEM stage1 values
Next action

Before applying old GMAC-init or switch/B53/MDIO patches, instrument BCMGENET TX path.

Recommended next patch order:

Apply 996-bcmgenet-tc7200u-xmit-desc-debug.patch
Apply 997-bcmgenet-tc7200u-tx-poll-debug.patch
Rebuild/wrap debug initramfs
Boot
Bring eth0 up once
Capture one TX watchdog
Capture dmesg filtered for GENET/TX/DMA/IRQ/debug
Capture /proc/interrupts

Do not apply 998-bmips-tc7200u-gmac-init.patch until the debug patches show what BCMGENET is actually programming.
