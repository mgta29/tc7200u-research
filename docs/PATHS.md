# TC7200U Path Map

## Main Repositories

| Purpose | Path |
|---|---|
| OpenWrt source/build tree | `~/src/openwrt` |
| Research repo | `~/tc7200u-research` |
| Windows TFTP root | `/mnt/c/tftp` |

## OpenWrt Build Outputs

| Purpose | Path |
|---|---|
| Raw initramfs image | `~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin` |
| Build-dir raw initramfs copy | `~/src/openwrt/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/tmp/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin` |
| Kernel ELF | `~/src/openwrt/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.87/vmlinux` |
| BMIPS setup source | `~/src/openwrt/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.87/arch/mips/bmips/setup.c` |
| TC7200U DTS | `~/src/openwrt/target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts` |
| Viper DTSI | `~/src/openwrt/target/linux/bmips/dts/bcm3384_viper.dtsi` |

## TFTP And Helper Paths

| Purpose | Path |
|---|---|
| Active CFE/TFTP image | `/mnt/c/tftp/openwrt-ps-irqfallback.bin` |
| Main helper script | `~/tc7200u-research/scripts/tcbuilder.sh` |
| Wrapper manifest output | `~/tc7200u-research/records/generated/` |
| Host-side TFTP proof captures | `~/tc7200u-research/records/logs/tftp/` |
| Host-side PowerShell run scripts | `~/tc7200u-research/scripts/tftp/` |
| OpenWrt picocom send command files | `~/tc7200u-research/scripts/picocom-cmd/` |

## Records Storage

| Purpose | Path |
|---|---|
| Notes and summaries | `~/tc7200u-research/records/notes/` |
| Serial boot logs | `~/tc7200u-research/records/logs/serial/` |
| CFE and recovery logs | `~/tc7200u-research/records/logs/cfe/` |
| Host-side TFTP and packet proof logs | `~/tc7200u-research/records/logs/tftp/<YYYY-MM-DD-version>/` |
| Build/install/wrap/verify logs | `~/tc7200u-research/records/logs/builds/` |
| Generated manifests and captures | `~/tc7200u-research/records/generated/` |
| DTS/config/source snapshots | `~/tc7200u-research/records/snapshots/` |
| Network scans | `~/tc7200u-research/records/network-scans/` |
| Pre-edit backups | `~/tc7200u-research/records/backups/` |
| Rescue images | `~/tc7200u-research/records/artifacts/rescue/` |
| Test images | `~/tc7200u-research/records/artifacts/test-images/` |
| Invalid comparison images | `~/tc7200u-research/records/artifacts/invalid/` |
| Reverse-engineering output | `~/tc7200u-research/records/reverse/` |
| Helper script and snippets | `~/tc7200u-research/scripts/` |
| OpenWrt patch copies | `~/tc7200u-research/patches/` |
