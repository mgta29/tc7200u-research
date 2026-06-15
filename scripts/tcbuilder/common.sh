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
