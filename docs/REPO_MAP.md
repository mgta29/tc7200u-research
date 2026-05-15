# TC7200.U Repo Map

## Curated docs

- `README.md`: start page.
- `docs/START_HERE.md`: current resume point.
- `docs/SAFETY.md`: no-flash and image safety rules.
- `docs/STATUS.md`: bring-up state and blockers.
- `docs/ETHERNET.md`: Ethernet findings and next diagnostic.
- `docs/CFE_IMAGE_FORMAT.md`: A825 wrapper and HCS evidence.
- `docs/PATHS.md`: local path map.
- `docs/WORKFLOW.md`: safe command flow.

## Active scripts

- `scripts/tc7200u`: master command dispatcher.
- `scripts/tc7200u-auto-build-install-wrap.sh`: build/install/wrap/check flow.
- `scripts/tc7200u-wrap-current-openwrt.sh`: wrap current OpenWrt initramfs.
- `scripts/tc7200u-a825-wrap.py`: A825 header writer.
- `scripts/tc7200u-verify-a825-image.py`: A825 image verifier.
- `scripts/tc7200u-capture-current-state.sh`: state capture helper.

## Obsolete scripts

- `scripts/obsolete/make_tc7200u_ps_brcm.py`: old experiment; wrong output filename.

## Organized evidence

- `artifacts/rescue/`: known-good rescue image and checksum.
- `artifacts/test-images/`: RAM-boot test images.
- `artifacts/invalid/`: failed or unsafe comparison images.
- `evidence/serial/`: serial boot logs.
- `evidence/cfe/`: CFE, recovery, and HCS logs.
- `evidence/network-scans/`: LAN, modem, and CFE/TFTP network scans.
- `evidence/snapshots/`: DTS/config/source snapshots.
- `research/notes/`: raw notes by topic.
- `patches/`: current, archived, and disabled OpenWrt patch copies.

## Important output

```text
/mnt/c/tftp/openwrt-ps-irqfallback.bin
```

Use only after:

```text
size_ok=True
```
