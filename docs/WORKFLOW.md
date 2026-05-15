# TC7200.U Workflow

## Safe flow

```text
build OpenWrt -> wrap initramfs -> verify size_ok=True -> TFTP fixed filename
```

## Test result rule

Worthy test results must be committed and pushed to git after capture. A result is worthy when it changes the known state, confirms or disproves a hypothesis, affects the next DTS/kernel/package step, documents a boot/TFTP failure or success, captures a new serial-log finding, or prevents repeating the same test. Trivial repeats that add no new information do not need a separate commit.

## Main helper commands

```sh
cd ~/tc7200u-research
scripts/tc7200u paths
scripts/tc7200u status
scripts/tc7200u wrap
scripts/tc7200u state
```

`wrap` is the normal safe build/wrap/verify flow. It writes the active CFE/TFTP
image to:

```text
/mnt/c/tftp/openwrt-ps-irqfallback.bin
```

`check`, `verify`, and `build` are kept as compatibility subcommands, but they
currently run the same safe flow as `wrap`. Normal usage should call `tcwrap`.

Generated manifests and state captures go to:

```text
research/notes/generated/
```

The output directory can be overridden:

```sh
RESEARCH_NOTES_DIR=/tmp/tc7200u-notes scripts/tc7200u state
```

## Shell aliases

Interactive WSL sessions should use these aliases:

```sh
alias tc='~/tc7200u-research/scripts/tc7200u'
alias tcwrap='~/tc7200u-research/scripts/tc7200u wrap'
alias tcstate='~/tc7200u-research/scripts/tc7200u state'
alias tcstatus='~/tc7200u-research/scripts/tc7200u status'
alias tcresearch='cd ~/tc7200u-research'
alias tcopenwrt='cd ~/src/openwrt'
alias cfe-tftp='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\\tftp\\start-cfe-tftp-77.ps1'
alias cte-tftp='cfe-tftp'
```

Common resume commands:

```sh
tcresearch
tcstatus
tcwrap
cfe-tftp
tcstate
```

## Manual build and wrap

```sh
tcresearch
tcwrap
cfe-tftp
tcstate
```

Required success marker:

```text
size_ok=True
```

## Safe TFTP file

```text
/mnt/c/tftp/openwrt-ps-irqfallback.bin
```

Do not rename:

```text
openwrt-ps-irqfallback.bin
```

Do not flash. RAM boot only.
