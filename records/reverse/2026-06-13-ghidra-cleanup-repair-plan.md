# Ghidra cleanup / repair plan

## Scope
Repair and organize the TC7200U Ghidra reverse-engineering project without deleting old logs, old Ghidra projects, notes, or evidence.

## Rules
- Preserve old logs and prior Ghidra state.
- Work on a duplicate or clean re-import.
- No fake functions.
- No dummy placeholders.
- No silent renames.
- Candidate names must keep `_candidate` suffix.
- MIPS big-endian must be used for TC7200U stage work.
- Stage1 base remains `0x80004000` unless proven otherwise.

## Safe repair sequence
1. Backup the existing Ghidra project.
2. Duplicate the program or create a clean re-import.
3. Verify language: `MIPS:BE:32:default`.
4. Verify base address: `0x80004000`.
5. Inspect Memory Map.
6. Keep imported firmware block initialized.
7. Add RAM/MMIO blocks only when needed by confirmed xrefs.
8. Remove wrong labels/types/functions carefully.
9. Reapply confirmed labels/comments.
10. Save progress as dated notes.

## Cleanup targets
- Memory block organization.
- Bad auto-analysis artifacts.
- Wrong labels.
- Wrong data types.
- Fake functions.
- Ambiguous globals.
- Overlapping symbol names.

## Result
This creates a clean, auditable Ghidra workspace while preserving the original damaged/messy project as evidence.
