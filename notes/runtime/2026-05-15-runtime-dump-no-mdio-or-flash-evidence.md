# TC7200.U runtime dump: no flash, MDIO, switch, or PHY evidence exposed

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

Summary:
- /proc/mtd was empty except for the header.
- Filtered dmesg showed only machine ID, JFFS2 support, and bcm6368-enetsw probe.
- No MDIO, switch, PHY, B53, BCM53125, NAND, SPI, or CFE partition evidence appeared.
- /proc/iomem only showed RAM, serial, and the three enetsw DMA windows.
- debugfs is mounted, but quick dump did not expose useful Ethernet switch or MDIO data.
- ethtool eth0 returned: No data available.

Observed dmesg lines:
    MIPS: machine is Technicolor TC7200.U
    bcm6368-enetsw 14e01000.ethernet: mtd mac 86:8a:94:10:80:4b
    bcm6368-enetsw 14e01000.ethernet: eth0 at 0xb4e01000, IRQ 0

Observed iomem:
    14e00500-14e00517 : 14e00500.serial serial@14e00520
    14e01000-14e0107f : 14e01000.ethernet dma
    14e01100-14e0117f : 14e01000.ethernet dma-channels
    14e01200-14e0127f : 14e01000.ethernet dma-sram

Interpretation:
The runtime image exposes no useful flash partitions, no MDIO bus, no switch node, and no PHY identity.
The simple bcm6368-enetsw DMA/IRQ permutation matrix is exhausted.

Next useful direction:
Add temporary debug prints to bcm6368-enetsw.c to inspect selected DMA channels, IRQs, DMA_CFG, per-channel config/status/mask registers, SRAM ring registers, descriptor ring addresses, and descriptor state after start_xmit.
Goal: determine whether TX DMA starts, whether descriptors are consumed, and whether interrupt/status bits ever change.
