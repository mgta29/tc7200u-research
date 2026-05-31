#!/usr/bin/env bash
set -euo pipefail

OWRT="${OWRT:-$HOME/src/openwrt}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RESEARCH_BUILDS_DIR="${RESEARCH_BUILDS_DIR:-$RESEARCH/research/builds}"
RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RESEARCH_BUILDS_DIR}"
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
WRAPPED=""
A825WRAP="$RESEARCH/scripts/tc7200u-a825-wrap.py"
A825VERIFY="$RESEARCH/scripts/tc7200u-verify-a825-image.py"
A825CHECK="$RESEARCH/scripts/tc7200u-check-gates.sh"
A825STATE="$RESEARCH/scripts/tc7200u-capture-current-state.sh"
A825PACKAGES="$RESEARCH/scripts/tc7200u-ensure-debug-packages.sh"
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
  auto            Build (if needed), wrap, verify. (default)
  check-gates     Run gate checks on serial log.
  capture-state   Capture current OpenWrt/wrapper state snapshot.
  ensure-packages Apply TC7200U package profile and run defconfig.
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
		paths|interactive|help)
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
	echo "  5) paths"
	printf 'Choice [1]: ' >&2
	local choice=""
	IFS= read -r choice || true
	choice="$(trim_ws "${choice:-}")"
	case "$choice" in
		""|"1") MODE="auto" ;;
		"2") MODE="check-gates" ;;
		"3") MODE="capture-state" ;;
		"4") MODE="ensure-packages" ;;
		"5") MODE="paths" ;;
		*) echo "FAIL: invalid interactive mode choice: $choice" >&2; exit 2 ;;
	esac
}

POSITIONAL_MODE_SET=0
while [ "$#" -gt 0 ]; do
	case "$1" in
		auto|build|wrap|check|verify|wrap-verify|check-gates|gates|capture-state|state|ensure-packages|packages|ensure-debug-packages|paths|interactive|help)
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

if [ "$MODE" = "paths" ]; then
	echo "MODE=$MODE"
	echo "BUILD_MODE=$BUILD_MODE"
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

if [ "$MODE" = "check-gates" ]; then
	if [ ! -x "$A825CHECK" ]; then
		echo "FAIL: missing executable gate checker: $A825CHECK" >&2
		exit 1
	fi
	if [ -n "$CHECK_LOG_PATH" ]; then
		exec "$A825CHECK" --log "$CHECK_LOG_PATH"
	fi
	exec "$A825CHECK"
fi

if [ "$MODE" = "capture-state" ]; then
	if [ ! -x "$A825STATE" ]; then
		echo "FAIL: missing executable capture helper: $A825STATE" >&2
		exit 1
	fi
	exec "$A825STATE"
fi

if [ "$MODE" = "ensure-packages" ]; then
	if [ ! -x "$A825PACKAGES" ]; then
		echo "FAIL: missing executable package helper: $A825PACKAGES" >&2
		exit 1
	fi
	exec "$A825PACKAGES"
fi

if [ "$MODE" != "auto" ]; then
	echo "FAIL: unsupported mode: $MODE" >&2
	usage >&2
	exit 2
fi

if [ ! -x "$A825WRAP" ]; then
	echo "FAIL: missing executable wrapper: $A825WRAP" >&2
	exit 1
fi
if [ ! -x "$A825VERIFY" ]; then
	echo "FAIL: missing executable verifier: $A825VERIFY" >&2
	exit 1
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
		RAW="$RESEARCH_NOTES_DIR/${TS}-source-payload.raw"
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
	config_before="$RESEARCH_NOTES_DIR/${TS}-openwrt-config-before-debug-packages"
	config_after="$RESEARCH_NOTES_DIR/${TS}-openwrt-config-after-debug-packages"
	cp "$OWRT/.config" "$config_before"
	progress_note "saved: $config_before"

	progress "Applying TC7200U package profile"
	progress_note "TC7200U_PACKAGE_PROFILE=${TC7200U_PACKAGE_PROFILE:-fastboot} (set to debug for full diagnostics tools)"
	run_logged "$RESEARCH_NOTES_DIR/${TS}-ensure-debug-packages.log" "$RESEARCH/scripts/tc7200u-ensure-debug-packages.sh"

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

wrap_log="$RESEARCH_NOTES_DIR/${TS}-wrap.log"
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
	run_logged "$wrap_log" "$A825WRAP" --input "$RAW" --output "$WRAPPED" --filename "$REQUEST_NAME" "${WRAP_EXTRA_ARGS[@]}"
fi
sync
progress_note "wrapped: $WRAPPED"

progress "Verifying wrapped image safety checks"
verify_log="$RESEARCH_NOTES_DIR/${TS}-verify.log"
run_logged "$verify_log" "$A825VERIFY" --raw "$RAW" --wrapped "$WRAPPED" --expect-load "$EXPECT_LOAD_HEX" --expect-name "$VERIFY_EXPECT_NAME" --expect-signature "$VERIFY_EXPECT_SIGNATURE_HEX"
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
