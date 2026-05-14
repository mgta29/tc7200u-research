# TC7200U Path Map

## Main repositories

| Purpose | Path |
|---|---|
| OpenWrt source/build tree | `~/src/openwrt` |
| Research repo | `~/tc7200u-research` |
| Windows TFTP root | `/mnt/c/tftp` |
| Serial logs | `~/tc7200u-logs` |

## OpenWrt build outputs

| Purpose | Path |
|---|---|
| Raw initramfs image | `~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin` |
| Build-dir raw initramfs copy | `~/src/openwrt/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/tmp/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin` |
| Kernel ELF | `~/src/openwrt/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.87/vmlinux` |
| BMIPS setup source | `~/src/openwrt/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.87/arch/mips/bmips/setup.c` |
| Persistent MMIO patch | `~/src/openwrt/target/linux/bmips/patches-6.12/910-tc7200u-mmio-boot-log.patch` |
| TC7200U DTS | `~/src/openwrt/target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts` |
| Viper DTSI | `~/src/openwrt/target/linux/bmips/dts/bcm3384_viper.dtsi` |

## TFTP image paths

| Purpose | Path |
|---|---|
| Active CFE/TFTP image | `/mnt/c/tftp/openwrt-ps-irqfallback.bin` |
| A825 wrapper script | `~/tc7200u-research/scripts/tc7200u-a825-wrap.py` |

## Research repo storage

| Purpose | Path |
|---|---|
| Bootable/tested artifacts | `~/tc7200u-research/artifacts/` |
| Serial boot logs | `~/tc7200u-research/logs/` |
| Notes / manifests / summaries | `~/tc7200u-research/notes/` |
| Research helper scripts | `~/tc7200u-research/scripts/` |
| OpenWrt patch copies | `~/tc7200u-research/patches/openwrt-bmips/` |
