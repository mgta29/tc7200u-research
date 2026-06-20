snapshot_build_context() {
	report_section "build context"
	report_note "timestamp_local=$(date '+%Y-%m-%d %H:%M:%S %Z')"
	report_note "owrt=$OWRT"
	report_note "raw_expected=$RAW"
	report_note "source_image=${SOURCE_IMAGE_PATH:-}"
	report_note "preserve_from=${PRESERVE_FROM_PATH:-}"
	report_note "wrap_load_addr=${WRAP_LOAD_ADDR:-}"
	report_note "request_name=$REQUEST_NAME"
	report_note "result_name=$RESULT_NAME"
	report_note "wrapped_output=$WRAPPED"
	report_note "build_mode=$BUILD_MODE"
	report_note "patch_precheck=$PATCH_PRECHECK"
	report_note "fresh_header=$FRESH_HEADER"
	report_note "wrap_control=${WRAP_CONTROL:-}"
	report_note "wrap_major=${WRAP_MAJOR:-}"
	report_note "wrap_minor=${WRAP_MINOR:-}"
	report_note "wrap_build_time=${WRAP_BUILD_TIME:-}"
	report_note "wrap_crc32=${WRAP_CRC32:-}"
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

	report_section "enet reference"
	report_note "enet_values_note=$ENET_VALUES_NOTE"
	report_note "enet_status_note=$ENET_STATUS_NOTE"
	report_note "enet_control_baseline_note=$ENET_CONTROL_BASELINE_NOTE"
	report_note "enet_devmem_baseline_note=$ENET_DEVMEM_BASELINE_NOTE"
	report_note "enet_fixedlink_watchdog_note=$ENET_FIXEDLINK_WATCHDOG_NOTE"
	report_note "enet_live_mbdma_note=$ENET_LIVE_MBDMA_NOTE"
	report_note "enet_txdump_note=$ENET_TXDUMP_NOTE"
	report_note "enet_ctrlmap_note=$ENET_CTRLMAP_NOTE"
	report_note "enet_compare_fpm=${ENET_COMPARE_FPM_ADDRS[*]}"
	report_note "enet_compare_genet=${ENET_COMPARE_GENET_ADDRS[*]}"
	report_note "enet_compare_profile=${ENET_COMPARE_PROFILE_ADDRS[*]}"
	report_note "enet_compare_mdio=${ENET_COMPARE_MDIO_ADDRS[*]}"
	report_note "enet_oem_hints_begin"
	printf '  %s\n' "${ENET_OEM_COMPARE_HINTS[@]}" >>"$RUN_REPORT"
	report_note "enet_oem_hints_end"
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
		prepare)
			report_note "why=forced kernel prepare + install sequence requested"
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
		clean)
			report_note "why=forced target/linux clean + full rebuild requested"
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

changed_bmips_patch_files() {
	git -C "$OWRT" ls-files -m -o --exclude-standard -- 'target/linux/bmips/patches-*/*.patch' 2>/dev/null || true
}

run_patch_precheck() {
	local action="$1"
	local precheck_log="$BUILD_LOG_BASE/${TS}-patch-precheck.log"
	local patch_rel=""
	local patch_abs=""
	local patch_count=0
	local precheck_failures=0
	local linux_tree=""

	if [ "$action" = "none" ]; then
		report_note "patch_precheck_status=skipped_no_build"
		return 0
	fi

	if [ "$PATCH_PRECHECK" != "1" ]; then
		progress_note "patch precheck disabled"
		report_note "patch_precheck_status=disabled"
		return 0
	fi

	linux_tree="$(find "$OWRT/build_dir/target-mips_mips32_musl/linux-bmips_bcm63268" -maxdepth 1 -type d -name 'linux-*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"

	: >"$precheck_log"
	{
		echo "=== patch precheck ==="
		echo "timestamp_local=$(date '+%Y-%m-%d %H:%M:%S %Z')"
		echo "owrt=$OWRT"
		echo "build_action=$action"
		if [ -n "$linux_tree" ] && [ -d "$linux_tree" ]; then
			echo "linux_tree=$linux_tree"
		else
			echo "linux_tree=missing"
		fi
	} >>"$precheck_log"

	while IFS= read -r patch_rel; do
		[ -n "$patch_rel" ] || continue
		patch_count=$((patch_count + 1))
		patch_abs="$OWRT/$patch_rel"
		echo >>"$precheck_log"
		echo "patch=$patch_rel" >>"$precheck_log"

		if [ ! -f "$patch_abs" ]; then
			echo "FAIL: missing patch file: $patch_abs" >>"$precheck_log"
			precheck_failures=$((precheck_failures + 1))
			continue
		fi

		if [ -n "$linux_tree" ] && [ -d "$linux_tree" ]; then
			if ! git -C "$linux_tree" apply --check --unsafe-paths "$patch_abs" >>"$precheck_log" 2>&1; then
				echo "FAIL: git apply --check failed for $patch_rel" >>"$precheck_log"
				precheck_failures=$((precheck_failures + 1))
			else
				echo "OK: git apply --check passed for $patch_rel" >>"$precheck_log"
			fi
		else
			if ! grep -q '^@@ ' "$patch_abs"; then
				echo "FAIL: patch does not contain unified diff hunks (@@): $patch_rel" >>"$precheck_log"
				precheck_failures=$((precheck_failures + 1))
			else
				echo "WARN: linux source tree not prepared yet, ran syntax-only hunk check for $patch_rel" >>"$precheck_log"
			fi
		fi
	done < <(changed_bmips_patch_files)

	if [ "$patch_count" -eq 0 ]; then
		progress_note "patch precheck: no modified/untracked bmips patch files"
		report_note "patch_precheck_status=no_changed_patch_files"
		report_note "patch_precheck_log=$precheck_log"
		return 0
	fi

	progress_note "patch precheck checked $patch_count changed patch file(s)"
	progress_note "patch precheck log: $precheck_log"
	report_note "patch_precheck_status=ran"
	report_note "patch_precheck_files=$patch_count"
	report_note "patch_precheck_failures=$precheck_failures"
	report_note "patch_precheck_log=$precheck_log"

	if [ "$precheck_failures" -ne 0 ]; then
		echo "FAIL: patch precheck found $precheck_failures issue(s). See: $precheck_log" >&2
		tail -80 "$precheck_log" >&2 || true
		exit 1
	fi
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
	local prepare_log="$BUILD_LOG_BASE/${TS}-target-linux-prepare.log"
	local clean_log="$BUILD_LOG_BASE/${TS}-target-linux-clean.log"
	local install_log="$BUILD_LOG_BASE/${TS}-target-linux-install.log"
	local compile_log="$BUILD_LOG_BASE/${TS}-target-linux-compile.log"
	local full_log="$BUILD_LOG_BASE/${TS}-make-full-image.log"
	local fallback_log="$BUILD_LOG_BASE/${TS}-make-full-image-fallback.log"
	local fallback_stage=""

	run_prepare() {
		progress_note "running: make -j1 target/linux/prepare V=s"
		run_logged "$prepare_log" make -j1 target/linux/prepare V=s
	}

	run_clean() {
		progress_note "running: make target/linux/clean"
		run_logged "$clean_log" make target/linux/clean
	}

	run_compile() {
		progress_note "running: make -j$JOBS target/linux/compile V=s"
		run_logged "$compile_log" make -j"$JOBS" target/linux/compile V=s
	}

	run_install_allow_fail() {
		progress_note "running: make -j$JOBS target/linux/install V=s"
		run_logged_allow_fail "$install_log" make -j"$JOBS" target/linux/install V=s
	}

	run_full() {
		progress_note "running: make -j$JOBS V=s"
		run_logged "$full_log" make -j"$JOBS" V=s
	}

	case "$action" in
		none)
			progress_note "skipped build"
			report_note "make_action=skipped"
			;;
		prepare)
			report_note "make_action=prepare+install"
			run_prepare
			if ! run_install_allow_fail; then
				progress_note "install failed after prepare; retrying compile+install"
				progress_note "install fail log: $install_log"
				tail -40 "$install_log" >&2 || true
				report_note "fallback_reason=target/linux/install failed after prepare"
				run_compile
				if ! run_install_allow_fail; then
					progress_note "install failed after compile; retrying clean+full build"
					progress_note "install fail log: $install_log"
					tail -40 "$install_log" >&2 || true
					report_note "fallback_reason=target/linux/install failed after prepare+compile"
					run_clean
					fallback_stage="clean+full"
					run_logged "$fallback_log" make -j"$JOBS" V=s
				fi
			fi
			;;
		install)
			report_note "make_action=install"
			if ! run_install_allow_fail; then
				progress_note "install failed; retrying prepare+install"
				progress_note "install fail log: $install_log"
				tail -40 "$install_log" >&2 || true
				report_note "fallback_reason=target/linux/install failed"
				run_prepare
				if ! run_install_allow_fail; then
					progress_note "install failed after prepare; retrying compile+install"
					progress_note "install fail log: $install_log"
					tail -40 "$install_log" >&2 || true
					report_note "fallback_reason=target/linux/install failed after prepare"
					run_compile
					if ! run_install_allow_fail; then
						progress_note "install failed after compile; retrying clean+full image build"
						progress_note "install fail log: $install_log"
						tail -40 "$install_log" >&2 || true
						report_note "fallback_reason=target/linux/install failed after prepare+compile"
						run_clean
						fallback_stage="clean+full"
						run_logged "$fallback_log" make -j"$JOBS" V=s
					fi
				fi
			fi
			;;
		compile)
			report_note "make_action=compile+install"
			run_compile
			if ! run_install_allow_fail; then
				progress_note "install failed after compile; retrying prepare+compile+install"
				progress_note "install fail log: $install_log"
				tail -40 "$install_log" >&2 || true
				report_note "fallback_reason=target/linux/install failed after compile"
				run_prepare
				run_compile
				if ! run_install_allow_fail; then
					progress_note "install still failed; retrying clean+full image build"
					progress_note "install fail log: $install_log"
					tail -40 "$install_log" >&2 || true
					report_note "fallback_reason=target/linux/install failed after prepare+compile"
					run_clean
					fallback_stage="clean+full"
					run_logged "$fallback_log" make -j"$JOBS" V=s
				fi
			fi
			;;
		full)
			report_note "make_action=full"
			if ! run_logged_allow_fail "$full_log" make -j"$JOBS" V=s; then
				progress_note "full build failed; retrying clean+full build"
				progress_note "full build fail log: $full_log"
				tail -40 "$full_log" >&2 || true
				report_note "fallback_reason=full build failed"
				run_clean
				fallback_stage="clean+full"
				run_logged "$fallback_log" make -j"$JOBS" V=s
			fi
			;;
		clean)
			report_note "make_action=clean+full"
			run_clean
			run_full
			;;
		*)
			echo "FAIL: unsupported build action: $action" >&2
			exit 2
			;;
	esac

	if [ -n "$fallback_stage" ]; then
		report_note "fallback_stage=$fallback_stage"
	fi
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
