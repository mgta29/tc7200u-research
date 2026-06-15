# Git organization pass - 2026-06-09

## Purpose

This note logs the 2026-06-09 git cleanup pass for:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research`

The goal of this pass is to organize the current dirty tree into logical local commits without modifying, moving, renaming, or deleting any existing non-Markdown file content.

## Constraints used for this pass

- only `.md` files may be added or edited
- non-Markdown file contents remain exactly as they were already present in the working tree
- old logs and notes remain unchanged
- git metadata changes such as staging and local commits are allowed

## Commit grouping used

The tree is organized into these local commits:

1. `notes: add 2026-06-08 and 2026-06-09 research notes`
2. `docs: log 2026-06-09 git organization constraints`
3. `tools: capture existing helper and timer updates`
4. `artifacts: capture current tracked image changes`
5. `reverse: add current ghidra workspace as-is`

## Non-Markdown content left untouched

This pass intentionally does not alter the contents of:

- tracked image artifacts under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\artifacts`
- helper updates already present in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tcbuilder.sh`
- helper updates already present in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\tools\serial-decompress-timer.py`
- the untracked reverse workspace under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\reverse`

## Known layout exception

The current top-level reverse-engineering workspace remains at:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\reverse\d60242_ghidra`

Repository docs say reverse-engineering output normally belongs under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse`, but this pass does not relocate it. The mismatch is recorded here and the directory is committed as-is.

## Preservation

This note was added as a new dated Markdown record. No older log or note file was edited or deleted by this pass.
