is_programstore_wrapped_file() {
	local file="$1"
	python3 - "$file" <<'PY'
import struct
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = path.read_bytes()
if len(data) < 92:
    raise SystemExit(1)

def crc16_ccitt_hcs(buf: bytes) -> int:
    crc = 0xffff
    for b in buf:
        crc ^= b << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xffff
            else:
                crc = (crc << 1) & 0xffff
    return crc ^ 0xffff

hcs = struct.unpack(">H", data[84:86])[0]
calc_hcs = crc16_ccitt_hcs(data[:84])
if hcs != calc_hcs:
    raise SystemExit(1)

file_len = struct.unpack(">I", data[12:16])[0]
if file_len <= 0:
    raise SystemExit(1)
if file_len + 92 > len(data):
    raise SystemExit(1)
PY
}

programstore_header_name() {
	local file="$1"
	python3 - "$file" <<'PY'
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
if len(data) < 84:
    raise SystemExit(1)

name = data[20:84].split(b"\x00", 1)[0].decode("ascii", errors="replace")
print(name)
PY
}

programstore_header_signature() {
	local file="$1"
	python3 - "$file" <<'PY'
import struct
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
if len(data) < 2:
    raise SystemExit(1)

sig = struct.unpack(">H", data[0:2])[0]
print(f"0x{sig:04x}")
PY
}

a825_wrap() {
	python3 - "$@" <<'PY'
import argparse
import struct
import time
from pathlib import Path

HEADER_SIZE = 0x5C

def auto_int(x):
    return int(x, 0)

def parse_name_map(raw: str) -> tuple[str, str]:
    text = raw.strip()
    if "->" in text:
        left, right = text.split("->", 1)
    elif "=" in text:
        left, right = text.split("=", 1)
    elif " - " in text:
        left, right = text.split(" - ", 1)
    else:
        raise SystemExit("name-map must be INPUT=RESULT, INPUT->RESULT, or INPUT - RESULT")

    request_name = left.strip()
    result_name = right.strip()
    if not request_name or not result_name:
        raise SystemExit("name-map must include non-empty INPUT and RESULT names")
    if "/" in request_name or "\\" in request_name:
        raise SystemExit("name-map INPUT must be a plain filename")
    if "/" in result_name or "\\" in result_name:
        raise SystemExit("name-map RESULT must be a plain filename")
    return request_name, result_name

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

def parse_programstore_header(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < HEADER_SIZE:
        raise SystemExit(f"preserve-from image too small for ProgramStore header: {path}")

    hdr = data[:HEADER_SIZE]
    sig, control, major, minor = struct.unpack(">HHHH", hdr[0:8])
    build_time, file_len, load_addr = struct.unpack(">III", hdr[8:20])
    filename = hdr[20:84].split(b"\x00", 1)[0].decode("ascii", errors="replace")
    hcs = struct.unpack(">H", hdr[84:86])[0]
    calc_hcs = crc16_ccitt_hcs(hdr[:84])
    crc32_value = struct.unpack(">I", hdr[88:92])[0]
    if hcs != calc_hcs:
        raise SystemExit(
            f"preserve-from image has invalid HCS (0x{hcs:04x} != 0x{calc_hcs:04x}): {path}"
        )

    return {
        "signature": sig,
        "control": control,
        "major": major,
        "minor": minor,
        "build_time": build_time,
        "file_len": file_len,
        "load_addr": load_addr,
        "filename": filename,
        "crc32": crc32_value,
    }

def make_header(
    payload_size: int,
    load_addr: int,
    filename: str,
    build_time: int,
    crc32_value: int,
    control: int,
    major: int,
    minor: int,
) -> bytes:
    name = filename.encode("ascii")
    if len(name) > 63:
        raise SystemExit("filename too long for 64-byte CFE field")

    header = bytearray()
    header += struct.pack(">H", 0xa825)
    header += struct.pack(">H", control & 0xffff)
    header += struct.pack(">H", major & 0xffff)
    header += struct.pack(">H", minor & 0xffff)
    header += struct.pack(">I", build_time)
    header += struct.pack(">I", payload_size)
    header += struct.pack(">I", load_addr)
    header += name + b"\x00" * (64 - len(name))
    if len(header) != 0x54:
        raise SystemExit(f"internal header length error: {len(header)}")

    hcs = crc16_ccitt_hcs(bytes(header))
    header += struct.pack(">H", hcs)
    header += b"\x00\x00"
    header += struct.pack(">I", crc32_value)
    if len(header) != HEADER_SIZE:
        raise SystemExit(f"final header length error: {len(header)}")
    return bytes(header)

ap = argparse.ArgumentParser()
ap.add_argument("--input", required=True)
ap.add_argument("--output", required=True)
ap.add_argument("--load-addr", type=auto_int, default=None)
ap.add_argument("--control", type=auto_int, default=None)
ap.add_argument("--major", type=auto_int, default=None)
ap.add_argument("--minor", type=auto_int, default=None)
ap.add_argument("--filename", default=None)
ap.add_argument("--name-map", default=None)
ap.add_argument("--preserve-from", default=None)
ap.add_argument("--build-time", type=auto_int, default=None)
ap.add_argument("--crc32", type=auto_int, default=None)
args = ap.parse_args()

output_path = Path(args.output)
filename = args.filename
preserved = parse_programstore_header(Path(args.preserve_from)) if args.preserve_from else None

if args.name_map:
    mapped_input, mapped_result = parse_name_map(args.name_map)
    output_path = output_path.parent / mapped_result
    if filename is None:
        filename = mapped_input

if filename is None:
    filename = "openwrt-initramfs.bin"

control = args.control if args.control is not None else (preserved["control"] if preserved else 0x0000)
major = args.major if args.major is not None else (preserved["major"] if preserved else 0x0100)
minor = args.minor if args.minor is not None else (preserved["minor"] if preserved else 0x04ff)
load_addr = args.load_addr if args.load_addr is not None else (preserved["load_addr"] if preserved else 0x82000000)
build_time = args.build_time if args.build_time is not None else (preserved["build_time"] if preserved else int(time.time()))
crc32_value = args.crc32 if args.crc32 is not None else (preserved["crc32"] if preserved else 0x00000000)

payload = Path(args.input).read_bytes()
header = make_header(len(payload), load_addr, filename, build_time, crc32_value, control, major, minor)
output_path.write_bytes(header + payload)

print(f"payload_size={len(payload)}")
print(f"output_size={len(payload) + len(header)}")
print(f"header_size={len(header)}")
print(f"filename={filename}")
print(f"control=0x{control:04x}")
print(f"major=0x{major:04x}")
print(f"minor=0x{minor:04x}")
print(f"load_addr=0x{load_addr:08x}")
print(f"build_time=0x{build_time:08x}")
print(f"crc32=0x{crc32_value:08x}")
if preserved:
    print(f"preserve_from={args.preserve_from}")
    print(f"preserve_signature=0x{preserved['signature']:04x}")
print(f"output={output_path}")
print(f"hcs=0x{struct.unpack('>H', header[0x54:0x56])[0]:04x}")
PY
}

a825_verify() {
	python3 - "$@" <<'PY'
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

ap = argparse.ArgumentParser()
ap.add_argument("--raw", required=True)
ap.add_argument("--wrapped", required=True)
ap.add_argument("--expect-load", default="0x82000000")
ap.add_argument("--expect-name", default=None)
ap.add_argument("--expect-signature", default="0xa825")
args = ap.parse_args()

raw = Path(args.raw)
wrapped = Path(args.wrapped)
expect_load = int(args.expect_load, 0)
expect_name = args.expect_name.encode("ascii") if args.expect_name is not None else None
expect_signature = None if args.expect_signature.lower() == "any" else int(args.expect_signature, 0)

if not raw.exists():
    raise SystemExit(f"FAIL: raw image missing: {raw}")
if not wrapped.exists():
    raise SystemExit(f"FAIL: wrapped image missing: {wrapped}")

raw_bytes = raw.read_bytes()
wrapped_bytes = wrapped.read_bytes()
if len(wrapped_bytes) < HEADER_SIZE:
    raise SystemExit("FAIL: wrapped image is smaller than 92-byte ProgramStore header")

hdr = wrapped_bytes[:HEADER_SIZE]
payload = wrapped_bytes[HEADER_SIZE:]
sig, control, major, minor = struct.unpack(">HHHH", hdr[0:8])
build_time, file_len, load_addr = struct.unpack(">III", hdr[8:20])
filename = hdr[20:84].split(b"\x00", 1)[0]
hcs = struct.unpack(">H", hdr[84:86])[0]
expected_hcs = crc16_ccitt_hcs(hdr[:84])
crc = struct.unpack(">I", hdr[88:92])[0]

failures = []
if expect_signature is not None and sig != expect_signature:
    failures.append(f"signature is 0x{sig:04x}, expected 0x{expect_signature:04x}")
if file_len != len(raw_bytes):
    failures.append(f"header file length is {file_len}, raw size is {len(raw_bytes)}")
if len(wrapped_bytes) != len(raw_bytes) + HEADER_SIZE:
    failures.append(f"wrapped size is {len(wrapped_bytes)}, expected {len(raw_bytes) + HEADER_SIZE}")
if load_addr != expect_load:
    failures.append(f"load address is 0x{load_addr:08x}, expected 0x{expect_load:08x}")
if expect_name is not None and filename != expect_name:
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
print("expected_signature=any" if expect_signature is None else f"expected_signature=0x{expect_signature:04x}")
print(f"control=0x{control:04x}")
print(f"major=0x{major:04x}")
print(f"minor=0x{minor:04x}")
print(f"build_time=0x{build_time:08x}")
print(f"file_length={file_len}")
print(f"load_address=0x{load_addr:08x}")
print(f"filename={filename.decode('ascii', errors='replace')}")
print("expected_name=(not checked)" if expect_name is None else f"expected_name={expect_name.decode('ascii', errors='replace')}")
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
print("OK: wrapped image matches raw payload and expected header fields")
PY
}

reverse_stage1() {
	python3 - "$RECORDS_DIR" "$@" <<'PY'
import argparse
import hashlib
import lzma
import struct
from pathlib import Path

records_dir = Path(__import__("sys").argv[1])
argv = __import__("sys").argv[2:]
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

def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def parse_programstore_header(data: bytes) -> dict:
    if len(data) < HEADER_SIZE:
        raise SystemExit("FAIL: file is smaller than ProgramStore header size")
    hdr = data[:HEADER_SIZE]
    sig, control, major, minor = struct.unpack(">HHHH", hdr[0:8])
    build_time, file_len, load_addr = struct.unpack(">III", hdr[8:20])
    filename = hdr[20:84].split(b"\x00", 1)[0].decode("ascii", errors="replace")
    hcs = struct.unpack(">H", hdr[84:86])[0]
    crc = struct.unpack(">I", hdr[88:92])[0]
    calc_hcs = crc16_ccitt_hcs(hdr[:84])
    return {"signature": sig, "control": control, "major": major, "minor": minor, "build_time": build_time, "file_len": file_len, "load_addr": load_addr, "filename": filename, "hcs": hcs, "calc_hcs": calc_hcs, "crc": crc}

def parse_lzma1_props(prop: bytes):
    if len(prop) < 5:
        raise ValueError("payload too short for LZMA properties")
    p0 = prop[0]
    if p0 >= 225:
        raise ValueError(f"invalid LZMA properties byte: 0x{p0:02x}")
    pb = p0 // 45
    rem = p0 % 45
    lp = rem // 9
    lc = rem % 9
    dict_size = int.from_bytes(prop[1:5], "little")
    return lc, lp, pb, dict_size

def try_decompress_lzma1(payload: bytes):
    meta = {"is_lzma": False}
    try:
        lc, lp, pb, dict_size = parse_lzma1_props(payload[:5])
    except ValueError as ex:
        meta["error"] = str(ex)
        return None, meta
    meta.update({"is_lzma": True, "lc": lc, "lp": lp, "pb": pb, "dict_size": dict_size})
    try:
        dec = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=[{"id": lzma.FILTER_LZMA1, "lc": lc, "lp": lp, "pb": pb, "dict_size": dict_size}])
        raw = dec.decompress(payload[5:])
        if not dec.eof and dec.unused_data == b"":
            meta["warning"] = "stream did not reach explicit EOF marker"
        return raw, meta
    except lzma.LZMAError as ex:
        meta["error"] = f"LZMA decode failed: {ex}"
        return None, meta

def safe_tag(name: str) -> str:
    out = [ch if ch.isalnum() or ch in ("-", "_", ".") else "-" for ch in name]
    return "".join(out).strip("-") or "image"

def find_ascii_offsets(blob: bytes, needle: bytes):
    hits = []
    i = 0
    while True:
        pos = blob.find(needle, i)
        if pos < 0:
            break
        hits.append(pos)
        i = pos + 1
    return hits

def write_marker_report(path: Path, raw: bytes, load_addr: int) -> None:
    markers = [
        b"Booting Linux on TP1...",
        b"Linux Boot Args:",
        b"<<<<< rx_thread sent initial handshake >>>>>>",
        b"HandShakeMsg = %08lx",
        b"unhandled message %08lx",
        b"Error: getHostDqmMessage(handshake) on %s",
        b"Error: handshake rx unexpected message",
        b"Creating DOCSIS Control Thread...",
        b"Creating TR-069 Thread...",
        b"Incompatible Firmware",
    ]
    lines = [f"load_address=0x{load_addr:08x}", "marker_hits:"]
    for marker in markers:
        hits = find_ascii_offsets(raw, marker)
        label = marker.decode("ascii", errors="replace")
        if not hits:
            lines.append(f"  - {label}: none")
            continue
        for off in hits[:8]:
            lines.append(f"  - {label}: file_off=0x{off:08x} runtime=0x{(load_addr + off):08x}")
        if len(hits) > 8:
            lines.append(f"  - ... ({len(hits) - 8} more hits)")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")

ap = argparse.ArgumentParser(description="Extract and inspect TC7200 stage1 ProgramStore image.")
ap.add_argument("--input", required=True)
ap.add_argument("--out-dir", default=None)
ap.add_argument("--force-load", default=None)
args = ap.parse_args(argv)

src = Path(args.input).expanduser().resolve()
if not src.exists():
    raise SystemExit(f"FAIL: input not found: {src}")
out_dir = Path(args.out_dir).expanduser().resolve() if args.out_dir else records_dir / "reverse" / safe_tag(src.name)
out_dir.mkdir(parents=True, exist_ok=True)

wrapped = src.read_bytes()
header = parse_programstore_header(wrapped)
payload = wrapped[HEADER_SIZE:]
header_log = out_dir / "programstore_header.txt"
raw_payload_path = out_dir / "payload.lzma"
raw_image_path = out_dir / "image.raw"
marker_report = out_dir / "marker_report.txt"
summary_path = out_dir / "summary.txt"
raw_payload_path.write_bytes(payload)

decoded, lz_meta = try_decompress_lzma1(payload)
if decoded is None:
    decoded = payload
    decode_mode = "passthrough"
else:
    decode_mode = "lzma_raw"
raw_image_path.write_bytes(decoded)

load_addr = int(args.force_load, 0) if args.force_load else header["load_addr"]
write_marker_report(marker_report, decoded, load_addr)
header_lines = [
    f"source={src}",
    f"wrapped_size={len(wrapped)}",
    f"signature=0x{header['signature']:04x}",
    f"control=0x{header['control']:04x}",
    f"major=0x{header['major']:04x}",
    f"minor=0x{header['minor']:04x}",
    f"build_time=0x{header['build_time']:08x}",
    f"file_length={header['file_len']}",
    f"load_address=0x{header['load_addr']:08x}",
    f"filename={header['filename']}",
    f"hcs=0x{header['hcs']:04x}",
    f"expected_hcs=0x{header['calc_hcs']:04x}",
    f"crc=0x{header['crc']:08x}",
    f"payload_size={len(payload)}",
    f"payload_sha256={sha256_hex(payload)}",
]
header_log.write_text("\n".join(header_lines) + "\n", encoding="utf-8")
summary = [
    f"input={src}",
    f"out_dir={out_dir}",
    f"payload={raw_payload_path}",
    f"image_raw={raw_image_path}",
    f"header_log={header_log}",
    f"marker_report={marker_report}",
    f"decode_mode={decode_mode}",
    f"raw_image_size={len(decoded)}",
    f"raw_image_sha256={sha256_hex(decoded)}",
]
for key in ("is_lzma", "lc", "lp", "pb", "dict_size", "warning", "error"):
    if key in lz_meta:
        summary.append(f"{key}={lz_meta[key]}")
summary_path.write_text("\n".join(summary) + "\n", encoding="utf-8")
print("\n".join(summary))
PY
}

strip_programstore_payload() {
	local input="$1"
	local output="$2"

	if ! tail -c "+$((A825_HEADER_BYTES + 1))" "$input" >"$output" 2>/dev/null; then
		if ! dd if="$input" of="$output" bs=1 skip="$A825_HEADER_BYTES" 2>/dev/null; then
			echo "FAIL: unable to strip A825 header from source image: $input" >&2
			exit 1
		fi
	fi
}
