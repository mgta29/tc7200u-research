# TC7200.U CFE Image Format Notes

## Known CFE Network Facts

- Modem/CFE: `192.168.77.1`
- TFTP server/PC: `192.168.77.2`
- CFE-requested filename: `openwrt-(version number in hex).bin`
- Active TFTP path: `/mnt/c/tftp/openwrt-ps-irqfallback.bin`

Serve the filename CFE asks for.

## A825 ProgramStore Wrapper

The working TC7200U wrapper writes a 92-byte A825 ProgramStore header before the
OpenWrt initramfs payload.

Known fields:

- signature/PID: `a825`
- default no-template load address: `0x82000000`
- internal header filename default: `openwrt-initramfs.bin`
- known-good total received size: `6417987` bytes

Canonical template:

- `records/artifacts/rescue/tc7200-stage2-console-good.bin`
- SHA256: `a2b9fa164d092387dc0382698cbdff940bb97cce6c41a029ac70c1b357497c4b`

Legacy A825 rescue baseline (kept for comparison):

- `records/artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`
- payload load address: `0x82000000`

## Supported Script

- Supported command: `./scripts/wrapper.sh`
- Removed command: `./scripts/tcbuilder.sh` now exits non-zero with a migration
  hint.

Recommended template-aligned invocation:

```sh
./scripts/wrapper.sh \
  --input ~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin \
  --output /mnt/c/tftp/openwrt-ps-irqfallback.bin \
  --filename openwrt-initramfs.bin \
  --preserve-from ./records/artifacts/rescue/tc7200-stage2-console-good.bin \
  --fresh-header
```

No-template invocation:

```sh
./scripts/wrapper.sh \
  --input ~/src/openwrt/bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin \
  --output /mnt/c/tftp/openwrt-ps-irqfallback.bin \
  --filename openwrt-initramfs.bin
```

There is no public `verify` command anymore. The wrapper runs the internal A825
verification pass automatically and emits `size_ok=True` on success.

## Known-Good Images

Current known-good image:

```text
records/artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin
```

SHA256:

```text
14b05d771147ab37c388894cd5a66fc2bed230176068902d4444ce29ef1fb8ae
```

Original A825 baseline:

```text
records/artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin
```

SHA256:

```text
2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513
```

Result:

- HCS passed.
- CFE executed Image 4.
- OpenWrt booted to userspace.

## Invalid Image Classes

Stored under `records/artifacts/invalid/`:

- HCS-failing wrapped images.
- Raw initramfs images without the A825 ProgramStore header.
- 12-byte loader-header images.

These are comparison artifacts only.
