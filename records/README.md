# TC7200U Records

`records/` is the single bucket for research data. Keep code, curated docs,
patches, and helper snippets at the repo top level.

## Layout

- `records/notes/`: human research notes by topic.
- `records/logs/serial/`: picocom, UART, boot, and runtime serial logs.
- `records/logs/cfe/`: CFE, HCS, and recovery logs.
- `records/logs/tftp/<YYYY-MM-DD-version>/`: host TFTP, packet, route, neighbor, link,
  and ping proof captures.
- `records/logs/builds/`: OpenWrt build/install/wrap/verify logs.
- `records/generated/`: manifests, state captures, hashes, generated measurements, and
  deep-mine output.
- `records/snapshots/`: DTS, config, and source snapshots.
- `records/network-scans/`: LAN, modem, and CFE/TFTP network scans.
- `records/backups/`: pre-edit backups.
- `records/artifacts/rescue/`: known-good images and checksums.
- `records/artifacts/test-images/`: RAM-boot experiment images.
- `records/artifacts/invalid/`: failed or comparison-only images.
- `records/reverse/`: reverse-engineering projects, labels, scripts, and extracted
  ProgramStore material.

## Write Rules

- Put new serial captures in `records/logs/serial/`.
- Put new host TFTP and packet proof runs in
  `records/logs/tftp/<YYYY-MM-DD-version>/`.
- Put helper-generated manifests and state captures in `records/generated/`.
- Put build/install/wrap/verify logs in `records/logs/builds/`.
- Put current source snapshots in `records/snapshots/`.
- Put reverse-engineering output in `records/reverse/`.
- Keep binary image contents unchanged when moving or indexing files.
