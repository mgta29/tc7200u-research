# TC7200.U Start Here

Last updated: 2026-06-20.

## Current State

OpenWrt can boot from CFE/TFTP and reach a serial shell on the Technicolor
TC7200.U / BCM3383 platform. The active blocker remains Ethernet bring-up.

Working pieces:

- CFE/TFTP boot with the known-good image.
- Serial console TX/RX with `CONFIG_BCM7120_L2_IRQ=y`.
- A825 ProgramStore wrapper generation with internal verification through
  `./scripts/programstore.sh`.
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

Build OpenWrt manually, then wrap the payload directly.

```sh
cd ~/src/openwrt
make -j"$(nproc)" target/linux/install V=s
cd ~/tc7200u-research
./scripts/programstore.sh \
  --input ~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin \
  --output /mnt/c/tftp/openwrt-ps-irqfallback.bin \
  --filename openwrt-initramfs.bin \
  --preserve-from ./records/artifacts/rescue/tc7200-stage2-console-good.bin \
  --fresh-header
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

