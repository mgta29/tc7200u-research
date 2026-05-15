# Evidence

This directory stores raw evidence that should remain close to its original
form.

## Layout

- `serial/`: serial boot logs and runtime collection logs.
- `cfe/`: CFE filename, HCS failure, and recovery notes.
- `snapshots/`: DTS, config, and OpenWrt source snapshots.
- `backups/`: backups made before OpenWrt image makefile edits.

## Old path map

| Old path | New path |
|---|---|
| `logs/serial-*` | `evidence/serial/` |
| `logs/2026-05-14-cfe-forced-filename.txt` | `evidence/cfe/` |
| `logs/2026-05-14-hcsfail-5697264.txt` | `evidence/cfe/` |
| `logs/2026-05-14-image-recovery.txt` | `evidence/cfe/` |
| `snapshots/` | `evidence/snapshots/` |
| `artifacts/current-openwrt/` | `evidence/snapshots/current-openwrt/` |
| `backup/openwrt-image-mk-backups/` | `evidence/backups/openwrt-image-mk-backups/` |

Keep new serial and CFE logs here unless a helper script writes a generated
summary to `research/notes/generated/`.
