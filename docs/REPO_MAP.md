# TC7200.U Repo Map

## Curated Docs

- `README.md`: start page.
- `AI_HELPER.json`: machine-readable repo guide.
- `docs/START_HERE.md`: current resume point.
- `docs/STATUS.md`: bring-up state and blockers.
- `docs/ETHERNET.md`: Ethernet findings and next diagnostic.
- `docs/MEMORY_MAP.md`: RAM/load addresses, MMIO bases, IRQ banks, and flash map notes.
- `docs/CFE_IMAGE_FORMAT.md`: A825 wrapper and HCS notes.
- `docs/PATHS.md`: local path map.
- `docs/WORKFLOW.md`: command flow and aliases.

## Active Helper

- `scripts/tc7200u-auto-build-install-wrap.sh`: single helper for build,
  wrap, verify, state capture, package profile setup, serial console logging,
  gate checks, and ProgramStore reverse inspection.

Supporting snippets:

- `scripts/tftp/`: host-side PowerShell snippets for TFTP, packet, route,
  neighbor, and link proof runs.
- `scripts/picocom-cmd/`: OpenWrt-side command batches sent through picocom.
- `tools/serial-decompress-timer.py`: standalone serial timing logger.

## Normal Aliases

- `tcresearch`: enter the repo.
- `tcstatus`: show git and helper status.
- `tcwrap`: build/wrap/verify.
- `tccheck`: build/wrap/verify compatibility mode.
- `tcverify`: build/wrap/verify compatibility mode.
- `tcstate`: capture current build/image state.
- `cfe-tftp`: start the one-shot CFE TFTP server.
- `cte-tftp`: alias to `cfe-tftp`.

## Records Layout

- `records/notes/`: human research notes by topic.
- `records/logs/serial/`: picocom, UART, boot, and runtime serial logs.
- `records/logs/cfe/`: CFE, HCS, and recovery logs.
- `records/logs/tftp/<YYYY-MM-DD-version>/`: host TFTP, packet, route,
  neighbor, link, and ping proof captures.
- `records/logs/builds/`: OpenWrt build/install/wrap/verify logs.
- `records/generated/`: manifests, state captures, hashes, generated
  measurements, and deep-mine output.
- `records/snapshots/`: DTS, config, and source snapshots.
- `records/network-scans/`: LAN, modem, and CFE/TFTP network scans.
- `records/backups/`: pre-edit backups.
- `records/artifacts/rescue/`: known-good images and checksums.
- `records/artifacts/test-images/`: RAM-boot experiment images.
- `records/artifacts/invalid/`: failed or comparison-only images.
- `records/reverse/`: reverse-engineering projects, labels, scripts, and
  extracted ProgramStore material.

## Patches

- `patches/bcm3383-technicolor-tc7200u.dts`: current live diagnostic DTS snapshot.
- `patches/openwrt-bmips/998-bmips-tc7200u-gmac-init.patch`: BCM3383 GMAC
  pinmux/clock/reset quirk.
- `patches/openwrt-bmips/experiments/`: historical experiment patch sets.

## Important Output

```text
/mnt/c/tftp/openwrt-ps-irqfallback.bin
```

Required wrapper marker:

```text
size_ok=True
```
