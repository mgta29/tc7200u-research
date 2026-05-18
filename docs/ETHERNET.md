# TC7200.U Ethernet Notes

## Current conclusion

The current best direction is BCM3383 GENET at `0x12c00000`, not
`bcm6368-enetsw` at `0x14e01000`.

Reason:

- Public TC7200 Linux source maps `14e01000` as HSSPI.
- The same source maps `12c00000` as `brcm,genet-v1`.
- GENET at `12c00000` can probe under OpenWrt and create `eth0`.
- Fixed-link RGMII can report link up and queue a real TX frame.
- The remaining failure is TDMA/descriptor/register behavior before switch
  integration, not basic MAC discovery.

## Exhausted path

The `bcm6368-enetsw` matrix at `0x14e01000` is exhausted:

- Original IRQ/DMA order: boots, `eth0` exists, no packet I/O.
- DMA swap only: boots, no improvement.
- Interrupt swap only: boots, no improvement.
- Combined DMA and interrupt swap: boots, no improvement.
- Minimal AMAC test: probes but hangs before userspace.

Keep those notes as evidence, but do not continue guessing DMA/IRQ order on that
path.

Relevant archived notes:

- `research/notes/plans/2026-05-15-next-ethernet-debug-plan.md`
- `research/notes/runtime-probes/2026-05-14-runtime-drivers-no-ethernet.md`
- `research/notes/runtime-probes/2026-05-15-enetsw-combined-swap-negative.md`
- `research/notes/runtime-probes/2026-05-15-amac-minimal-node-hangs-before-userspace.md`

## GENET evidence

Source finding:

- `research/notes/source-research/2026-05-15-linux-technicolor-genet-finding.md`

Important values from that note:

- MAC: `ethernet@12c00000`
- Compatible: `brcm,genet-v1`
- Register size: `0x4000`
- Interrupts: 16 and 17 through `periph_intc`
- UniMAC MDIO offset: `0x600`
- Vendor setup uses `bcm3383_init_gmac()`.
- Vendor setup calls `bcm3383_pinmux_select(10)` before GMAC init.

Runtime findings:

- `research/notes/runtime-probes/2026-05-15-genet-internal-phy-link-down.md`
- `research/notes/runtime-probes/2026-05-15-bcmgenet-12c00000-negative-result.md`
- `research/notes/runtime-probes/2026-05-17-genet-txpoll-dma-not-consuming.md`
- `research/notes/runtime-probes/2026-05-17-genet-tx-desc-present-no-tdma-consume.md`
- `research/notes/runtime-probes/2026-05-17-genet-xmitdesc-real-frame-no-tdma-consume.md`
- `research/notes/runtime-probes/2026-05-17-genet-corrected-devmem-slot0-no-consume.md`
- `research/notes/runtime-probes/2026-05-17-genet-reserved-low-txbuf-still-no-tdma.md`
- `research/notes/runtime-probes/2026-05-17-genet-ext-periphirq0-2-evidence.md`
- `research/notes/runtime-probes/2026-05-18-genet-hwirq64-active-tdma-still-stuck.md`

Known result:

- Boot reaches userspace.
- `bcmgenet 12c00000.ethernet` probes.
- `eth0` exists.
- UniMAC MDIO appears.
- Internal PHY/GPHY data reads as invalid `0x0000`; internal PHY mode is not a
  solved path.
- Fixed-link RGMII reports link up, but TX watchdog repeats.
- XMITDESC shows a real TX frame queued into ring16.
- TXPOLL shows TDMA enabled and hardware producer index 1, but hardware
  consumer index remains 0.
- Compact GENET v1 status/length descriptor packing now reads back correctly:
  `wrote_len=0x000e009a`, `rb_len=0x000e009a`.
- Manual slot 0 devmem rewrite with corrected compact descriptor
  `0x000e009a` and low address `0x00080000` also read back correctly, but TDMA
  still left `hw_c=0`.
- Manual slot 1 rewrite plus producer advance to `2` also read back correctly,
  with TXPOLL showing `hw_p=2` and `hw_c=0`.
- Full ring16 TDMA snapshot shows expected GENET v1 ring setup:
  `READ_PTR=0`, `CONS=0`, `PROD=2`, `RING_BUF_SIZE=0x01000800`,
  `START=0`, `END=0x1ff`, `DMA_CTRL=0x00020001`, `DMA_STATUS=0`.
  TDMA still does not walk the ring.
- Descriptor/data address reachability is the active blocker:
  Linux gives DMA addresses around `0x06xxxxxx`, while GENET descriptor RAM
  keeps only low 20 bits.
- ADDRSHIFT8 wrote/read back the shifted address but still left `hw_c=0`.
- `dma_alloc_coherent(... GFP_DMA)` bounce allocation still produced high DMA:
  `bounce_dma=0x06e01000`, descriptor `rb_addr=0x00001000`, `hw_c=0`.
- Reserved TX buffer at physical `0x01680000` mapped and was used for TX, but
  descriptor readback still kept only `0x00080000`, and TDMA still left
  `hw_c=0`.
- Ring16 metadata is sane enough to show one posted descriptor, and global
  `TDMA_STATUS=0x00000000` reports no useful global error.
- Generic RGMII OOB control write at `0x12c0008c` did not latch:
  writing `0x00010050` read back as `0x00000001`.
- Current inherited GENET IRQ mapping to hwirqs `16/17` shows zero interrupt
  counts.
- Runtime interrupt probing shows active UniMAC0 DMA/status in the extended
  `INT_EXT_PER PeriphIRQ0_2` bank:
  `0x14e00338=0x3000007D`, `0x14e0033c=0x045A0409`.
- The DTS override is confirmed: `eth0` now appears on hwirqs `64/66`.
  hwirq `64` counts, hwirq `66` remains idle, and the console stays usable.
- TDMA/RDMA SCB burst is currently `0x10`. The next test forces GENET v1 DMA
  burst size to `0x08`, matching Broadcom U-Boot and an existing Linux GENET
  platform quirk.
- Burst size `0x08` programmed correctly but did not move TDMA. The next branch
  tests whether BCM3383 GENET v1 uses the v2-style global DMA register map with
  `DMA_RING_CFG` at `+0x00` and `DMA_CTRL` at `+0x04`.
- The v2-style global DMA register map programmed correctly and should be kept,
  but TDMA still did not consume the compact descriptor.
- Normal Linux descriptor status was retested after the DMA-regmap fix and also
  failed. The 20-bit descriptor RAM read back `0x009aefc0` as `0x000aefc0`.
- Manual swapped-word descriptor rewrites after the DMA-regmap fix also failed
  for both standard/truncated status and compact status.
- After `9990`, the descriptor format/order matrix is negative.
- Clearing surrounding descriptor RAM words before reposting slot 0 also failed.
  Adjacent/stale descriptor words are not the blocker.
- TDMA control bit probing also failed: `tdma_ctrl=0x00030001` latched but
  `cons/write` stayed zero.
- The paired TDMA ring config bit also failed: `tdma_cfg=0x00030000` with
  `tdma_ctrl=0x00030001` latched, but `cons/write` stayed zero.
- The wider/v4 ring register layout also failed: producer at `0x12c03c0c`
  latched, but consumer/write did not move.
- The next manual branch tests whether BCM3383 services ring0 instead of
  Linux's descriptor ring16.
- Some GENET images previously showed memory/page-table corruption and are not
  stable baselines.

## Next test

Next diagnostic should keep the fixed DMA regmap and compact descriptor status,
then test whether TDMA services ring0 instead of ring16 on BCM3383:

- `phy-mode = "rgmii"`
- no `phy-handle`
- no MDIO child for the DMA diagnostic
- fixed-link, 1000 full-duplex
- compact GENET v1 status/length packing active
- ADDRDBG, DESCRB, TXPOLL, and RAW state debug enabled
- `periph_intc` exposes `PeriphIRQ0_2`
- GENET interrupts are `<64>, <66>`
- no parent IRQ manual enable
- no B53/DSA yet

Goal:

- Write ring0 read/consumer/producer/size/start/end/mbuf/write registers at
  `0x12c03800..0x12c03820`.
- Enable ring0 globally with `tdma_cfg=0x00000001` and
  `tdma_ctrl=0x00000003`.
- Repost compact descriptor `0x000e009a` and low address `0x00080000`.
- Advance the ring0 producer at `0x12c03808` and check whether ring0
  consumer/write registers move.
- Prove whether Linux can produce a DMA address that GENET descriptor RAM can
  represent and TDMA can consume.
- Read BCM3383 clock/reset state, especially `ClkCtrlUBus`, and compare against
  current `bcm3383_init_gmac()`.
- Probe BCM3383 GENET DMA window/base/init behavior; the reserved-buffer test
  did not fix TDMA consumption.
- Watch for TDMA consumer index movement, TX completion, DMA/IRQ activity, and
  memory corruption.
- Keep IRQ `<13 4>` as a separate test branch.
- Add proper BCM53125/B53 switch description only after GENET TDMA behavior is
  understood.

## Guardrails

- RAM boot only.
- Do not flash.
- Preserve serial logs under `evidence/serial/`.
- Preserve generated manifests and state captures under `research/notes/generated/`.
- Do not treat `eth0` existence alone as success; require link, packets, and no
  kernel instability.
- Do not manually enable parent `periph_intc` bits 16/17; that path produced a
  console-flooding IRQ storm.
- Do not repeat failed DMA paths: plain `DMA_OWN`, ADDRSHIFT8, fatal
  `DMA_BIT_MASK(20)`, Zephyr-style `dma-ranges`, `mem=16M`, or `mem=32M`.
- Do not repeat manual descriptor/producer pokes unless a new kernel-side setup
  change makes them meaningful.
- Keep serial commands short; long pasted lines can be corrupted by serial
  overruns.

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
- plain `DMA_OWN` without compact GENET v1 status packing, including after the
  `9990` DMA regmap fix
- swapped descriptor word order after the `9990` DMA regmap fix
- adjacent descriptor clear around slot 0 after the `9990` DMA regmap fix
- TDMA control bit-only probe with `tdma_ctrl=0x00030001`
- TDMA config/control bit probe with `tdma_cfg=0x00030000` and
  `tdma_ctrl=0x00030001`
- v4 ring register layout on ring16
- manual low16 status poke
- reserved low TX buffer as standalone fix
- generic RGMII OOB poke at `0x12c0008c`
- blind parent IRQ enable
- B53/DSA before TDMA consumes descriptors

<!-- TC7200U_CURRENT_GENET_STATE_END -->
