# 2026-05-31 Helper Provenance Update

## Current State

The helper workflow is now consolidated into one executable:

```text
scripts/tc7200u-auto-build-install-wrap.sh
```

Older split launchers and helper scripts were removed. Use aliases from
`docs/WORKFLOW.md`.

## Current Behavior

- `tc wrap`, `tc check`, `tc verify`, and `tc build` run the build/wrap/verify
  path.
- `tc state` captures image, build, and repo state.
- `tc check-gates` checks a serial log and can save a report.
- `tc ensure-packages` applies the selected package profile.
- `tc serial-console` starts picocom logging.
- `tc reverse-stage1` extracts and inspects a wrapped ProgramStore image.
- Build and helper logs default to `records/logs/builds/`.
- Generated manifests and state captures default to `records/generated/`.

## Validation

- `bash -n scripts/tc7200u-auto-build-install-wrap.sh`
- `scripts/tc7200u-auto-build-install-wrap.sh help`
- `scripts/tc7200u-auto-build-install-wrap.sh paths`
- `scripts/tc7200u-auto-build-install-wrap.sh selftest`

## Result

The build process is traceable run-by-run: what was built, how it was built,
which image was wrapped, and which output path was selected.
