# 2026-06-07 tcbuilder Interactive Default

Changed `scripts/tcbuilder.sh` so the default startup path is interactive in a
TTY, with a fallback to `auto` for non-interactive invocations.

What changed:
- `MODE` now defaults to `interactive`.
- A terminal session opens the interactive menu automatically.
- Non-TTY invocations fall back to `auto` so scripted usage does not hang.
- Operator docs now say `tcbuild` is the canonical entrypoint and explain how to
  reach the auto build/wrap/verify path from the menu.

Verification:
- `bash -n scripts/tcbuilder.sh`
- `./scripts/tcbuilder.sh selftest`
- `./scripts/tcbuilder.sh paths`
- `printf '6\n' | script -qec './scripts/tcbuilder.sh' /dev/null`

Notes:
- No old logs were edited.
- Existing canonical A825 ProgramStore-wrapped template handling was not
  changed by this default-mode update.
