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
- TFTP filename forced by CFE: openwrt-ps-irqfallback.bin

Image / CFE state:
- Known-good RAM image: artifacts/openwrt-ps-irqfallback-GOOD-5696426.bin
- Known-good received size: 5696426 bytes
- Known-good ProgramStore signature/PID: a825
- Known-good load address: 0x82000000
- Known-good result: HCS passed; CFE executed Image 4; OpenWrt booted to userspace
- Known-bad image size: 5697264 bytes
- Known-bad result: HCS failed on Image 3 Program Header; kernel did not start; no flash write was done
- Do not replace /mnt/c/tftp/openwrt-ps-irqfallback.bin with HCS-failing builds

Safe build/wrap/TFTP rule:
- Always build OpenWrt first.
- Always run scripts/tc7200u-wrap-current-openwrt.sh.
- Only TFTP /mnt/c/tftp/openwrt-ps-irqfallback.bin after the wrapper manifest says size_ok=True.
- Do not rename the file inside CFE; serve the filename CFE asks for.

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
