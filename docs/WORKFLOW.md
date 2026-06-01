# TC7200.U Workflow

## Normal Flow

```text
build OpenWrt -> wrap initramfs -> verify size_ok=True -> serve requested CFE filename
```

The single active helper is:

```sh
~/tc7200u-research/scripts/tcbuilder.sh
```

Main modes:

```sh
tc paths
tc status
tc wrap
tc check
tc verify
tc state
tc check-gates --check-log records/logs/serial/picocom-example.log
tc ensure-packages
tc serial-console
tc reverse-stage1 --source-image records/artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin
tc selftest
```

`wrap`, `check`, `verify`, and `build` all run the build/wrap/verify path. The
default package profile is `fastboot`. To keep the larger diagnostics profile:

```sh
TC7200U_PACKAGE_PROFILE=debug tcwrap
```

When changed or new BMIPS kernel patch files are detected under
`target/linux/bmips/patches-*`, `tcbuilder.sh` now runs a pre-check before the
build phase to catch patch apply/syntax issues earlier. Skip this only when
needed:

```sh
tc wrap --skip-precheck
```

For OpenWrt auto-wrap runs (no `--source-image`), the helper now defaults to:

- `--preserve-from records/artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`
- `--load-addr 0x80004000`

Override the load address only when intentionally testing another boot format:

```sh
tc wrap --load-addr 0x82000000
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

Interactive WSL sessions should use these aliases:

```sh
alias tc='~/tc7200u-research/scripts/tcbuilder.sh'
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
tcwrap
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
