# TC7200.U CFE Image Format Notes

## Known CFE network facts

- Modem/CFE: `192.168.77.1`
- TFTP server/PC: `192.168.77.2`
- CFE-requested filename: `openwrt-ps-irqfallback.bin`
- Active TFTP path: `/mnt/c/tftp/openwrt-ps-irqfallback.bin`

Do not rename the file inside CFE. Serve the filename CFE asks for.

## A825 ProgramStore wrapper

The working TC7200U wrapper writes a 92-byte A825 ProgramStore header before the
OpenWrt initramfs payload.

Known fields:

- signature/PID: `a825`
- payload load address: `0x82000000`
- internal header filename: `openwrt-initramfs.bin`
- known-good total received size: `5696426` bytes

Scripts:

- `scripts/tc7200u-a825-wrap.py`
- `scripts/tc7200u-verify-a825-image.py`
- `scripts/tc7200u-wrap-current-openwrt.sh`

Generated wrap manifests are written to:

```text
research/notes/generated/
```

Override:

```sh
RESEARCH_NOTES_DIR=/path/to/notes scripts/tc7200u-wrap-current-openwrt.sh
```

## Known-good image

```text
artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin
```

SHA256:

```text
2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513
```

Result:

- HCS passed.
- CFE executed Image 4.
- OpenWrt booted to userspace.

## Invalid image classes

Stored under `artifacts/invalid/`:

- HCS-failing wrapped images.
- Raw initramfs images without the A825 Program Header.
- 12-byte loader-header images that are not valid TC7200U CFE images.

These are comparison artifacts only. Do not TFTP them as the active rescue path.

## Evidence

Useful notes:

- `research/notes/image-format/2026-05-14-cfe-header-analysis.txt`
- `research/notes/image-format/2026-05-14-hcsfail-vs-good-header-cmp.txt`
- `research/notes/image-format/2026-05-14-known-good-image.json`
- `research/notes/image-format/2026-05-14-openwrt-wrapper-search.txt`
- `research/notes/runtime-probes/2026-05-14-tftp-hcs44ca-image-manifest.md`

Useful logs:

- `evidence/cfe/2026-05-14-cfe-forced-filename.txt`
- `evidence/cfe/2026-05-14-hcsfail-5697264.txt`
- `evidence/cfe/2026-05-14-image-recovery.txt`
