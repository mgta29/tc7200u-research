#!/usr/bin/env bash
set -euo pipefail

OWRT="${OWRT:-$HOME/src/openwrt}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RECORDS_DIR="${RECORDS_DIR:-$RESEARCH/records}"
RESEARCH_BUILDS_DIR="${RESEARCH_BUILDS_DIR:-$RECORDS_DIR/logs/builds}"
RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RECORDS_DIR/generated}"
RAW="$OWRT/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin"
SOURCE_IMAGE="${SOURCE_IMAGE:-${INPUT_IMAGE:-${TC7200U_SOURCE_IMAGE:-}}}"
NAME_MAP="${NAME_MAP:-${TC7200U_NAME_MAP:-}}"
DEFAULT_REQUEST_NAME="${TC7200U_DEFAULT_REQUEST_NAME:-openwrt-initramfs.bin}"
DEFAULT_RESULT_NAME="${TC7200U_DEFAULT_RESULT_NAME:-$DEFAULT_REQUEST_NAME}"
RESCUE_RESULT_NAME="openwrt-ps-irqfallback.bin"
REQUEST_NAME="${REQUEST_NAME:-${TFTP_REQUEST_NAME:-$DEFAULT_REQUEST_NAME}}"
RESULT_NAME="${RESULT_NAME:-${TFTP_RESULT_NAME:-$DEFAULT_RESULT_NAME}}"
BIN_NAME="${BIN_NAME:-${TFTP_BIN_NAME:-}}"
TFTP_OUT_DIR="${TFTP_OUT_DIR:-${TFTP_ROOT_DIR:-C:\\tftp\\}}"
ALLOW_RESCUE_OVERWRITE="${ALLOW_RESCUE_OVERWRITE:-0}"
FORCE_REWRAP_SOURCE="${FORCE_REWRAP_SOURCE:-0}"
INTERACTIVE="${INTERACTIVE:-0}"
MODE="${MODE:-auto}"
BUILD_MODE="${BUILD_MODE:-auto}"
BUILD_LOG_BASE="${BUILD_LOG_BASE:-$RESEARCH_BUILDS_DIR}"
CHECK_LOG_PATH="${CHECK_LOG_PATH:-}"
CHECK_REPORT_OUT="${CHECK_REPORT_OUT:-}"
CHECK_SAVE_REPORT="${CHECK_SAVE_REPORT:-1}"
WRAPPED=""
A825_HEADER_BYTES=92
EXPECT_LOAD_HEX="0x82000000"
VERIFY_EXPECT_NAME=""
VERIFY_EXPECT_SIGNATURE_HEX="0xa825"
WRAP_EXTRA_ARGS=()
SKIP_WRAP=0
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 1)}"
TS="$(date +%Y-%m-%d-%H%M%S)"
RUN_REPORT=""
STEP=0
TOTAL_STEPS=7

trim_ws() {
	printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
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
			echo "FAIL: --name-map must be INPUT=RESULT, INPUT->RESULT, or INPUT - RESULT: $raw" >&2
			exit 2
			;;
	esac

	REQUEST_NAME="$(trim_ws "$left")"
	RESULT_NAME="$(trim_ws "$right")"
}

usage() {
	cat <<'EOF'
Usage:
  tc7200u-auto-build-install-wrap.sh [mode] [options]

Modes:
  help            Print this help text.
  auto            Build (if needed), wrap, verify. (default)
  wrap            Alias for auto.
  check           Alias for auto.
  verify          Alias for auto.
  build           Alias for auto.
  status          Print git and helper status.
  check-gates     Run gate checks on serial log.
  state           Alias for capture-state.
  capture-state   Capture current OpenWrt/wrapper state snapshot.
  ensure-packages Apply TC7200U package profile and run defconfig.
  serial-console  Attach USB serial and log picocom output.
  reverse-stage1  Extract and inspect a wrapped ProgramStore image.
  selftest        Run local A825 wrapper/verifier tests.
  paths           Print resolved paths and effective names.
  interactive     Prompt for mode and filename interactively.

Options:
  --mode MODE
  --interactive
  --build-mode auto|none|install|compile|full
  --name-map INPUT=RESULT | INPUT->RESULT | INPUT - RESULT
  --request-name NAME
  --result-name NAME
  --bin-name NAME.bin
  --tftp-dir C:\tftp\
  --source-image PATH
  --allow-rescue-overwrite
  --force-rewrap-source
  --check-log /abs/path/to/picocom.log
  --log /abs/path/to/picocom.log
  --report-out /abs/path/to/report.txt
  --no-save
EOF
}

normalize_mode() {
	local mode="$1"
	case "$mode" in
		auto|build|wrap|check|verify|wrap-verify)
			printf 'auto\n'
			;;
		check-gates|gates)
			printf 'check-gates\n'
			;;
		capture-state|state)
			printf 'capture-state\n'
			;;
		ensure-packages|packages|ensure-debug-packages)
			printf 'ensure-packages\n'
			;;
		serial-console|serial|console)
			printf 'serial-console\n'
			;;
		reverse-stage1|reverse)
			printf 'reverse-stage1\n'
			;;
		status|selftest|paths|interactive|help)
			printf '%s\n' "$mode"
			;;
		*)
			printf '%s\n' "$mode"
			;;
	esac
}

interactive_choose_mode() {
	echo "Select mode:"
	echo "  1) auto (build+wrap+verify)"
	echo "  2) check-gates"
	echo "  3) capture-state"
	echo "  4) ensure-packages"
	echo "  5) serial-console"
	echo "  6) paths"
	printf 'Choice [1]: ' >&2
	local choice=""
	IFS= read -r choice || true
	choice="$(trim_ws "${choice:-}")"
	case "$choice" in
		""|"1") MODE="auto" ;;
		"2") MODE="check-gates" ;;
		"3") MODE="capture-state" ;;
		"4") MODE="ensure-packages" ;;
		"5") MODE="serial-console" ;;
		"6") MODE="paths" ;;
		*) echo "FAIL: invalid interactive mode choice: $choice" >&2; exit 2 ;;
	esac
}

POSITIONAL_MODE_SET=0
while [ "$#" -gt 0 ]; do
	case "$1" in
		auto|build|wrap|check|verify|wrap-verify|check-gates|gates|capture-state|state|ensure-packages|packages|ensure-debug-packages|serial-console|serial|console|reverse-stage1|reverse|status|selftest|paths|interactive|help)
			if [ "$POSITIONAL_MODE_SET" = "0" ]; then
				MODE="$1"
				POSITIONAL_MODE_SET=1
				shift
				continue
			fi
			echo "FAIL: unknown argument: $1" >&2
			exit 2
			;;
		--mode)
			[ "$#" -ge 2 ] || { echo "FAIL: --mode requires a value" >&2; exit 2; }
			MODE="$2"
			shift 2
			;;
		--interactive)
			INTERACTIVE=1
			shift
			;;
		--build-mode)
			[ "$#" -ge 2 ] || { echo "FAIL: --build-mode requires a value" >&2; exit 2; }
			BUILD_MODE="$2"
			shift 2
			;;
		--check-log|--log)
			[ "$#" -ge 2 ] || { echo "FAIL: $1 requires a value" >&2; exit 2; }
			CHECK_LOG_PATH="$2"
			shift 2
			;;
		--report-out)
			[ "$#" -ge 2 ] || { echo "FAIL: --report-out requires a value" >&2; exit 2; }
			CHECK_REPORT_OUT="$2"
			shift 2
			;;
		--no-save)
			CHECK_SAVE_REPORT=0
			shift
			;;
		--name-map)
			[ "$#" -ge 2 ] || { echo "FAIL: --name-map requires a value" >&2; exit 2; }
			NAME_MAP="$2"
			shift 2
			;;
		--request-name)
			[ "$#" -ge 2 ] || { echo "FAIL: --request-name requires a value" >&2; exit 2; }
			REQUEST_NAME="$2"
			shift 2
			;;
		--result-name)
			[ "$#" -ge 2 ] || { echo "FAIL: --result-name requires a value" >&2; exit 2; }
			RESULT_NAME="$2"
			shift 2
			;;
		--bin-name)
			[ "$#" -ge 2 ] || { echo "FAIL: --bin-name requires a value" >&2; exit 2; }
			BIN_NAME="$2"
			shift 2
			;;
		--tftp-dir)
			[ "$#" -ge 2 ] || { echo "FAIL: --tftp-dir requires a value" >&2; exit 2; }
			TFTP_OUT_DIR="$2"
			shift 2
			;;
		--source-image|--input-image)
			[ "$#" -ge 2 ] || { echo "FAIL: --source-image requires a value" >&2; exit 2; }
			SOURCE_IMAGE="$2"
			shift 2
			;;
		--allow-rescue-overwrite)
			ALLOW_RESCUE_OVERWRITE=1
			shift
			;;
		--force-rewrap-source)
			FORCE_REWRAP_SOURCE=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			echo "FAIL: unknown argument: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

parse_name_map "$NAME_MAP"
REQUEST_NAME="$(trim_ws "$REQUEST_NAME")"
RESULT_NAME="$(trim_ws "$RESULT_NAME")"
BIN_NAME="$(trim_ws "$BIN_NAME")"
TFTP_OUT_DIR="$(trim_ws "$TFTP_OUT_DIR")"
SOURCE_IMAGE="$(trim_ws "$SOURCE_IMAGE")"
MODE="$(normalize_mode "$(trim_ws "$MODE")")"
BUILD_MODE="$(printf '%s' "$BUILD_MODE" | tr '[:upper:]' '[:lower:]')"
CHECK_LOG_PATH="$(trim_ws "$CHECK_LOG_PATH")"

case "$BUILD_MODE" in
	auto|none|install|compile|full)
		;;
	*)
		echo "FAIL: invalid --build-mode '$BUILD_MODE' (use auto|none|install|compile|full)" >&2
		exit 2
		;;
esac

if [ "$MODE" = "interactive" ]; then
	INTERACTIVE=1
fi

if [ "$INTERACTIVE" = "1" ] && [ -t 0 ]; then
	interactive_choose_mode
fi

if [ "$MODE" = "help" ]; then
	usage
	exit 0
fi

if [ -z "$BIN_NAME" ] && [ -z "$NAME_MAP" ] && [ -t 0 ] && [ "$MODE" = "auto" ] && [ "$REQUEST_NAME" = "$DEFAULT_REQUEST_NAME" ] && [ "$RESULT_NAME" = "$DEFAULT_RESULT_NAME" ]; then
	printf 'Enter BIN filename (example: tc7200u-test.bin): ' >&2
	IFS= read -r BIN_NAME || true
	BIN_NAME="$(trim_ws "${BIN_NAME:-}")"
fi

if [ -z "$BIN_NAME" ] && [ -t 0 ] && [ "$MODE" = "auto" ] && [ "$REQUEST_NAME" = "$DEFAULT_REQUEST_NAME" ] && [ "$RESULT_NAME" = "$DEFAULT_RESULT_NAME" ]; then
	BIN_NAME="tc7200u-${TS}.bin"
fi

if [ -n "$BIN_NAME" ]; then
	REQUEST_NAME="$BIN_NAME"
	RESULT_NAME="$BIN_NAME"
fi

VERIFY_EXPECT_NAME="$REQUEST_NAME"

if [ -n "$SOURCE_IMAGE" ] && [ "$RESULT_NAME" = "$RESCUE_RESULT_NAME" ] && [ "$ALLOW_RESCUE_OVERWRITE" != "1" ]; then
	echo "FAIL: refusing to overwrite rescue image '$RESCUE_RESULT_NAME' from --source-image flow." >&2
	echo "FAIL: choose --bin-name <new-file>. Use --allow-rescue-overwrite only if intentional." >&2
	exit 2
fi

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

TFTP_OUT_DIR_WSL="$(to_wsl_path "$TFTP_OUT_DIR")"
TFTP_OUT_DIR_WSL="$(printf '%s' "$TFTP_OUT_DIR_WSL" | sed 's#/\+#/#g; s#/*$##')"
[ -n "$TFTP_OUT_DIR_WSL" ] || { echo "FAIL: empty TFTP output directory" >&2; exit 2; }
TFTP_OUT_DIR_DISPLAY="$(printf '%s' "$TFTP_OUT_DIR" | sed 's#[/\\]*$##')"
TFTP_OUT_SEP="/"
if printf '%s' "$TFTP_OUT_DIR_DISPLAY" | grep -Eq '^[A-Za-z]:'; then
	TFTP_OUT_SEP="\\"
fi

SOURCE_IMAGE_PATH=""
if [ -n "$SOURCE_IMAGE" ]; then
	SOURCE_IMAGE_PATH="$(to_wsl_path "$SOURCE_IMAGE")"
	if [ ! -f "$SOURCE_IMAGE_PATH" ]; then
		echo "FAIL: source image not found: $SOURCE_IMAGE ($SOURCE_IMAGE_PATH)" >&2
		exit 2
	fi
fi

WRAPPED="$TFTP_OUT_DIR_WSL/$RESULT_NAME"

mkdir -p "$RESEARCH_NOTES_DIR"
mkdir -p "$BUILD_LOG_BASE"
mkdir -p "$RESEARCH_BUILDS_DIR"
mkdir -p "$(dirname "$WRAPPED")"

progress() {
	STEP=$((STEP + 1))
	printf '[%d/%d] %s\n' "$STEP" "$TOTAL_STEPS" "$*"
}

progress_note() {
	printf '      %s\n' "$*"
}

report_note() {
	if [ -z "${RUN_REPORT:-}" ]; then
		return 0
	fi
	printf '%s\n' "$*" >>"$RUN_REPORT"
}

report_section() {
	report_note ""
	report_note "== $1 =="
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
	report_note "command_log=$log"
	report_note "command=$cmd_text"
	report_note "exit_code=$rc"
	return "$rc"
}

snapshot_build_context() {
	report_section "build context"
	report_note "timestamp_local=$(date '+%Y-%m-%d %H:%M:%S %Z')"
	report_note "owrt=$OWRT"
	report_note "raw_expected=$RAW"
	report_note "source_image=${SOURCE_IMAGE_PATH:-}"
	report_note "request_name=$REQUEST_NAME"
	report_note "result_name=$RESULT_NAME"
	report_note "wrapped_output=$WRAPPED"
	report_note "build_mode=$BUILD_MODE"
	report_note "jobs=$JOBS"

	if [ -f "$OWRT/.config" ]; then
		report_note "openwrt_config=$OWRT/.config"
		report_note "openwrt_target_lines_begin"
		grep -E '^CONFIG_TARGET_|^CONFIG_TARGET_BOARD=|^CONFIG_TARGET_SUBTARGET=|^CONFIG_TARGET_PROFILE=|^CONFIG_TARGET_ROOTFS_INITRAMFS' "$OWRT/.config" | sed 's/^/  /' >>"$RUN_REPORT" || true
		report_note "openwrt_target_lines_end"
	else
		report_note "openwrt_config_missing=1"
	fi

	if [ -d "$OWRT/bin/targets" ]; then
		report_note "initramfs_candidates_begin"
		find "$OWRT/bin/targets" -maxdepth 6 -type f \( -name '*initramfs*' -o -name '*.itb' -o -name '*.bin' \) | sort | sed 's/^/  /' | head -n 80 >>"$RUN_REPORT" || true
		report_note "initramfs_candidates_end"
	else
		report_note "openwrt_bin_targets_missing=1"
	fi

	report_note "recent_make_logs_begin"
	find "$RESEARCH_BUILDS_DIR" -maxdepth 1 -type f \( -name '*target-linux-*.log' -o -name '*make-full-image*.log' \) -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 10 | cut -d' ' -f2- | sed 's/^/  /' >>"$RUN_REPORT" || true
	report_note "recent_make_logs_end"
}

report_build_decision() {
	local action="$1"
	local config_changed="$2"
	local raw_exists="$3"
	local stale_input="$4"
	local vmlinux="$5"

	report_section "build decision"
	report_note "selected_action=$action"
	report_note "raw_exists=$raw_exists"
	report_note "config_changed=$config_changed"
	if [ -f "$RAW" ]; then
		report_note "raw_mtime=$(stat -c '%y' "$RAW" 2>/dev/null || echo unknown)"
	fi
	if [ -f "$OWRT/.config" ]; then
		report_note "config_mtime=$(stat -c '%y' "$OWRT/.config" 2>/dev/null || echo unknown)"
	fi
	if [ -n "$vmlinux" ] && [ -f "$vmlinux" ]; then
		report_note "vmlinux_path=$vmlinux"
		report_note "vmlinux_mtime=$(stat -c '%y' "$vmlinux" 2>/dev/null || echo unknown)"
	else
		report_note "vmlinux_path=none"
	fi
	if [ -n "$stale_input" ]; then
		report_note "stale_input=$stale_input"
	else
		report_note "stale_input=none"
	fi

	case "$action" in
		none)
			report_note "why=no newer config/source/vmlinux than selected raw image"
			;;
		install)
			report_note "why=kernel build artifacts exist; only image install/update required"
			;;
		compile)
			report_note "why=config or sources changed after raw image; kernel/image rebuild required"
			;;
		full)
			report_note "why=no usable bmips build artifact detected; full make required"
			;;
		*)
			report_note "why=unknown"
			;;
	esac
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

select_build_action() {
	local config_changed="$1"
	local raw_exists="$2"
	local stale_input="$3"
	local vmlinux="$4"
	local action="none"

	if [ "$BUILD_MODE" != "auto" ]; then
		printf '%s\n' "$BUILD_MODE"
		return 0
	fi

	if [ "$raw_exists" != "1" ]; then
		if [ -n "$vmlinux" ] && [ -f "$vmlinux" ]; then
			action="install"
		else
			action="full"
		fi
		printf '%s\n' "$action"
		return 0
	fi

	if [ "$config_changed" = "1" ]; then
		printf 'compile\n'
		return 0
	fi

	if [ "$OWRT/.config" -nt "$RAW" ]; then
		printf 'install\n'
		return 0
	fi

	if [ -n "$stale_input" ]; then
		printf 'compile\n'
		return 0
	fi

	if [ -n "$vmlinux" ] && [ -f "$vmlinux" ] && [ "$vmlinux" -nt "$RAW" ]; then
		printf 'install\n'
		return 0
	fi

	printf 'none\n'
}

run_openwrt_build() {
	local action="$1"
	local install_log="$BUILD_LOG_BASE/${TS}-target-linux-install.log"
	local compile_log="$BUILD_LOG_BASE/${TS}-target-linux-compile.log"
	local fallback_log="$BUILD_LOG_BASE/${TS}-make-full-image-fallback.log"

	case "$action" in
		none)
			progress_note "skipped build"
			report_note "make_action=skipped"
			;;
		install)
			if ! run_logged_allow_fail "$install_log" make -j"$JOBS" target/linux/install V=s; then
				progress_note "install failed in auto mode; retrying full image build"
				progress_note "install fail log: $install_log"
				tail -40 "$install_log" >&2 || true
				report_note "fallback_reason=target/linux/install failed"
				run_logged "$fallback_log" make -j"$JOBS" V=s
			fi
			;;
		compile)
			run_logged "$compile_log" make -j"$JOBS" target/linux/compile V=s
			if ! run_logged_allow_fail "$install_log" make -j"$JOBS" target/linux/install V=s; then
				progress_note "install failed after compile; retrying full image build"
				progress_note "install fail log: $install_log"
				tail -40 "$install_log" >&2 || true
				report_note "fallback_reason=target/linux/install failed after compile"
				run_logged "$fallback_log" make -j"$JOBS" V=s
			fi
			;;
		full)
			run_logged "$BUILD_LOG_BASE/${TS}-make-full-image.log" make -j"$JOBS" V=s
			;;
		*)
			echo "FAIL: unsupported build action: $action" >&2
			exit 2
			;;
	esac
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

status_mode() {
	cd "$RESEARCH"
	echo "== git =="
	git status --short || true
	echo
	echo "== scripts =="
	find scripts -maxdepth 3 -type f | sort
	echo
	echo "== records =="
	find records -maxdepth 3 -type d 2>/dev/null | sort || true
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

ensure_packages() (
	set -euo pipefail
	local profile=""
	local enable_packages=""
	local disable_packages=""
	local tmp_config=""
	local missing=0
	local pkg=""

	cd "$OWRT"
	[ -f .config ] || { echo "FAIL: missing OpenWrt .config in $OWRT" >&2; exit 1; }

	TC7200U_DEBUG_PACKAGES_DEFAULT="ethtool ip-full mtd nand-utils ubi-utils block-mount blkid lsblk dtc strace tcpdump"
	TC7200U_DRIVER_PACKAGES_DEFAULT="kmod-bgmac-b53 kmod-dsa-core kmod-mdio-bcm-unimac"
	TC7200U_PACKAGE_PROFILE="${TC7200U_PACKAGE_PROFILE:-fastboot}"
	TC7200U_DEBUG_PACKAGES="${TC7200U_DEBUG_PACKAGES:-$TC7200U_DEBUG_PACKAGES_DEFAULT}"
	TC7200U_EXTRA_DEBUG_PACKAGES="${TC7200U_EXTRA_DEBUG_PACKAGES:-}"
	TC7200U_DRIVER_PACKAGES="${TC7200U_DRIVER_PACKAGES:-$TC7200U_DRIVER_PACKAGES_DEFAULT}"
	TC7200U_INCLUDE_DRIVER_PACKAGES="${TC7200U_INCLUDE_DRIVER_PACKAGES:-0}"

	normalize_package_words() {
		printf '%s\n' "$1" | tr '[:space:]' '\n' | awk 'NF && !seen[$0]++ { print }'
	}

	set_pkg_state() {
		local cfg="$1"
		local pkg_name="$2"
		local state="$3"
		local opt="CONFIG_PACKAGE_${pkg_name}"

		awk -v opt="$opt" '$0 != opt"=y" && $0 != "# "opt" is not set" { print }' "$cfg" >"$cfg.next"
		mv "$cfg.next" "$cfg"
		if [ "$state" = "y" ]; then
			echo "${opt}=y" >>"$cfg"
		else
			echo "# ${opt} is not set" >>"$cfg"
		fi
	}

	profile="$(printf '%s' "$TC7200U_PACKAGE_PROFILE" | tr '[:upper:]' '[:lower:]')"
	case "$profile" in
		fastboot)
			disable_packages="$(normalize_package_words "$TC7200U_DEBUG_PACKAGES_DEFAULT $TC7200U_DEBUG_PACKAGES $TC7200U_EXTRA_DEBUG_PACKAGES $TC7200U_DRIVER_PACKAGES_DEFAULT $TC7200U_DRIVER_PACKAGES")"
			;;
		debug)
			enable_packages="$(normalize_package_words "$TC7200U_DEBUG_PACKAGES $TC7200U_EXTRA_DEBUG_PACKAGES")"
			if [ "$TC7200U_INCLUDE_DRIVER_PACKAGES" = "1" ]; then
				enable_packages="$(normalize_package_words "$enable_packages $TC7200U_DRIVER_PACKAGES")"
			fi
			;;
		*)
			echo "FAIL: unsupported TC7200U_PACKAGE_PROFILE: $TC7200U_PACKAGE_PROFILE (use fastboot or debug)" >&2
			exit 2
			;;
	esac

	tmp_config="$(mktemp)"
	cp .config "$tmp_config"
	if [ -n "$enable_packages" ]; then
		while IFS= read -r pkg; do
			[ -n "$pkg" ] || continue
			set_pkg_state "$tmp_config" "$pkg" y
		done <<EOF_PACKAGES
$enable_packages
EOF_PACKAGES
	fi
	if [ -n "$disable_packages" ]; then
		while IFS= read -r pkg; do
			[ -n "$pkg" ] || continue
			set_pkg_state "$tmp_config" "$pkg" n
		done <<EOF_PACKAGES
$disable_packages
EOF_PACKAGES
	fi
	cp "$tmp_config" .config
	rm -f "$tmp_config"

	echo "== TC7200U package profile =="
	echo "OWRT=$OWRT"
	echo "TC7200U_PACKAGE_PROFILE=$profile"
	echo "TC7200U_INCLUDE_DRIVER_PACKAGES=$TC7200U_INCLUDE_DRIVER_PACKAGES"
	make defconfig
	echo

	if [ "$profile" = "debug" ]; then
		if [ -z "$enable_packages" ]; then
			echo "INFO: debug profile selected with empty package set"
		else
			while IFS= read -r pkg; do
				[ -n "$pkg" ] || continue
				if grep -qx "CONFIG_PACKAGE_${pkg}=y" .config; then
					echo "enabled:   $pkg"
				else
					echo "WARN: not enabled after defconfig: $pkg" >&2
					missing=1
				fi
			done <<EOF_PACKAGES
$enable_packages
EOF_PACKAGES
		fi
		[ "$missing" = "0" ] || echo "WARN: at least one debug package was not selected. Check feeds/package name availability." >&2
		echo "OK: OpenWrt .config updated for TC7200U debug profile"
	else
		if [ -z "$disable_packages" ]; then
			echo "INFO: fastboot profile had no packages to disable"
		else
			while IFS= read -r pkg; do
				[ -n "$pkg" ] || continue
				if grep -qx "CONFIG_PACKAGE_${pkg}=y" .config; then
					echo "WARN: still enabled after fastboot profile: $pkg" >&2
					missing=1
				else
					echo "disabled:  $pkg"
				fi
			done <<EOF_PACKAGES
$disable_packages
EOF_PACKAGES
		fi
		[ "$missing" = "0" ] || echo "WARN: fastboot profile could not disable at least one package." >&2
		echo "OK: OpenWrt .config updated for TC7200U fastboot profile"
	fi
)

capture_state() {
	local linux_dir=""
	local vmlinux=""
	local setupc=""
	local patch=""
	local dts=""
	local dtsi=""
	local out=""

	linux_dir="$(find "$OWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268" -maxdepth 1 -type d -name 'linux-*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
	linux_dir="${linux_dir:-$OWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-missing}"
	vmlinux="$linux_dir/vmlinux"
	setupc="$linux_dir/arch/mips/bmips/setup.c"
	patch="$OWRT/target/linux/bmips/patches-6.12/910-tc7200u-mmio-boot-log.patch"
	dts="$OWRT/target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts"
	dtsi="$OWRT/target/linux/bmips/dts/bcm3384_viper.dtsi"
	out="$RESEARCH_NOTES_DIR/${TS}-current-state.txt"

	mkdir -p "$RESEARCH_NOTES_DIR"
	{
		echo "# TC7200U current state"
		echo
		date -Is
		echo
		echo "## Important files"
		echo "OWRT=$OWRT"
		echo "LINUX_DIR=$linux_dir"
		echo "REQUEST_NAME=$REQUEST_NAME"
		echo "RESULT_NAME=$RESULT_NAME"
		ls -lh --time-style=long-iso "$RAW" "$WRAPPED" "$vmlinux" "$setupc" "$patch" "$dts" "$dtsi" 2>&1 || true
		echo
		echo "## SHA256"
		sha256sum "$RAW" "$WRAPPED" "$vmlinux" "$setupc" "$patch" "$dts" "$dtsi" 2>&1 || true
		echo
		echo "## A825 verification"
		a825_verify --raw "$RAW" --wrapped "$WRAPPED" --expect-name "$REQUEST_NAME" 2>&1 || true
		echo
		echo "## MMIO strings in object/vmlinux/raw"
		strings -a "$linux_dir/arch/mips/bmips/setup.o" 2>/dev/null | grep -F 'tc7200u-mmio' || true
		echo
		strings -a "$vmlinux" 2>/dev/null | grep -F 'tc7200u-mmio' || true
		echo
		strings -a "$RAW" 2>/dev/null | grep -F 'tc7200u-mmio' || true
		echo
		echo "## Current MMIO probe list in build source"
		grep -nA40 'static const phys_addr_t addrs' "$setupc" 2>&1 || true
		echo
		echo "## Current MMIO probe list in persistent patch"
		grep -nA60 'static int __init __used tc7200u_mmio_boot_log' "$patch" 2>&1 || true
		echo
		echo "## Network-related config"
		grep -Rns "CONFIG_BGMAC\|CONFIG_B53\|CONFIG_NET_DSA\|CONFIG_MDIO_BCM" "$OWRT/.config" "$OWRT/target/linux/bmips/config-6.12" "$OWRT/target/linux/bmips/bcm63268/config-6.12" "$linux_dir/.config" 2>/dev/null || true
	} >"$out"
	echo "$out"
}

check_gates() {
	local log_path="$CHECK_LOG_PATH"
	local report_out="$CHECK_REPORT_OUT"
	local save_report="$CHECK_SAVE_REPORT"
	local newest=""
	local basename_no_ext=""
	local ts=""

	while [ "$#" -gt 0 ]; do
		case "$1" in
			--log)
				shift; [ "$#" -gt 0 ] || { echo "ERROR: --log requires a value" >&2; exit 2; }
				log_path="$1"
				;;
			--report-out)
				shift; [ "$#" -gt 0 ] || { echo "ERROR: --report-out requires a value" >&2; exit 2; }
				report_out="$1"
				;;
			--no-save)
				save_report=0
				;;
			-h|--help)
				echo "Usage: $0 check-gates [--log /abs/path/to/picocom.log] [--report-out /abs/path/to/report.txt] [--no-save]"
				return 0
				;;
			*)
				echo "ERROR: unknown check-gates argument: $1" >&2
				exit 2
				;;
		esac
		shift
	done

	if [ -z "$log_path" ]; then
		newest="$(ls -1t "$RECORDS_DIR/logs/serial"/picocom-mapp-*.log "$RECORDS_DIR/logs/serial"/picocom-*.log 2>/dev/null | head -n 1 || true)"
		[ -n "$newest" ] || { echo "ERROR: no picocom logs found under $RECORDS_DIR/logs/serial" >&2; exit 2; }
		log_path="$newest"
	fi
	[ -f "$log_path" ] || { echo "ERROR: log not found: $log_path" >&2; exit 2; }

	basename_no_ext="$(basename "$log_path")"
	basename_no_ext="${basename_no_ext%.log}"
	ts="$(date +%Y-%m-%d-%H%M%S)"
	if [ -z "$report_out" ] && [ "$save_report" = "1" ]; then
		mkdir -p "$RESEARCH_BUILDS_DIR"
		report_out="$RESEARCH_BUILDS_DIR/${ts}-check-gates-${basename_no_ext}.txt"
	fi

	count_fixed() {
		local pat="$1"
		local out
		out="$(rg -F -c -- "$pat" "$log_path" || true)"
		[ -n "$out" ] && echo "$out" || echo "0"
	}
	line_first() {
		local pat="$1"
		rg -F -n -- "$pat" "$log_path" | head -n 1 | cut -d: -f1 || true
	}
	line_last_after() {
		local pat="$1"
		local start_line="$2"
		[ -n "$start_line" ] || { echo ""; return; }
		rg -F -n -- "$pat" "$log_path" | awk -F: -v s="$start_line" '$1 > s { print $1 }' | tail -n 1 || true
	}
	status_line() {
		local name="$1"
		local value="$2"
		printf '%-8s %s\n' "$name" "$value"
	}

	local tftp_complete sig_a825 exec_img4 exceptions decomp_fail nand_fail nand_ooo
	local hs_getmsg_err hs_unexp_err unhandled_msgs hs_msg_lines cfe_banner
	local owrt_loader owrt_kernel_decomp warn_no_console panic_lines panic_init_kill
	local procd_init_lines press_enter_lines busybox_shell_lines build_warning_lines
	local build_error_lines build_patch_fail_lines build_target_time_lines exec_line
	local cfe_after_exec_line gate_a gate_a_detail gate_b gate_c gate_c_detail
	local hs_total gate_d gate_e gate_e_detail

	tftp_complete="$(count_fixed 'Tftp complete')"
	sig_a825="$(count_fixed 'Signature: a825')"
	exec_img4="$(count_fixed 'Executing Image 4...')"
	exceptions="$(count_fixed 'EXCEPTION TYPE:')"
	decomp_fail="$(count_fixed 'Decompression failed')"
	nand_fail="$(count_fixed 'NandFlashRead: Failed to find replacement block!')"
	nand_ooo="$(count_fixed 'NandFlashRead: Detected out-of-order block')"
	hs_getmsg_err="$(count_fixed 'Error: getHostDqmMessage(handshake)')"
	hs_unexp_err="$(count_fixed 'Error: handshake rx unexpected message')"
	unhandled_msgs="$(count_fixed 'unhandled message')"
	hs_msg_lines="$(count_fixed 'HandShakeMsg =')"
	cfe_banner="$(count_fixed 'Board IP Address [')"
	owrt_loader="$(count_fixed 'OpenWrt kernel loader for BMIPS')"
	owrt_kernel_decomp="$(count_fixed 'Decompressing kernel...')"
	warn_no_console="$(count_fixed 'Warning: unable to open an initial console.')"
	panic_lines="$(count_fixed 'Kernel panic - not syncing:')"
	panic_init_kill="$(count_fixed 'Attempted to kill init!')"
	procd_init_lines="$(count_fixed 'procd: - init -')"
	press_enter_lines="$(count_fixed 'Please press Enter to activate this console.')"
	busybox_shell_lines="$(count_fixed 'BusyBox v')"
	build_warning_lines="$(count_fixed 'WARNING: Makefile')"
	build_error_lines="$(count_fixed 'ERROR:')"
	build_patch_fail_lines="$(count_fixed 'Patch failed!')"
	build_target_time_lines="$(count_fixed 'time: target/linux/')"
	exec_line="$(line_first 'Executing Image 4...')"
	cfe_after_exec_line="$(line_last_after 'Board IP Address [' "$exec_line")"

	gate_a="FAIL"
	gate_a_detail="missing header/load markers"
	if [ "$tftp_complete" -ge 1 ] && [ "$sig_a825" -ge 1 ] && [ "$exec_img4" -ge 1 ]; then
		gate_a="PASS"
		gate_a_detail="accepted"
	fi
	if [ "$gate_a" = "FAIL" ] && [ "$decomp_fail" -gt 0 ]; then
		gate_a_detail="decompression_failed"
	fi

	gate_b="PASS"
	[ "$exceptions" -eq 0 ] || gate_b="FAIL"
	[ -z "$cfe_after_exec_line" ] || gate_b="FAIL"
	if [ "$panic_lines" -gt 0 ] || [ "$panic_init_kill" -gt 0 ]; then gate_b="FAIL"; fi

	gate_c="PASS"
	gate_c_detail="clean"
	if [ "$nand_fail" -gt 0 ]; then
		gate_c="FAIL"
		gate_c_detail="fatal/unknown"
	fi
	hs_total=$((hs_getmsg_err + hs_unexp_err + unhandled_msgs + hs_msg_lines))
	gate_d="PASS"
	if [ "$hs_total" -gt 20 ]; then gate_d="FAIL"; elif [ "$hs_total" -gt 0 ]; then gate_d="WARN"; fi
	if [ -n "$cfe_after_exec_line" ] && [ "$hs_total" -gt 0 ]; then gate_d="FAIL"; fi

	gate_e="PASS"
	gate_e_detail="console_ready"
	if [ "$warn_no_console" -gt 0 ] || [ "$panic_lines" -gt 0 ] || [ "$panic_init_kill" -gt 0 ]; then
		gate_e="FAIL"; gate_e_detail="userspace_console_failed"
	elif [ "$procd_init_lines" -eq 0 ] || [ "$press_enter_lines" -eq 0 ] || [ "$busybox_shell_lines" -eq 0 ]; then
		gate_e="WARN"; gate_e_detail="boot_not_fully_observed"
	fi

	echo "log=$log_path"
	echo
	echo "== markers =="
	echo "tftp_complete=$tftp_complete"
	echo "signature_a825=$sig_a825"
	echo "executing_image4=$exec_img4"
	echo "exceptions=$exceptions"
	echo "decompression_failed=$decomp_fail"
	echo "nand_fail_no_replacement=$nand_fail"
	echo "nand_out_of_order=$nand_ooo"
	echo "hs_getmsg_error=$hs_getmsg_err"
	echo "hs_unexpected_error=$hs_unexp_err"
	echo "unhandled_message_lines=$unhandled_msgs"
	echo "handshake_msg_lines=$hs_msg_lines"
	echo "cfe_banner_lines=$cfe_banner"
	echo "openwrt_loader_lines=$owrt_loader"
	echo "openwrt_decompress_kernel_lines=$owrt_kernel_decomp"
	echo "warning_initial_console_lines=$warn_no_console"
	echo "kernel_panic_lines=$panic_lines"
	echo "panic_init_kill_lines=$panic_init_kill"
	echo "procd_init_lines=$procd_init_lines"
	echo "press_enter_lines=$press_enter_lines"
	echo "busybox_shell_lines=$busybox_shell_lines"
	echo "build_warning_lines=$build_warning_lines"
	echo "build_error_lines=$build_error_lines"
	echo "build_patch_fail_lines=$build_patch_fail_lines"
	echo "build_target_time_lines=$build_target_time_lines"
	[ -z "$exec_line" ] || echo "executing_image4_line=$exec_line"
	[ -z "$cfe_after_exec_line" ] || echo "cfe_banner_after_exec_line=$cfe_after_exec_line"
	echo
	echo "== gate verdicts =="
	status_line "Gate A:" "$gate_a ($gate_a_detail)"
	status_line "Gate B:" "$gate_b"
	status_line "Gate C:" "$gate_c ($gate_c_detail)"
	status_line "Gate D:" "$gate_d"
	status_line "Gate E:" "$gate_e ($gate_e_detail)"

	if [ "$save_report" = "1" ] && [ -n "$report_out" ]; then
		{
			echo "# TC7200U Gate Report"
			echo
			echo "generated_at=$(date -Is)"
			echo "log_path=$log_path"
			echo "report_path=$report_out"
			echo
			echo "## Log metadata"
			ls -lh --time-style=long-iso "$log_path" 2>/dev/null || true
			sha256sum "$log_path" 2>/dev/null || true
			echo
			echo "## Marker counts"
			echo "tftp_complete=$tftp_complete"
			echo "signature_a825=$sig_a825"
			echo "executing_image4=$exec_img4"
			echo "exceptions=$exceptions"
			echo "decompression_failed=$decomp_fail"
			echo "nand_fail_no_replacement=$nand_fail"
			echo "nand_out_of_order=$nand_ooo"
			echo "hs_getmsg_error=$hs_getmsg_err"
			echo "hs_unexpected_error=$hs_unexp_err"
			echo "unhandled_message_lines=$unhandled_msgs"
			echo "handshake_msg_lines=$hs_msg_lines"
			echo "cfe_banner_lines=$cfe_banner"
			echo "openwrt_loader_lines=$owrt_loader"
			echo "openwrt_decompress_kernel_lines=$owrt_kernel_decomp"
			echo "warning_initial_console_lines=$warn_no_console"
			echo "kernel_panic_lines=$panic_lines"
			echo "panic_init_kill_lines=$panic_init_kill"
			echo "procd_init_lines=$procd_init_lines"
			echo "press_enter_lines=$press_enter_lines"
			echo "busybox_shell_lines=$busybox_shell_lines"
			echo "build_warning_lines=$build_warning_lines"
			echo "build_error_lines=$build_error_lines"
			echo "build_patch_fail_lines=$build_patch_fail_lines"
			echo "build_target_time_lines=$build_target_time_lines"
			[ -z "$exec_line" ] || echo "executing_image4_line=$exec_line"
			[ -z "$cfe_after_exec_line" ] || echo "cfe_banner_after_exec_line=$cfe_after_exec_line"
			echo
			echo "## Gate verdicts"
			status_line "Gate A:" "$gate_a ($gate_a_detail)"
			status_line "Gate B:" "$gate_b"
			status_line "Gate C:" "$gate_c ($gate_c_detail)"
			status_line "Gate D:" "$gate_d"
			status_line "Gate E:" "$gate_e ($gate_e_detail)"
			echo
			echo "## Boot/runtime key lines"
			rg -n "OpenWrt kernel loader for BMIPS|Decompressing kernel|Starting kernel at|Linux version|Kernel command line|Warning: unable to open an initial console|Run /init as init process|do_page_fault\\(\\)|Kernel panic - not syncing|Attempted to kill init|Rebooting in|Reboot failed|procd: - early -|procd: - ubus -|procd: - init -|Please press Enter to activate this console.|BusyBox v|NETDEV WATCHDOG|EXCEPTION TYPE:" "$log_path" || true
			echo
			echo "## Build key lines"
			rg -n "WARNING: Makefile|time: target/linux/|Patch failed!|ERROR: target/linux failed to build|make\\[[0-9]+\\]: \\*\\*\\*" "$log_path" || true
		} >"$report_out"
		echo
		echo "report_saved=$report_out"
	fi
}

serial_console() {
	local busid="${BUSID:-1-9}"
	local dev="${DEV:-}"
	local pwsh="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
	local send_char_delay="${SEND_CHAR_DELAY:-60}"
	local send_line_delay="${SEND_LINE_DELAY:-000}"
	local send_cmd="${SEND_CMD:-ascii-xfr -s -l${send_line_delay} -c ${send_char_delay}}"
	local log=""
	local devices=()

	echo "== TC7200.U serial console =="
	echo "BUSID=$busid"
	case "$busid" in *[!0-9.-]*) echo "ERROR: unsafe BUSID: $busid" >&2; exit 1 ;; esac
	if [ -x "$pwsh" ]; then
		if ! "$pwsh" -NoProfile -Command "usbipd attach --wsl --busid $busid"; then
			echo "WARN: usbipd attach failed or device is already attached. Continuing."
		fi
	else
		echo "WARN: PowerShell path not found: $pwsh"
	fi
	sudo modprobe usbserial
	sudo modprobe ch341
	if [ -z "$dev" ]; then
		for _ in $(seq 1 40); do
			mapfile -t devices < <(find /dev -maxdepth 1 \( -name 'ttyUSB*' -o -name 'ttyACM*' \) -print 2>/dev/null | sort)
			if [ "${#devices[@]}" -eq 1 ]; then dev="${devices[0]}"; break; fi
			if [ "${#devices[@]}" -gt 1 ]; then
				echo "ERROR: multiple serial devices found; set DEV explicitly" >&2
				printf '  %s\n' "${devices[@]}" >&2
				exit 1
			fi
			sleep 0.25
		done
	fi
	[ -n "$dev" ] || { echo "ERROR: no /dev/ttyUSB* or /dev/ttyACM* found"; exit 1; }
	if pgrep -af "picocom.*$dev" >/dev/null; then
		echo "ERROR: picocom already appears to be using $dev"
		pgrep -af "picocom.*$dev" || true
		exit 1
	fi
	mkdir -p "$RECORDS_DIR/logs/serial"
	log="$RECORDS_DIR/logs/serial/picocom-$(date +%Y%m%d-%H%M%S).log"
	echo "DEV=$dev"
	echo "LOG=$log"
	echo "Exit picocom: Ctrl-a then Ctrl-x"
	echo "Slow-send file in picocom: Ctrl-a then Ctrl-s"
	echo "SEND_CMD=$send_cmd"
	exec sudo picocom -b 115200 --flow n --send-cmd "$send_cmd" --logfile "$log" "$dev"
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

selftest_mode() {
	local tmp=""
	local raw=""
	local wrapped=""
	local bad_hcs=""
	local bad_payload=""

	tmp="$(mktemp -d "${TMPDIR:-/tmp}/tc7200u-selftest.XXXXXX")"
	cleanup() {
		case "$tmp" in
			/tmp/tc7200u-selftest.*) rm -rf "$tmp" ;;
		esac
	}
	trap cleanup EXIT INT TERM
	raw="$tmp/raw.bin"
	wrapped="$tmp/wrapped.bin"
	bad_hcs="$tmp/bad-hcs.bin"
	bad_payload="$tmp/bad-payload.bin"
	printf 'test-payload' >"$raw"
	a825_wrap --input "$raw" --output "$wrapped" --build-time 0x12345678 >/dev/null
	a825_verify --raw "$raw" --wrapped "$wrapped" >/dev/null
	cp "$wrapped" "$bad_hcs"
	printf '\000\000' | dd of="$bad_hcs" bs=1 seek=84 conv=notrunc status=none
	if a825_verify --raw "$raw" --wrapped "$bad_hcs" >/dev/null 2>&1; then
		echo "FAIL: verifier accepted corrupted HCS" >&2
		exit 1
	fi
	cp "$wrapped" "$bad_payload"
	printf X | dd of="$bad_payload" bs=1 seek=92 conv=notrunc status=none
	if a825_verify --raw "$raw" --wrapped "$bad_payload" >/dev/null 2>&1; then
		echo "FAIL: verifier accepted corrupted payload" >&2
		exit 1
	fi
	if a825_verify --raw "$raw" --wrapped "$wrapped" --expect-load 0x83000000 >/dev/null 2>&1; then
		echo "FAIL: verifier accepted wrong expected load address" >&2
		exit 1
	fi
	echo "OK: TC7200U script selftest passed"
	trap - EXIT INT TERM
	cleanup
}

if [ "$MODE" = "paths" ]; then
	echo "MODE=$MODE"
	echo "BUILD_MODE=$BUILD_MODE"
	echo "RECORDS_DIR=$RECORDS_DIR"
	echo "RESEARCH=$RESEARCH"
	echo "RESEARCH_BUILDS_DIR=$RESEARCH_BUILDS_DIR"
	echo "RESEARCH_NOTES_DIR=$RESEARCH_NOTES_DIR"
	echo "OWRT=$OWRT"
	echo "RAW=$RAW"
	echo "REQUEST_NAME=$REQUEST_NAME"
	echo "RESULT_NAME=$RESULT_NAME"
	echo "WRAPPED=$WRAPPED"
	echo "TFTP_OUT_DIR=$TFTP_OUT_DIR"
	echo "TFTP_OUT_DIR_WSL=$TFTP_OUT_DIR_WSL"
	exit 0
fi

if [ "$MODE" = "status" ]; then
	status_mode
	exit 0
fi

if [ "$MODE" = "selftest" ]; then
	selftest_mode
	exit 0
fi

if [ "$MODE" = "reverse-stage1" ]; then
	reverse_stage1 "$@"
	exit 0
fi

if [ "$MODE" = "serial-console" ]; then
	serial_console "$@"
	exit 0
fi

if [ "$MODE" = "check-gates" ]; then
	check_gates "$@"
	exit 0
fi

if [ "$MODE" = "capture-state" ]; then
	capture_state
	exit 0
fi

if [ "$MODE" = "ensure-packages" ]; then
	ensure_packages
	exit 0
fi

if [ "$MODE" != "auto" ]; then
	echo "FAIL: unsupported mode: $MODE" >&2
	usage >&2
	exit 2
fi

RUN_REPORT="$RESEARCH_BUILDS_DIR/${TS}-build-provenance.log"
: >"$RUN_REPORT"
report_section "meta"
report_note "mode=$MODE"
report_note "script=$0"
report_note "ts=$TS"
report_note "research=$RESEARCH"
report_note "notes_dir=$RESEARCH_NOTES_DIR"
report_note "build_log_base=$BUILD_LOG_BASE"
progress_note "build report: $RUN_REPORT"
snapshot_build_context

if [ -n "$SOURCE_IMAGE_PATH" ]; then
	TOTAL_STEPS=3
	report_section "flow"
	report_note "path=source-image"
	report_note "why=custom source image provided; openwrt make skipped"
	progress "Preparing custom source image"
	progress_note "name map: $REQUEST_NAME -> $RESULT_NAME"
	progress_note "tftp dir: $TFTP_OUT_DIR ($TFTP_OUT_DIR_WSL)"
	progress_note "source image: $SOURCE_IMAGE ($SOURCE_IMAGE_PATH)"

	if is_programstore_wrapped_file "$SOURCE_IMAGE_PATH"; then
		RAW="$BUILD_LOG_BASE/${TS}-source-payload.raw"
		progress_note "detected existing ProgramStore header"
		src_load_hex="$(dd if="$SOURCE_IMAGE_PATH" bs=1 skip=16 count=4 2>/dev/null | xxd -p -c4 || true)"
		if printf '%s' "$src_load_hex" | grep -Eq '^[0-9a-fA-F]{8}$'; then
			EXPECT_LOAD_HEX="0x$(printf '%s' "$src_load_hex" | tr 'A-F' 'a-f')"
			progress_note "preserved load address: $EXPECT_LOAD_HEX"
		else
			progress_note "unable to read source load address; falling back to $EXPECT_LOAD_HEX"
		fi
			src_header_name="$(programstore_header_name "$SOURCE_IMAGE_PATH" || true)"
			if [ -n "$src_header_name" ]; then
				progress_note "source header filename: $src_header_name"
			fi
			src_signature_hex="$(programstore_header_signature "$SOURCE_IMAGE_PATH" || true)"
			if printf '%s' "$src_signature_hex" | grep -Eq '^0x[0-9a-fA-F]{4}$'; then
				src_signature_hex="$(printf '%s' "$src_signature_hex" | tr 'A-F' 'a-f')"
				progress_note "source signature: $src_signature_hex"
			else
				src_signature_hex=""
			fi

			if [ "$FORCE_REWRAP_SOURCE" = "1" ]; then
				progress_note "force-rewrap enabled; stripping ${A825_HEADER_BYTES}-byte header"
				progress_note "preserving source ProgramStore control/revision/load/build fields"
				WRAP_EXTRA_ARGS+=(--preserve-from "$SOURCE_IMAGE_PATH")
			if ! tail -c "+$((A825_HEADER_BYTES + 1))" "$SOURCE_IMAGE_PATH" >"$RAW" 2>/dev/null; then
				if ! dd if="$SOURCE_IMAGE_PATH" of="$RAW" bs=1 skip="$A825_HEADER_BYTES" 2>/dev/null; then
					echo "FAIL: unable to strip A825 header from source image: $SOURCE_IMAGE_PATH" >&2
					exit 1
				fi
			fi
			else
				progress_note "preserving wrapped source image bytes exactly (no header rewrite)"
				VERIFY_EXPECT_NAME="${src_header_name:-$VERIFY_EXPECT_NAME}"
				if [ -n "$src_signature_hex" ]; then
					VERIFY_EXPECT_SIGNATURE_HEX="$src_signature_hex"
				fi
				SKIP_WRAP=1
				if ! tail -c "+$((A825_HEADER_BYTES + 1))" "$SOURCE_IMAGE_PATH" >"$RAW" 2>/dev/null; then
					if ! dd if="$SOURCE_IMAGE_PATH" of="$RAW" bs=1 skip="$A825_HEADER_BYTES" 2>/dev/null; then
						echo "FAIL: unable to strip A825 header from source image: $SOURCE_IMAGE_PATH" >&2
					exit 1
				fi
			fi
		fi
		[ -s "$RAW" ] || { echo "FAIL: stripped payload is empty: $RAW" >&2; exit 1; }
	else
		progress_note "source appears to be raw payload (no ProgramStore header)"
		RAW="$SOURCE_IMAGE_PATH"
	fi

	progress_note "raw: $RAW"
else
	report_section "flow"
	report_note "path=openwrt-build"
	progress "Inspecting OpenWrt build outputs"
	progress_note "name map: $REQUEST_NAME -> $RESULT_NAME"
	progress_note "tftp dir: $TFTP_OUT_DIR ($TFTP_OUT_DIR_WSL)"
	VMLINUX="$(latest_vmlinux || true)"
	if [ -n "$VMLINUX" ]; then
		progress_note "latest vmlinux: $VMLINUX"
	else
		progress_note "latest vmlinux: not found yet"
	fi

	progress "Capturing OpenWrt config before package profile"
	config_before="$BUILD_LOG_BASE/${TS}-openwrt-config-before-debug-packages"
	config_after="$BUILD_LOG_BASE/${TS}-openwrt-config-after-debug-packages"
	cp "$OWRT/.config" "$config_before"
	progress_note "saved: $config_before"

	progress "Applying TC7200U package profile"
	progress_note "TC7200U_PACKAGE_PROFILE=${TC7200U_PACKAGE_PROFILE:-fastboot} (set to debug for full diagnostics tools)"
	run_logged "$BUILD_LOG_BASE/${TS}-ensure-debug-packages.log" ensure_packages

	cp "$OWRT/.config" "$config_after"
	progress_note "saved: $config_after"

	progress "Checking whether image rebuild is needed"
	config_changed=0
	raw_exists=0
	stale_input=""
	if ! cmp -s "$config_before" "$config_after"; then
		progress_note "package profile config changed"
		config_changed=1
	fi

	if [ -f "$RAW" ]; then
		raw_exists=1
	else
		progress_note "raw initramfs missing"
	fi

	if [ "$raw_exists" = "1" ]; then
		if [ "$OWRT/.config" -nt "$RAW" ]; then
			progress_note "OpenWrt .config is newer than raw initramfs"
		fi
		if [ -n "$VMLINUX" ] && [ "$VMLINUX" -nt "$RAW" ]; then
			progress_note "vmlinux is newer than raw initramfs"
		fi
		stale_input="$(newer_build_input || true)"
		if [ -n "$stale_input" ]; then
			progress_note "source newer than raw image: $stale_input"
		fi
	else
		stale_input=""
	fi

	build_action="$(select_build_action "$config_changed" "$raw_exists" "$stale_input" "$VMLINUX")"
	progress_note "decision: $build_action (build-mode=$BUILD_MODE)"
	report_build_decision "$build_action" "$config_changed" "$raw_exists" "$stale_input" "$VMLINUX"

	progress "Building OpenWrt image if required"
	cd "$OWRT"
	run_openwrt_build "$build_action"

	if [ ! -f "$RAW" ]; then
		echo "FAIL: raw initramfs missing after build: $RAW" >&2
		exit 1
	fi
	progress_note "raw: $RAW"
fi

wrap_log="$BUILD_LOG_BASE/${TS}-wrap.log"
if [ "$SKIP_WRAP" = "1" ]; then
	progress "Copying pre-wrapped source image"
	progress_note "log: $wrap_log"
	cp -f "$SOURCE_IMAGE_PATH" "$WRAPPED"
	{
		echo "mode=passthrough"
		echo "source=$SOURCE_IMAGE_PATH"
		echo "output=$WRAPPED"
			echo "raw=$RAW"
			echo "expect_load=$EXPECT_LOAD_HEX"
			echo "expect_name=$VERIFY_EXPECT_NAME"
			echo "expect_signature=$VERIFY_EXPECT_SIGNATURE_HEX"
		} >"$wrap_log"
else
	progress "Wrapping raw initramfs with A825 header"
	run_logged "$wrap_log" a825_wrap --input "$RAW" --output "$WRAPPED" --filename "$REQUEST_NAME" "${WRAP_EXTRA_ARGS[@]}"
fi
sync
progress_note "wrapped: $WRAPPED"

progress "Verifying wrapped image"
verify_log="$BUILD_LOG_BASE/${TS}-verify.log"
run_logged "$verify_log" a825_verify --raw "$RAW" --wrapped "$WRAPPED" --expect-load "$EXPECT_LOAD_HEX" --expect-name "$VERIFY_EXPECT_NAME" --expect-signature "$VERIFY_EXPECT_SIGNATURE_HEX"
report_section "outputs"
report_note "raw=$RAW"
report_note "wrapped=$WRAPPED"
report_note "wrap_log=$wrap_log"
report_note "verify_log=$verify_log"
if [ -f "$RAW" ]; then
	report_note "raw_sha256=$(sha256sum "$RAW" | awk '{print $1}')"
fi
if [ -f "$WRAPPED" ]; then
	report_note "wrapped_sha256=$(sha256sum "$WRAPPED" | awk '{print $1}')"
fi

grep -q '^size_ok=True$' "$verify_log"
echo "CHECK OK: size_ok=True"
grep -m1 '^OK: wrapped image matches raw payload and expected header fields$' "$verify_log"
report_note "result=ok"
report_note "ready_for_tftp_request=$REQUEST_NAME"
report_note "served_file=$TFTP_OUT_DIR_DISPLAY$TFTP_OUT_SEP$RESULT_NAME"
echo "AUTO: ready for cfe-tftp. CFE request: $REQUEST_NAME ; served file: $TFTP_OUT_DIR_DISPLAY$TFTP_OUT_SEP$RESULT_NAME."
