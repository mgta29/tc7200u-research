# TC7200.U CFE Image Format Notes

## Known CFE Network Facts

- Modem/CFE: `192.168.77.1`
- TFTP server/PC: `192.168.77.2`
- CFE-requested filename: `openwrt-ps-irqfallback.bin`
- Active TFTP path: `/mnt/c/tftp/openwrt-ps-irqfallback.bin`

Serve the filename CFE asks for.

## A825 ProgramStore Wrapper

The working TC7200U wrapper writes a 92-byte A825 ProgramStore header before the
OpenWrt initramfs payload.

Known fields:

- signature/PID: `a825`
- payload load address: `0x82000000`
- internal header filename: `openwrt-initramfs.bin`
- known-good total received size: `5696426` bytes

Script:

- `scripts/tc7200u-auto-build-install-wrap.sh`

Generated wrap manifests are written to:

```text
records/generated/
```

Override:

```sh
RESEARCH_NOTES_DIR=/path/to/generated tc wrap
```

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
- Raw initramfs images without the A825 Program Header.
- 12-byte loader-header images.

These are comparison artifacts only.

## Useful Records

Notes:

- `records/notes/image-format/2026-05-14-cfe-header-analysis.txt`
- `records/notes/image-format/2026-05-14-hcsfail-vs-good-header-cmp.txt`
- `records/notes/image-format/2026-05-14-known-good-image.json`
- `records/notes/image-format/2026-05-14-openwrt-wrapper-search.txt`
- `records/notes/runtime-probes/2026-05-14-tftp-hcs44ca-image-manifest.md`

Logs:

- `records/logs/cfe/2026-05-14-cfe-forced-filename.txt`
- `records/logs/cfe/2026-05-14-hcsfail-5697264.txt`
- `records/logs/cfe/2026-05-14-image-recovery.txt`
