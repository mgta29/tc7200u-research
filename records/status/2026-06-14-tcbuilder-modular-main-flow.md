# 2026-06-14 tcbuilder Modular Main Flow

Changed `scripts/tcbuilder.sh` from a large top-level execution block into a
named `main` flow with explicit setup and dispatch stages.

What changed:
- Added `parse_cli_args` so mode parsing, global option parsing, and post-`--`
  passthrough arguments are handled in one place.
- Added runtime setup helpers for normalization, validation, output-name
  resolution, and path/directory preparation.
- Replaced the bottom `if`/`else` execution chain with `run_mode_dispatch`,
  `run_auto_mode`, and smaller helpers for source-image preparation, OpenWrt
  build preparation, wrapping, and verification.
- Removed the duplicated A825 payload-strip logic by centralizing it in
  `strip_programstore_payload`.

Verification:
- `bash -n scripts/tcbuilder.sh`
- `./scripts/tcbuilder.sh selftest`
- `./scripts/tcbuilder.sh paths`
- `./scripts/tcbuilder.sh check-gates -- --help`

Notes:
- CLI mode names and existing helper behavior were kept intact.
- No old logs were edited.
