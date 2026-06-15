begin_auto_report() {
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
	report_candidate_context
	snapshot_build_context
}

prepare_source_image_flow() {
	local src_load_hex=""
	local src_header_name=""
	local src_signature_hex=""

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
			src_load_hex="0x$(printf '%s' "$src_load_hex" | tr 'A-F' 'a-f')"
			EXPECT_LOAD_HEX="$src_load_hex"
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

		if [ "$FRESH_HEADER" = "1" ]; then
			progress_note "fresh-header enabled; stripping header and regenerating ProgramStore metadata"
			if [ -z "$WRAP_LOAD_ADDR" ] && printf '%s' "$src_load_hex" | grep -Eq '^0x[0-9a-fA-F]{8}$'; then
				INHERIT_LOAD_HEX="$src_load_hex"
			fi
		elif [ "$FORCE_REWRAP_SOURCE" = "1" ]; then
			progress_note "force-rewrap enabled; stripping ${A825_HEADER_BYTES}-byte header"
			progress_note "preserving source ProgramStore control/revision/load/build fields"
			WRAP_EXTRA_ARGS+=(--preserve-from "$SOURCE_IMAGE_PATH")
		else
			progress_note "preserving wrapped source image bytes exactly (no header rewrite)"
			VERIFY_EXPECT_NAME="${src_header_name:-$VERIFY_EXPECT_NAME}"
			if [ -n "$src_signature_hex" ]; then
				VERIFY_EXPECT_SIGNATURE_HEX="$src_signature_hex"
			fi
			SKIP_WRAP=1
		fi

		strip_programstore_payload "$SOURCE_IMAGE_PATH" "$RAW"
		[ -s "$RAW" ] || { echo "FAIL: stripped payload is empty: $RAW" >&2; exit 1; }
	else
		progress_note "source appears to be raw payload (no ProgramStore header)"
		RAW="$SOURCE_IMAGE_PATH"
	fi

	progress_note "raw: $RAW"
}

prepare_openwrt_build_flow() {
	local vmlinux=""
	local config_before=""
	local config_after=""
	local config_changed=0
	local raw_exists=0
	local stale_input=""
	local build_action=""

	report_section "flow"
	report_note "path=openwrt-build"
	progress "Inspecting OpenWrt build outputs"
	progress_note "name map: $REQUEST_NAME -> $RESULT_NAME"
	progress_note "tftp dir: $TFTP_OUT_DIR ($TFTP_OUT_DIR_WSL)"
	vmlinux="$(latest_vmlinux || true)"
	if [ -n "$vmlinux" ]; then
		progress_note "latest vmlinux: $vmlinux"
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
		if [ -n "$vmlinux" ] && [ "$vmlinux" -nt "$RAW" ]; then
			progress_note "vmlinux is newer than raw initramfs"
		fi
		stale_input="$(newer_build_input || true)"
		if [ -n "$stale_input" ]; then
			progress_note "source newer than raw image: $stale_input"
		fi
	fi

	build_action="$(select_build_action "$config_changed" "$raw_exists" "$stale_input" "$vmlinux")"
	progress_note "decision: $build_action (build-mode=$BUILD_MODE)"
	report_build_decision "$build_action" "$config_changed" "$raw_exists" "$stale_input" "$vmlinux"
	run_patch_precheck "$build_action"

	progress "Building OpenWrt image if required"
	cd "$OWRT"
	run_openwrt_build "$build_action"

	if [ ! -f "$RAW" ]; then
		echo "FAIL: raw initramfs missing after build: $RAW" >&2
		exit 1
	fi
	progress_note "raw: $RAW"
}

apply_preserve_from_template() {
	local preserve_load_hex=""
	local preserve_sig_hex=""

	if [ -n "$SOURCE_IMAGE_PATH" ] || [ -z "$PRESERVE_FROM_PATH" ]; then
		return 0
	fi

	progress_note "preserve-from header template: $PRESERVE_FROM_IMAGE ($PRESERVE_FROM_PATH)"
	if ! is_programstore_wrapped_file "$PRESERVE_FROM_PATH"; then
		echo "FAIL: preserve-from image is not a valid ProgramStore A825 image: $PRESERVE_FROM_PATH" >&2
		exit 2
	fi

	preserve_load_hex="$(dd if="$PRESERVE_FROM_PATH" bs=1 skip=16 count=4 2>/dev/null | xxd -p -c4 || true)"
	if printf '%s' "$preserve_load_hex" | grep -Eq '^[0-9a-fA-F]{8}$'; then
		preserve_load_hex="0x$(printf '%s' "$preserve_load_hex" | tr 'A-F' 'a-f')"
	fi

	if [ "$FRESH_HEADER" = "1" ]; then
		if [ -z "$WRAP_LOAD_ADDR" ] && printf '%s' "$preserve_load_hex" | grep -Eq '^0x[0-9a-fA-F]{8}$'; then
			EXPECT_LOAD_HEX="$preserve_load_hex"
			INHERIT_LOAD_HEX="$preserve_load_hex"
			progress_note "fresh-header enabled; using template load address without preserving template metadata"
		fi
		report_note "preserve_from_path=$PRESERVE_FROM_PATH"
		report_note "preserve_from_fresh_header=1"
	else
		WRAP_EXTRA_ARGS+=(--preserve-from "$PRESERVE_FROM_PATH")

		if [ -z "$WRAP_LOAD_ADDR" ]; then
			if printf '%s' "$preserve_load_hex" | grep -Eq '^0x[0-9a-fA-F]{8}$'; then
				EXPECT_LOAD_HEX="$preserve_load_hex"
				progress_note "preserved load address from template: $EXPECT_LOAD_HEX"
			fi
		else
			progress_note "preserve-from load overridden by --load-addr: $WRAP_LOAD_ADDR"
		fi

		preserve_sig_hex="$(programstore_header_signature "$PRESERVE_FROM_PATH" || true)"
		if printf '%s' "$preserve_sig_hex" | grep -Eq '^0x[0-9a-fA-F]{4}$'; then
			VERIFY_EXPECT_SIGNATURE_HEX="$(printf '%s' "$preserve_sig_hex" | tr 'A-F' 'a-f')"
		fi
		report_note "preserve_from_applied=1"
		report_note "preserve_from_path=$PRESERVE_FROM_PATH"
		report_note "preserve_from_expect_load=$EXPECT_LOAD_HEX"
	fi
}

apply_wrap_load_override() {
	if [ "$SKIP_WRAP" != "1" ] && [ -n "$WRAP_LOAD_ADDR" ]; then
		progress_note "forcing wrap load address: $WRAP_LOAD_ADDR"
		WRAP_EXTRA_ARGS+=(--load-addr "$WRAP_LOAD_ADDR")
		report_note "wrap_load_addr_effective=$WRAP_LOAD_ADDR"
	fi
}

apply_header_metadata_overrides() {
	if [ "$SKIP_WRAP" = "1" ]; then
		return 0
	fi

	if [ "$FRESH_HEADER" = "1" ]; then
		progress_note "fresh-header enabled: generating a new ProgramStore metadata header"
		report_note "fresh_header_effective=1"
		if [ -n "$INHERIT_LOAD_HEX" ] && [ -z "$WRAP_LOAD_ADDR" ]; then
			progress_note "fresh-header preserving load address: $INHERIT_LOAD_HEX"
			WRAP_EXTRA_ARGS+=(--load-addr "$INHERIT_LOAD_HEX")
			report_note "wrap_load_addr_effective=$INHERIT_LOAD_HEX"
		fi
	fi

	if [ -n "$WRAP_CONTROL" ]; then
		progress_note "forcing wrap control: $WRAP_CONTROL"
		WRAP_EXTRA_ARGS+=(--control "$WRAP_CONTROL")
		report_note "wrap_control_effective=$WRAP_CONTROL"
	fi
	if [ -n "$WRAP_MAJOR" ]; then
		progress_note "forcing wrap major revision: $WRAP_MAJOR"
		WRAP_EXTRA_ARGS+=(--major "$WRAP_MAJOR")
		report_note "wrap_major_effective=$WRAP_MAJOR"
	fi
	if [ -n "$WRAP_MINOR" ]; then
		progress_note "forcing wrap minor revision: $WRAP_MINOR"
		WRAP_EXTRA_ARGS+=(--minor "$WRAP_MINOR")
		report_note "wrap_minor_effective=$WRAP_MINOR"
	fi
	if [ -n "$WRAP_BUILD_TIME" ]; then
		progress_note "forcing wrap build time: $WRAP_BUILD_TIME"
		WRAP_EXTRA_ARGS+=(--build-time "$WRAP_BUILD_TIME")
		report_note "wrap_build_time_effective=$WRAP_BUILD_TIME"
	fi
	if [ -n "$WRAP_CRC32" ]; then
		progress_note "forcing wrap crc32: $WRAP_CRC32"
		WRAP_EXTRA_ARGS+=(--crc32 "$WRAP_CRC32")
		report_note "wrap_crc32_effective=$WRAP_CRC32"
	fi
}

write_passthrough_wrap_log() {
	local log_path="$1"

	{
		echo "mode=passthrough"
		echo "source=$SOURCE_IMAGE_PATH"
		echo "output=$WRAPPED"
		echo "raw=$RAW"
		echo "expect_load=$EXPECT_LOAD_HEX"
		echo "expect_name=$VERIFY_EXPECT_NAME"
		echo "expect_signature=$VERIFY_EXPECT_SIGNATURE_HEX"
	} >"$log_path"
}

wrap_output_image() {
	WRAP_LOG_PATH="$BUILD_LOG_BASE/${TS}-wrap.log"
	if [ "$SKIP_WRAP" = "1" ]; then
		progress "Copying pre-wrapped source image"
		progress_note "log: $WRAP_LOG_PATH"
		cp -f "$SOURCE_IMAGE_PATH" "$WRAPPED"
		write_passthrough_wrap_log "$WRAP_LOG_PATH"
	else
		progress "Wrapping raw initramfs with A825 header"
		run_logged "$WRAP_LOG_PATH" a825_wrap --input "$RAW" --output "$WRAPPED" --filename "$REQUEST_NAME" "${WRAP_EXTRA_ARGS[@]}"
	fi
	sync
	progress_note "wrapped: $WRAPPED"
}

verify_wrapped_output() {
	VERIFY_LOG_PATH="$BUILD_LOG_BASE/${TS}-verify.log"
	progress "Verifying wrapped image"
	run_logged "$VERIFY_LOG_PATH" a825_verify --raw "$RAW" --wrapped "$WRAPPED" --expect-load "$EXPECT_LOAD_HEX" --expect-name "$VERIFY_EXPECT_NAME" --expect-signature "$VERIFY_EXPECT_SIGNATURE_HEX"
	report_section "outputs"
	report_note "raw=$RAW"
	report_note "wrapped=$WRAPPED"
	report_note "wrap_log=$WRAP_LOG_PATH"
	report_note "verify_log=$VERIFY_LOG_PATH"
	if [ -f "$RAW" ]; then
		report_note "raw_sha256=$(sha256sum "$RAW" | awk '{print $1}')"
	fi
	if [ -f "$WRAPPED" ]; then
		report_note "wrapped_sha256=$(sha256sum "$WRAPPED" | awk '{print $1}')"
	fi

	grep -q '^size_ok=True$' "$VERIFY_LOG_PATH"
	echo "CHECK OK: size_ok=True"
	grep -m1 '^OK: wrapped image matches raw payload and expected header fields$' "$VERIFY_LOG_PATH"
	report_note "result=ok"
	report_note "ready_for_tftp_request=$REQUEST_NAME"
	report_note "served_file=$TFTP_OUT_DIR_DISPLAY$TFTP_OUT_SEP$RESULT_NAME"
	echo "AUTO: ready for cfe-tftp. CFE request: $REQUEST_NAME ; served file: $TFTP_OUT_DIR_DISPLAY$TFTP_OUT_SEP$RESULT_NAME."
}

run_mode_dispatch() {
	case "$MODE" in
		paths)
			print_paths_mode
			return 0
			;;
		status)
			status_mode
			return 0
			;;
		candidate)
			run_candidate_mode
			return 0
			;;
		selftest)
			selftest_mode
			return 0
			;;
		reverse-stage1)
			reverse_stage1 "${MODE_ARGS[@]}"
			return 0
			;;
		serial-console)
			serial_console "${MODE_ARGS[@]}"
			return 0
			;;
		check-gates)
			check_gates "${MODE_ARGS[@]}"
			return 0
			;;
		capture-state)
			capture_state
			return 0
			;;
		ensure-packages)
			ensure_packages
			return 0
			;;
		auto)
			return 1
			;;
		*)
			echo "FAIL: unsupported mode: $MODE" >&2
			usage >&2
			exit 2
			;;
	esac
}

run_auto_mode() {
	begin_auto_report

	if [ -n "$SOURCE_IMAGE_PATH" ]; then
		prepare_source_image_flow
	else
		prepare_openwrt_build_flow
	fi

	apply_preserve_from_template
	apply_wrap_load_override
	apply_header_metadata_overrides
	wrap_output_image
	verify_wrapped_output
}
