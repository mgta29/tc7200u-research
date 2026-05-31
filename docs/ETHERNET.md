# TC7200.U Ethernet Notes

## Current Conclusion

The current best direction is BCM3383 GENET at `0x12c00000`, not
`bcm6368-enetsw` at `0x14e01000`.

Reason:

- Public TC7200 Linux source maps `14e01000` as HSSPI.
- The same source maps `12c00000` as `brcm,genet-v1`.
- GENET at `12c00000` can probe under OpenWrt and create `eth0`.
- Fixed-link RGMII can report link up and queue a real TX frame.
- The remaining failure is TDMA/descriptor/register behavior before switch
  integration, not basic MAC discovery.

## Exhausted Path

The `bcm6368-enetsw` matrix at `0x14e01000` is exhausted:

- Original IRQ/DMA order: boots, `eth0` exists, no packet I/O.
- DMA swap only: boots, no improvement.
- Interrupt swap only: boots, no improvement.
- Combined DMA and interrupt swap: boots, no improvement.
- Minimal AMAC test: probes but hangs before userspace.

Keep those notes as historical records, but do not continue guessing DMA/IRQ
order on that path.

Relevant notes:

- `records/notes/plans/2026-05-15-next-ethernet-debug-plan.md`
- `records/notes/runtime-probes/2026-05-14-runtime-drivers-no-ethernet.md`
- `records/notes/runtime-probes/2026-05-15-enetsw-combined-swap-negative.md`
- `records/notes/runtime-probes/2026-05-15-amac-minimal-node-hangs-before-userspace.md`

## GENET Evidence

Source finding:

- `records/notes/source-research/2026-05-15-linux-technicolor-genet-finding.md`

Important values from that note:

- MAC: `ethernet@12c00000`
- Compatible: `brcm,genet-v1`
- Register size: `0x4000`
- Interrupts: 16 and 17 through `periph_intc`
- UniMAC MDIO offset: `0x600`
- Vendor setup uses `bcm3383_init_gmac()`.
- Vendor setup calls `bcm3383_pinmux_select(10)` before GMAC init.

High-signal runtime findings:

- `records/notes/runtime-probes/2026-05-15-genet-internal-phy-link-down.md`
- `records/notes/runtime-probes/2026-05-15-bcmgenet-12c00000-negative-result.md`
- `records/notes/runtime-probes/2026-05-17-genet-txpoll-dma-not-consuming.md`
- `records/notes/runtime-probes/2026-05-17-genet-tx-desc-present-no-tdma-consume.md`
- `records/notes/runtime-probes/2026-05-17-genet-xmitdesc-real-frame-no-tdma-consume.md`
- `records/notes/runtime-probes/2026-05-17-genet-corrected-devmem-slot0-no-consume.md`
- `records/notes/runtime-probes/2026-05-17-genet-reserved-low-txbuf-still-no-tdma.md`
- `records/notes/runtime-probes/2026-05-17-genet-ext-periphirq0-2-evidence.md`
- `records/notes/runtime-probes/2026-05-18-genet-hwirq64-active-tdma-still-stuck.md`
- `records/notes/runtime-probes/2026-05-24-flood-no-watchdog-still-no-rx.md`
- `records/notes/runtime-probes/2026-05-24-flood-watchdog-queue-stopped.md`
- `records/notes/runtime-probes/2026-05-24-pktmon-peer-arp-only-no-owrt-egress.md`

Known result:

- Boot reaches userspace.
- `bcmgenet 12c00000.ethernet` probes.
- `eth0` exists.
- UniMAC MDIO appears.
- Internal PHY/GPHY data reads invalid `0x0000`; internal PHY mode is not a
  solved path.
- Fixed-link RGMII reports link up, but TX watchdog repeats.
- XMITDESC shows a real TX frame queued into ring16.
- TXPOLL shows TDMA enabled and hardware producer index 1, but hardware
  consumer index remains 0.
- Compact GENET v1 status/length descriptor packing reads back correctly:
  `wrote_len=0x000e009a`, `rb_len=0x000e009a`.
- Manual slot 0 and slot 1 descriptor rewrites read back correctly but TDMA
  still leaves `hw_c=0`.
- Full ring16 TDMA snapshot shows expected GENET v1 ring setup with
  `DMA_CTRL=0x00020001` and `DMA_STATUS=0`.
- Descriptor/data address reachability is the active blocker: Linux gives DMA
  addresses around `0x06xxxxxx`, while GENET descriptor RAM keeps only low
  20 bits.
- ADDRSHIFT8, `GFP_DMA` coherent bounce, and reserved low TX buffer tests did
  not fix TX.
- Runtime interrupt probing shows active UniMAC0 DMA/status in the extended
  `INT_EXT_PER PeriphIRQ0_2` bank.
- The DTS override maps GENET to hwirqs `64/66`; hwirq `64` counts, hwirq `66`
  remains idle.
- Ring0 is the first positive TDMA movement signal, but ring0 replay does not
  increment TX MIB counters or complete transmission.
- IF0/IF1 UNIMAC config windows are independent, but command behavior remains
  non-functional for upstream MDIO semantics.
- A corrected-subnet traffic run still failed with TX counters increasing, RX
  zero, hwirq `64` increasing, hwirq `66` zero, and ring/global registers in
  the stuck signature.

## Next Test

Next diagnostic should stop repeating ring16 descriptor pokes and focus on the
DMA address/window side of the ring0 stall:

- `phy-mode = "rgmii"`
- no `phy-handle`
- no MDIO child for the DMA diagnostic
- fixed-link, 1000 full-duplex
- compact GENET v1 status/length packing active for comparisons
- ADDRDBG, DESCRB, TXPOLL, and RAW state debug enabled
- `periph_intc` exposes `PeriphIRQ0_2`
- GENET interrupts are `<64>, <66>`
- no parent IRQ manual enable
- no B53/DSA yet

Goal:

- Stop additional raw MDIO command probing for now. The IF0/IF1 branch is
  negative for upstream-style command/data behavior.
- Stop manual descriptor replay and runtime topology pokes unless a new
  kernel-side setup change makes them meaningful.
- Keep parent interrupt masks untouched.
- Move to a kernel-only descriptor-width branch:
  - keep current GENET V1 offsets
  - set `GENET_V1 words_per_bd` from `2` to `3` as a temporary test
  - reboot and compare TDMA/ring signature (`read/cons/prod/write`) and IRQ
    behavior.
- Compare candidate GENET/UBUS DMA translation registers only after each narrow
  kernel-side branch changes a relevant status.
- Read BCM3383 clock/reset state, especially `ClkCtrlUBus`, and compare against
  current `bcm3383_init_gmac()`.
- Keep IRQ `<13 4>` as a separate test branch.
- Add BCM53125/B53 switch description only after GENET TDMA behavior is
  understood.

## Source Mining

The TC72XX LxG1 OEM Linux tree contains BCM3384 `bcmvenet.o` / `bcm_venet.o`
prebuilt objects with debug info. Disassembly shows `bcmvenet_xmit` uses FPM
buffers and DQM queues, not direct GENET TDMA descriptors. Missing low-level
headers referenced by strings/debug data include `fpm_ctrl.h`, `fpm_pool.h`,
`unimac_mbdma.h`, `ioproc_dqm64_blockdef.h`, and `segdma_regs.h`.

Implication: vendor BCM3384 Ethernet may run through VENET + FPM/DQM +
SEGDMA/UNIMAC/IOP, while the current OpenWrt path is forcing direct `bcmgenet`
TDMA ring16.

See:

- `records/notes/runtime-probes/2026-05-18-tc72xx-lxg1-venet-dqm-fpm-findings.md`
- `records/notes/runtime-probes/2026-05-19-unimac-core0-core1-link-toggle-no-delta.md`
- `records/notes/runtime-probes/2026-05-19-77-subnet-ping-fails-ring-static.md`
- `records/notes/runtime-probes/2026-05-19-reset-baseline-12c00000-words4-negative.md`
- `records/notes/runtime-probes/2026-05-18-tc72xx-bfc5-deepmine-negative.md`
