# TC7200 stage1 ISA confirmation: MIPS32, not MIPS16 (2026-06-07)

Scope:
- Record the corrected ISA conclusion from the current Ghidra session.
- Preserve the reason for the correction so the wrong MIPS16 assumption is not reused.

Inputs:
- Imported raw image: `/home/mgta29/tc7200u-research/reverse/d60242_ghidra/image.raw`
- Ghidra listing at entry `0x80004000`
- Visible analysis state:
  - `assume ISA_MODE = 0x0`
  - `assume PAIR_INSTRUCTION_FLAG = 0x0`
  - 4-byte instruction alignment at the reset/entry window

Conclusion:
- The stage1 image is standard big-endian `MIPS32`.
- It is not `MIPS16`.

Reasoning:
- `ISA_MODE = 0x0` indicates normal MIPS ISA mode, not 16-bit compressed mode.
- The entry block advances in 4-byte instruction steps.
- The decoded startup instructions (`mtc0`, `nop`, related CP0 setup) match normal 32-bit MIPS code layout.

Operational impact:
- Ghidra imports for this stage1 image should use:
  - Language: `MIPS:BE:32:default`
  - Base address: `0x80004000`
- Any regions previously forced or interpreted as `MIPS16` should be cleared and re-disassembled as `MIPS32`.
- The Java label script already matches the corrected ISA expectation and does not need an ISA-mode change for this point.

Follow-up:
- Clean bad function splits created under the wrong interpretation.
- Re-disassemble affected regions as `MIPS32`.
- Re-run analysis, then re-run the label script.
