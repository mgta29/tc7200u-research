# TC7200.U Start Here

Last updated: 2026-05-17.

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

Continue the GENET DMA address diagnostic:

- MAC base: `0x12c00000`, size `0x4000`.
- Keep RGMII fixed-link and no B53/DSA for the next diagnostic.
- Keep parent `periph_intc` bits unchanged in the DMA test branch; blind enable
  caused an IRQ storm.
- Do not repeat the old fatal `DMA_BIT_MASK(20)` probe path.
- Next DMA experiment is a reserved low physical TX bounce-buffer diagnostic, a
  BCM3383 GENET DMA window/base/init probe, or a non-fatal 20-bit DMA mask
  diagnostic.
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
