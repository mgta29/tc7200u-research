# TC7200.U OpenWrt first full userspace boot

Status:
- OpenWrt SNAPSHOT boots to shell over ttyS0.
- Serial console works with bcm63xx_uart at 0x14e00500.
- BCM3380 L2 interrupt controller now registers correctly.
- Init/procd works.
- Ethernet is not present yet: only loopback exists.
- No MTD devices visible yet: /proc/mtd empty.

Confirmed boot lines:
- MIPS: machine is Technicolor TC7200.U
- irq_bcm7120_l2: registered BCM3380 L2 intc (/ubus/periph_intc@14e00048)
- irq_bcm7120_l2: registered BCM3380 L2 intc (/ubus/cmips_intc@151f8048)
- 14e00500.serial: ttyS0 at MMIO 0x14e00500 (irq = 8)
- init: Console is alive
- procd: - init -
- root login on ttyS0

Current missing pieces:
- Ethernet/GMAC0
- MDIO/switch/BCM53125
- NAND/SPI MTD map
