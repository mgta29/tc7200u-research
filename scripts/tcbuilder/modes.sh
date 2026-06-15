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

print_paths_mode() {
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
	echo "PRESERVE_FROM_IMAGE=$PRESERVE_FROM_IMAGE"
	echo "PRESERVE_FROM_PATH=$PRESERVE_FROM_PATH"
	echo "WRAP_LOAD_ADDR=$WRAP_LOAD_ADDR"
	echo "WRAP_CONTROL=$WRAP_CONTROL"
	echo "WRAP_MAJOR=$WRAP_MAJOR"
	echo "WRAP_MINOR=$WRAP_MINOR"
	echo "WRAP_BUILD_TIME=$WRAP_BUILD_TIME"
	echo "WRAP_CRC32=$WRAP_CRC32"
	echo "EXPECT_LOAD_HEX=$EXPECT_LOAD_HEX"
	echo "PATCH_PRECHECK=$PATCH_PRECHECK"
	echo "FRESH_HEADER=$FRESH_HEADER"
	echo "CANDIDATE_LABEL=$CANDIDATE_LABEL"
}
