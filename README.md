# Technicolor TC7200.U / BCM3383 OpenWrt Research

This repository preserves TC7200.U OpenWrt bring-up notes, logs, captures,
snapshots, binary images, reverse output, patch copies, and the current A825
wrapper workflow.

Start here:

- [Start Here](docs/START_HERE.md): current state and immediate resume steps.
- [Status](docs/STATUS.md): working state, blockers, and recommended work.
- [Ethernet](docs/ETHERNET.md): GENET direction, failed paths, and next test.
- [CFE Image Format](docs/CFE_IMAGE_FORMAT.md): A825 wrapper and HCS notes.
- [Workflow](docs/WORKFLOW.md): wrapper-only command flow.
- [Paths](docs/PATHS.md): local paths used by the repo and wrapper.
- [Repo Map](docs/REPO_MAP.md): repository layout.
- [AI Helper](AI_HELPER.json): machine-readable repo guide for future agents.

Current wrapper surface:

- Supported command: `./scripts/wrapper.sh`
- Removed command: `./scripts/tcbuilder.sh` now fails with a migration hint.
- Required wrapper validation marker: `size_ok=True`
- Default no-template load address: `0x82000000`
- Canonical preserve-from template:
  `records/artifacts/rescue/tc7200-stage2-console-good.bin`

Known-good images:

- Current known-good image:
  `records/artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`
- Canonical A825 template:
  `records/artifacts/rescue/tc7200-stage2-console-good.bin`
- Original A825 baseline:
  `records/artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`
- DO NOT DELETE OLD LOGS OR HISTORICAL NOTES.

Top-level layout:

- `records/`: research notes, logs, captures, generated output, snapshots,
  binaries, reverse output, network scans, and backups.
- `docs/`: curated status, workflow, path, and topic docs.
- `patches/`: OpenWrt patch copies, disabled patch history, and current
  DTS/config snapshots.
- `scripts/`: `wrapper.sh`, the `tcbuilder.sh` migration stub, and
  `wsl-safe.ps1`.
- `reverse/`: live Ghidra workspace kept outside `records/`.

Current layout guardrail:

- `records/notes/` is a wrong legacy path and should not receive new files.
