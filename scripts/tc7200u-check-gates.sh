#!/usr/bin/env bash
set -euo pipefail

RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
RESEARCH_BUILDS_DIR="${RESEARCH_BUILDS_DIR:-$RESEARCH/research/builds}"
LOG_PATH=""
REPORT_OUT=""
SAVE_REPORT=1

usage() {
  cat <<'EOF'
Usage:
  tc7200u-check-gates.sh [--log /abs/path/to/picocom.log] [--report-out /abs/path/to/report.txt] [--no-save]

Behavior:
  - If --log is omitted, uses newest from:
      $RESEARCH/research/mapping-stage/picocom-mapp-*.log
      $RESEARCH/evidence/serial/picocom-*.log
  - Prints Gate A/B/C/D/E status from the current checklist.
  - Saves a detailed runtime report into $RESEARCH/research/builds by default.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --log)
      shift
      [ "$#" -gt 0 ] || { echo "ERROR: --log requires a value" >&2; exit 2; }
      LOG_PATH="$1"
      ;;
    --report-out)
      shift
      [ "$#" -gt 0 ] || { echo "ERROR: --report-out requires a value" >&2; exit 2; }
      REPORT_OUT="$1"
      ;;
    --no-save)
      SAVE_REPORT=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ -z "$LOG_PATH" ]; then
  newest="$(ls -1t \
    "$RESEARCH"/research/mapping-stage/picocom-mapp-*.log \
    "$RESEARCH"/evidence/serial/picocom-*.log \
    2>/dev/null | head -n 1 || true)"
  if [ -z "$newest" ]; then
    echo "ERROR: no picocom logs found in:" >&2
    echo "  $RESEARCH/research/mapping-stage/picocom-mapp-*.log" >&2
    echo "  $RESEARCH/evidence/serial/picocom-*.log" >&2
    exit 2
  fi
  LOG_PATH="$newest"
fi

if [ ! -f "$LOG_PATH" ]; then
  echo "ERROR: log not found: $LOG_PATH" >&2
  exit 2
fi

basename_no_ext="$(basename "$LOG_PATH")"
basename_no_ext="${basename_no_ext%.log}"
ts="$(date +%Y-%m-%d-%H%M%S)"
if [ -z "$REPORT_OUT" ] && [ "$SAVE_REPORT" = "1" ]; then
  mkdir -p "$RESEARCH_BUILDS_DIR"
  REPORT_OUT="$RESEARCH_BUILDS_DIR/${ts}-check-gates-${basename_no_ext}.txt"
fi

count_fixed() {
  local pat="$1"
  local out
  out="$(rg -F -c -- "$pat" "$LOG_PATH" || true)"
  if [ -z "$out" ]; then
    echo "0"
  else
    echo "$out"
  fi
}

line_first() {
  local pat="$1"
  rg -F -n -- "$pat" "$LOG_PATH" | head -n 1 | cut -d: -f1 || true
}

line_last_after() {
  local pat="$1"
  local start_line="$2"
  if [ -z "$start_line" ]; then
    echo ""
    return
  fi
  rg -F -n -- "$pat" "$LOG_PATH" | awk -F: -v s="$start_line" '$1 > s { print $1 }' | tail -n 1 || true
}

status() {
  local name="$1"
  local value="$2"
  printf '%-8s %s\n' "$name" "$value"
}

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
if [ "$exceptions" -gt 0 ]; then
  gate_b="FAIL"
fi
if [ -n "$cfe_after_exec_line" ]; then
  gate_b="FAIL"
fi
if [ "$panic_lines" -gt 0 ] || [ "$panic_init_kill" -gt 0 ]; then
  gate_b="FAIL"
fi

gate_c="PASS"
gate_c_detail="clean"
if [ "$nand_fail" -gt 0 ]; then
  gate_c="FAIL"
  gate_c_detail="fatal/unknown"
fi

if [ "$nand_fail" -gt 0 ]; then
  tr69_hits="$(count_fixed 'Creating TR-069 Thread...')"
  docsis_hits="$(count_fixed 'Creating DOCSIS Control Thread...')"
  deep_runtime_hits=$((tr69_hits + docsis_hits))
  if [ "$deep_runtime_hits" -gt 0 ] && [ "$exceptions" -eq 0 ] && [ -z "$cfe_after_exec_line" ]; then
    gate_c_detail="nonfatal/degraded"
  fi
fi

hs_total=$((hs_getmsg_err + hs_unexp_err + unhandled_msgs + hs_msg_lines))
gate_d="PASS"
if [ "$hs_total" -gt 20 ]; then
  gate_d="FAIL"
elif [ "$hs_total" -gt 0 ]; then
  gate_d="WARN"
fi
if [ -n "$cfe_after_exec_line" ] && [ "$hs_total" -gt 0 ]; then
  gate_d="FAIL"
fi

gate_e="PASS"
gate_e_detail="console_ready"
if [ "$warn_no_console" -gt 0 ] || [ "$panic_lines" -gt 0 ] || [ "$panic_init_kill" -gt 0 ]; then
  gate_e="FAIL"
  gate_e_detail="userspace_console_failed"
elif [ "$procd_init_lines" -eq 0 ] || [ "$press_enter_lines" -eq 0 ] || [ "$busybox_shell_lines" -eq 0 ]; then
  gate_e="WARN"
  gate_e_detail="boot_not_fully_observed"
fi

echo "log=$LOG_PATH"
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
if [ -n "$exec_line" ]; then
  echo "executing_image4_line=$exec_line"
fi
if [ -n "$cfe_after_exec_line" ]; then
  echo "cfe_banner_after_exec_line=$cfe_after_exec_line"
fi

echo
echo "== gate verdicts =="
status "Gate A:" "$gate_a ($gate_a_detail)"
status "Gate B:" "$gate_b"
status "Gate C:" "$gate_c ($gate_c_detail)"
status "Gate D:" "$gate_d"
status "Gate E:" "$gate_e ($gate_e_detail)"

echo
echo "== quick triage grep =="
echo "rg -n \"Tftp complete|Signature:|Executing Image 4|EXCEPTION TYPE|NandFlashRead|handshake|unexpected message|Board IP Address|Kernel panic|Attempted to kill init|Warning: unable to open an initial console|procd: - init -|Please press Enter|BusyBox v\" \"$LOG_PATH\""

if [ "$SAVE_REPORT" = "1" ] && [ -n "$REPORT_OUT" ]; then
  {
    echo "# TC7200U Gate Report"
    echo
    echo "generated_at=$(date -Is)"
    echo "log_path=$LOG_PATH"
    echo "report_path=$REPORT_OUT"
    echo
    echo "## Log metadata"
    ls -lh --time-style=long-iso "$LOG_PATH" 2>/dev/null || true
    sha256sum "$LOG_PATH" 2>/dev/null || true
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
    if [ -n "$exec_line" ]; then
      echo "executing_image4_line=$exec_line"
    fi
    if [ -n "$cfe_after_exec_line" ]; then
      echo "cfe_banner_after_exec_line=$cfe_after_exec_line"
    fi
    echo
    echo "## Gate verdicts"
    status "Gate A:" "$gate_a ($gate_a_detail)"
    status "Gate B:" "$gate_b"
    status "Gate C:" "$gate_c ($gate_c_detail)"
    status "Gate D:" "$gate_d"
    status "Gate E:" "$gate_e ($gate_e_detail)"
    echo
    echo "## Boot/runtime key lines"
    rg -n "OpenWrt kernel loader for BMIPS|Decompressing kernel|Starting kernel at|Linux version|Kernel command line|Warning: unable to open an initial console|Run /init as init process|do_page_fault\\(\\)|Kernel panic - not syncing|Attempted to kill init|Rebooting in|Reboot failed|procd: - early -|procd: - ubus -|procd: - init -|Please press Enter to activate this console.|BusyBox v|NETDEV WATCHDOG|EXCEPTION TYPE:" "$LOG_PATH" || true
    echo
    echo "## Build key lines (if present)"
    rg -n "WARNING: Makefile|time: target/linux/|Patch failed!|ERROR: target/linux failed to build|make\\[[0-9]+\\]: \\*\\*\\*" "$LOG_PATH" || true
    echo
    echo "## Quick triage command"
    echo "rg -n \"Tftp complete|Signature:|Executing Image 4|EXCEPTION TYPE|NandFlashRead|handshake|unexpected message|Board IP Address|Kernel panic|Attempted to kill init|Warning: unable to open an initial console|procd: - init -|Please press Enter|BusyBox v\" \"$LOG_PATH\""
  } > "$REPORT_OUT"
  echo
  echo "report_saved=$REPORT_OUT"
fi
