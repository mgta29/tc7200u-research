# TC7200U Records

`records/` is the single bucket for research data. Keep code, curated docs,
patches, and helper snippets at the repo top level.

## Canonical Layout

- `records/bring-up/`: bring-up, console, and boot baseline notes.
- `records/ethernet/`: Ethernet-specific investigation notes.
- `records/flash/`: flash map and load-address notes.
- `records/image-format/`: wrapper, header, and image-format notes.
- `records/runtime-probes/`: runtime experiment notes and probe analysis.
- `records/source-research/`: external source and similar-platform research.
- `records/status/`: status, provenance, and repo-organization notes.
- `records/reverse/`: reverse-engineering notes, labels, scripts, and extracted
  ProgramStore material.
- `records/logs/serial/`: picocom, UART, boot, and runtime serial logs.
- `records/logs/cfe/`: CFE, HCS, and recovery logs.
- `records/logs/devmen/`: raw devmem/devmen captures kept under the current
  directory name.
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
- `records/notes/`: wrong legacy path still present in the worktree; do not
  add new files here.

## Write Rules

- Put new Markdown research notes in the matching top-level topic directory under
  `records/`.
- Do not add new records under `records/notes/`.
- Put new serial captures in `records/logs/serial/`.
- Put new host TFTP and packet proof runs in
  `records/logs/tftp/<YYYY-MM-DD-version>/`.
- Put helper-generated manifests and state captures in `records/generated/`.
- Put build/install/wrap/verify logs in `records/logs/builds/`.
- Put current source snapshots in `records/snapshots/`.
- Put reverse-engineering output in `records/reverse/`.
- Keep binary image contents unchanged when moving or indexing files.
