#!/usr/bin/env python3
import argparse
import sys
import time
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

    with serial.Serial(args.port, args.baud, timeout=0.05) as ser, log_path.open("wb") as f:
        print(f"Logging serial to: {log_path}", file=sys.stderr)
        print("Power/reboot the router now. Ctrl+C to stop.", file=sys.stderr)

        while True:
            b = ser.read(1)
            if not b:
                continue

            now = time.monotonic()
            f.write(b)
            f.flush()
            sys.stdout.buffer.write(b)
            sys.stdout.buffer.flush()

            buf = (buf + b)[-4096:]

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

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStopped.", file=sys.stderr)
