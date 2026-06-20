# 2026-06-20 Wrapper-Only Migration

## Summary

The public `tcbuilder` surface was retired. The repository now supports only:

- `./scripts/wrapper.sh`

`scripts/tcbuilder.sh` remains only as a migration stub that prints the removal
notice and exits non-zero.

## What Changed

- moved the A825 ProgramStore wrap, strip, and internal verify path into
  `scripts/wrapper.sh`
- removed the public build, verify, status, state, serial, reverse, candidate,
  gate, and menu behaviors
- updated current docs and `AI_HELPER.json` to describe the repo as wrapper-only
- kept historical logs and older dated notes unchanged

## Wrapper Policy

- raw no-template wraps default to load address `0x82000000`
- template-aligned wraps still use
  `records/artifacts/rescue/tc7200-stage2-console-good.bin`
- wrapped inputs still support passthrough, forced rewrap, and fresh-header
  rewrap
- internal validation still emits `size_ok=True`

## Follow-On Checks

- syntax-check `scripts/wrapper.sh`
- verify raw payload wrapping still succeeds
- verify wrapped-source passthrough and both rewrap paths still succeed
- verify `scripts/tcbuilder.sh` fails with the migration hint
