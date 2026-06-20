#!/usr/bin/env bash
set -euo pipefail

OWRT="${OWRT:-$HOME/src/openwrt}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RECORDS_DIR="${RECORDS_DIR:-$RESEARCH/records}"
RESEARCH_BUILDS_DIR="${RESEARCH_BUILDS_DIR:-$RECORDS_DIR/logs/builds}"
RESEARCH_NOTES_DIR="${RESEARCH_NOTES_DIR:-$RECORDS_DIR/generated}"
RAW="$OWRT/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin"
SOURCE_IMAGE="${SOURCE_IMAGE:-${INPUT_IMAGE:-${TC7200U_SOURCE_IMAGE:-}}}"
PRESERVE_FROM_IMAGE="${PRESERVE_FROM_IMAGE:-${TC7200U_PRESERVE_FROM_IMAGE:-}}"
WRAP_LOAD_ADDR="${WRAP_LOAD_ADDR:-${TC7200U_WRAP_LOAD_ADDR:-}}"
WRAP_CONTROL="${WRAP_CONTROL:-${TC7200U_WRAP_CONTROL:-}}"
WRAP_MAJOR="${WRAP_MAJOR:-${TC7200U_WRAP_MAJOR:-}}"
WRAP_MINOR="${WRAP_MINOR:-${TC7200U_WRAP_MINOR:-}}"
WRAP_BUILD_TIME="${WRAP_BUILD_TIME:-${TC7200U_WRAP_BUILD_TIME:-}}"
WRAP_CRC32="${WRAP_CRC32:-${TC7200U_WRAP_CRC32:-}}"
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
MODE="${MODE:-interactive}"
BUILD_MODE="${BUILD_MODE:-auto}"
PATCH_PRECHECK="${PATCH_PRECHECK:-1}"
BUILD_LOG_BASE="${BUILD_LOG_BASE:-$RESEARCH_BUILDS_DIR}"
CHECK_LOG_PATH="${CHECK_LOG_PATH:-}"
CHECK_REPORT_OUT="${CHECK_REPORT_OUT:-}"
CHECK_SAVE_REPORT="${CHECK_SAVE_REPORT:-1}"
FRESH_HEADER="${FRESH_HEADER:-${TC7200U_FRESH_HEADER:-}}"
CANDIDATE_LABEL="${CANDIDATE_LABEL:-${TC7200U_CANDIDATE_LABEL:-}}"
WRAPPED=""
A825_HEADER_BYTES=92
DEFAULT_WRAP_LOAD_HEX="0x82000000"
EXPECT_LOAD_HEX="0x82000000"
VERIFY_EXPECT_NAME=""
VERIFY_EXPECT_SIGNATURE_HEX="0xa825"
WRAP_EXTRA_ARGS=()
MODE_ARGS=()
WRAP_LOG_PATH=""
VERIFY_LOG_PATH=""
INHERIT_LOAD_HEX=""
CANDIDATE_STAMP=""
CANDIDATE_STAMP_FILE=""
CANDIDATE_PATCH_PATH=""
CANDIDATE_AUTO_LOG=""
CANDIDATE_SHA256_LOG=""
CANDIDATE_FILE_LOG=""
CANDIDATE_CONSOLE_TEE_STARTED=0
SKIP_WRAP=0
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 1)}"
TS="$(date +%Y-%m-%d-%H%M%S)"
RUN_REPORT=""
STEP=0
TOTAL_STEPS=7
DEFAULT_PRESERVE_FROM_IMAGE="$RECORDS_DIR/artifacts/rescue/tc7200-stage2-console-good.bin"
PRESERVE_FROM_DEFAULTED=0

# Carried ENET references and compare sets from the maintained status/reverse notes.
ENET_VALUES_NOTE='\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\important-openwrt-tc7200u-enet-usable-values.md'
ENET_STATUS_NOTE='\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\important-openwrt-tc7200u-enet-usable-status.md'
ENET_CONTROL_BASELINE_NOTE='\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-17-fresh-openwrt-console-success.md'
ENET_DEVMEM_BASELINE_NOTE='\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-devmem-fpm-genet-baseline.md'
ENET_FIXEDLINK_WATCHDOG_NOTE='\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-genet-fixedlink-probe-watchdog.md'
ENET_LIVE_MBDMA_NOTE='\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-fpm-live-mbdma-unprogrammed.md'
ENET_TXDUMP_NOTE='\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-txdump-tdma-stuck.md'
ENET_CTRLMAP_NOTE='\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-ctrlmap-debug-findings.md' 

ENET_COMPARE_FPM_ADDRS=(
	0x12200040
	0x12200044
	0x12200200
	0x12200208
	0x12200210
	0x12200218
)
ENET_COMPARE_GENET_ADDRS=(
	0x12c00004
	0x12c00008
	0x12c0000c
	0x12c00010
	0x12c00044
	0x12c00048
	0x12c0004c
	0x12c00050
	0x12c00054
	0x12c00058
	0x12c00070
)
ENET_COMPARE_PROFILE_ADDRS=(
	0x14e001c4
	0x14e00002
	0x14e00264
)
ENET_COMPARE_MDIO_ADDRS=(
	0x12c0062c
	0x12c0062e
	0x12c00630
	0x12c00632
	0x12c0262c
	0x12c0262e
	0x12c02630
	0x12c02632
)
ENET_OEM_COMPARE_HINTS=(
	"0x12c00004=(old & 0xffffe000) | 0x9010"
	"0x12c00044=0x02020202"
	"0x12c00008=0x12200200"
	"0x12c0004c=0x12200218"
	"0x12c00050=0x12200210"
	"0x12c00054=0x12200208"
	"0x12c00058=0x12200200"
	"0x12c00070=0x00000003 or 0x00030000"
	"size0x100->0x12200218"
	"size0x200->0x12200210"
	"size0x400->0x12200208"
	"size0x800->0x12200200"
)

TCBUILDER_SCRIPT_DIR="$(
	CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
TCBUILDER_MODULE_DIR="${TCBUILDER_MODULE_DIR:-$TCBUILDER_SCRIPT_DIR/tcbuilder}"

load_tcbuilder_module() {
	local module_name="$1"
	local module_path="$TCBUILDER_MODULE_DIR/$module_name.sh"

	[ -f "$module_path" ] || { echo "FAIL: missing tcbuilder module: $module_path" >&2; exit 1; }
	# shellcheck source=/dev/null
	. "$module_path"
}

for module_name in common cli build programstore modes auto candidate; do
	load_tcbuilder_module "$module_name"
done

main() {
	parse_cli_args "$@"
	normalize_runtime_inputs
	apply_default_preserve_from_image
	apply_auto_wrap_load_default
	validate_wrap_load_addr
	validate_build_mode
	normalize_patch_precheck
	resolve_interactive_mode
	apply_auto_fresh_header_default
	normalize_fresh_header
	maybe_show_help
	validate_mode_specific_options
	resolve_output_names
	validate_source_image_target
	validate_plain_filenames
	resolve_runtime_paths
	prepare_runtime_directories

	if run_mode_dispatch; then
		return 0
	fi

	run_auto_mode
}

main "$@"
