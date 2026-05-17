#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path

def auto_int(x):
    return int(x, 0)

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

def make_header(payload_size: int, load_addr: int, filename: str, build_time: int, crc32_value: int) -> bytes:
    name = filename.encode("ascii")
    if len(name) > 63:
        raise SystemExit("filename too long for 64-byte CFE field")

    header = bytearray()
    header += struct.pack(">H", 0xa825)          # Signature
    header += struct.pack(">H", 0x0000)          # Control
    header += struct.pack(">H", 0x0100)          # Major Rev
    header += struct.pack(">H", 0x04ff)          # Minor Rev
    header += struct.pack(">I", build_time)      # Build Time
    header += struct.pack(">I", payload_size)    # File Length
    header += struct.pack(">I", load_addr)       # Load Address
    header += name + b"\x00" * (64 - len(name))  # Filename field

    if len(header) != 0x54:
        raise SystemExit(f"internal header length error: {len(header)}")

    hcs = crc16_ccitt_hcs(bytes(header))
    header += struct.pack(">H", hcs)
    header += b"\x00\x00"
    header += struct.pack(">I", crc32_value)

    if len(header) != 0x5c:
        raise SystemExit(f"final header length error: {len(header)}")

    return bytes(header)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--load-addr", type=auto_int, default=0x82000000)
    ap.add_argument("--filename", default="openwrt-initramfs.bin")
    ap.add_argument("--build-time", type=auto_int, default=None)
    ap.add_argument("--crc32", type=auto_int, default=0x00000000)
    args = ap.parse_args()

    payload = Path(args.input).read_bytes()
    import time
    build_time = int(time.time()) if args.build_time is None else args.build_time
    header = make_header(len(payload), args.load_addr, args.filename, build_time, args.crc32)
    Path(args.output).write_bytes(header + payload)

    print(f"payload_size={len(payload)}")
    print(f"output_size={len(payload) + len(header)}")
    print(f"header_size={len(header)}")
    print(f"hcs=0x{struct.unpack('>H', header[0x54:0x56])[0]:04x}")

if __name__ == "__main__":
    main()
