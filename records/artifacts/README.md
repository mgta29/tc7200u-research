# Artifacts

Binary images are grouped by use and result. Do not infer that a file should be
served by CFE just because it exists in this repository.

## Rescue

`rescue/` contains images that reached OpenWrt userspace and are worth
preserving as baselines:

- `openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`
- `openwrt-ps-irqfallback-GOOD-5696426.bin`
- `openwrt-ps-irqfallback-GOOD-5696426.sha256`

Current known-good image:

- Path: `records/artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`
- Size: `5097194` bytes
- SHA256: `14b05d771147ab37c388894cd5a66fc2bed230176068902d4444ce29ef1fb8ae`

Original A825 baseline:

- Path: `records/artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`
- Size: `5696426` bytes
- SHA256: `2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513`

## Test Images

`test-images/` contains RAM-boot experiment images retained for comparison.

## Invalid Comparison Images

`invalid/` contains images known to fail validation or useful only for byte
comparison:

- HCS-failing images.
- Raw initramfs images without the correct A825 Program Header.
- 12-byte loader-header images.

Active CFE/TFTP output remains:

```text
/mnt/c/tftp/openwrt-ps-irqfallback.bin
```
