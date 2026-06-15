report_candidate_context() {
	if [ "$MODE" != "candidate" ]; then
		return 0
	fi

	report_section "candidate"
	report_note "candidate_label=$CANDIDATE_LABEL"
	report_note "candidate_stamp=$CANDIDATE_STAMP"
	report_note "candidate_stamp_file=$CANDIDATE_STAMP_FILE"
	report_note "candidate_patch=$CANDIDATE_PATCH_PATH"
	report_note "candidate_auto_log=$CANDIDATE_AUTO_LOG"
	report_note "candidate_sha256_log=$CANDIDATE_SHA256_LOG"
	report_note "candidate_file_log=$CANDIDATE_FILE_LOG"
}

prepare_candidate_artifacts() {
	local patch_targets=(
		target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts
		target/linux/bmips/bcm63268/config-6.12
		target/linux/bmips/patches-6.12
		target/linux/bmips/dts
		target/linux/bmips/image
	)

	CANDIDATE_STAMP="$TS"
	CANDIDATE_STAMP_FILE="$RESEARCH_BUILDS_DIR/current-${CANDIDATE_LABEL}.stamp"
	CANDIDATE_PATCH_PATH="$RESEARCH/patches/tc7200u-${CANDIDATE_LABEL}-${CANDIDATE_STAMP}.patch"
	CANDIDATE_AUTO_LOG="$RESEARCH_BUILDS_DIR/tc7200u-${CANDIDATE_LABEL}-${CANDIDATE_STAMP}-auto.log"
	CANDIDATE_SHA256_LOG="$RESEARCH_BUILDS_DIR/tc7200u-${CANDIDATE_LABEL}-${CANDIDATE_STAMP}-sha256.txt"
	CANDIDATE_FILE_LOG="$RESEARCH_BUILDS_DIR/tc7200u-${CANDIDATE_LABEL}-${CANDIDATE_STAMP}-file.txt"

	mkdir -p "$RESEARCH_BUILDS_DIR" "$RESEARCH/patches"
	printf '%s\n' "$CANDIDATE_STAMP" >"$CANDIDATE_STAMP_FILE"
	git -C "$OWRT" diff -- "${patch_targets[@]}" >"$CANDIDATE_PATCH_PATH"

	echo "== candidate =="
	echo "label=$CANDIDATE_LABEL"
	echo "stamp=$CANDIDATE_STAMP"
	echo "stamp_file=$CANDIDATE_STAMP_FILE"
	echo "patch=$CANDIDATE_PATCH_PATH"
	echo "auto_log=$CANDIDATE_AUTO_LOG"
	echo "sha256_log=$CANDIDATE_SHA256_LOG"
	echo "file_log=$CANDIDATE_FILE_LOG"
}

start_candidate_console_log() {
	if [ "$CANDIDATE_CONSOLE_TEE_STARTED" = "1" ]; then
		return 0
	fi

	exec > >(tee -a "$CANDIDATE_AUTO_LOG")
	exec 2>&1
	CANDIDATE_CONSOLE_TEE_STARTED=1
}

write_candidate_sha256_report() {
	local inputs=()

	[ -f "$RAW" ] && inputs+=("$RAW")
	[ -f "$WRAPPED" ] && inputs+=("$WRAPPED")
	if [ -n "${PRESERVE_FROM_PATH:-}" ] && [ -f "$PRESERVE_FROM_PATH" ]; then
		inputs+=("$PRESERVE_FROM_PATH")
	fi

	[ "${#inputs[@]}" -gt 0 ] || { echo "FAIL: no inputs available for candidate sha256 report" >&2; exit 1; }

	echo
	echo "== candidate sha256 =="
	sha256sum "${inputs[@]}" | tee "$CANDIDATE_SHA256_LOG"
}

write_candidate_file_report() {
	echo
	echo "== candidate wrapped image =="
	{
		ls -lah "$WRAPPED"
		file "$WRAPPED"
	} | tee "$CANDIDATE_FILE_LOG"
}

run_candidate_mode() {
	prepare_candidate_artifacts
	start_candidate_console_log
	run_auto_mode
	write_candidate_sha256_report
	write_candidate_file_report
}
