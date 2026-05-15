# Technicolor TC7200.U / BCM3383 OpenWrt research

This repository preserves TC7200.U OpenWrt bring-up evidence, scripts, boot
artifacts, and notes. The current priority is fast, safe resumption of RAM boot
debugging.

Start here:

- [Start Here](docs/START_HERE.md): current state and next action.
- [Safety](docs/SAFETY.md): RAM boot, CFE/TFTP, and no-flash rules.
- [Status](docs/STATUS.md): working state, blockers, and recommended work.
- [Ethernet](docs/ETHERNET.md): GENET direction, failed paths, and next test.
- [CFE Image Format](docs/CFE_IMAGE_FORMAT.md): A825 wrapper and HCS notes.
- [Workflow](docs/WORKFLOW.md): build, wrap, verify, and TFTP checklist.
- [Paths](docs/PATHS.md): local paths used by scripts and notes.
- [Repo Map](docs/REPO_MAP.md): repository layout.

Hard safety facts:

- Active TFTP filename remains `/mnt/c/tftp/openwrt-ps-irqfallback.bin`.
- Current known-good RAM boot image is
  `artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin`.
- Original A825 rescue image is
  `artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin`.
- Original A825 rescue SHA256 is
  `2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513`.
- Only TFTP after the wrapper manifest says `size_ok=True`.
- RAM boot only. Do not flash.

Top-level layout:

- `artifacts/`: rescue image, test images, and invalid comparison images.
- `docs/`: curated status, safety, workflow, path, and topic docs.
- `evidence/`: serial logs, CFE logs, snapshots, and backups.
- `patches/`: OpenWrt patch copies and disabled patch history.
- `research/notes/`: raw notes grouped by topic.
- `scripts/`: local helper scripts for wrapping, verification, and state capture.
