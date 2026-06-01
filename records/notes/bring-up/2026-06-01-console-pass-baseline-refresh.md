# 2026-06-01 console PASS baseline refresh

Goal:
- Confirm that the pinned control image still reaches OpenWrt userspace shell.

Result:
- PASS.
- Serial log: `records/logs/serial/picocom-20260601-193010.log`
- Gate report: `records/logs/builds/2026-06-01-195304-check-gates-picocom-20260601-193010.txt`
- Gate verdicts:
  - Gate A PASS
  - Gate B PASS
  - Gate C PASS (clean)
  - Gate D PASS
  - Gate E PASS (console_ready)

Key runtime markers:
- `OpenWrt kernel loader for BMIPS`
- `Decompressing kernel... done!`
- `Run /init as init process`
- `procd: - init -`
- `Please press Enter to activate this console.`
- `BusyBox v1.37.0 ...`

Pinned rescue copy:
- `records/artifacts/rescue/tc7200-console-good-20260601-193010.bin`

Notes:
- Ethernet remains the blocker (`NETDEV WATCHDOG` still present in this run).
- A separate run (`picocom-20260601-190051.log`) booted console but showed
  repeated `SIGSEGV` in `ubus`; do not use that for clean baseline claims.
