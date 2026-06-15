# TC7200U Path Map

## Main Repositories

| Purpose | Path |
|---|---|
| OpenWrt source/build tree | `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt` |
| Research repo | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research` |
| Windows TFTP root via WSL | `\\wsl.localhost\Ubuntu\mnt\c\tftp` |

## OpenWrt Build Outputs

| Purpose | Path |
|---|---|
| Raw initramfs image | `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt\bin\targets\bmips\bcm63268\openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin` |
| Build-dir raw initramfs copy | `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt\build_dir\target-mips_mips32_musl\linux-bmips_bcm63268\tmp\openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin` |
| Kernel ELF | `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt\build_dir\target-mips_mips32_musl\linux-bmips_bcm63268\linux-6.12.87\vmlinux` |
| BMIPS setup source | `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt\build_dir\target-mips_mips32_musl\linux-bmips_bcm63268\linux-6.12.87\arch\mips\bmips\setup.c` |
| TC7200U DTS | `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt\target\linux\bmips\dts\bcm3383-technicolor-tc7200u.dts` |
| Viper DTSI | `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt\target\linux\bmips\dts\bcm3384_viper.dtsi` |

## TFTP And Helper Paths

| Purpose | Path |
|---|---|
| Active CFE/TFTP image | `\\wsl.localhost\Ubuntu\mnt\c\tftp\openwrt-ps-irqfallback.bin` |
| Main helper script | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tcbuilder.sh` |
| Helper module directory | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tcbuilder` |
| WSL-safe PowerShell wrapper | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\wsl-safe.ps1` |
| Wrapper manifest output | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\generated` |
| Host-side TFTP proof captures | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\tftp` |
| Live Ghidra workspace | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\reverse\d60242_ghidra` |

## Records Storage

| Purpose | Path |
|---|---|
| Bring-up notes | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up` |
| Ethernet notes | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet` |
| Flash notes | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\flash` |
| Image-format notes | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format` |
| Runtime-probe notes | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes` |
| Source-research notes | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research` |
| Status and provenance notes | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status` |
| Reverse-engineering notes and artifacts | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse` |
| Serial boot logs | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial` |
| CFE and recovery logs | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\cfe` |
| Devmem/devmen logs | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\devmen` |
| Host-side TFTP and packet proof logs | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\tftp\<YYYY-MM-DD-version>` |
| Build/install/wrap/verify logs | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds` |
| Generated manifests and captures | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\generated` |
| DTS/config/source snapshots | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\snapshots` |
| Network scans | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\network-scans` |
| Pre-edit backups | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\backups` |
| Rescue images | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\artifacts\rescue` |
| Test images | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\artifacts\test-images` |
| Invalid comparison images | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\artifacts\invalid` |
| Helper scripts | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts` |
| OpenWrt patch copies | `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\patches` |

`records/notes/` is a wrong legacy path and should not receive new files.
