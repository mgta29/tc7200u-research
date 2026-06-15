# 2026-05-19 - UNIMAC CORE0/CORE1 link-toggle probe shows no delta

## Summary

A direct down/up probe compared key UNIMAC core registers for both interface
windows:

- CORE0: `0x12c00808`, `0x12c00814`
- CORE1: `0x12c02808`, `0x12c02814`

The test was run with `eth0` down, then `eth0` up, then sampled again.

## Result

Values were unchanged between down and up:

- `0x12c00808 = 0x010000d8`
- `0x12c00814 = 0x000005ee`
- `0x12c02808 = 0x00010000`
- `0x12c02814 = 0x00000000`

Interrupt state remained the known pattern:

- `/proc/interrupts`: hwirq `64` increments
- `/proc/interrupts`: hwirq `66` remains `0`

## Interpretation

This probe does not provide a core-ownership discriminator. The sampled
CORE0/CORE1 registers are stable configuration/state values in this scenario
and do not track link toggle.

It does not contradict GENET activity on hwirq `64`, but it means we should
not use these four registers alone to infer which UMAC core path is truly
active for TX completion.

## Next action

Keep this as a negative discriminator and continue with TDMA-side diagnosis:

1. Keep ring/TDMA state capture around `0x12c03800..0x12c03c48`.
2. Sample IF0 and IF1 MIB windows before/after controlled traffic while link is
   up.
3. If still flat, continue kernel-side DMA/descriptor path changes rather than
   more static UMAC register snapshots.
