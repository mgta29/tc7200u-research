#!/usr/bin/env bash
set -euo pipefail

OWRT="${OWRT:-$HOME/src/openwrt}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RESEARCH/research/notes/generated}"
RAW="$OWRT/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin"
WRAPPED="/mnt/c/tftp/openwrt-ps-irqfallback.bin"
A825WRAP="$RESEARCH/scripts/tc7200u-a825-wrap.py"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 1)}"
TS="$(date +%Y-%m-%d-%H%M%S)"

mkdir -p "$RESEARCH_NOTES_DIR"
mkdir -p "$(dirname "$WRAPPED")"

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

if [ ! -x "$A825WRAP" ]; then
	echo "FAIL: missing executable wrapper: $A825WRAP" >&2
	exit 1
fi

VMLINUX="$(latest_vmlinux || true)"

config_before="$RESEARCH_NOTES_DIR/${TS}-openwrt-config-before-debug-packages"
config_after="$RESEARCH_NOTES_DIR/${TS}-openwrt-config-after-debug-packages"
cp "$OWRT/.config" "$config_before"

run_logged "$RESEARCH_NOTES_DIR/${TS}-ensure-debug-packages.log" "$RESEARCH/scripts/tc7200u-ensure-debug-packages.sh"

cp "$OWRT/.config" "$config_after"

need_build=0
if ! cmp -s "$config_before" "$config_after"; then
	need_build=1
fi

if [ ! -f "$RAW" ]; then
	need_build=1
elif [ "$OWRT/.config" -nt "$RAW" ]; then
	need_build=1
elif [ -n "$VMLINUX" ] && [ "$VMLINUX" -nt "$RAW" ]; then
	need_build=1
fi

if [ "$need_build" = "1" ]; then
	cd "$OWRT"
	run_logged "$RESEARCH_NOTES_DIR/${TS}-make-full-image.log" make -j"$JOBS" V=s
fi

if [ ! -f "$RAW" ]; then
	echo "FAIL: raw initramfs missing after build: $RAW" >&2
	exit 1
fi

wrap_log="$RESEARCH_NOTES_DIR/${TS}-wrap.log"
run_logged "$wrap_log" "$A825WRAP" --input "$RAW" --output "$WRAPPED"
sync

verify_log="$RESEARCH_NOTES_DIR/${TS}-verify.log"
if ! python3 - "$RAW" "$WRAPPED" >"$verify_log" 2>&1 <<'PY'
import hashlib
import struct
import sys
from pathlib import Path

HEADER_SIZE = 92
raw = Path(sys.argv[1])
wrapped = Path(sys.argv[2])

raw_bytes = raw.read_bytes()
wrapped_bytes = wrapped.read_bytes()

if len(wrapped_bytes) < HEADER_SIZE:
    raise SystemExit("FAIL: wrapped image is smaller than 92-byte a825 header")

hdr = wrapped_bytes[:HEADER_SIZE]
payload = wrapped_bytes[HEADER_SIZE:]

sig, control, major, minor = struct.unpack(">HHHH", hdr[0:8])
build_time, file_len, load_addr = struct.unpack(">III", hdr[8:20])
filename = hdr[20:84].split(b"\x00", 1)[0]
hcs = struct.unpack(">H", hdr[84:86])[0]
crc = struct.unpack(">I", hdr[88:92])[0]

failures = []

if sig != 0xA825:
    failures.append(f"signature is 0x{sig:04x}, expected 0xa825")
if file_len != len(raw_bytes):
    failures.append(f"header file length is {file_len}, raw size is {len(raw_bytes)}")
if len(wrapped_bytes) != len(raw_bytes) + HEADER_SIZE:
    failures.append(f"wrapped size is {len(wrapped_bytes)}, expected {len(raw_bytes) + HEADER_SIZE}")
if load_addr != 0x82000000:
    failures.append(f"load address is 0x{load_addr:08x}, expected 0x82000000")
if filename != b"openwrt-initramfs.bin":
    failures.append(f"filename is {filename!r}, expected b'openwrt-initramfs.bin'")
if payload != raw_bytes:
    failures.append("payload after 92-byte header does not exactly match raw image")

print(f"signature=0x{sig:04x}")
print(f"payload_size={file_len}")
print(f"total_size={len(wrapped_bytes)}")
print(f"size_ok={len(wrapped_bytes) == file_len + HEADER_SIZE}")
print(f"raw_sha256={hashlib.sha256(raw_bytes).hexdigest()}")
print(f"wrapped_sha256={hashlib.sha256(wrapped_bytes).hexdigest()}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(1)

print("OK: wrapped a825 image matches raw payload and expected header fields")
PY
then
	echo "FAIL: verify failed: $verify_log" >&2
	cat "$verify_log" >&2
	exit 1
fi

grep -q '^size_ok=True$' "$verify_log"
echo "CHECK OK: size_ok=True"
grep -m1 '^OK: wrapped a825 image matches raw payload and expected header fields$' "$verify_log"
echo "AUTO: ready for cfe-tftp. Only TFTP /mnt/c/tftp/openwrt-ps-irqfallback.bin."
