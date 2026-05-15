#!/usr/bin/env bash
set -euo pipefail

OWRT="${OWRT:-$HOME/src/openwrt}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RESEARCH/research/notes/generated}"
RAW="$OWRT/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin"
VML="$OWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.87/vmlinux"
OUT="${OUT:-/mnt/c/tftp/openwrt-ps-irqfallback.bin}"
WRAP="$RESEARCH/scripts/tc7200u-a825-wrap.py"
MAN="$RESEARCH_NOTES_DIR/$(date +%F-%H%M%S)-wrap-manifest.txt"

cd "$OWRT"

if [ ! -f "$VML" ]; then
    echo "ERROR: missing vmlinux: $VML" >&2
    exit 1
fi

if [ ! -f "$RAW" ]; then
    echo "ERROR: missing raw initramfs: $RAW" >&2
    echo "Run: cd ~/src/openwrt; make target/linux/compile V=s" >&2
    exit 1
fi

if [ "$VML" -nt "$RAW" ]; then
    echo "ERROR: vmlinux is newer than raw initramfs. Refusing to wrap stale image." >&2
    echo "Run: cd ~/src/openwrt; make target/linux/compile V=s" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUT")"
mkdir -p "$RESEARCH_NOTES_DIR"
"$WRAP" --input "$RAW" --output "$OUT"
sync

{
    echo "TC7200U image manifest"
    echo "date_utc=$(date -u +%FT%TZ)"
    echo
    echo "OpenWrt dir: $OWRT"
    echo "Raw OpenWrt initramfs: $RAW"
    ls -lh --time-style=long-iso "$RAW"
    sha256sum "$RAW"
    wc -c "$RAW"
    echo
    echo "Uncompressed kernel object: $VML"
    ls -lh --time-style=long-iso "$VML"
    sha256sum "$VML"
    echo
    echo "Wrapped CFE/TFTP image: $OUT"
    ls -lh --time-style=long-iso "$OUT"
    sha256sum "$OUT"
    wc -c "$OUT"
    echo
    echo "TFTP server filename: openwrt-ps-irqfallback.bin"
    echo "Internal a825 header filename: openwrt-initramfs.bin"
    echo "CFE load address: 0x82000000"
    echo "Kernel runtime/decompress target observed: 0x80010000"
    echo
    echo "Header decode:"
    python3 - <<PY
from pathlib import Path
import struct
p=Path("$OUT")
b=p.read_bytes()[:92]
sig,ctrl,maj,minr,build,size,load=struct.unpack(">HHHHIII", b[:20])
name=b[20:84].split(b"\0",1)[0].decode("ascii","replace")
hcs=struct.unpack(">H", b[84:86])[0]
crc=struct.unpack(">I", b[88:92])[0]
print(f"signature=0x{sig:04x}")
print(f"control=0x{ctrl:04x}")
print(f"major=0x{maj:04x}")
print(f"minor=0x{minr:04x}")
print(f"build_time=0x{build:08x}")
print(f"payload_size={size}")
print(f"load_addr=0x{load:08x}")
print(f"name={name}")
print(f"hcs=0x{hcs:04x}")
print(f"crc=0x{crc:08x}")
print(f"total_size={p.stat().st_size}")
print(f"size_ok={p.stat().st_size == size + 92}")
PY
    echo
    echo "Recipe lines:"
    grep -Rns "KERNEL_INITRAMFS\\|loader-lzma\\|LZMA_TEXT_START\\|lzma" "$OWRT/target/linux/bmips/image/Makefile" "$OWRT/target/linux/bmips/image/bcm63268.mk" 2>/dev/null || true
} | tee "$MAN"

echo
echo "Manifest written: $MAN"
