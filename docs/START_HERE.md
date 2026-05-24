# TC7200.U Start Here

Last updated: 2026-05-19.

## Current state

OpenWrt can RAM boot over CFE/TFTP and reach a serial shell on the
Technicolor TC7200.U / BCM3383 platform. This is not a flashable system.

Solved:

- CFE/TFTP RAM boot with the known-good rescue image.
- Serial console TX/RX after enabling `CONFIG_BCM7120_L2_IRQ=y`.
- A825 ProgramStore wrapper generation and verification.
- Kernel-side MMIO probing through `ioremap()` and `printk()`.

Current blocker:

- Ethernet bring-up. GENET at `0x12c00000` is the current hardware direction,
  fixed-link reports up, and a real TX frame is queued, but TDMA does not
  consume the descriptor.
- Compact GENET v1 status/length descriptor packing now reads back correctly:
  `wrote_len=0x000e009a`, `rb_len=0x000e009a`.
- The active blocker is descriptor/data address reachability:
  Linux maps TX buffers around `0x06xxxxxx`, but GENET descriptor RAM keeps only
  low 20 address bits, for example `0x06e01000 -> 0x00001000`.
- TDMA ring16 shows producer index 1 and consumer index 0, with global
  `TDMA_STATUS=0x00000000`.
- Manual descriptor devmem probes now reached producer index 2 with both slot 0
  and slot 1 populated, but `TDMA_READ_PTR` and `TDMA_CONS_INDEX` stayed 0.
- Ring16/global TDMA register setup looks sane for GENET v1, so stop repeating
  manual descriptor pokes until a kernel-side DMA setup change is made.
- Reserved TX buffer test mapped physical `0x01680000` and forced TX
  descriptors to that buffer, but descriptor readback still used only
  `0x00080000` and TDMA still left `hw_c=0`.
- IF0/IF1 UNIMAC probing confirms separate interface windows
  (`0x12c00618` and `0x12c02618` are not mirrored), but command paths remain
  non-functional for upstream-style MDIO command/data behavior.
- Ring retests still return the same stuck signature:
  `0x12c03800=0x00010003`, `0x12c03804=0x00000028`,
  `0x12c03808=0x00010000`, `0x12c0380c=0x00000000`,
  `0x12c03c40/44/48=1/1/1`; IRQ `64` counts, IRQ `66` stays idle.
- A corrected-subnet follow-up (`192.168.77.1 -> 192.168.77.2`) captured a
  second stuck ring-window signature:
  `0x12c02c08/0x12c03c08=0x00000000`,
  `0x12c02c0c/0x12c03c0c=0x06f850c0`,
  `0x12c02c20/0x12c03c20=0x00000000`.
  RX remained zero, TX errors increased, and IRQ behavior stayed `64` active /
  `66` idle.
- A pre/post descriptor snapshot under `ping -c 3` was fully invariant:
  ring window fields and `0x12c03000..0x12c0300c` did not change at all
  (sampled value set included `0x06e72140` at `0x12c02c0c/0x12c03c0c`),
  while RX stayed zero and `66` remained idle.
- A pointer check then showed `0x12c02c0c/0x12c03c0c` is not a readable alias
  of the descriptor window: both returned `0x06e76d40`, while direct `devmem`
  at that address read back `0xff...` bus-fill values.
- A follow-up cycle test showed this field changes on `eth0` reinit
  (`0x06f197c0 -> 0x06e73dc0`) but stays static during traffic; sampled
  descriptor words still do not change.
- A standalone `eth0 nomaster` run is also negative with the same signature:
  RX zero, hwirq `64` only, hwirq `66` idle, sampled pointer/descriptor words
  unchanged across PRE/POST.
- A direct CORE0/CORE1 down-vs-up probe is also static:
  `0x12c00808/0x12c00814` and `0x12c02808/0x12c02814` do not change across
  link toggle, so they are not a useful active-path discriminator.

Do not work on:

- Flashing.
- Persistent image installation.
- MTD or partition writes.
- More `bcm6368-enetsw` DMA/IRQ swaps at `0x14e01000`.

## Safe resume checklist

1. Read [Safety](SAFETY.md).
2. Confirm the active TFTP file is still `/mnt/c/tftp/openwrt-ps-irqfallback.bin`.
3. Preserve all images under `artifacts/rescue/`.
4. Build OpenWrt first.
5. Wrap with `tcwrap` or `scripts/tc7200u wrap`.
6. TFTP only if the manifest reports `size_ok=True`.
7. Keep all tests RAM boot only.
8. Save generated captures under `research/notes/generated/`.

## Next technical action

Continue the GENET TDMA diagnostic:

- MAC base: `0x12c00000`, size `0x4000`.
- Keep RGMII fixed-link and no B53/DSA for the next diagnostic.
- Keep parent `periph_intc` bits unchanged in the DMA test branch; blind enable
  caused an IRQ storm.
- Pause raw MDIO command probing for now; IF0/IF1 command-path branch is
  negative.
- Do not repeat the old fatal `DMA_BIT_MASK(20)` probe path.
- Next kernel branch set: temporary `GENET_V1 words_per_bd` change from `2` to
  `3`, plus strict v1 BD/OWN handling validation. Runtime register pokes are
  now considered exhausted.
- After descriptor-width result, continue BCM3383 GENET DMA window/base/init
  probing. Read `ClkCtrlUBus` first; current `bcm3383_init_gmac()` enables
  GMAC low/high clocks and reset but not the named UBUS GMAC clock bit.
- IRQ `<13 4>` remains a separate branch and must not be combined with DMA
  address tests.

Use these notes as the starting evidence:

- `docs/MEMORY_MAP.md`
- `research/notes/source-research/2026-05-17-similar-firmware-useful-map-data.md`
- `research/notes/source-research/2026-05-15-linux-technicolor-genet-finding.md`
- `research/notes/status/2026-05-16-current-tc7200u-bringup-baseline.md`
- `research/notes/runtime-probes/2026-05-17-genet-txpoll-dma-not-consuming.md`
- `research/notes/runtime-probes/2026-05-17-genet-tx-desc-present-no-tdma-consume.md`
- `research/notes/runtime-probes/2026-05-17-genet-xmitdesc-real-frame-no-tdma-consume.md`
- `research/notes/runtime-probes/2026-05-17-genet-corrected-devmem-slot0-no-consume.md`
- `research/notes/runtime-probes/2026-05-17-genet-reserved-low-txbuf-still-no-tdma.md`

## Current commands

```sh
tcresearch
tcstatus
tcwrap
cfe-tftp
tcstate
```

Only continue to CFE/TFTP when the wrapper output contains:

```text
size_ok=True
```

<!-- TC7200U_CURRENT_GENET_STATE_START -->

## Current GENET state — 2026-05-19

Latest conclusion:

- GENET at `0x12c00000` probes and `eth0` link reports up.
- TDMA/ring remains stuck with repeated signature:
  `0x12c03800=0x00010003`, `0x12c03804=0x00000028`,
  `0x12c03808=0x00010000`, `0x12c0380c=0x00000000`,
  `0x12c03c40/44/48=1/1/1`.
- A second stuck signature also appears in the `0x12c02cxx/0x12c03cxx` windows:
  `+0x08=0x00000000`, `+0x0c=0x06f850c0`, `+0x20=0x00000000` on both
  windows, with RX still zero and TX errors increasing.
- IRQ behavior is unchanged: hwirq `64` increments, hwirq `66` remains idle.
- IF0/IF1 UNIMAC interface config windows are independent:
  `0x12c00618` and `0x12c02618` are not mirrored.
- IF0/IF1 command-path probing is negative for upstream-style MDIO semantics:
  IF0 command retains busy-like values, IF1 command collapses to `0x28000000`,
  and nearby status/data candidates do not move.
- CORE0/CORE1 UMAC down/up probe is also negative as a discriminator:
  `0x12c00808/0x12c00814` and `0x12c02808/0x12c02814` are unchanged across
  link down/up while hwirq `64` continues to increment.
- Raw MDIO reverse-engineering is paused for now.
- Next branch is kernel-side descriptor-width test only:
  temporary `GENET_V1 words_per_bd` from `2` to `3`, offsets unchanged.

Current intended OpenWrt patch state for the next test:

- Active baseline:
  - GENET at `0x12c00000`
  - interrupts `<64>, <66>`
  - fixed-link RGMII diagnostic setup
  - no new runtime MDIO poke scripts
- Next code change:
  - temporary `GENET_V1 words_per_bd = 3` test branch

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

<!-- TC7200U_CURRENT_GENET_STATE_END -->


## Current Ethernet research note

The TC72XX LxG1 OEM tree suggests the vendor BCM3384 Ethernet path is VENET + FPM/DQM + SEGDMA/UNIMAC/IOP, not direct upstream `bcmgenet` TDMA. This may explain why direct GENET TDMA ring16 remains stuck.

See: `research/notes/runtime-probes/2026-05-18-tc72xx-lxg1-venet-dqm-fpm-findings.md`.
See also: `research/notes/runtime-probes/2026-05-19-unimac-if0-if1-mdio-command-path-negative.md`.
See also:
`research/notes/runtime-probes/2026-05-19-unimac-core0-core1-link-toggle-no-delta.md`.

## TC72XX source mining state

`tc72xx-bfc5` deep mining is negative for the Ethernet blocker. The useful OEM clue remains from LxG1: BCM3384 vendor Ethernet may use VENET + FPM/DQM + SEGDMA/UNIMAC/IOP, but BFC5 does not expose that layer.

See: `research/notes/runtime-probes/2026-05-18-tc72xx-bfc5-deepmine-negative.md`.
