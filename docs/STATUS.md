# TC7200U OpenWrt Bring-up Status

Last updated: 2026-05-17.

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
  - `scripts/tc7200u`
  - `scripts/tc7200u-auto-build-install-wrap.sh`
  - `scripts/tc7200u-a825-wrap.py`
  - `scripts/tc7200u-verify-a825-image.py`
- Kernel-side MMIO probing with `ioremap()` and `printk()` works and is
  preferred over `/dev/mem`.

## Not working

- Ethernet is not passing packets.
  - GENET at `0x12c00000` probes and creates `eth0`.
  - Fixed-link RGMII reports link up, but TX does not complete.
  - `bcmgenet_xmit()` queues a real TX frame into descriptor RAM and writes
    producer index 1.
  - TDMA stays enabled, but the hardware consumer index never advances.
  - Compact GENET v1 status/length descriptor packing now reads back correctly:
    `wrote_len=0x000e009a`, `rb_len=0x000e009a`.
  - Corrected manual descriptor slot 0 devmem test with `0x000e009a` and
    `0x00080000` also reads back correctly, but TDMA still does not consume it.
  - Manual descriptor slot 1 plus producer advance to `2` also reads back
    correctly, with `hw_p=2` and `hw_c=0`.
  - Full ring16 TDMA snapshot shows sane GENET v1 ring setup and enabled TDMA,
    but `READ_PTR` and `CONS_INDEX` remain `0`.
  - Linux DMA mappings and coherent bounce allocations still land in the
    `0x06xxxxxx` RAM bank.
  - GENET descriptor RAM stores only low 20 address bits, for example:
    `0x06835002 -> 0x00035002` and `0x06e01000 -> 0x00001000`.
  - ADDRSHIFT8 did not fix TX.
  - Reserved low TX buffer at physical `0x01680000` still left `hw_c=0`, so
    high RAM allocation is not the sole blocker.
  - Generic RGMII OOB write at `0x12c0008c` did not latch and did not improve
    TX.
  - The inherited GENET hwirqs `16/17` show zero interrupt counts, while
    `INT_EXT_PER PeriphIRQ0_2` reports active UniMAC status:
    `0x14e00338=0x3000007D`, `0x14e0033c=0x045A0409`.
  - The current DTS test branch maps GENET to extended hwirqs `64/66`.
  - `mem=16M` and `mem=32M` were invalid tests because they failed before a
    useful GENET runtime test.
  - Internal PHY mode reads invalid GPHY data and is not a solved path.
  - The earlier `bcm6368-enetsw` path at `0x14e01000` produced no packet I/O.
- MTD is not up.
  - `/proc/mtd` is empty or not useful at this stage.
  - NAND/SPI partition discovery is still missing.
- DTS is still incomplete.
  - UART and interrupt controllers are present.
  - Current diagnostic DTS snapshots include disabled HSSPI, temporary NAND,
    and GENET fixed-link nodes.
  - Real Ethernet, MDIO, switch, NAND, and SPI nodes are still missing or
    unvalidated for production use.
- Flashing is not safe yet.
  - Use RAM/TFTP boot only.

## Ethernet direction

The current source evidence points away from `bcm6368-enetsw` at `0x14e01000`.
The matching TC7200 source maps:

- `spi@14e01000` as HSSPI.
- `ethernet@12c00000` as `brcm,genet-v1`.
- GENET interrupts as 16 and 17 through `periph_intc`.
- BCM3383 GMAC init through clock/reset and pinmux setup.

The fixed-link GENET diagnostic now reaches TX queueing, but TDMA does not
consume the descriptor. The next Ethernet work is descriptor/register/DMA
verification, not B53/DSA integration.

## Current blockers

1. Prove how BCM3383 GENET expects TX buffer addresses to be represented or
   translated for TDMA.
2. Verify the extended `PeriphIRQ0_2` GENET interrupt mapping and whether the
   generic GENET ISR can acknowledge it cleanly.
3. Investigate BCM3383 GENET DMA window/base/init and UBUS/SCB clock setup.
   The reserved TX buffer at physical `0x01680000` still left `hw_c=0`.
4. Keep the BCM3383 GMAC clock/reset/pinmux quirk in the test baseline.
5. Keep IRQ `<13 4>` as a separate branch; do not combine it with DMA address
   tests.
6. Add safe MDIO/B53/BCM53125 switch description only after GENET TDMA consumes
   descriptors.
7. After Ethernet, proceed to read-only flash discovery.
8. Only after MTD and flash layout are understood, consider persistent images.

## Recommended next work

1. Keep the known-good images under `artifacts/rescue/` frozen as rescue
   baselines.
2. Do not overwrite the rescue image in `/mnt/c/tftp`.
3. Keep generated wrap manifests and state captures under
   `research/notes/generated/`.
4. Stop spending time on `bcm6368-enetsw` DMA/IRQ swaps at `0x14e01000`.
5. Do not repeat the already-failed `DMA_OWN`, ADDRSHIFT8, fatal/non-fatal
   `DMA_BIT_MASK(20)`, Zephyr-style `dma-ranges`, `mem=16M`/`mem=32M`, or
   reserved low TX buffer standalone paths.
6. Do not manually enable parent `periph_intc` bits 16/17; the blind enable
   path causes an IRQ storm.
7. Treat memory-map/load-address warnings from GENET test images as serious
   until explained.
8. Handle MTD/SPI/NAND only after Ethernet is understood, and begin read-only.
9. Use `docs/MEMORY_MAP.md` and
   `research/notes/source-research/2026-05-17-similar-firmware-useful-map-data.md`
   before changing DTS `reg`, `interrupts`, or boot/link addresses.

## Bottom line

Serial console and RAM OpenWrt boot are solved. The project is blocked on GENET
DMA window/init behavior: make TDMA consume TX descriptors first, then revisit
switch wiring, then MTD/flash layout, then safe persistent image
work.

<!-- TC7200U_CURRENT_GENET_STATE_START -->

## Current GENET state — 2026-05-17

Latest conclusion:

- GENET at `0x12c00000` probes and `eth0` link reports up.
- TX descriptor is posted and TDMA producer advances.
- TDMA consumer still remains `0`.
- Normal high DMA allocation is not the only blocker.
- Reserved low physical TX buffer at `0x01680000` also failed.
- Upstream/original status format with reserved low TX buffer also failed.
- Compact status format with reserved low TX buffer also failed.
- Descriptor word-order testing did not make TDMA consume.
- Generic RGMII OOB write at `0x12c0008c` did not latch.
- Current inherited hwirqs `16/17` are not counting.
- Runtime interrupt probing points to `INT_EXT_PER PeriphIRQ0_2`:
  `mask=0x3000007D`, `status=0x045A0409`.
- Current next branch maps GENET to extended hwirqs `64/66` while keeping the
  TDMA/raw-state debug active.

Current intended OpenWrt patch state for the next test:

- Active:
  - `996-bcmgenet-tc7200u-xmit-desc-debug.patch`
  - `997-bcmgenet-tc7200u-tx-poll-debug.patch`
  - `9975-bcmgenet-tc7200u-v1-dma-own-test.patch`
  - `9976-bcmgenet-tc7200u-desc-readback-debug.patch`
  - `9978-bcmgenet-tc7200u-v1-pack20-desc-test.patch`
  - `9979-bcmgenet-tc7200u-addr-debug.patch`
  - `998-bmips-tc7200u-gmac-init.patch`
  - `9986-bcmgenet-tc7200u-v1-reserved-txbuf-test.patch`
  - `9988-bcmgenet-tc7200u-raw-state-dump.patch`
  - DTS override exposing `PeriphIRQ0_2` and mapping GENET to `<64>, <66>`
- Inactive:
  - `9987-bcmgenet-tc7200u-v1-resv-swapped-desc-test.patch`

Do not repeat:

- `mem=16M` / `mem=32M`
- fatal or non-fatal `DMA_BIT_MASK(20)`
- `GFP_DMA` coherent bounce
- `ADDRSHIFT8`
- `LOWLIT 0x00080000`
- plain `DMA_OWN` without compact GENET v1 status packing
- manual low16 status poke
- reserved low TX buffer as standalone fix
- generic RGMII OOB poke at `0x12c0008c`
- blind parent IRQ enable
- B53/DSA before TDMA consumes descriptors

<!-- TC7200U_CURRENT_GENET_STATE_END -->
