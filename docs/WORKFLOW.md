# TC7200.U Wrapper Workflow

## Normal Flow

```text
build OpenWrt manually -> run ./scripts/programstore.sh -> confirm size_ok=True -> serve the output file from C:\tftp
```

The only supported operational command is:

```sh
./scripts/programstore.sh
```

`tcbuilder` is retired. `./scripts/tcbuilder.sh` remains only as a failing
migration stub and does not redirect old modes.

## Canonical Raw-Payload Wrap

Use the current known-good template policy when wrapping a fresh raw initramfs:

```sh
./scripts/programstore.sh \
  --input ~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin \
  --output /mnt/c/tftp/openwrt-ps-irqfallback.bin \
  --filename openwrt-initramfs.bin \
  --preserve-from ./records/artifacts/rescue/tc7200-stage2-console-good.bin \
  --fresh-header
```

That keeps the template-aligned load address while regenerating the live header
metadata for the new payload.

## Canonical No-Template Wrap

When no template is supplied, the wrapper uses the canonical default load
address directly:

```sh
./scripts/programstore.sh \
  --input ~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin \
  --output /mnt/c/tftp/openwrt-ps-irqfallback.bin \
  --filename openwrt-initramfs.bin
```

Default no-template policy:

- load address: `0x82000000`
- signature: `0xa825`
- internal header filename: `openwrt-initramfs.bin`

## Wrapped-Source Handling

Existing wrapped images are passed through byte-for-byte unless a rewrap mode is
explicitly requested.

Passthrough existing wrapped image:

```sh
./scripts/programstore.sh \
  --input ./records/artifacts/rescue/tc7200-stage2-console-good.bin \
  --output ./records/artifacts/test-images/tc7200-stage2-console-good-copy.bin
```

Force a rewrap that preserves the source ProgramStore metadata:

```sh
./scripts/programstore.sh \
  --input ./records/artifacts/rescue/tc7200-stage2-console-good.bin \
  --output ./records/artifacts/test-images/tc7200-stage2-console-good-rewrap.bin \
  --filename openwrt-initramfs.bin \
  --force-rewrap-source
```

Force a fresh-header rewrap from an already wrapped source:

```sh
./scripts/programstore.sh \
  --input ./records/artifacts/rescue/tc7200-stage2-console-good.bin \
  --output ./records/artifacts/test-images/tc7200-stage2-console-good-fresh.bin \
  --filename openwrt-initramfs.bin \
  --fresh-header
```

## Validation Behavior

There is no public `verify` or `inspect` command anymore. The wrapper runs the
internal A825 verification pass automatically and writes logs under:

```text
records/logs/builds/
```

Required marker:

```text
size_ok=True
```

## PowerShell To WSL

Use the WSL-safe helper when launching from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File \\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\wsl-safe.ps1 -Command "cd ~/tc7200u-research && ./scripts/programstore.sh --help"
```

## Active TFTP Path

```text
/mnt/c/tftp/openwrt-ps-irqfallback.bin
```

