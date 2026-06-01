# Technicolor TC7200.U / BCM3383 OpenWrt Research

This repository preserves TC7200.U OpenWrt bring-up notes, logs, captures,
snapshots, binary images, helper scripts, and OpenWrt patch copies. The normal
data bucket is `records/`; current code and docs stay outside it.

Start here:

- [Start Here](docs/START_HERE.md): current state and next action.
- [Status](docs/STATUS.md): working state, blockers, and recommended work.
- [Ethernet](docs/ETHERNET.md): GENET direction, failed paths, and next test.
- [CFE Image Format](docs/CFE_IMAGE_FORMAT.md): A825 wrapper and HCS notes.
- [Workflow](docs/WORKFLOW.md): helper command usage and aliases.
- [Paths](docs/PATHS.md): local paths used by scripts and notes.
- [Repo Map](docs/REPO_MAP.md): repository layout.
- [AI Helper](AI_HELPER.json): machine-readable repo guide for future agents.

Current constants:

- Required wrapper validation marker: `size_ok=True`
- Current known-good image:
  `records/artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`
- Original A825 baseline:
  `records/artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`
- Original A825 SHA256:
  `2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513`
- DO NOT DELETE OLD LOGS/MD FILES!

Top-level layout:

- `records/`: notes, logs, captures, generated output, snapshots, binaries,
  reverse-engineering output, network scans, and backups.
- `docs/`: curated status, workflow, path, and topic docs.
- `patches/`: OpenWrt patch copies and disabled patch history.
- `scripts/`: helper script and host/serial command snippets.
- `tools/`: standalone analysis tools.
