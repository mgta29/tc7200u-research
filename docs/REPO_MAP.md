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
- `scripts/tc7200u-a825-wrap.py`: A825 header writer.
- `scripts/tc7200u-verify-a825-image.py`: A825 image verifier.
- `scripts/tc7200u-capture-current-state.sh`: state capture helper.
- `scripts/tc7200u-ensure-debug-packages.sh`: debug package config helper.
- `tools/serial-decompress-timer.py`: interactive serial timing logger.

## Normal aliases

- `tcresearch`: enter the research repo.
- `tcstatus`: show git and helper status.
- `tcwrap`: run the safe build/wrap/verify flow.
- `cfe-tftp`: start the one-shot CFE TFTP server.
- `tcstate`: capture current build/image state.

`tc check`, `tc verify`, and `tc build` remain compatibility subcommands, but
they currently run the same safe flow as `tc wrap`. Use `tc rules` directly if
the RAM-boot rules need to be printed.

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
