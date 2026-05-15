#!/usr/bin/env bash
set -euo pipefail

OWRT="${OWRT:-$HOME/src/openwrt}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
export RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RESEARCH/research/notes/generated}"
RAW="$OWRT/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin"
WRAPPED="/mnt/c/tftp/openwrt-ps-irqfallback.bin"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 1)}"
TS="$(date +%Y-%m-%d-%H%M%S)"

mkdir -p "$RESEARCH_NOTES_DIR"

latest_vmlinux() {
	find "$OWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268" -path '*/linux-*/vmlinux' -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-
}

run_logged() {
	local log="$1"
	shift
	if ! "$@" >"$log" 2>&1; then
		echo "FAIL: command failed: $*" >&2
		echo "FAIL: log: $log" >&2
		tail -80 "$log" >&2 || true
		exit 1
	fi
}

VMLINUX="$(latest_vmlinux || true)"

need_build=0
if [ ! -f "$RAW" ]; then
	need_build=1
elif [ -n "$VMLINUX" ] && [ "$VMLINUX" -nt "$RAW" ]; then
	need_build=1
fi

if [ "$need_build" = "1" ]; then
	cd "$OWRT"
	run_logged "$RESEARCH_NOTES_DIR/${TS}-make-compile.log" make -j"$JOBS" target/linux/compile V=s
	run_logged "$RESEARCH_NOTES_DIR/${TS}-make-install.log" make -j"$JOBS" target/linux/install V=s
fi

cd "$RESEARCH"

wrap_log="$RESEARCH_NOTES_DIR/${TS}-wrap.log"
if ! scripts/tc7200u-wrap-current-openwrt.sh >"$wrap_log" 2>&1; then
	echo "FAIL: wrap failed: $wrap_log" >&2
	tail -80 "$wrap_log" >&2 || true
	exit 1
fi

if ! grep -q '^size_ok=True$' "$wrap_log"; then
	echo "FAIL: size_ok=True not found in wrap manifest output: $wrap_log" >&2
	tail -80 "$wrap_log" >&2 || true
	exit 1
fi

echo "CHECK OK: size_ok=True"

verify_log="$RESEARCH_NOTES_DIR/${TS}-verify.log"
if ! scripts/tc7200u-verify-a825-image.py --raw "$RAW" --wrapped "$WRAPPED" >"$verify_log" 2>&1; then
	echo "FAIL: verify failed: $verify_log" >&2
	cat "$verify_log" >&2
	exit 1
fi

if ! grep -q '^OK: wrapped a825 image matches raw payload and expected header fields$' "$verify_log"; then
	echo "FAIL: verifier success line missing: $verify_log" >&2
	cat "$verify_log" >&2
	exit 1
fi

grep -m1 '^OK: wrapped a825 image matches raw payload and expected header fields$' "$verify_log"
echo "AUTO: ready for cfe-tftp. Only TFTP /mnt/c/tftp/openwrt-ps-irqfallback.bin."
