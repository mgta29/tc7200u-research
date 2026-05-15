#!/usr/bin/env bash
set -euo pipefail

OWRT="${OWRT:-$HOME/src/openwrt}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
export RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RESEARCH/research/notes/generated}"
RAW="$OWRT/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin"
WRAPPED="/mnt/c/tftp/openwrt-ps-irqfallback.bin"

latest_vmlinux() {
	find "$OWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268" -path '*/linux-*/vmlinux' -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-
}

VMLINUX="$(latest_vmlinux || true)"

need_build=0
if [ ! -f "$RAW" ]; then
	echo "AUTO: raw initramfs missing; building OpenWrt target/linux."
	need_build=1
elif [ -n "$VMLINUX" ] && [ "$VMLINUX" -nt "$RAW" ]; then
	echo "AUTO: vmlinux is newer than raw initramfs; rebuilding target/linux."
	need_build=1
fi

if [ "$need_build" = "1" ]; then
	cd "$OWRT"
	make target/linux/compile V=s
	make target/linux/install V=s
fi

need_wrap=0
if [ ! -f "$WRAPPED" ]; then
	echo "AUTO: wrapped TFTP image missing; wrapping."
	need_wrap=1
elif [ "$RAW" -nt "$WRAPPED" ]; then
	echo "AUTO: wrapped TFTP image is older than raw initramfs; re-wrapping."
	need_wrap=1
else
	echo "AUTO: wrapped TFTP image is current."
fi

cd "$RESEARCH"
if [ "$need_wrap" = "1" ]; then
	out="$(scripts/tc7200u-wrap-current-openwrt.sh)"
	printf '%s\n' "$out"
	printf '%s\n' "$out" | grep -q 'size_ok=True'
else
	scripts/tc7200u-wrap-current-openwrt.sh | tee /tmp/tc7200u-wrap-check.txt
	grep -q 'size_ok=True' /tmp/tc7200u-wrap-check.txt
fi

echo "AUTO: ready for cfe-tftp. Only TFTP /mnt/c/tftp/openwrt-ps-irqfallback.bin."
