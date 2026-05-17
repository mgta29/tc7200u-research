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

Continue the GENET descriptor/DMA diagnostic:

- MAC base: `0x12c00000`, size `0x4000`.
- Keep RGMII fixed-link and no B53/DSA for the next diagnostic.
- Keep parent `periph_intc` bits 16/17 unchanged; blind enable causes an IRQ
  storm.
- Verify GENET v1 descriptor ownership, TDMA/RDMA/INTRL2 offsets, and
  `hw_params` before changing switch wiring.
- Next experiment is a GENET v1-only `DMA_OWN` OR test, but only with the
  XMITDESC/TXPOLL debug still active.

Use these notes as the starting evidence:

- `research/notes/source-research/2026-05-15-linux-technicolor-genet-finding.md`
- `research/notes/status/2026-05-16-current-tc7200u-bringup-baseline.md`
- `research/notes/runtime-probes/2026-05-17-genet-txpoll-dma-not-consuming.md`
- `research/notes/runtime-probes/2026-05-17-genet-tx-desc-present-no-tdma-consume.md`
- `research/notes/runtime-probes/2026-05-17-genet-xmitdesc-real-frame-no-tdma-consume.md`

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
