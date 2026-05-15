#!/usr/bin/env bash
set -euo pipefail

BUSID="${BUSID:-1-9}"
DEV="${DEV:-}"
RESEARCH="${RESEARCH:-$HOME/tc7200u-research}"
PWSH="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

echo "== TC7200.U serial console =="
echo "BUSID=$BUSID"

if [ -x "$PWSH" ]; then
    if ! "$PWSH" -NoProfile -Command "usbipd attach --wsl --busid $BUSID"; then
        echo "WARN: usbipd attach failed or device is already attached. Continuing."
    fi
else
    echo "WARN: PowerShell path not found: $PWSH"
fi

sudo modprobe usbserial
sudo modprobe ch341

if [ -z "$DEV" ]; then
    for _ in $(seq 1 40); do
        DEV="$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -1 || true)"
        [ -n "$DEV" ] && break
        sleep 0.25
    done
fi

if [ -z "$DEV" ]; then
    echo "ERROR: no /dev/ttyUSB* or /dev/ttyACM* found"
    exit 1
fi

if pgrep -af "picocom.*$DEV" >/dev/null; then
    echo "ERROR: picocom already appears to be using $DEV"
    pgrep -af "picocom.*$DEV" || true
    exit 1
fi

mkdir -p "$RESEARCH/logs"
LOG="$RESEARCH/logs/picocom-$(date +%Y%m%d-%H%M%S).log"

echo "DEV=$DEV"
echo "LOG=$LOG"
echo "Exit picocom: Ctrl-a then Ctrl-x"
echo "Use only one serial terminal."

exec sudo picocom -b 115200 --flow n --logfile "$LOG" "$DEV"
