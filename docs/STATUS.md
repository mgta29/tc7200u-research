# TC7200U OpenWrt Bring-up Status

Last updated: 2026-05-15.

## Current state

This project is in early bring-up state. It can boot OpenWrt from RAM over
CFE/TFTP and reach a serial shell, but it is not a working flashable OpenWrt
system.

## Working

- RAM/TFTP boot works with the known-good rescue image:
  - `artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`
  - Size: `5097194` bytes
  - SHA256:
    `14b05d771147ab37c388894cd5a66fc2bed230176068902d4444ce29ef1fb8ae`
- The original A825 rescue baseline is preserved:
  - `artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`
  - Size: `5696426` bytes
  - SHA256:
    `2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513`
- OpenWrt reaches a shell over serial on `ttyS0`.
- UART RX works when `CONFIG_BCM7120_L2_IRQ=y` is enabled.
- BCM3380 L2 interrupt controllers register:
  - `/ubus/periph_intc@14e00048`
  - `/ubus/cmips_intc@151f8048`
- TC7200U CFE TFTP wrapping is partly understood:
  - signature: `a825`
  - header length: 92 bytes
  - payload load address: `0x82000000`
  - internal header filename: `openwrt-initramfs.bin`
- Local wrapper and verifier scripts exist:
  - `scripts/tc7200u-a825-wrap.py`
  - `scripts/tc7200u-verify-a825-image.py`
- Kernel-side MMIO probing with `ioremap()` and `printk()` works and is
  preferred over `/dev/mem`.

## Not working

- Ethernet is not up.
  - GENET at `0x12c00000` probes and creates `eth0`, but link stays down.
  - Internal PHY mode reads invalid GPHY data and is not a solved path.
  - The earlier `bcm6368-enetsw` path at `0x14e01000` produced no packet I/O.
- MTD is not up.
  - `/proc/mtd` is empty or not useful at this stage.
  - NAND/SPI partition discovery is still missing.
- DTS is still incomplete.
  - UART and interrupt controllers are present.
  - Real Ethernet, MDIO, switch, NAND, and SPI nodes are still missing or
    unvalidated.
- Flashing is not safe yet.
  - Use RAM/TFTP boot only.

## Ethernet direction

The current source evidence points away from `bcm6368-enetsw` at `0x14e01000`.
The matching TC7200 source maps:

- `spi@14e01000` as HSSPI.
- `ethernet@12c00000` as `brcm,genet-v1`.
- GENET interrupts as 16 and 17 through `periph_intc`.
- BCM3383 GMAC init through clock/reset and pinmux setup.

The next Ethernet work should test GENET without the invalid internal PHY path,
then add BCM53125/B53 switch wiring after the diagnostic result is understood.

## Current blockers

1. Confirm the correct GENET PHY/switch description.
2. Prove whether GENET can start TX/DMA/IRQs with fixed-link RGMII diagnostics.
3. Add the minimum BCM3383 GMAC clock/reset init needed by OpenWrt.
4. Add safe MDIO/B53/BCM53125 switch description only after GENET behavior is
   understood.
5. After Ethernet, proceed to read-only flash discovery.
6. Only after MTD and flash layout are understood, consider persistent images.

## Recommended next work

1. Keep the known-good images under `artifacts/rescue/` frozen as rescue
   baselines.
2. Do not overwrite the rescue image in `/mnt/c/tftp`.
3. Keep generated wrap manifests and state captures under
   `research/notes/generated/`.
4. Stop spending time on `bcm6368-enetsw` DMA/IRQ swaps at `0x14e01000`.
5. Test a GENET RGMII/fixed-link diagnostic node at `0x12c00000`.
6. Treat memory-map/load-address warnings from GENET test images as serious
   until explained.
7. Handle MTD/SPI/NAND only after Ethernet is understood, and begin read-only.

## Bottom line

Serial console and RAM OpenWrt boot are solved. The project is blocked on board
description and driver bring-up: Ethernet first, then MTD/flash layout, then
safe persistent image work.
