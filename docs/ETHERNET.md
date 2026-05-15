# TC7200.U Ethernet Notes

## Current conclusion

The current best direction is BCM3383 GENET at `0x12c00000`, not
`bcm6368-enetsw` at `0x14e01000`.

Reason:

- Public TC7200 Linux source maps `14e01000` as HSSPI.
- The same source maps `12c00000` as `brcm,genet-v1`.
- GENET at `12c00000` can probe under OpenWrt and create `eth0`.
- The remaining failure is PHY/switch/link configuration, not basic MAC
  discovery.

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

Known result:

- Boot reaches userspace.
- `bcmgenet 12c00000.ethernet` probes.
- `eth0` exists.
- UniMAC MDIO appears.
- Internal PHY/GPHY data reads as invalid `0x0000`.
- Link stays down.
- One GENET image later showed memory/page-table corruption and is not a stable
  baseline.

## Next test

Next diagnostic should avoid internal PHY mode:

- `phy-mode = "rgmii"`
- no `phy-handle`
- no MDIO child for the first diagnostic
- fixed-link, 1000 full-duplex

Goal:

- Determine whether GENET can start without being blocked by invalid internal
  PHY setup.
- Watch for TX packets, DMA/IRQ activity, and memory corruption.
- If the fixed-link diagnostic is stable, add proper BCM53125/B53 switch
  description next.

## Guardrails

- RAM boot only.
- Do not flash.
- Preserve serial logs under `evidence/serial/`.
- Preserve generated manifests and state captures under `research/notes/generated/`.
- Do not treat `eth0` existence alone as success; require link, packets, and no
  kernel instability.
