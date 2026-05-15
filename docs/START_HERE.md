# TC7200.U Start Here

Last updated: 2026-05-15.

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
  but link/PHY/switch wiring is not solved.

Do not work on:

- Flashing.
- Persistent image installation.
- MTD or partition writes.
- More `bcm6368-enetsw` DMA/IRQ swaps at `0x14e01000`.

## Safe resume checklist

1. Read [Safety](SAFETY.md).
2. Confirm the active TFTP file is still `/mnt/c/tftp/openwrt-ps-irqfallback.bin`.
3. Preserve `artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`.
4. Build OpenWrt first.
5. Wrap with `scripts/tc7200u-wrap-current-openwrt.sh`.
6. TFTP only if the manifest reports `size_ok=True`.
7. Keep all tests RAM boot only.
8. Save generated captures under `research/notes/generated/`.

## Next technical action

Test a safer GENET diagnostic node:

- MAC base: `0x12c00000`, size `0x4000`.
- Avoid internal PHY mode for the next diagnostic.
- Try an RGMII/fixed-link setup to see whether GENET can start without the
  invalid internal PHY/GPHY path.
- Add BCM53125/B53 switch description only after the GENET diagnostic result is
  understood.

Use these notes as the starting evidence:

- `research/notes/source-research/2026-05-15-linux-technicolor-genet-finding.md`
- `research/notes/runtime-probes/2026-05-15-genet-internal-phy-link-down.md`
- `research/notes/runtime-probes/2026-05-15-bcmgenet-12c00000-negative-result.md`

## Current commands

```sh
cd ~/src/openwrt
make target/linux/compile V=s
make target/linux/install V=s

cd ~/tc7200u-research
scripts/tc7200u-wrap-current-openwrt.sh
```

Only continue to CFE/TFTP when the wrapper output contains:

```text
size_ok=True
```
