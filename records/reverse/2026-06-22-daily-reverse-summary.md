# 2026-06-22 daily reverse summary

## Scope control

- This is a continuation of the 2026-06-21 reverse carry pass after the workspace date crossed to 2026-06-22.
- Requested source path `records/notes/reverse` is still absent; controlled source remains `records/reverse`.
- Pre-summary control count after the 2026-06-21 updates: `70` reverse markdown files and `33471` reverse markdown lines.

## Documentation updates completed

- Updated `2026-06-21-daily-reverse-summary.md` with the late Host-DQM IM5, NATP Host-DQM, heap, and net-config carry.
- Updated `important-openwrt-tc7200u-enet-usable-values.md` with a superseding IRQ13/Host-DQM correction: proven Host-DQM IM5 groups are `0x23..0x28`; group `0x30` remains an unproven hypothesis for Host-DQM.
- Updated `important-openwrt-tc7200u-enet-usable-values.md` with corrected child-bank semantics: `child_bank+0x08` is mask/control/enable and `child_bank+0x0c` is status/pending.
- Updated `important-reverse-structure-reference.md` with Host-DQM object ops, refined Host-DQM/FAP layouts, NATP no-match RX manager, corrected child-bank regs, encoded IRQ decode entry, NATP/GFAP manager/vector/L1-cache layouts, heap headers/stats, and net-config cache structures.
- Restored `important-reverse-structure-reference.md` from the tracked baseline before applying the additive update because it was deleted in the working tree at the start of the continuation.

## OpenWrt development carry

- Do not add blind IRQ clear/ack writes until OpenWrt snapshots parent IM5, child-bank, and GENET INTRL2 locals coherently.
- Keep NATP selector `4` / MPEG_PROC Host-DQM windows as reverse-control targets, not immediate Linux driver constants.
- Resize the Ghidra block at `8187bc60` through `81883daf` before applying `net_config_indexed_cache_entry_400_candidate[32]` at `8187bdb0`.

## Control result

- `git diff --check` passed for the three updated carry documents.
- `important-reverse-structure-reference.md` now reports `82` current carried structures/support layouts.