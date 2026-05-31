# 2026-05-31 Script Wrapper Provenance Update

## Scope
- Unified launcher behavior so `./tc7200` and `./tc7200u` both support `auto` mode routing.
- Added compatibility launcher `scripts/tc7200` forwarding to `scripts/tc7200u`.
- Extended `tc7200u-auto-build-install-wrap.sh` with per-run provenance logging under `research/builds`.
- Kept slow serial send support in `tc7200u-serial-console.sh` (`--send-cmd` with configurable char delay).
- Kept gate checker report persistence in `tc7200u-check-gates.sh`.

## Key Changes
- `scripts/tc7200u`
  - Added `auto` command alias.
  - Added `check-gates` command routing via wrapper mode.
  - Help output now lists `auto` and `check-gates`.
- `scripts/tc7200`
  - New compatibility shim:
    - `exec "$SCRIPT_DIR/tc7200u" "$@"`
- `scripts/tc7200u-auto-build-install-wrap.sh`
  - Build logs default to `research/builds`.
  - New run report file:
    - `research/builds/<timestamp>-build-provenance.log`
  - Report now captures:
    - active OpenWrt target lines from `.config` (BMIPS vs MEDIATEK proof)
    - discovered initramfs candidates under `bin/targets`
    - build decision (`none/install/compile/full`) and reason
    - exact command lines executed, per-command log paths, and exit codes
    - output hashes and final TFTP request/served names
  - Per-command logs include `meta` header (`timestamp`, `cwd`, `command`) and `exit` footer.
- `scripts/tc7200u-serial-console.sh`
  - Uses slow send command with configurable char delay for more reliable `picocom` transfer.
- `scripts/tc7200u-check-gates.sh`
  - Saves detailed gate reports to `research/builds` and includes runtime/build marker sections.

## Validation Performed
- `bash -n` passed for:
  - `scripts/tc7200u-auto-build-install-wrap.sh`
  - `scripts/tc7200u`
  - `scripts/tc7200`
- Command routing verified:
  - `./tc7200 help` shows `auto`.
  - `./tc7200 auto --mode paths` resolves expected paths.
- Provenance report verified:
  - Contains `CONFIG_TARGET_bmips*` lines.
  - Contains mediatek initramfs candidates listing for mismatch detection.
  - Contains `selected_action`, `why=...`, `command=...`, `exit_code=...`.

## Result
- Build process is now traceable run-by-run (what was built, how it was built, and why that path was selected), reducing risk of accidentally wrapping non-BMIPS images.
