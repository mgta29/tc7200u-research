#!/usr/bin/env bash
set -euo pipefail

RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RECORDS_DIR="${RECORDS_DIR:-$RESEARCH/records}"
RESEARCH_BUILDS_DIR="${RESEARCH_BUILDS_DIR:-$RECORDS_DIR/logs/builds}"

INPUT_IMAGE="${INPUT_IMAGE:-${TC7200U_SOURCE_IMAGE:-}}"
OUTPUT_IMAGE="${OUTPUT_IMAGE:-${TC7200U_OUTPUT_IMAGE:-}}"
HEADER_FILENAME="${HEADER_FILENAME:-${TC7200U_HEADER_FILENAME:-openwrt-initramfs.bin}}"
PRESERVE_FROM_IMAGE="${PRESERVE_FROM_IMAGE:-${TC7200U_PRESERVE_FROM_IMAGE:-}}"
WRAP_LOAD_ADDR="${WRAP_LOAD_ADDR:-${TC7200U_WRAP_LOAD_ADDR:-}}"
WRAP_CONTROL="${WRAP_CONTROL:-${TC7200U_WRAP_CONTROL:-}}"
WRAP_MAJOR="${WRAP_MAJOR:-${TC7200U_WRAP_MAJOR:-}}"
WRAP_MINOR="${WRAP_MINOR:-${TC7200U_WRAP_MINOR:-}}"
WRAP_BUILD_TIME="${WRAP_BUILD_TIME:-${TC7200U_WRAP_BUILD_TIME:-}}"
WRAP_CRC32="${WRAP_CRC32:-${TC7200U_WRAP_CRC32:-}}"
FRESH_HEADER="${FRESH_HEADER:-${TC7200U_FRESH_HEADER:-0}}"
FORCE_REWRAP_SOURCE="${FORCE_REWRAP_SOURCE:-0}"

DEFAULT_WRAP_LOAD_HEX="0x82000000"
A825_HEADER_BYTES=92
VERIFY_EXPECT_SIGNATURE_HEX="0xa825"
VERIFY_EXPECT_NAME=""
EXPECT_LOAD_HEX="$DEFAULT_WRAP_LOAD_HEX"
TS="$(date +%Y-%m-%d-%H%M%S)"
STEP=0
TOTAL_STEPS=4
TMP_DIR=""
RAW_PAYLOAD=""
SOURCE_IMAGE_PATH=""
OUTPUT_IMAGE_PATH=""
PRESERVE_FROM_PATH=""
WRAP_LOG_PATH=""
VERIFY_LOG_PATH=""
SKIP_WRAP=0
INHERIT_LOAD_HEX=""
SOURCE_WAS_WRAPPED=0
WRAP_EXTRA_ARGS=()

usage() {
	cat <<'EOF'
Usage:
  ./scripts/programstore.sh --input PATH --output PATH [options]

Options:
  --input PATH
  --output PATH
  --filename NAME
  --preserve-from PATH
  --fresh-header
  --force-rewrap-source
  --load-addr 0x<hex>
  --control 0x<hex>|<int>
  --major 0x<hex>|<int>
  --minor 0x<hex>|<int>
  --build-time 0x<hex>|<int>
  --crc32 0x<hex>|<int>
  -h, --help

Notes:
  - There are no subcommands. This script only wraps a payload into an A825
    ProgramStore image and runs the internal verification pass.
  - With a raw payload, --preserve-from copies ProgramStore metadata from a
    known-good wrapped image unless --fresh-header is also used.
  - With an already wrapped input, the default behavior is byte-for-byte
    passthrough. Use --force-rewrap-source or --fresh-header to rewrite it.
EOF
}

trim_ws() {
	printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

canonical_hex() {
	local value="$1"
	value="$(printf '%s' "$value" | sed 's/^0[xX]//' | tr 'A-F' 'a-f')"
	printf '0x%s' "$value"
}

to_wsl_path() {
	local path="$1"
	local drive=""
	local tail=""

	if printf '%s' "$path" | grep -Eq '^[A-Za-z]:[\\/].*'; then
		drive="$(printf '%s' "$path" | cut -c1 | tr 'A-Z' 'a-z')"
		tail="${path:2}"
		tail="$(printf '%s' "$tail" | sed 's#\\#/#g; s#^/*##')"
		printf '/mnt/%s/%s' "$drive" "$tail"
		return 0
	fi

	printf '%s' "$path"
}

progress() {
	STEP=$((STEP + 1))
	printf '[%d/%d] %s\n' "$STEP" "$TOTAL_STEPS" "$*"
}

progress_note() {
	printf '      %s\n' "$*"
}

command_to_string() {
	local rendered=""
	printf -v rendered '%q ' "$@"
	printf '%s' "${rendered% }"
}

write_command_log_header() {
	local log="$1"
	local cmd_text="$2"
	{
		echo "=== meta ==="
		echo "timestamp_local=$(date '+%Y-%m-%d %H:%M:%S %Z')"
		echo "cwd=$(pwd)"
		echo "command=$cmd_text"
		echo "=== output ==="
	} >"$log"
}

write_command_log_footer() {
	local log="$1"
	local rc="$2"
	{
		echo
		echo "=== exit ==="
		echo "exit_code=$rc"
	} >>"$log"
}

run_logged_allow_fail() {
	local log="$1"
	shift
	local cmd_text=""
	local rc=0

	cmd_text="$(command_to_string "$@")"
	progress_note "log: $log"
	write_command_log_header "$log" "$cmd_text"
	if "$@" >>"$log" 2>&1; then
		rc=0
	else
		rc=$?
	fi
	write_command_log_footer "$log" "$rc"
	return "$rc"
}

run_logged() {
	local log="$1"
	shift
	if ! run_logged_allow_fail "$log" "$@"; then
		echo "FAIL: command failed: $*" >&2
		echo "FAIL: log: $log" >&2
		tail -80 "$log" >&2 || true
		exit 1
	fi
}

cleanup() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

parse_cli_args() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--input)
				[ "$#" -ge 2 ] || { echo "FAIL: --input requires a value" >&2; exit 2; }
				INPUT_IMAGE="$2"
				shift 2
				;;
			--output)
				[ "$#" -ge 2 ] || { echo "FAIL: --output requires a value" >&2; exit 2; }
				OUTPUT_IMAGE="$2"
				shift 2
				;;
			--filename)
				[ "$#" -ge 2 ] || { echo "FAIL: --filename requires a value" >&2; exit 2; }
				HEADER_FILENAME="$2"
				shift 2
				;;
			--preserve-from)
				[ "$#" -ge 2 ] || { echo "FAIL: --preserve-from requires a value" >&2; exit 2; }
				PRESERVE_FROM_IMAGE="$2"
				shift 2
				;;
			--fresh-header)
				FRESH_HEADER=1
				shift
				;;
			--force-rewrap-source)
				FORCE_REWRAP_SOURCE=1
				shift
				;;
			--load-addr)
				[ "$#" -ge 2 ] || { echo "FAIL: --load-addr requires a value" >&2; exit 2; }
				WRAP_LOAD_ADDR="$2"
				shift 2
				;;
			--control)
				[ "$#" -ge 2 ] || { echo "FAIL: --control requires a value" >&2; exit 2; }
				WRAP_CONTROL="$2"
				shift 2
				;;
			--major)
				[ "$#" -ge 2 ] || { echo "FAIL: --major requires a value" >&2; exit 2; }
				WRAP_MAJOR="$2"
				shift 2
				;;
			--minor)
				[ "$#" -ge 2 ] || { echo "FAIL: --minor requires a value" >&2; exit 2; }
				WRAP_MINOR="$2"
				shift 2
				;;
			--build-time)
				[ "$#" -ge 2 ] || { echo "FAIL: --build-time requires a value" >&2; exit 2; }
				WRAP_BUILD_TIME="$2"
				shift 2
				;;
			--crc32)
				[ "$#" -ge 2 ] || { echo "FAIL: --crc32 requires a value" >&2; exit 2; }
				WRAP_CRC32="$2"
				shift 2
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				echo "FAIL: unknown argument: $1" >&2
				usage >&2
				exit 2
				;;
		esac
	done
}

normalize_bool() {
	case "$1" in
		1|true|TRUE|yes|YES|on|ON) printf '1\n' ;;
		0|false|FALSE|no|NO|off|OFF|"") printf '0\n' ;;
		*)
			echo "FAIL: invalid boolean value '$1'" >&2
			exit 2
			;;
	esac
}

validate_plain_filename() {
	local label="$1"
	local value="$2"
	case "$value" in
		""|*/*|*\\*)
			echo "FAIL: $label must be a plain filename: $value" >&2
			exit 2
			;;
	esac
}

validate_hex_value() {
	local label="$1"
	local value="$2"
	if ! printf '%s' "$value" | grep -Eq '^0[xX][0-9a-fA-F]{1,8}$'; then
		echo "FAIL: $label must be a hex value like 0x<hex> (got: $value)" >&2
		exit 2
	fi
}

normalize_runtime_inputs() {
	INPUT_IMAGE="$(trim_ws "$INPUT_IMAGE")"
	OUTPUT_IMAGE="$(trim_ws "$OUTPUT_IMAGE")"
	HEADER_FILENAME="$(trim_ws "$HEADER_FILENAME")"
	PRESERVE_FROM_IMAGE="$(trim_ws "$PRESERVE_FROM_IMAGE")"
	WRAP_LOAD_ADDR="$(trim_ws "$WRAP_LOAD_ADDR")"
	WRAP_CONTROL="$(trim_ws "$WRAP_CONTROL")"
	WRAP_MAJOR="$(trim_ws "$WRAP_MAJOR")"
	WRAP_MINOR="$(trim_ws "$WRAP_MINOR")"
	WRAP_BUILD_TIME="$(trim_ws "$WRAP_BUILD_TIME")"
	WRAP_CRC32="$(trim_ws "$WRAP_CRC32")"
	FRESH_HEADER="$(normalize_bool "$(trim_ws "$FRESH_HEADER")")"
	FORCE_REWRAP_SOURCE="$(normalize_bool "$(trim_ws "$FORCE_REWRAP_SOURCE")")"
}

validate_args() {
	[ -n "$INPUT_IMAGE" ] || { echo "FAIL: --input is required" >&2; exit 2; }
	[ -n "$OUTPUT_IMAGE" ] || { echo "FAIL: --output is required" >&2; exit 2; }
	validate_plain_filename "--filename" "$HEADER_FILENAME"

	if [ -n "$WRAP_LOAD_ADDR" ]; then
		validate_hex_value "--load-addr" "$WRAP_LOAD_ADDR"
		WRAP_LOAD_ADDR="$(canonical_hex "$WRAP_LOAD_ADDR")"
		EXPECT_LOAD_HEX="$WRAP_LOAD_ADDR"
	fi

	if [ "$FRESH_HEADER" = "1" ] && [ "$FORCE_REWRAP_SOURCE" = "1" ]; then
		echo "FAIL: --fresh-header and --force-rewrap-source are mutually exclusive" >&2
		exit 2
	fi
}

resolve_runtime_paths() {
	SOURCE_IMAGE_PATH="$(to_wsl_path "$INPUT_IMAGE")"
	OUTPUT_IMAGE_PATH="$(to_wsl_path "$OUTPUT_IMAGE")"
	PRESERVE_FROM_PATH=""

	[ -f "$SOURCE_IMAGE_PATH" ] || {
		echo "FAIL: input image not found: $INPUT_IMAGE ($SOURCE_IMAGE_PATH)" >&2
		exit 2
	}

	if [ -n "$PRESERVE_FROM_IMAGE" ]; then
		PRESERVE_FROM_PATH="$(to_wsl_path "$PRESERVE_FROM_IMAGE")"
		[ -f "$PRESERVE_FROM_PATH" ] || {
			echo "FAIL: preserve-from image not found: $PRESERVE_FROM_IMAGE ($PRESERVE_FROM_PATH)" >&2
			exit 2
		}
	fi
}

prepare_runtime_directories() {
	mkdir -p "$RESEARCH_BUILDS_DIR"
	mkdir -p "$(dirname "$OUTPUT_IMAGE_PATH")"
	TMP_DIR="$(mktemp -d)"
	trap cleanup EXIT
}

has_metadata_overrides() {
	[ -n "$WRAP_LOAD_ADDR" ] || [ -n "$WRAP_CONTROL" ] || [ -n "$WRAP_MAJOR" ] || [ -n "$WRAP_MINOR" ] || [ -n "$WRAP_BUILD_TIME" ] || [ -n "$WRAP_CRC32" ]
}

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

programstore_header_load() {
	local file="$1"
	python3 - "$file" <<'PY'
import struct
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
if len(data) < 20:
    raise SystemExit(1)

load_addr = struct.unpack(">I", data[16:20])[0]
print(f"0x{load_addr:08x}")
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

a825_wrap() {
	python3 - "$@" <<'PY'
import argparse
import struct
import time
from pathlib import Path

HEADER_SIZE = 0x5C

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
ap.add_argument("--filename", required=True)
ap.add_argument("--preserve-from", default=None)
ap.add_argument("--build-time", type=auto_int, default=None)
ap.add_argument("--crc32", type=auto_int, default=None)
args = ap.parse_args()

output_path = Path(args.output)
preserved = parse_programstore_header(Path(args.preserve_from)) if args.preserve_from else None

control = args.control if args.control is not None else (preserved["control"] if preserved else 0x0000)
major = args.major if args.major is not None else (preserved["major"] if preserved else 0x0100)
minor = args.minor if args.minor is not None else (preserved["minor"] if preserved else 0x04ff)
load_addr = args.load_addr if args.load_addr is not None else (preserved["load_addr"] if preserved else 0x82000000)
build_time = args.build_time if args.build_time is not None else (preserved["build_time"] if preserved else int(time.time()))
crc32_value = args.crc32 if args.crc32 is not None else (preserved["crc32"] if preserved else 0x00000000)

payload = Path(args.input).read_bytes()
header = make_header(len(payload), load_addr, args.filename, build_time, crc32_value, control, major, minor)
output_path.write_bytes(header + payload)

print(f"payload_size={len(payload)}")
print(f"output_size={len(payload) + len(header)}")
print(f"header_size={len(header)}")
print(f"filename={args.filename}")
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

inspect_input_image() {
	local src_load_hex=""
	local src_header_name=""
	local src_signature_hex=""

	progress "Inspecting input image"
	progress_note "input: $INPUT_IMAGE ($SOURCE_IMAGE_PATH)"
	progress_note "output: $OUTPUT_IMAGE ($OUTPUT_IMAGE_PATH)"

	if is_programstore_wrapped_file "$SOURCE_IMAGE_PATH"; then
		SOURCE_WAS_WRAPPED=1
		RAW_PAYLOAD="$TMP_DIR/source-payload.raw"
		strip_programstore_payload "$SOURCE_IMAGE_PATH" "$RAW_PAYLOAD"

		src_load_hex="$(programstore_header_load "$SOURCE_IMAGE_PATH" || true)"
		src_header_name="$(programstore_header_name "$SOURCE_IMAGE_PATH" || true)"
		src_signature_hex="$(programstore_header_signature "$SOURCE_IMAGE_PATH" || true)"
		[ -n "$src_load_hex" ] && EXPECT_LOAD_HEX="$src_load_hex"

		if [ "$FRESH_HEADER" = "1" ]; then
			progress_note "detected wrapped source image"
			progress_note "fresh-header enabled; regenerating ProgramStore metadata"
			if [ -z "$WRAP_LOAD_ADDR" ] && [ -n "$src_load_hex" ]; then
				INHERIT_LOAD_HEX="$src_load_hex"
			fi
		elif [ "$FORCE_REWRAP_SOURCE" = "1" ]; then
			progress_note "detected wrapped source image"
			progress_note "force-rewrap-source enabled; preserving source ProgramStore metadata"
			WRAP_EXTRA_ARGS+=(--preserve-from "$SOURCE_IMAGE_PATH")
		else
			if [ -n "$PRESERVE_FROM_PATH" ] || has_metadata_overrides; then
				echo "FAIL: wrapped input is passthrough by default; add --fresh-header or --force-rewrap-source to apply wrapper metadata changes" >&2
				exit 2
			fi
			SKIP_WRAP=1
			VERIFY_EXPECT_NAME="${src_header_name:-$HEADER_FILENAME}"
			if [ -n "$src_signature_hex" ]; then
				VERIFY_EXPECT_SIGNATURE_HEX="$src_signature_hex"
			fi
			progress_note "detected wrapped source image"
			progress_note "preserving wrapped bytes exactly (no header rewrite)"
		fi
	else
		if [ "$FORCE_REWRAP_SOURCE" = "1" ]; then
			echo "FAIL: --force-rewrap-source requires an already wrapped input image" >&2
			exit 2
		fi
		RAW_PAYLOAD="$SOURCE_IMAGE_PATH"
		progress_note "detected raw payload input"
	fi

	VERIFY_EXPECT_NAME="${VERIFY_EXPECT_NAME:-$HEADER_FILENAME}"
	progress_note "verification header name: $VERIFY_EXPECT_NAME"
	progress_note "expected load address: $EXPECT_LOAD_HEX"
}

apply_preserve_from_policy() {
	local preserve_load_hex=""
	local preserve_sig_hex=""

	progress "Resolving wrapper metadata policy"

	if [ "$SOURCE_WAS_WRAPPED" = "1" ] && [ -n "$PRESERVE_FROM_PATH" ]; then
		echo "FAIL: --preserve-from is not supported together with an already wrapped --input; use --force-rewrap-source or --fresh-header against the source itself" >&2
		exit 2
	fi

	if [ -z "$PRESERVE_FROM_PATH" ]; then
		progress_note "preserve-from: none"
	else
		progress_note "preserve-from: $PRESERVE_FROM_IMAGE ($PRESERVE_FROM_PATH)"
		if ! is_programstore_wrapped_file "$PRESERVE_FROM_PATH"; then
			echo "FAIL: preserve-from image is not a valid ProgramStore A825 image: $PRESERVE_FROM_PATH" >&2
			exit 2
		fi

		preserve_load_hex="$(programstore_header_load "$PRESERVE_FROM_PATH" || true)"
		preserve_sig_hex="$(programstore_header_signature "$PRESERVE_FROM_PATH" || true)"

		if [ "$FRESH_HEADER" = "1" ]; then
			progress_note "fresh-header with preserve-from: using template load address only"
			if [ -z "$WRAP_LOAD_ADDR" ] && [ -n "$preserve_load_hex" ]; then
				INHERIT_LOAD_HEX="$preserve_load_hex"
				EXPECT_LOAD_HEX="$preserve_load_hex"
			fi
		else
			progress_note "preserving ProgramStore metadata from template"
			WRAP_EXTRA_ARGS+=(--preserve-from "$PRESERVE_FROM_PATH")
			if [ -z "$WRAP_LOAD_ADDR" ] && [ -n "$preserve_load_hex" ]; then
				EXPECT_LOAD_HEX="$preserve_load_hex"
			fi
			if [ -n "$preserve_sig_hex" ]; then
				VERIFY_EXPECT_SIGNATURE_HEX="$preserve_sig_hex"
			fi
		fi
	fi

	if [ "$FRESH_HEADER" = "1" ] && [ -n "$INHERIT_LOAD_HEX" ] && [ -z "$WRAP_LOAD_ADDR" ]; then
		WRAP_EXTRA_ARGS+=(--load-addr "$INHERIT_LOAD_HEX")
		EXPECT_LOAD_HEX="$INHERIT_LOAD_HEX"
	fi

	if [ -n "$WRAP_LOAD_ADDR" ]; then
		WRAP_EXTRA_ARGS+=(--load-addr "$WRAP_LOAD_ADDR")
		EXPECT_LOAD_HEX="$WRAP_LOAD_ADDR"
		progress_note "load-addr override: $WRAP_LOAD_ADDR"
	fi
	if [ -n "$WRAP_CONTROL" ]; then
		WRAP_EXTRA_ARGS+=(--control "$WRAP_CONTROL")
	fi
	if [ -n "$WRAP_MAJOR" ]; then
		WRAP_EXTRA_ARGS+=(--major "$WRAP_MAJOR")
	fi
	if [ -n "$WRAP_MINOR" ]; then
		WRAP_EXTRA_ARGS+=(--minor "$WRAP_MINOR")
	fi
	if [ -n "$WRAP_BUILD_TIME" ]; then
		WRAP_EXTRA_ARGS+=(--build-time "$WRAP_BUILD_TIME")
	fi
	if [ -n "$WRAP_CRC32" ]; then
		WRAP_EXTRA_ARGS+=(--crc32 "$WRAP_CRC32")
	fi

	if [ "$SKIP_WRAP" = "1" ]; then
		progress_note "mode: passthrough existing wrapped image"
	elif [ "$FRESH_HEADER" = "1" ]; then
		progress_note "mode: fresh-header rewrap"
	elif [ "$SOURCE_WAS_WRAPPED" = "1" ] && [ "$FORCE_REWRAP_SOURCE" = "1" ]; then
		progress_note "mode: preserve-source-metadata rewrap"
	elif [ -n "$PRESERVE_FROM_PATH" ]; then
		progress_note "mode: template-guided wrap"
	else
		progress_note "mode: canonical no-template wrap"
	fi
}

write_passthrough_log() {
	local log_path="$1"
	{
		echo "mode=passthrough"
		echo "input=$SOURCE_IMAGE_PATH"
		echo "output=$OUTPUT_IMAGE_PATH"
		echo "raw=$RAW_PAYLOAD"
		echo "expect_load=$EXPECT_LOAD_HEX"
		echo "expect_name=$VERIFY_EXPECT_NAME"
		echo "expect_signature=$VERIFY_EXPECT_SIGNATURE_HEX"
	} >"$log_path"
}

wrap_output_image() {
	WRAP_LOG_PATH="$RESEARCH_BUILDS_DIR/${TS}-wrapper-wrap.log"
	progress "Producing wrapped image"
	if [ "$SKIP_WRAP" = "1" ]; then
		cp -f "$SOURCE_IMAGE_PATH" "$OUTPUT_IMAGE_PATH"
		write_passthrough_log "$WRAP_LOG_PATH"
	else
		run_logged "$WRAP_LOG_PATH" a825_wrap --input "$RAW_PAYLOAD" --output "$OUTPUT_IMAGE_PATH" --filename "$HEADER_FILENAME" "${WRAP_EXTRA_ARGS[@]}"
	fi
	sync
	progress_note "wrapped output: $OUTPUT_IMAGE_PATH"
}

verify_output_image() {
	VERIFY_LOG_PATH="$RESEARCH_BUILDS_DIR/${TS}-wrapper-verify.log"
	progress "Running internal verification"
	run_logged "$VERIFY_LOG_PATH" a825_verify --raw "$RAW_PAYLOAD" --wrapped "$OUTPUT_IMAGE_PATH" --expect-load "$EXPECT_LOAD_HEX" --expect-name "$VERIFY_EXPECT_NAME" --expect-signature "$VERIFY_EXPECT_SIGNATURE_HEX"
	grep -q '^size_ok=True$' "$VERIFY_LOG_PATH"
	progress_note "size_ok=True"
	progress_note "wrap log: $WRAP_LOG_PATH"
	progress_note "verify log: $VERIFY_LOG_PATH"
}

main() {
	parse_cli_args "$@"
	normalize_runtime_inputs
	validate_args
	resolve_runtime_paths
	prepare_runtime_directories
	inspect_input_image
	apply_preserve_from_policy
	wrap_output_image
	verify_output_image
}

main "$@"

