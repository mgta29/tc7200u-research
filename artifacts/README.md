# Artifacts

Binary images are grouped by safety status. Do not infer that a file is safe
because it exists in this repository.

## Rescue

`artifacts/rescue/` contains RAM boot images that are known to reach OpenWrt
userspace and are worth preserving as rescue baselines:

- `openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`
- `openwrt-ps-irqfallback-GOOD-5696426.bin`
- `openwrt-ps-irqfallback-GOOD-5696426.sha256`

Current known-good RAM boot image:

- Path: `artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`
- Size: `5097194` bytes
- SHA256: `14b05d771147ab37c388894cd5a66fc2bed230176068902d4444ce29ef1fb8ae`

Original A825 rescue baseline:

- Path: `artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`
- Size: `5696426` bytes
- SHA256: `2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513`

These images booted OpenWrt to userspace. Preserve them and do not overwrite
them with test builds.

## Test images

`artifacts/test-images/` contains RAM-boot experiment images retained for
comparison. These are not rescue images.

## Invalid comparison images

`artifacts/invalid/` contains images known to be invalid, risky, or useful only
for byte comparison:

- HCS-failing images.
- Raw initramfs images without the correct A825 Program Header.
- 12-byte loader-header images.

Do not serve these as `/mnt/c/tftp/openwrt-ps-irqfallback.bin`.
