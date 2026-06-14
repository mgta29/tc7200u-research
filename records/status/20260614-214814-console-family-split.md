# TC7200U console family split

## Confirmed working

Working image:
- records/artifacts/rescue/tc7200-console-good-20260601-193010.bin
- records/artifacts/rescue/tc7200-stage2-console-good.bin

Known-good family markers from status:
- wrapped/template size: 6418079 bytes
- file length: 6417987 bytes
- load address: 80004000
- kernel build marker: Linux version ... #0 SMP Sun May 17 18:30:33 2026
- Gate E PASS / console_ready on known-good serial logs

## Confirmed broken/rebuild family

Newer/current rebuild family markers:
- load address often 82000000
- Linux version 6.12.91 / newer mutable OpenWrt tree
- observed failures include no real ttyS0 console, init panic, or userspace SIGSEGV
- not equivalent to the known-good image family

## Rule

Do not mix the pinned known-good payload family with newer rebuilt test payloads.
Before Ethernet work, require Gate E PASS and pin:
- CFE filename
- file length
- raw_sha256
- wrapped_sha256
- load address
- kernel version line
