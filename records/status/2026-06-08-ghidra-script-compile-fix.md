# Ghidra script compile fix for `getSymbols(addr)` API mismatch (2026-06-08)

Scope:
- Fix the Java compile failure seen when loading `tc7200_stage1_label_map.java` from Ghidra.

Changed file:
- `/home/mgta29/tc7200u-research/records/reverse/ghidra/tc7200_stage1_label_map.java`

Problem:
- The target Ghidra build returns `Symbol[]` from `currentProgram.getSymbolTable().getSymbols(addr)`.
- The script was written against a variant/API expectation that used `SymbolIterator`.
- This caused compile errors and prevented `tc7200_stage1_label_map` from loading at all.

Fix:
- Removed the `SymbolIterator` import.
- Replaced both symbol scans with direct iteration over the returned `Symbol[]`.
- The affected logic is:
  - duplicate-label detection in `hasLabelAtAddress(...)`
  - obsolete-label cleanup in `removeObsoleteLabels(...)`

Practical result:
- The script should now compile on the current Ghidra installation instead of failing with:
  - `incompatible types: ghidra.program.model.symbol.Symbol[] cannot be converted to ghidra.program.model.symbol.SymbolIterator`

Operational note:
- Ghidra loads scripts from the user script directory, not automatically from the research repo.
- If `/home/mgta29/tc7200u-research/records/reverse/ghidra/tc7200_stage1_label_map.java` is the source of truth, the updated file still needs to be copied/synced into the active Ghidra script directory before rerunning it.
