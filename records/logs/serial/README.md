# Serial Log Organization

Date: 2026-06-16
Scope: organize the current contents of `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial` without renaming or editing historical log files.

## Naming rule going forward

Primary serial run logs should use:

- `picocom-YYYYMMDD-HHMMSS.log`

Use the log filename only for capture identity.
Put scenario meaning in the matching note under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\*`, not in the serial filename.

## Current organization

### 1. Primary canonical run logs

These are the main serial run history and already follow the preferred naming:

- `picocom-20260515-123108.log`
- `picocom-20260515-125754.log`
- `picocom-20260515-192023.log`
- `picocom-20260517-023425.log`
- `picocom-20260517-031103.log`
- `picocom-20260517-034708.log`
- `picocom-20260517-040921.log`
- `picocom-20260517-042543.log`
- `picocom-20260517-044523.log`
- `picocom-20260517-050652.log`
- `picocom-20260517-053525.log`
- `picocom-20260517-055525.log`
- `picocom-20260524-215536.log`
- `picocom-20260524-220912.log`
- `picocom-20260525-001249.log`
- `picocom-20260525-121047.log`
- `picocom-20260525-140510.log`
- `picocom-20260525-174217.log`
- `picocom-20260525-184351.log`
- `picocom-20260525-194022.log`
- `picocom-20260525-213837.log`
- `picocom-20260525-220235.log`
- `picocom-20260526-001742.log`
- `picocom-20260526-011147.log`
- `picocom-20260526-013025.log`
- `picocom-20260526-041757.log`
- `picocom-20260526-045012.log`
- `picocom-20260531-042155.log`
- `picocom-20260531-043728.log`
- `picocom-20260531-043902.log`
- `picocom-20260531-045431.log`
- `picocom-20260531-050727.log`
- `picocom-20260531-092524.log`
- `picocom-20260531-095452.log`
- `picocom-20260531-143536.log`
- `picocom-20260531-162708.log`
- `picocom-20260531-165916.log`
- `picocom-20260531-182309.log`
- `picocom-20260531-184359.log`
- `picocom-20260531-195342.log`
- `picocom-20260531-202031.log`
- `picocom-20260531-215656.log`
- `picocom-20260531-223409.log`
- `picocom-20260601-190051.log`
- `picocom-20260601-193010.log`
- `picocom-20260601-210242.log`
- `picocom-20260601-213511.log`
- `picocom-20260601-221118.log`
- `picocom-20260601-233331.log`
- `picocom-20260602-053300.log`
- `picocom-20260607-200256.log`
- `picocom-20260607-205043.log`
- `picocom-20260614-112942.log`
- `picocom-20260614-113731.log`
- `picocom-20260614-123915.log`
- `picocom-20260614-131456.log`
- `picocom-20260614-135834.log`
- `picocom-20260614-145537.log`
- `picocom-20260614-152550.log`
- `picocom-20260614-162113.log`
- `picocom-20260614-164752.log`
- `picocom-20260614-173947.log`
- `picocom-20260614-182740.log`
- `picocom-20260614-195654.log`
- `picocom-20260614-201315.log`
- `picocom-20260614-210210.log`
- `picocom-20260614-212432.log`
- `picocom-20260614-234116.log`
- `picocom-20260615-001046.log`
- `picocom-20260615-002451.log`
- `picocom-20260615-005940.log`
- `picocom-20260615-013645.log`
- `picocom-20260615-235913.log`
- `picocom-20260616-002555.log`
- `picocom-20260616-004109.log`
- `picocom-20260616-010159.log`
- `picocom-20260616-011430.log`

Status:

- primary keep
- canonical naming already good

### 2. Special noncanonical logs to keep

These do not follow the preferred naming, but they are not waste. They carry meaningful scenario-specific evidence and should remain preserved as historical special cases.

Scenario-named substantive logs:

- `2026-05-15-b53-switch-1e-unsupported-device-zero.log`
- `2026-05-15-genet-mdio-node-present-tx-watchdog.log`
- `2026-05-15-genet-rgmii-fixed-link-tx-errors.log`
- `2026-05-15-genet-rgmii-fixed-link-watchdog.log`
- `2026-05-15-nand-int-base-command-09-timeout.log`
- `2026-05-15-nand-v5-command-09-timeout.log`

Why kept:

- these are content-labeled historical captures
- they align with runtime-probe topic notes
- they contain substantive GENET, MDIO, or NAND findings

Stage1 mapping / reverse-correlation captures:

- `picocom-mapp-20260531-005939.log`
- `picocom-mapp-20260531-010417.log`
- `picocom-mapp-20260531-011305.log`
- `picocom-mapp-20260531-011944.log`

Why kept:

- these are special mapping-family logs tied to the stage1 reverse work
- they are not noise
- they are not the preferred naming for future generic runs

Legacy early-capture evidence:

- `serial-20260513-214947.log`
- `serial-20260514-182258.log`
- `serial-20260514-200514-mmio-cmips.log`
- `serial-20260514-214701-wide-mmio.log`
- `serial-20260515-090648-enetsw-baseline.log`
- `serial-20260515-092715-enetsw-baseline.log`
- `serial-20260515-094059-enetsw-baseline.log`
- `serial-20260515-095810-enetsw-baseline.log`

Why kept:

- these are legacy pre-canonical serial captures
- they contain real boot/runtime evidence
- they should be treated as historical raw captures, not current naming examples

Status for all files in this section:

- keep-special
- noncanonical historical names

### 3. Duplicate or alias-style files

- `baseline-console-ready-20260531-182309.log`

Status:

- keep for provenance
- alias-style duplicate family
- not the preferred reference path when the canonical matching `picocom-*` file exists

Preferred reference:

- `picocom-20260531-182309.log`

### 4. Raw dump / non-primary dump-style captures

These files should not be the first reference when a canonical `picocom-*` run exists. They are preserved, but they are closer to raw dump/supporting capture than to primary organized run history.

- `serial-20260515-101552-decompress-timer.log`
- `serial-20260515-103251-decompress-timer-rescue.log`
- `serial-20260515-105400-decompress-timer-rescue.log`
- `serial-20260515-112318-decompress-timer-rescue.log`
- `serial-20260515-114541-decompress-timer-rescue.log`
- `tc7200_uart_full.log`

Status:

- keep-dump
- non-primary
- use only when the specific timer/rescue/full-UART dump context matters

Why marked this way:

- the decompress-timer files are raw legacy diagnostic captures, not good naming examples for normal run history
- `tc7200_uart_full.log` is a broad full-UART dump, useful for deep reference, but not a clean per-run canonical serial log

## Practical use rule

When citing a serial log in new notes:

1. prefer a canonical `picocom-YYYYMMDD-HHMMSS.log` file
2. use special noncanonical files only when they are the unique source for that scenario
3. avoid using dump-style files as the primary citation if a cleaner canonical run exists

## Preservation rule

This organization note does not rename old logs.
It records how they should be interpreted now.
