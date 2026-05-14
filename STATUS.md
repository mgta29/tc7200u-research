# TC7200U OpenWrt bring-up status

_Last updated: 2026-05-14_

## Current state

This project is in early bring-up state. It can boot OpenWrt from RAM over CFE/TFTP and reaches a serial shell, but it is **not yet a working flashable OpenWrt system**.

## Working

- RAM/TFTP boot works with the known-good rescue image:
  - `artifacts/openwrt-ps-irqfallback-GOOD-5696426.bin`
  - SHA256: `2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513`
- OpenWrt reaches shell over serial on `ttyS0`.
- UART RX works when `CONFIG_BCM7120_L2_IRQ=y` is enabled.
- BCM3380 L2 interrupt controllers register:
  - `/ubus/periph_intc@14e00048`
  - `/ubus/cmips_intc@151f8048`
- TC7200U CFE TFTP wrapping is partly understood:
  - signature: `a825`
  - header length: 92 bytes
  - payload load address: `0x82000000`
  - filename field: `openwrt-initramfs.bin`
- A local wrapper script exists:
  - `scripts/tc7200u-a825-wrap.py`
- Kernel-side MMIO probing with `ioremap()` and `printk()` works and is preferred over `/dev/mem`.
- Expanded CMIPS/peripheral MMIO probe has booted and logged values without crashing:
  - `0x14e00048 -> 0x00000000`
  - `0x14e0004c -> 0x00002000`
  - `0x14e00350 -> 0x00006220`
  - `0x14e00354 -> 0x00000000`
  - `0x14e00500 -> 0x00e53704`
  - `0x151f8048 -> 0xb51f8048`
  - `0x151f804c -> 0xb51f804c`

## Not working / missing

- Ethernet is not up.
  - Runtime currently shows only `lo`.
  - No confirmed `eth0`, `bgmac`, `b53`, or DSA switch registration yet.
- MTD is not up.
  - `/proc/mtd` is empty or not useful at this stage.
  - NAND/SPI partition discovery is still missing.
- DTS is still minimal.
  - UART and interrupt controllers are present.
  - Real GMAC/MDIO/switch/NAND/SPI nodes are still missing or unvalidated.
- Flashing is not safe yet.
  - Use RAM/TFTP boot only.
- Some generated images fail CFE HCS validation or are otherwise invalid.
  - Keep failed images only for comparison.
  - Do not overwrite the known-good 5696426 rescue image.

## Known invalid / risky image classes

- Raw OpenWrt initramfs image without the TC7200U `a825` Program Header.
- 12-byte `scripts/cfe-bin-header.py` loader-header images.
- HCS-failing generated images unless explicitly kept as comparison artifacts.

## Current blockers

1. Identify and describe the Ethernet path.
2. Confirm GMAC0/base address/IRQ/reset/clock details.
3. Add a minimal safe Ethernet DTS node.
4. Get at least one network interface registered in Linux.
5. After Ethernet, proceed to read-only flash discovery.
6. Only after MTD and flash layout are understood, consider persistent image work.

## Recommended next work

1. Freeze `artifacts/openwrt-ps-irqfallback-GOOD-5696426.bin` as the rescue baseline.
2. Do not overwrite the rescue image in `/mnt/c/tftp`; copy test images under distinct names before use.
3. Keep using kernel-side `printk()` / `ioremap()` probes for register discovery.
4. Do not rely on `/dev/mem` for this platform path.
5. Focus next on Ethernet:
   - enable/check `CONFIG_BGMAC`
   - enable/check `CONFIG_BGMAC_PLATFORM`
   - inspect/add minimal GMAC0 DTS node only after confirming address and IRQ
6. Handle MTD/SPI/NAND only after Ethernet is understood, and begin read-only.

## Bottom line

Serial console and RAM OpenWrt boot are solved. The project is now blocked on device description and driver bring-up: Ethernet first, then MTD/flash layout, then safe persistent images.
