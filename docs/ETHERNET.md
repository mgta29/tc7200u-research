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
- Descriptor/data address reachability is the active blocker:
  Linux gives DMA addresses around `0x06xxxxxx`, while GENET descriptor RAM
  keeps only low 20 bits.
- ADDRSHIFT8 wrote/read back the shifted address but still left `hw_c=0`.
- `dma_alloc_coherent(... GFP_DMA)` bounce allocation still produced high DMA:
  `bounce_dma=0x06e01000`, descriptor `rb_addr=0x00001000`, `hw_c=0`.
- Ring16 metadata is sane enough to show one posted descriptor, and global
  `TDMA_STATUS=0x00000000` reports no useful global error.
- Some GENET images previously showed memory/page-table corruption and are not
  stable baselines.

## Next test

Next diagnostic should stay focused on TDMA descriptor consumption through the
DMA address branch:

- `phy-mode = "rgmii"`
- no `phy-handle`
- no MDIO child for the DMA diagnostic
- fixed-link, 1000 full-duplex
- compact GENET v1 status/length packing active
- ADDRDBG, DESCRB, and TXPOLL debug enabled
- no parent IRQ manual enable
- no B53/DSA yet

Goal:

- Prove whether Linux can produce a DMA address that GENET descriptor RAM can
  represent and TDMA can consume.
- Run the non-fatal 20-bit DMA mask diagnostic, or test a reserved low physical
  TX bounce buffer.
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
- Keep serial commands short; long pasted lines can be corrupted by serial
  overruns.
