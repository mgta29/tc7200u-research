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
