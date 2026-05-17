#!/usr/bin/env python3
import argparse
import hashlib
import struct
from pathlib import Path

HEADER_SIZE = 92

def crc16_ccitt_hcs(data: bytes) -> int:
    crc = 0xffff
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xffff
            else:
                crc = (crc << 1) & 0xffff
    return crc ^ 0xffff

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", required=True)
    ap.add_argument("--wrapped", required=True)
    ap.add_argument("--expect-load", default="0x82000000")
    ap.add_argument("--expect-name", default="openwrt-initramfs.bin")
    args = ap.parse_args()

    raw = Path(args.raw)
    wrapped = Path(args.wrapped)
    expect_load = int(args.expect_load, 0)
    expect_name = args.expect_name.encode("ascii")

    if not raw.exists():
        raise SystemExit(f"FAIL: raw image missing: {raw}")
    if not wrapped.exists():
        raise SystemExit(f"FAIL: wrapped image missing: {wrapped}")

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
    expected_hcs = crc16_ccitt_hcs(hdr[:84])
    crc = struct.unpack(">I", hdr[88:92])[0]

    failures = []

    if sig != 0xA825:
        failures.append(f"signature is 0x{sig:04x}, expected 0xa825")
    if file_len != len(raw_bytes):
        failures.append(f"header file length is {file_len}, raw size is {len(raw_bytes)}")
    if len(wrapped_bytes) != len(raw_bytes) + HEADER_SIZE:
        failures.append(f"wrapped size is {len(wrapped_bytes)}, expected {len(raw_bytes) + HEADER_SIZE}")
    if load_addr != expect_load:
        failures.append(f"load address is 0x{load_addr:08x}, expected 0x{expect_load:08x}")
    if filename != expect_name:
        failures.append(f"filename is {filename!r}, expected {expect_name!r}")
    if hcs != expected_hcs:
        failures.append(f"hcs is 0x{hcs:04x}, expected 0x{expected_hcs:04x}")
    if payload != raw_bytes:
        failures.append("payload after 92-byte header does not exactly match raw image")

    print(f"raw={raw}")
    print(f"wrapped={wrapped}")
    print(f"raw_size={len(raw_bytes)}")
    print(f"wrapped_size={len(wrapped_bytes)}")
    print(f"signature=0x{sig:04x}")
    print(f"control=0x{control:04x}")
    print(f"major=0x{major:04x}")
    print(f"minor=0x{minor:04x}")
    print(f"build_time=0x{build_time:08x}")
    print(f"file_length={file_len}")
    print(f"load_address=0x{load_addr:08x}")
    print(f"filename={filename.decode('ascii', errors='replace')}")
    print(f"hcs=0x{hcs:04x}")
    print(f"expected_hcs=0x{expected_hcs:04x}")
    print(f"crc=0x{crc:08x}")
    print(f"size_ok={len(wrapped_bytes) == len(raw_bytes) + HEADER_SIZE}")
    print(f"raw_sha256={sha256_file(raw)}")
    print(f"wrapped_sha256={sha256_file(wrapped)}")

    if failures:
        print("")
        for f in failures:
            print(f"FAIL: {f}")
        raise SystemExit(1)

    print("")
    print("OK: wrapped a825 image matches raw payload and expected header fields")

if __name__ == "__main__":
    main()
