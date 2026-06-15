# 2026-06-14 tcbuilder Candidate Mode

Added a `candidate` helper mode that folds the manual candidate-prep wrapper
into `scripts/tcbuilder.sh`.

What changed:
- Added `candidate --label NAME` to the helper CLI.
- The helper now writes `records/logs/builds/current-NAME.stamp` using the
  helper timestamp for the run.
- The helper now exports the current OpenWrt diff for the tracked BMIPS DTS,
  config, patch, and image paths into
  `patches/tc7200u-NAME-<STAMP>.patch`.
- The helper now saves a caller-named combined auto console log as
  `records/logs/builds/tc7200u-NAME-<STAMP>-auto.log`.
- After the auto flow finishes, the helper now saves
  `tc7200u-NAME-<STAMP>-sha256.txt` for the raw image, wrapped output, and
  preserve-from template when present.
- After the auto flow finishes, the helper now saves
  `tc7200u-NAME-<STAMP>-file.txt` with `ls -lah` and `file` output for the
  wrapped image.

Verification:
- `bash -n scripts/tcbuilder.sh scripts/tcbuilder/*.sh`
- `./scripts/tcbuilder.sh selftest`
- `./scripts/tcbuilder.sh paths`
- `./scripts/tcbuilder.sh candidate --label smoke-candidate --source-image records/artifacts/rescue/tc7200-stage2-console-good.bin --bin-name tc7200u-smoke.bin --tftp-dir /tmp/tcbuilder-candidate-smoke`

Notes:
- `candidate` is a wrapper around the existing auto build/wrap/verify path, not
  a separate build implementation.
- No old logs were edited.
