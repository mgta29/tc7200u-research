#!/usr/bin/env python3
import argparse
import select
import sys
import termios
import time
import tty
from pathlib import Path

import serial

MARKERS = [
    b"Tftp complete",
    b"Executing Image 4",
    b"Decompressing kernel...",
    b"done!",
    b"blasting from",
    b"Starting kernel",
    b"Run /init as init process",
    b"root@(none):~#",
    b"Kernel panic",
]

def check_markers(buf, seen, start, now):
    for marker in MARKERS:
        if marker not in seen and marker in buf:
            seen[marker] = now - start
            print(f"\n[TIMER] {marker.decode(errors='replace')} at +{seen[marker]:.3f}s", file=sys.stderr)

            if marker == b"done!" and b"Decompressing kernel..." in seen:
                dt = seen[b"done!"] - seen[b"Decompressing kernel..."]
                print(f"[TIMER] decompress_duration={dt:.3f}s", file=sys.stderr)

            if marker == b"Starting kernel" and b"Decompressing kernel..." in seen:
                dt = seen[b"Starting kernel"] - seen[b"Decompressing kernel..."]
                print(f"[TIMER] decompress_to_start_kernel={dt:.3f}s", file=sys.stderr)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--log", required=True)
    args = ap.parse_args()

    log_path = Path(args.log)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    start = time.monotonic()
    seen = {}
    buf = b""

    old_tty = termios.tcgetattr(sys.stdin)

    try:
        tty.setraw(sys.stdin.fileno())

        with serial.Serial(args.port, args.baud, timeout=0) as ser, log_path.open("wb") as f:
            print(f"\nLogging serial to: {log_path}", file=sys.stderr)
            print("Interactive mode: press keys normally. Ctrl+C to stop.", file=sys.stderr)
            print("At CFE menu, press: g", file=sys.stderr)

            while True:
                readable, _, _ = select.select([ser.fileno(), sys.stdin.fileno()], [], [], 0.05)
                now = time.monotonic()

                if ser.fileno() in readable:
                    data = ser.read(4096)
                    if data:
                        f.write(data)
                        f.flush()
                        sys.stdout.buffer.write(data)
                        sys.stdout.buffer.flush()
                        buf = (buf + data)[-4096:]
                        check_markers(buf, seen, start, now)

                if sys.stdin.fileno() in readable:
                    ch = sys.stdin.buffer.read(1)
                    if ch:
                        if ch == b"\n":
                            ch = b"\r"
                        ser.write(ch)
                        ser.flush()

    finally:
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_tty)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStopped.", file=sys.stderr)
