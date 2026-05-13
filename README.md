# Technicolor TC7200.U / BCM3383 OpenWrt research

Device:
- Technicolor TC7200.U
- Broadcom BCM3383Z-B0 / BMIPS4350
- RAM: 128 MB
- NAND: 64 MB
- SPI flash: 1 MB
- Switch detected by CFE: BCM53125
- CFE signature/PID: a825

Known CFE network:
- Modem/CFE: 192.168.77.1
- TFTP server/PC: 192.168.77.2
- TFTP filename: openwrt-ps-irqfallback.bin

Important finding:
- Serial TX worked from kernel.
- Serial RX did not work until BCM3380/BCM7120 L2 interrupt controller support was enabled.
- Required kernel config:
  CONFIG_BCM7120_L2_IRQ=y

Proof:
- CFE serial input works: pressing p prints flash map.
- USB-TTL loopback works.
- OpenWrt RX test received typed input:
  TC7200U-RXTEST: RX: abc7

Do not flash yet:
- RAM boot only for now.
- Avoid CFE d/s/e/E/X until serial, LAN, and recovery are confirmed.
