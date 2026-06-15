# Serial log organization pass - 2026-06-16

## Purpose

This note records the serial-log organization pass for:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial`

The goal of this pass is to document which files are already in the preferred
`picocom-YYYYMMDD-HHMMSS.log` format and which historical exceptions should be
treated as special evidence, aliases, or raw dump-style captures.

## Result

Added organization index:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\README.md`

That index records four groups:

1. primary canonical `picocom-*` run logs
2. substantive historical noncanonical logs to keep
3. alias-style duplicate family files
4. raw dump / non-primary dump-style captures

## High-level classification decisions

Canonical keep:

- the main `picocom-YYYYMMDD-HHMMSS.log` family is already the preferred naming
  and should remain the default citation path for future notes

Keep-special:

- scenario-labeled 2026-05-15 logs were kept as substantive evidence
- `picocom-mapp-*` logs were kept as stage1 mapping/reverse-correlation captures
- early `serial-*` baseline and MMIO/enetsw logs were kept as legacy evidence

Alias-style:

- `baseline-console-ready-20260531-182309.log` is treated as an alias-style
  duplicate family file; the canonical reference path is
  `picocom-20260531-182309.log`

Keep-dump / non-primary:

- `serial-20260515-101552-decompress-timer.log`
- `serial-20260515-103251-decompress-timer-rescue.log`
- `serial-20260515-105400-decompress-timer-rescue.log`
- `serial-20260515-112318-decompress-timer-rescue.log`
- `serial-20260515-114541-decompress-timer-rescue.log`
- `tc7200_uart_full.log`

These were marked as preserved dump-style captures, not primary organized run
history.

## Preservation

No existing serial log file was edited or renamed by this pass.
This note and the serial-log index are additive only.
