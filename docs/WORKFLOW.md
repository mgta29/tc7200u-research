# TC7200.U Workflow

## Normal Flow

```text
build OpenWrt -> wrap initramfs -> verify size_ok=True -> serve requested CFE filename
```

The canonical helper entrypoint is `tcbuild`; in a TTY with no explicit mode it
opens the interactive menu. It resolves to:

```sh
~/tc7200u-research/scripts/tcbuilder.sh
```

Main modes:

```sh
tcbuild
tc paths
tc status
tc wrap
tc check
tc verify
tc state
tc check-gates --check-log records/logs/serial/picocom-example.log
tc ensure-packages
tc candidate --label candidate1-control-plus-trace
tc serial-console
tc reverse-stage1 --source-image records/artifacts/rescue/tc7200-stage2-console-good.bin
tc selftest
```

The `auto` path and the `wrap`, `check`, `verify`, and `build` modes all run
the same build/wrap/verify path. Launch `tcbuild` in a terminal to open the
menu, then choose `1` for the auto path. The default package profile is
`fastboot`. To keep the larger diagnostics profile:

```sh
TC7200U_PACKAGE_PROFILE=debug tcbuild auto
```

To fold the manual candidate wrapper into the helper, use `candidate` with a
label. It writes the current stamp file, exports the current OpenWrt diff to a
candidate patch under `patches/`, runs the auto path, then saves the SHA256 and
wrapped-image `file` reports under `records/logs/builds/`:

```sh
TC7200U_PACKAGE_PROFILE=debug tcbuild candidate --label candidate1-control-plus-trace
```

When changed or new BMIPS kernel patch files are detected under
`target/linux/bmips/patches-*`, `tcbuilder.sh` now runs a pre-check before the
build phase to catch patch apply/syntax issues earlier. Skip this only when
needed:

```sh
tcbuild auto --skip-precheck
```

For OpenWrt auto-wrap runs (no `--source-image`), the helper now defaults to
the canonical preserve-from template and fresh-header mode. That keeps the
template’s encoded load address but regenerates the ProgramStore build time and
helper-managed filename instead of inheriting stale metadata:

- `--preserve-from records/artifacts/rescue/tc7200-stage2-console-good.bin`
- preserved load address: `0x82000000`
- effective default: `--fresh-header`

Use `--no-fresh-header` or `FRESH_HEADER=0` only when intentionally testing the
old behavior that preserves the template header metadata exactly. Override the
load address only when intentionally testing a non-canonical boot format.

To regenerate the ProgramStore header for explicit preserve-from or
wrapped-source flows, use `--fresh-header`. This keeps the helper-managed
filename and updates the build time. If you also want the control/revision/CRC
fields to change from their defaults, pass them explicitly:

```sh
tcbuild auto --fresh-header
tcbuild auto --fresh-header --control 0x0001 --major 0x0101 --minor 0x0500
tcbuild auto --no-fresh-header
```

Generated manifests, state captures, hashes, and measurements go to:

```text
records/generated/
```

The output directory can be overridden:

```sh
RESEARCH_NOTES_DIR=/tmp/tc7200u-generated tc state
```

Build/install/wrap logs go to:

```text
records/logs/builds/
```

## Shell Aliases

Interactive WSL sessions should use these aliases, with `tcbuild` as the canonical
entrypoint:

```sh
alias tcbuild='~/tc7200u-research/scripts/tcbuilder.sh'
alias tc='~/tc7200u-research/scripts/tcbuilder.sh'
alias tcserial='~/tc7200u-research/scripts/tcbuilder.sh serial-console'
alias tcwrap='~/tc7200u-research/scripts/tcbuilder.sh wrap'
alias tccheck='~/tc7200u-research/scripts/tcbuilder.sh check'
alias tcverify='~/tc7200u-research/scripts/tcbuilder.sh verify'
alias tcstate='~/tc7200u-research/scripts/tcbuilder.sh state'
alias tcstatus='~/tc7200u-research/scripts/tcbuilder.sh status'
alias tcresearch='cd ~/tc7200u-research'
alias tcopenwrt='cd ~/src/openwrt'
alias cfe-tftp='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\\tftp\\start-cfe-tftp-77.ps1'
alias cte-tftp='cfe-tftp'
```

## PowerShell to WSL (No `U:\...` Translation Warning)

When launching WSL from PowerShell while the current directory is `U:\...`,
WSL can print:

```text
wsl: Failed to translate 'U:\...'
```

Use the helper below so WSL always starts from a known Linux path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File \\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\wsl-safe.ps1 -Command "cd ~/tc7200u-research && ./scripts/tcbuilder.sh paths"
```

Or open an interactive WSL shell cleanly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File \\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\wsl-safe.ps1
```

Common resume commands:

```sh
tcresearch
tcstatus
tcbuild
cfe-tftp
tcstate
```

Required wrapper marker:

```text
size_ok=True
```

Active CFE/TFTP path:

```text
/mnt/c/tftp/openwrt-(version number in hex).bin
```

CFE-requested filename:

```text
openwrt-(version number in hex).bin
```

## Git Rule

After a useful research run, inspect `git status --short --branch`, add the
new records and docs, run the relevant checks, and create a local commit.
Push only when explicitly requested.
