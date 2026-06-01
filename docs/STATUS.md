# TC7200U OpenWrt Bring-Up Status

Last updated: 2026-06-01 (night).

## Current State

This project can boot OpenWrt from CFE/TFTP and reach a serial shell on the
Technicolor TC7200.U / BCM3383 platform on the known-good baseline. Newer
payload families built from the current mutable `openwrt-r34427` tree are
still regressing to `init` SIGSEGV panic. Ethernet remains the active blocker
after baseline recovery.

## Working

- CFE/TFTP boot reaches OpenWrt userspace.
- OpenWrt reaches a shell over serial on `ttyS0`.
- Gate checks are fully green on known-good serial logs:
  - `records/logs/serial/picocom-20260531-050727.log`
  - `records/logs/serial/picocom-20260601-193010.log`
  (`Gate A/B/C/D/E = PASS`).
- UART RX works when `CONFIG_BCM7120_L2_IRQ=y` is enabled.
- A825 ProgramStore wrapper generation and verification are integrated into
  `scripts/tcbuilder.sh`.
- Auto-wrap baseline now defaults to `--load-addr 0x80004000` for OpenWrt
  build output while preserving dynamic output filenames.
- Kernel-side MMIO probing with `ioremap()` and `printk()` works and is
  preferred over `/dev/mem`.

Known-good image:

- `records/artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`
- Size: `5097194` bytes
- SHA256: `14b05d771147ab37c388894cd5a66fc2bed230176068902d4444ce29ef1fb8ae`

Original A825 baseline:

- `records/artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`
- Size: `5696426` bytes
- SHA256: `2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513`

Recent known-good OpenWrt A825 boot:

- Serial evidence: `records/logs/serial/picocom-20260531-050727.log`
- Header markers:
  - `Load Address: 80004000`
  - `Filename: tc7200-stage2-openwrt-c0-load80004000.bin`
- Kernel marker:
  - `Linux version 6.12.87 ... r34427-6865d489d2`
- Userspace markers:
  - `procd: - init -`
  - `Please press Enter to activate this console.`

Latest known-good OpenWrt A825 boot:

- Serial evidence: `records/logs/serial/picocom-20260601-193010.log`
- Gate report:
  - `records/logs/builds/2026-06-01-195304-check-gates-picocom-20260601-193010.txt`
- Header markers:
  - `Load Address: 82000000`
  - `Filename: openwrt-initramfs.bin`
  - `File Length: 6417987 bytes`
- Userspace markers:
  - `procd: - init -`
  - `Please press Enter to activate this console.`
  - `BusyBox v1.37.0 ...`

Newly pinned rescue copy from that pass:

- `records/artifacts/rescue/tc7200-console-good-20260601-193010.bin`

Pinned known-good payload family (do not mix with newer test payloads):

- Header/file markers from successful runs:
  - `Load Address: 80004000`
  - `File Length: 6417987 bytes`
  - `Linux version ... #0 SMP Sun May 17 18:30:33 2026`
- Source lineage:
  - wrapped from `openwrt-ps-irqfallback.bin` payload (`raw_sha256`
    `a17f022f1ef947ee16f60f0481f315fc399278ca574fb73c6ddcf548efbe0deb`)
  - see `records/logs/builds/2026-05-31-083754-verify.log`

## Not Working

- Ethernet is not passing packets.
- Newer test build with ISP-informed changes regressed to userspace panic:
  `records/logs/serial/picocom-20260531-095452.log`
  (`Gate B FAIL`, `Gate E FAIL`).
- Current failing family (still reproducing on 2026-06-01):
  - `records/logs/serial/picocom-20260531-215656.log`
  - `records/logs/serial/picocom-20260531-223409.log`
  - markers:
    - `Run /init as init process`
    - `do_page_fault(): sending SIGSEGV to init`
    - `Kernel panic - not syncing: Attempted to kill init!`
  - example payload ID:
    - `tc7200-stage2-r34427-nand-ok-r1.bin`
    - `raw_sha256 d7251f8429d27521fbe45680306ae2b883d354dacd877b5e238dfb20c7cb1906`
    - `records/logs/builds/2026-05-31-223226-build-provenance.log`
- Separate unstable-but-booting case (not init panic):
  - `records/logs/serial/picocom-20260601-190051.log`
  - console starts, but repeated userspace faults appear:
    - `do_page_fault(): sending SIGSEGV to ubus ...`
- Panic regression markers:
  - `Load Address: 82000000`
  - `Filename: tc7200u-stage2-next.bin`
  - `Linux version 6.12.91 ... r34703-aa96b3ad55`
  - `Warning: unable to open an initial console.`
  - `Kernel panic - not syncing: Attempted to kill init!`
- GENET at `0x12c00000` probes and creates `eth0`.
- Fixed-link RGMII reports link up, but TX does not complete.
- `bcmgenet_xmit()` queues real TX frames into descriptor RAM.
- TDMA stays enabled, but the hardware consumer index never advances.
- RX stays zero in paired serial and host packet captures.
- hwirq `64` increments; hwirq `66` remains idle.
- MTD and persistent image work are not ready. Flash, NAND, SPI, and partition
  layout discovery must wait until Ethernet and read-only map discovery are
  understood.

## Recent Results

High-signal 2026-05-31 and prior results:

- `records/logs/serial/picocom-20260531-050727.log`:
  stable baseline boot with serial console (`Gate E PASS`).
- `records/logs/serial/picocom-20260531-095452.log`:
  kernel boots but userspace fails (`Gate E FAIL`, init killed).

- Flood TX reproduced `NETDEV WATCHDOG` with queue-stop and no hardware
  completion progress.
- Host-side packet captures showed peer ARP retries but no frames sourced from
  OpenWrt's runtime MAC.
- Correct-subnet traffic still failed with RX zero, TX errors increasing, and
  the same ring/global signatures.
- Bridge-off and link-cycle checks did not change the stuck state.

See:

- `records/notes/runtime-probes/2026-05-24-flood-watchdog-queue-stopped.md`
- `records/notes/runtime-probes/2026-05-24-flood-no-watchdog-still-no-rx.md`
- `records/notes/runtime-probes/2026-05-24-pktmon-peer-arp-only-no-owrt-egress.md`
- `records/notes/runtime-probes/2026-05-25-watchdog10half-bridgehold-v10-analysis.md`

## Ethernet Direction

The current source evidence points away from `bcm6368-enetsw` at `0x14e01000`.
The matching TC7200 source maps:

- `spi@14e01000` as HSSPI.
- `ethernet@12c00000` as `brcm,genet-v1`.
- GENET interrupts as 16 and 17 through `periph_intc`.
- BCM3383 GMAC init through clock/reset and pinmux setup.

The fixed-link GENET diagnostic reaches TX queueing, but TDMA does not consume
descriptors. The next Ethernet work is descriptor/register/DMA verification,
not B53/DSA integration.

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

1. Recover the exact known-good boot baseline before further Ethernet changes:
   force A825 wrapper template/load fields to the working `0x80004000` path,
   then require `Gate E PASS` on each new image.
2. Keep the known-good images under `records/artifacts/rescue/` unchanged.
3. Keep generated wrap manifests and state captures under `records/generated/`.
4. Stop spending time on `bcm6368-enetsw` DMA/IRQ swaps at `0x14e01000`.
5. Do not repeat already-failed `DMA_OWN`, ADDRSHIFT8, fatal/non-fatal
   `DMA_BIT_MASK(20)`, Zephyr-style `dma-ranges`, `mem=16M`/`mem=32M`, or
   reserved low TX buffer standalone paths.
6. Do not manually enable parent `periph_intc` bits 16/17; the blind enable
   path causes an IRQ storm.
7. Treat memory-map/load-address warnings from GENET test images as serious
   until explained.
8. Use `docs/MEMORY_MAP.md` and
   `records/notes/source-research/2026-05-17-similar-firmware-useful-map-data.md`
   before changing DTS `reg`, `interrupts`, or boot/link addresses.

## Immediate Next

1. Finalize wrapper default template to a verified `load=0x80004000` A825
   baseline and keep dynamic output names.
2. Rebuild BMIPS-only image (not mediatek/other target), wrap, and gate-check.
3. Pin image identity in every boot report (`filename`, `file_length`,
   `raw_sha256`, `wrapped_sha256`) and avoid switching payload families
   between runs.
4. Only after `Gate E PASS`, resume Ethernet bring-up using the ISP-derived
   GMAC function map (`fn_enet_gmac_init`, `fn_enet_build_core_cmd`,
   `fn_enet_poll_or_wait_ready`) as reference for OpenWrt-side diffs.

## Bottom Line

Serial console and CFE/TFTP OpenWrt boot are solved. The project is blocked on
GENET DMA window/init behavior: make TDMA consume TX descriptors first, then
revisit switch wiring, then MTD/flash layout.

## OEM Source Mining Status

The TC72XX LxG1 OEM tree suggests the vendor BCM3384 Ethernet path is VENET +
FPM/DQM + SEGDMA/UNIMAC/IOP, not direct upstream `bcmgenet` TDMA. BFC5 deep
mining is negative for useful BCM3383/BCM3384 Ethernet evidence.

See:

- `records/notes/runtime-probes/2026-05-18-tc72xx-lxg1-venet-dqm-fpm-findings.md`
- `records/notes/runtime-probes/2026-05-19-unimac-if0-if1-mdio-command-path-negative.md`
- `records/notes/runtime-probes/2026-05-19-unimac-core0-core1-link-toggle-no-delta.md`
- `records/notes/runtime-probes/2026-05-19-77-subnet-ping-fails-ring-static.md`
- `records/notes/runtime-probes/2026-05-19-reset-baseline-12c00000-words4-negative.md`
- `records/notes/runtime-probes/2026-05-18-tc72xx-bfc5-deepmine-negative.md`
