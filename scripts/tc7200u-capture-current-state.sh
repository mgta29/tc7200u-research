#!/bin/sh
set -eu

OWRT="${OWRT:-${OPENWRT:-$HOME/src/openwrt}}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RESEARCH/research/notes/generated}"
RAW="$OWRT/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin"
NAME_MAP="${NAME_MAP:-${TC7200U_NAME_MAP:-}}"
REQUEST_NAME="${REQUEST_NAME:-${TFTP_REQUEST_NAME:-openwrt-initramfs.bin}}"
RESULT_NAME="${RESULT_NAME:-${TFTP_RESULT_NAME:-openwrt-ps-irqfallback.bin}}"
WRAPPED=""
LINUX_DIR="$(find "$OWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268" -maxdepth 1 -type d -name 'linux-*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
LINUX_DIR="${LINUX_DIR:-$OWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-missing}"
VMLINUX="$LINUX_DIR/vmlinux"
SETUPC="$LINUX_DIR/arch/mips/bmips/setup.c"
PATCH="$OWRT/target/linux/bmips/patches-6.12/910-tc7200u-mmio-boot-log.patch"
DTS="$OWRT/target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts"
DTSI="$OWRT/target/linux/bmips/dts/bcm3384_viper.dtsi"

trim_ws() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

parse_name_map() {
    local raw="$1"
    local left=""
    local right=""

    [ -n "$raw" ] || return 0

    case "$raw" in
        *"->"*)
            left="${raw%%->*}"
            right="${raw#*->}"
            ;;
        *"="*)
            left="${raw%%=*}"
            right="${raw#*=}"
            ;;
        *" - "*)
            left="${raw%% - *}"
            right="${raw#* - }"
            ;;
        *)
            echo "FAIL: NAME_MAP must be INPUT=RESULT, INPUT->RESULT, or INPUT - RESULT: $raw" >&2
            exit 2
            ;;
    esac

    REQUEST_NAME="$(trim_ws "$left")"
    RESULT_NAME="$(trim_ws "$right")"
}

parse_name_map "$NAME_MAP"
REQUEST_NAME="$(trim_ws "$REQUEST_NAME")"
RESULT_NAME="$(trim_ws "$RESULT_NAME")"

case "$REQUEST_NAME" in
    ""|*/*|*\\*)
        echo "FAIL: request name must be a plain filename: $REQUEST_NAME" >&2
        exit 2
        ;;
esac
case "$RESULT_NAME" in
    ""|*/*|*\\*)
        echo "FAIL: result name must be a plain filename: $RESULT_NAME" >&2
        exit 2
        ;;
esac

WRAPPED="/mnt/c/tftp/$RESULT_NAME"

TS="$(date +%Y-%m-%d-%H%M%S)"
OUT="$RESEARCH_NOTES_DIR/${TS}-current-state.txt"

mkdir -p "$RESEARCH_NOTES_DIR"

{
    echo "# TC7200U current state"
    echo
    date -Is
    echo
    echo "## Important files"
    echo "OWRT=$OWRT"
    echo "LINUX_DIR=$LINUX_DIR"
    echo "REQUEST_NAME=$REQUEST_NAME"
    echo "RESULT_NAME=$RESULT_NAME"
    ls -lh --time-style=long-iso "$RAW" "$WRAPPED" "$VMLINUX" "$SETUPC" "$PATCH" "$DTS" "$DTSI" 2>&1 || true
    echo
    echo "## SHA256"
    sha256sum "$RAW" "$WRAPPED" "$VMLINUX" "$SETUPC" "$PATCH" "$DTS" "$DTSI" 2>&1 || true
    echo
    echo "## A825 verification"
    "$RESEARCH/scripts/tc7200u-verify-a825-image.py" --raw "$RAW" --wrapped "$WRAPPED" --expect-name "$REQUEST_NAME" 2>&1 || true
    echo
    echo "## MMIO strings in object/vmlinux/raw"
    strings -a "$LINUX_DIR/arch/mips/bmips/setup.o" 2>/dev/null | grep -F 'tc7200u-mmio' || true
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
    grep -Rns "CONFIG_BGMAC\|CONFIG_B53\|CONFIG_NET_DSA\|CONFIG_MDIO_BCM" "$OWRT/.config" "$OWRT/target/linux/bmips/config-6.12" "$OWRT/target/linux/bmips/bcm63268/config-6.12" "$LINUX_DIR/.config" 2>/dev/null || true
} > "$OUT"

echo "$OUT"
