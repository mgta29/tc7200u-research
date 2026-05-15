# Artifacts

Binary images are grouped by safety status. Do not infer that a file is safe
because it exists in this repository.

## Rescue

`artifacts/rescue/` contains the known-good RAM boot rescue baseline:

- `openwrt-ps-irqfallback-GOOD-5696426.bin`
- `openwrt-ps-irqfallback-GOOD-5696426.sha256`

This image booted OpenWrt to userspace after passing CFE HCS validation. Preserve
it and do not overwrite it with test builds.

Old path:

```text
artifacts/openwrt-ps-irqfallback-GOOD-5696426.bin
```

New path:

```text
artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin
```

## Test images

`artifacts/test-images/` contains RAM-boot experiment images retained for
comparison. These are not rescue images.

Moved here from old top-level `artifacts/*.bin` test names, including MMIO,
CMIPS, LZMA, and BRCM variants.

## Invalid comparison images

`artifacts/invalid/` contains images known to be invalid, risky, or useful only
for byte comparison:

- HCS-failing images.
- Raw initramfs images without the correct A825 Program Header.
- 12-byte loader-header images.

Do not serve these as `/mnt/c/tftp/openwrt-ps-irqfallback.bin`.
