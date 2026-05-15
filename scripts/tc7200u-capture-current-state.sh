#!/bin/sh
set -eu

OPENWRT="$HOME/src/openwrt"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RESEARCH/research/notes/generated}"
RAW="$OPENWRT/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin"
WRAPPED="/mnt/c/tftp/openwrt-ps-irqfallback.bin"
VMLINUX="$OPENWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.87/vmlinux"
SETUPC="$OPENWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.87/arch/mips/bmips/setup.c"
PATCH="$OPENWRT/target/linux/bmips/patches-6.12/910-tc7200u-mmio-boot-log.patch"
DTS="$OPENWRT/target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts"
DTSI="$OPENWRT/target/linux/bmips/dts/bcm3384_viper.dtsi"

TS="$(date +%Y-%m-%d-%H%M%S)"
OUT="$RESEARCH_NOTES_DIR/${TS}-current-state.txt"

mkdir -p "$RESEARCH_NOTES_DIR"

{
    echo "# TC7200U current state"
    echo
    date -Is
    echo
    echo "## Important files"
    ls -lh --time-style=long-iso "$RAW" "$WRAPPED" "$VMLINUX" "$SETUPC" "$PATCH" "$DTS" "$DTSI" 2>&1 || true
    echo
    echo "## SHA256"
    sha256sum "$RAW" "$WRAPPED" "$VMLINUX" "$SETUPC" "$PATCH" "$DTS" "$DTSI" 2>&1 || true
    echo
    echo "## A825 verification"
    "$RESEARCH/scripts/tc7200u-verify-a825-image.py" --raw "$RAW" --wrapped "$WRAPPED" 2>&1 || true
    echo
    echo "## MMIO strings in object/vmlinux/raw"
    strings -a "$OPENWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.87/arch/mips/bmips/setup.o" 2>/dev/null | grep -F 'tc7200u-mmio' || true
    echo
    strings -a "$VMLINUX" 2>/dev/null | grep -F 'tc7200u-mmio' || true
    echo
    strings -a "$RAW" 2>/dev/null | grep -F 'tc7200u-mmio' || true
    echo
    echo "## Current MMIO probe list in build source"
    grep -nA40 'static const phys_addr_t addrs' "$SETUPC" 2>&1 || true
    echo
    echo "## Current MMIO probe list in persistent patch"
    grep -nA60 'static int __init __used tc7200u_mmio_boot_log' "$PATCH" 2>&1 || true
    echo
    echo "## Network-related config"
    grep -Rns "CONFIG_BGMAC\|CONFIG_B53\|CONFIG_NET_DSA\|CONFIG_MDIO_BCM" "$OPENWRT/.config" "$OPENWRT/target/linux/bmips/config-6.12" "$OPENWRT/target/linux/bmips/bcm63268/config-6.12" "$OPENWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.87/.config" 2>/dev/null || true
} > "$OUT"

echo "$OUT"
