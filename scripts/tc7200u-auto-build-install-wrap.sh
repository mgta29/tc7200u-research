#!/usr/bin/env bash
set -euo pipefail

OWRT="${OWRT:-$HOME/src/openwrt}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RESEARCH/research/notes/generated}"
RAW="$OWRT/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin"
WRAPPED="/mnt/c/tftp/openwrt-ps-irqfallback.bin"
A825WRAP="$RESEARCH/scripts/tc7200u-a825-wrap.py"
A825VERIFY="$RESEARCH/scripts/tc7200u-verify-a825-image.py"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 1)}"
TS="$(date +%Y-%m-%d-%H%M%S)"
STEP=0
TOTAL_STEPS=7

mkdir -p "$RESEARCH_NOTES_DIR"
mkdir -p "$(dirname "$WRAPPED")"

progress() {
	STEP=$((STEP + 1))
	printf '[%d/%d] %s\n' "$STEP" "$TOTAL_STEPS" "$*"
}

progress_note() {
	printf '      %s\n' "$*"
}

latest_vmlinux() {
	find "$OWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268" -path '*/linux-*/vmlinux' -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-
}

newer_build_input() {
	local found=""
	local linux_tree
	local target_paths=(
		"$OWRT/target/linux/bmips/bcm63268/config-6.12"
		"$OWRT/target/linux/bmips/config-6.12"
		"$OWRT/target/linux/bmips/dts"
		"$OWRT/target/linux/bmips/image"
		"$OWRT/target/linux/bmips/patches-6.12"
	)

	found="$(find "${target_paths[@]}" -type f -newer "$RAW" -print -quit 2>/dev/null || true)"
	if [ -n "$found" ]; then
		printf '%s\n' "$found"
		return 0
	fi

	for linux_tree in "$OWRT"/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-*; do
		[ -d "$linux_tree" ] || continue
		found="$(
			find \
				"$linux_tree/arch/mips/bmips" \
				"$linux_tree/drivers/net/ethernet/broadcom/genet" \
				-type f \( -name '*.c' -o -name '*.h' -o -name '*.dts' -o -name '*.dtsi' \) \
				-newer "$RAW" -print -quit 2>/dev/null || true
		)"
		if [ -n "$found" ]; then
			printf '%s\n' "$found"
			return 0
		fi
	done

	return 1
}

run_logged() {
	local log="$1"
	shift
	progress_note "log: $log"
	if ! "$@" >"$log" 2>&1; then
		echo "FAIL: command failed: $*" >&2
		echo "FAIL: log: $log" >&2
		tail -80 "$log" >&2 || true
		exit 1
	fi
}

if [ ! -x "$A825WRAP" ]; then
	echo "FAIL: missing executable wrapper: $A825WRAP" >&2
	exit 1
fi
if [ ! -x "$A825VERIFY" ]; then
	echo "FAIL: missing executable verifier: $A825VERIFY" >&2
	exit 1
fi

progress "Inspecting OpenWrt build outputs"
VMLINUX="$(latest_vmlinux || true)"
if [ -n "$VMLINUX" ]; then
	progress_note "latest vmlinux: $VMLINUX"
else
	progress_note "latest vmlinux: not found yet"
fi

progress "Capturing OpenWrt config before debug package check"
config_before="$RESEARCH_NOTES_DIR/${TS}-openwrt-config-before-debug-packages"
config_after="$RESEARCH_NOTES_DIR/${TS}-openwrt-config-after-debug-packages"
cp "$OWRT/.config" "$config_before"
progress_note "saved: $config_before"

progress "Ensuring TC7200U debug package selection"
run_logged "$RESEARCH_NOTES_DIR/${TS}-ensure-debug-packages.log" "$RESEARCH/scripts/tc7200u-ensure-debug-packages.sh"

cp "$OWRT/.config" "$config_after"
progress_note "saved: $config_after"

progress "Checking whether image rebuild is needed"
need_build=0
stale_input=""
if ! cmp -s "$config_before" "$config_after"; then
	progress_note "debug package config changed"
	need_build=1
fi

if [ ! -f "$RAW" ]; then
	progress_note "raw initramfs missing"
	need_build=1
elif [ "$OWRT/.config" -nt "$RAW" ]; then
	progress_note "OpenWrt .config is newer than raw initramfs"
	need_build=1
elif [ -n "$VMLINUX" ] && [ "$VMLINUX" -nt "$RAW" ]; then
	progress_note "vmlinux is newer than raw initramfs"
	need_build=1
else
	stale_input="$(newer_build_input || true)"
	if [ -n "$stale_input" ]; then
		progress_note "source newer than raw image: $stale_input"
		need_build=1
	fi
fi
if [ "$need_build" = "1" ]; then
	progress_note "decision: rebuild"
else
	progress_note "decision: reuse existing raw image"
fi

progress "Building OpenWrt image if required"
if [ "$need_build" = "1" ]; then
	cd "$OWRT"
	run_logged "$RESEARCH_NOTES_DIR/${TS}-make-full-image.log" make -j"$JOBS" V=s
else
	progress_note "skipped build"
fi

if [ ! -f "$RAW" ]; then
	echo "FAIL: raw initramfs missing after build: $RAW" >&2
	exit 1
fi
progress_note "raw: $RAW"

progress "Wrapping raw initramfs with A825 header"
wrap_log="$RESEARCH_NOTES_DIR/${TS}-wrap.log"
run_logged "$wrap_log" "$A825WRAP" --input "$RAW" --output "$WRAPPED"
sync
progress_note "wrapped: $WRAPPED"

progress "Verifying wrapped image safety checks"
verify_log="$RESEARCH_NOTES_DIR/${TS}-verify.log"
run_logged "$verify_log" "$A825VERIFY" --raw "$RAW" --wrapped "$WRAPPED"

grep -q '^size_ok=True$' "$verify_log"
echo "CHECK OK: size_ok=True"
grep -m1 '^OK: wrapped a825 image matches raw payload and expected header fields$' "$verify_log"
echo "AUTO: ready for cfe-tftp. Only TFTP /mnt/c/tftp/openwrt-ps-irqfallback.bin."
