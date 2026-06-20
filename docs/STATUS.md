# TC7200U OpenWrt Bring-Up Status

Last updated: 2026-06-20.

## Current State

This project can boot OpenWrt from CFE/TFTP and reach a serial shell on the
Technicolor TC7200.U / BCM3383 platform on the known-good baseline. Ethernet
remains the active blocker.

The public operational surface is now wrapper-only:

- supported command: `./scripts/wrapper.sh`
- removed command: `./scripts/tcbuilder.sh` now exits non-zero with a migration
  hint
- no public build, verify, status, state, serial, reverse, candidate, or gate
  modes remain

## Working

- CFE/TFTP boot reaches OpenWrt userspace.
- OpenWrt reaches a shell over serial on `ttyS0`.
- UART RX works when `CONFIG_BCM7120_L2_IRQ=y` is enabled.
- A825 ProgramStore wrapper generation and internal verification are available
  through `./scripts/wrapper.sh`.
- The wrapper still emits the required `size_ok=True` verification marker.
- The canonical no-template wrapper path uses load address `0x82000000`.
- The canonical preserve-from template remains:
  `records/artifacts/rescue/tc7200-stage2-console-good.bin`.
- Kernel-side MMIO probing with `ioremap()` and `printk()` works and is
  preferred over `/dev/mem`.

Known-good image:

- `records/artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`
- Size: `5097194` bytes
- SHA256: `14b05d771147ab37c388894cd5a66fc2bed230176068902d4444ce29ef1fb8ae`

Canonical A825 template copy:

- `records/artifacts/rescue/tc7200-stage2-console-good.bin`
- Size: `6418079` bytes
- SHA256: `a2b9fa164d092387dc0382698cbdff940bb97cce6c41a029ac70c1b357497c4b`

Original A825 baseline:

- `records/artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`
- Size: `5696426` bytes
- SHA256: `2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513`

## Not Working

- Ethernet is not passing packets.
- GENET at `0x12c00000` probes and creates `eth0`.
- Fixed-link RGMII reports link up, but TX does not complete.
- `bcmgenet_xmit()` queues real TX frames into descriptor RAM.
- TDMA stays enabled, but the hardware consumer index never advances.
- RX stays zero in paired serial and host packet captures.
- hwirq `64` increments; hwirq `66` remains idle.
- MTD and persistent image work are not ready. Flash, NAND, SPI, and partition
  layout discovery must wait until Ethernet and read-only map discovery are
  understood.

## Current Blockers

1. Prove how BCM3383 GENET expects TX buffer addresses to be represented or
   translated for TDMA.
2. Investigate BCM3383 GENET DMA window/base/init and UBUS/SCB clock setup.
3. Keep the BCM3383 GMAC clock/reset/pinmux quirk in the test baseline.
4. Keep IRQ `<13 4>` as a separate branch; do not combine it with DMA address
   tests.
5. Pause additional raw MDIO command reverse-engineering for now; the IF0/IF1
   branch is negative.
6. Move to kernel-only descriptor ownership/format branches, including the
   temporary `GENET_V1 words_per_bd` test and strict v1 BD/OWN handling
   validation.
7. Add BCM53125/B53 switch description only after GENET TDMA consumes
   descriptors.
8. After Ethernet, proceed to read-only flash discovery.

## Recommended Next Work

1. Build the BMIPS initramfs manually in OpenWrt.
2. Wrap it with `./scripts/wrapper.sh`.
3. Use `--preserve-from ./records/artifacts/rescue/tc7200-stage2-console-good.bin --fresh-header`
   when the run should stay aligned with the current known-good template policy.
4. Confirm `size_ok=True` on every candidate before serving it via CFE/TFTP.
5. Only after a stable boot, resume Ethernet bring-up using the ISP-derived
   GMAC function map as reference for OpenWrt-side diffs.

## Bottom Line

Serial console and CFE/TFTP OpenWrt boot are solved. The project is blocked on
GENET DMA window/init behavior: make TDMA consume TX descriptors first, then
revisit switch wiring, then MTD/flash layout.
