# TC7200.U Workflow

## Safe flow

```text
build OpenWrt -> wrap initramfs -> verify size_ok=True -> TFTP fixed filename
```

## Main helper commands

```sh
cd ~/tc7200u-research
scripts/tc7200u paths
scripts/tc7200u wrap
scripts/tc7200u check
scripts/tc7200u verify
scripts/tc7200u state
scripts/tc7200u rules
```

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
alias tccheck='~/tc7200u-research/scripts/tc7200u check'
alias tcverify='~/tc7200u-research/scripts/tc7200u verify'
alias tcstate='~/tc7200u-research/scripts/tc7200u state'
alias tcstatus='~/tc7200u-research/scripts/tc7200u status'
alias tcrules='~/tc7200u-research/scripts/tc7200u rules'
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
tccheck
tcverify
tcstate
tcrules
cfe-tftp
```

## Manual build and wrap

```sh
cd ~/src/openwrt
make target/linux/compile V=s
make target/linux/install V=s

cd ~/tc7200u-research
scripts/tc7200u-wrap-current-openwrt.sh
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
