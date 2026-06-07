# TC7200.U Start Here

Last updated: 2026-05-31.

## Current State

OpenWrt can boot from CFE/TFTP and reach a serial shell on the Technicolor
TC7200.U / BCM3383 platform. The active blocker is Ethernet bring-up.

Working pieces:

- CFE/TFTP boot with the known-good image.
- Serial console TX/RX with `CONFIG_BCM7120_L2_IRQ=y`.
- A825 ProgramStore wrapper generation and verification.
- Kernel-side MMIO probing through `ioremap()` and `printk()`.

Current Ethernet blocker:

- GENET at `0x12c00000` probes and creates `eth0`.
- Fixed-link RGMII reports link up.
- TX frames are queued, but TDMA does not consume descriptors.
- RX stays zero in paired serial and host packet captures.
- IRQ `64` increments; IRQ `66` remains idle.
- Runtime register pokes and manual descriptor replay are exhausted unless a
  kernel-side setup branch changes the state.

## Resume Checklist

Running `tcbuild` in a terminal opens the interactive menu by default. Choose
`1` for the auto build/wrap/verify path.

```sh
tcresearch
tcstatus
tcbuild
cfe-tftp
tcstate
```

Before serving the image, confirm the wrapper output contains:

```text
size_ok=True
```

Active CFE/TFTP path:

```text
/mnt/c/tftp/openwrt-ps-irqfallback.bin
```

Generated captures and manifests go to:

```text
records/generated/
```

Serial logs go to:

```text
records/logs/serial/
```

## Next Technical Action

Continue the GENET TDMA diagnostic:

- MAC base: `0x12c00000`, size `0x4000`.
- Keep RGMII fixed-link and no B53/DSA for the next diagnostic.
- Keep parent `periph_intc` bits unchanged in the DMA test branch; blind enable
  caused an IRQ storm.
- Pause raw MDIO command probing for now; IF0/IF1 command-path branch is
  negative.
- Do not repeat the old fatal `DMA_BIT_MASK(20)` probe path.
- Next kernel branch set: temporary `GENET_V1 words_per_bd` change from `2` to
  `3`, plus strict v1 BD/OWN handling validation.
- After descriptor-width result, continue BCM3383 GENET DMA window/base/init
  probing. Read `ClkCtrlUBus` first; current `bcm3383_init_gmac()` enables
  GMAC low/high clocks and reset but not the named UBUS GMAC clock bit.
- IRQ `<13 4>` remains a separate branch and must not be combined with DMA
  address tests.

High-signal records:

- `docs/MEMORY_MAP.md`
- `records/notes/source-research/2026-05-17-similar-firmware-useful-map-data.md`
- `records/notes/source-research/2026-05-15-linux-technicolor-genet-finding.md`
- `records/notes/status/2026-05-16-current-tc7200u-bringup-baseline.md`
- `records/notes/runtime-probes/2026-05-17-genet-txpoll-dma-not-consuming.md`
- `records/notes/runtime-probes/2026-05-17-genet-tx-desc-present-no-tdma-consume.md`
- `records/notes/runtime-probes/2026-05-17-genet-xmitdesc-real-frame-no-tdma-consume.md`
- `records/notes/runtime-probes/2026-05-17-genet-corrected-devmem-slot0-no-consume.md`
- `records/notes/runtime-probes/2026-05-17-genet-reserved-low-txbuf-still-no-tdma.md`

## Current GENET State

Latest conclusion:

- GENET at `0x12c00000` probes and `eth0` link reports up.
- TDMA/ring remains stuck with repeated signature:
  `0x12c03800=0x00010003`, `0x12c03804=0x00000028`,
  `0x12c03808=0x00010000`, `0x12c0380c=0x00000000`,
  `0x12c03c40/44/48=1/1/1`.
- A second stuck signature appears in the `0x12c02cxx/0x12c03cxx` windows:
  `+0x08=0x00000000`, `+0x0c=0x06f850c0`, `+0x20=0x00000000` on both
  windows, with RX still zero and TX errors increasing.
- IF0/IF1 UNIMAC interface config windows are independent:
  `0x12c00618` and `0x12c02618` are not mirrored.
- IF0/IF1 command-path probing is negative for upstream-style MDIO semantics.
- Raw MDIO reverse-engineering is paused for now.
- Next branch is kernel-side descriptor-width test only:
  temporary `GENET_V1 words_per_bd` from `2` to `3`, offsets unchanged.

Do not repeat:

- `mem=16M` / `mem=32M`
- fatal or non-fatal `DMA_BIT_MASK(20)`
- `GFP_DMA` coherent bounce
- `ADDRSHIFT8`
- `LOWLIT 0x00080000`
- manual low16 status poke
- reserved low TX buffer as standalone fix
- blind parent IRQ enable
- B53/DSA before TDMA consumes descriptors

## Source Mining State

The TC72XX LxG1 OEM tree suggests the vendor BCM3384 Ethernet path is VENET +
FPM/DQM + SEGDMA/UNIMAC/IOP, not direct upstream `bcmgenet` TDMA. This may
explain why direct GENET TDMA ring16 remains stuck.

See:

- `records/notes/runtime-probes/2026-05-18-tc72xx-lxg1-venet-dqm-fpm-findings.md`
- `records/notes/runtime-probes/2026-05-19-unimac-if0-if1-mdio-command-path-negative.md`
- `records/notes/runtime-probes/2026-05-19-unimac-core0-core1-link-toggle-no-delta.md`
- `records/notes/runtime-probes/2026-05-18-tc72xx-bfc5-deepmine-negative.md`
