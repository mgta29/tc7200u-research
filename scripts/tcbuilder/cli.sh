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
  tcbuilder.sh [mode] [options]

Modes:
  help            Print this help text.
  interactive     Prompt for mode and filename interactively. (default in a TTY)
  auto            Build (if needed), wrap, verify.
  candidate       Save a named candidate stamp/patch/log set, then run auto.
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
  --label NAME
  --interactive
  --fresh-header
  --no-fresh-header
  --build-mode auto|none|prepare|install|compile|full|clean
  --name-map INPUT=RESULT | INPUT->RESULT | INPUT - RESULT
  --request-name NAME
  --result-name NAME
  --bin-name NAME.bin
  --tftp-dir C:\tftp\
  --source-image PATH
  --preserve-from PATH
  --load-addr 0x<hex>
  --control 0x<hex>|<int>
  --major 0x<hex>|<int>
  --minor 0x<hex>|<int>
  --build-time 0x<hex>|<int>
  --crc32 0x<hex>|<int>
  --allow-rescue-overwrite
  --force-rewrap-source
  --skip-precheck
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
		candidate|cand)
			printf 'candidate\n'
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

parse_cli_args() {
	local positional_mode_set=0
	MODE_ARGS=()

	while [ "$#" -gt 0 ]; do
		case "$1" in
			auto|build|wrap|check|verify|wrap-verify|candidate|cand|check-gates|gates|capture-state|state|ensure-packages|packages|ensure-debug-packages|serial-console|serial|console|reverse-stage1|reverse|status|selftest|paths|interactive|help)
				if [ "$positional_mode_set" = "0" ]; then
					MODE="$1"
					positional_mode_set=1
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
			--label)
				[ "$#" -ge 2 ] || { echo "FAIL: --label requires a value" >&2; exit 2; }
				CANDIDATE_LABEL="$2"
				shift 2
				;;
			--interactive)
				INTERACTIVE=1
				shift
				;;
			--fresh-header)
				FRESH_HEADER=1
				shift
				;;
			--no-fresh-header)
				FRESH_HEADER=0
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
			--preserve-from)
				[ "$#" -ge 2 ] || { echo "FAIL: --preserve-from requires a value" >&2; exit 2; }
				PRESERVE_FROM_IMAGE="$2"
				shift 2
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
			--allow-rescue-overwrite)
				ALLOW_RESCUE_OVERWRITE=1
				shift
				;;
			--force-rewrap-source)
				FORCE_REWRAP_SOURCE=1
				shift
				;;
			--skip-precheck)
				PATCH_PRECHECK=0
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

	MODE_ARGS=("$@")
}

normalize_runtime_inputs() {
	parse_name_map "$NAME_MAP"
	REQUEST_NAME="$(trim_ws "$REQUEST_NAME")"
	RESULT_NAME="$(trim_ws "$RESULT_NAME")"
	BIN_NAME="$(trim_ws "$BIN_NAME")"
	TFTP_OUT_DIR="$(trim_ws "$TFTP_OUT_DIR")"
	SOURCE_IMAGE="$(trim_ws "$SOURCE_IMAGE")"
	PRESERVE_FROM_IMAGE="$(trim_ws "$PRESERVE_FROM_IMAGE")"
	WRAP_LOAD_ADDR="$(trim_ws "$WRAP_LOAD_ADDR")"
	WRAP_CONTROL="$(trim_ws "$WRAP_CONTROL")"
	WRAP_MAJOR="$(trim_ws "$WRAP_MAJOR")"
	WRAP_MINOR="$(trim_ws "$WRAP_MINOR")"
	WRAP_BUILD_TIME="$(trim_ws "$WRAP_BUILD_TIME")"
	WRAP_CRC32="$(trim_ws "$WRAP_CRC32")"
	FRESH_HEADER="$(trim_ws "$FRESH_HEADER")"
	CANDIDATE_LABEL="$(trim_ws "$CANDIDATE_LABEL")"
	MODE="$(normalize_mode "$(trim_ws "$MODE")")"
	BUILD_MODE="$(printf '%s' "$BUILD_MODE" | tr '[:upper:]' '[:lower:]')"
	CHECK_LOG_PATH="$(trim_ws "$CHECK_LOG_PATH")"
}

validate_candidate_label() {
	case "$CANDIDATE_LABEL" in
		"" )
			echo "FAIL: candidate mode requires --label NAME (or TC7200U_CANDIDATE_LABEL)." >&2
			exit 2
			;;
		*[!A-Za-z0-9._-]*)
			echo "FAIL: candidate label may contain only letters, digits, dot, underscore, and dash: $CANDIDATE_LABEL" >&2
			exit 2
			;;
	esac
}

normalize_fresh_header() {
	case "$FRESH_HEADER" in
		1|0)
			;;
		true|yes|on)
			FRESH_HEADER=1
			;;
		false|no|off|"")
			FRESH_HEADER=0
			;;
		*)
			echo "FAIL: invalid FRESH_HEADER value '$FRESH_HEADER' (use 1|0|true|false|yes|no|on|off)" >&2
			exit 2
			;;
	esac
}

validate_mode_specific_options() {
	if [ "$MODE" = "candidate" ]; then
		validate_candidate_label
	fi
}

apply_default_preserve_from_image() {
	if [ -z "$PRESERVE_FROM_IMAGE" ] && [ -z "$SOURCE_IMAGE" ] && [ -f "$DEFAULT_PRESERVE_FROM_IMAGE" ]; then
		PRESERVE_FROM_IMAGE="$DEFAULT_PRESERVE_FROM_IMAGE"
		PRESERVE_FROM_DEFAULTED=1
	fi
}

apply_auto_fresh_header_default() {
	case "$MODE" in
		auto|candidate)
			;;
		*)
			return 0
			;;
	esac

	if [ -z "$SOURCE_IMAGE" ] && [ "$PRESERVE_FROM_DEFAULTED" = "1" ] && [ -z "$FRESH_HEADER" ]; then
		FRESH_HEADER=1
	fi
}

apply_auto_wrap_load_default() {
	# Preserve the canonical template header exactly when auto/candidate mode is
	# using a preserve-from image. Only inject the canonical load override when
	# there is no template to preserve.
	if [ -n "$WRAP_LOAD_ADDR" ] || [ -n "$SOURCE_IMAGE" ] || [ -n "$PRESERVE_FROM_IMAGE" ]; then
		return 0
	fi

	case "$MODE" in
		auto|candidate)
			WRAP_LOAD_ADDR="$DEFAULT_WRAP_LOAD_HEX"
			;;
	esac
}

validate_wrap_load_addr() {
	if [ -n "$WRAP_LOAD_ADDR" ]; then
		if ! printf '%s' "$WRAP_LOAD_ADDR" | grep -Eq '^0[xX][0-9a-fA-F]{1,8}$'; then
			echo "FAIL: --load-addr must be a hex value like 0x<hex> (got: $WRAP_LOAD_ADDR)" >&2
			exit 2
		fi
		WRAP_LOAD_ADDR="$(canonical_hex "$WRAP_LOAD_ADDR")"
		EXPECT_LOAD_HEX="$WRAP_LOAD_ADDR"
	fi
}

validate_build_mode() {
	case "$BUILD_MODE" in
		auto|none|prepare|install|compile|full|clean)
			;;
		*)
			echo "FAIL: invalid --build-mode '$BUILD_MODE' (use auto|none|prepare|install|compile|full|clean)" >&2
			exit 2
			;;
	esac
}

normalize_patch_precheck() {
	case "$PATCH_PRECHECK" in
		1|0)
			;;
		true|yes|on)
			PATCH_PRECHECK=1
			;;
		false|no|off)
			PATCH_PRECHECK=0
			;;
		*)
			echo "FAIL: invalid PATCH_PRECHECK value '$PATCH_PRECHECK' (use 1|0|true|false|yes|no|on|off)" >&2
			exit 2
			;;
	esac
}

resolve_interactive_mode() {
	if [ "$MODE" = "interactive" ]; then
		if [ -t 0 ]; then
			INTERACTIVE=1
		else
			MODE="auto"
		fi
	fi

	if [ "$INTERACTIVE" = "1" ] && [ -t 0 ]; then
		interactive_choose_mode
	fi
}

maybe_show_help() {
	if [ "$MODE" = "help" ]; then
		usage
		exit 0
	fi
}

resolve_output_names() {
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
}

validate_source_image_target() {
	if [ -n "$SOURCE_IMAGE" ] && [ "$RESULT_NAME" = "$RESCUE_RESULT_NAME" ] && [ "$ALLOW_RESCUE_OVERWRITE" != "1" ]; then
		echo "FAIL: refusing to overwrite rescue image '$RESCUE_RESULT_NAME' from --source-image flow." >&2
		echo "FAIL: choose --bin-name <new-file>. Use --allow-rescue-overwrite only if intentional." >&2
		exit 2
	fi
}

validate_plain_filenames() {
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
}

resolve_runtime_paths() {
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

	PRESERVE_FROM_PATH=""
	if [ -n "$PRESERVE_FROM_IMAGE" ]; then
		PRESERVE_FROM_PATH="$(to_wsl_path "$PRESERVE_FROM_IMAGE")"
		if [ ! -f "$PRESERVE_FROM_PATH" ]; then
			echo "FAIL: preserve-from image not found: $PRESERVE_FROM_IMAGE ($PRESERVE_FROM_PATH)" >&2
			exit 2
		fi
	fi

	WRAPPED="$TFTP_OUT_DIR_WSL/$RESULT_NAME"
}

prepare_runtime_directories() {
	mkdir -p "$RESEARCH_NOTES_DIR"
	mkdir -p "$BUILD_LOG_BASE"
	mkdir -p "$RESEARCH_BUILDS_DIR"
	mkdir -p "$(dirname "$WRAPPED")"
}
