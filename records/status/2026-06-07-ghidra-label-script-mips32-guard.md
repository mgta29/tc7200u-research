# Ghidra label script MIPS32 guard refresh (2026-06-07)

Scope:
- Tighten the Java label script so it refuses the wrong Ghidra language setup for TC7200 stage1.
- Add a stable entry label at the raw reset vector.

Changed file:
- `/home/mgta29/tc7200u-research/records/reverse/ghidra/tc7200_stage1_label_map.java`

Changes:
- Replaced the loose little-endian-only check with an exact language check for:
  - `MIPS:BE:32:default`
- Added an explicit error message that the stage1 image is `MIPS32`, not `MIPS16`.
- Added `entry_stage1_reset_vector` at `0x80004000` for both known profiles.

Reasoning:
- The previous script guard only rejected `:LE:` imports.
- That meant a wrongly interpreted non-LE setup could still pass the script gate.
- The current Ghidra session confirms the reset window is normal 4-byte `MIPS32` code with `ISA_MODE = 0x0`.

Expected effect after rerun:
- The script now fails fast on language setups that do not match the confirmed stage1 import mode.
- The reset vector gets a stable user label that marks the beginning of the MIPS32 startup path.
