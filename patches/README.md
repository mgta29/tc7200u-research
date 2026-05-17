# Patches

This directory stores patch copies and OpenWrt state snapshots used during
bring-up.

## Layout

- `openwrt-bmips/`: BMIPS/OpenWrt patch copies.
- `openwrt-bmips/experiments/`: dated diagnostic patch sets that are useful
  evidence but not current baseline patches.
- `disabled/`: disabled patch history.
- Top-level patch/config files: current working copies captured from OpenWrt.

## Current diagnostic patch snapshots

- `openwrt-bmips/996-bcmgenet-tc7200u-xmit-desc-debug.patch`: temporary
  descriptor logging around `bcmgenet_xmit()`.
- `openwrt-bmips/997-bcmgenet-tc7200u-tx-poll-debug.patch`: temporary TX
  timeout/TXPOLL logging without parent IRQ enable.
- `openwrt-bmips/998-bmips-tc7200u-gmac-init.patch`: TC7200.U BCM3383 GMAC
  pinmux, clock, and reset quirk.
- `openwrt-bmips/999-bcm63xx-uart-tc7200u-console.patch`: TC7200.U UART probe
  fallback.
- `openwrt-bmips/110-net-dsa-b53-bcm531x5-fix-cpu-rgmii-mode-interpretation.patch`:
  B53/BCM53125 CPU-port RGMII behavior patch retained for later switch work.

These files are research snapshots of the live OpenWrt tree. The `996` and
`997` patches are diagnostic-only and should not be treated as production
OpenWrt changes.

## Dated experiment patch sets

- `openwrt-bmips/experiments/2026-05-17-genet-dma-own-test/`: descriptor
  ownership and TX poll experiments.
- `openwrt-bmips/experiments/2026-05-17-genet-dma-address-tests/`: descriptor
  packing, DMA address, and bounce-buffer experiments.

## Old path map

| Old path | New path |
|---|---|
| `openwrt-patches/776-net-bgmac-platform-allow-bmips.patch` | `patches/openwrt-bmips/776-net-bgmac-platform-allow-bmips.patch` |
| `disabled-patches/openwrt-bmips/910-tc7200u-mmio-boot-log.patch.disabled` | `patches/disabled/openwrt-bmips/910-tc7200u-mmio-boot-log.patch.disabled` |
| `artifacts/openwrt-patches/998-bmips-tc7200u-gmac-init.patch` | duplicate removed; canonical copy is `patches/openwrt-bmips/998-bmips-tc7200u-gmac-init.patch` |
| `research/artifacts/openwrt-patches/2026-05-17-genet-dma-address-tests/` | `patches/openwrt-bmips/experiments/2026-05-17-genet-dma-address-tests/` |
| `research/patches/openwrt/2026-05-17-genet-dma-own-test/` | `patches/openwrt-bmips/experiments/2026-05-17-genet-dma-own-test/` |

The live OpenWrt tree remains `~/src/openwrt`; these files are repo evidence and
working copies, not proof that the OpenWrt tree has been updated.
