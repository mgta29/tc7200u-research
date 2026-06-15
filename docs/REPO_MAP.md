# TC7200.U Repo Map

Repo root:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research`

## Current Canonical Tree

```text
\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research
├── AI_HELPER.json
├── README.md
├── docs/
│   ├── CFE_IMAGE_FORMAT.md
│   ├── ETHERNET.md
│   ├── MEMORY_MAP.md
│   ├── PATHS.md
│   ├── REPO_MAP.md
│   ├── START_HERE.md
│   ├── STATUS.md
│   └── WORKFLOW.md
├── patches/
│   ├── README.md
│   ├── disabled/
│   │   └── openwrt-bmips/
│   ├── openwrt-bmips/
│   │   └── experiments/
│   └── <current patch and config snapshots>
├── records/
│   ├── README.md
│   ├── artifacts/
│   ├── backups/
│   ├── bring-up/
│   ├── ethernet/
│   ├── flash/
│   ├── generated/
│   ├── image-format/
│   ├── logs/
│   │   ├── builds/
│   │   ├── cfe/
│   │   ├── devmen/
│   │   ├── serial/
│   │   └── tftp/
│   ├── network-scans/
│   ├── reverse/
│   ├── runtime-probes/
│   ├── snapshots/
│   ├── source-research/
│   └── status/
├── reverse/
│   └── d60242_ghidra/
└── scripts/
    ├── tcbuilder/
    ├── tcbuilder.sh
    └── wsl-safe.ps1
```

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

- `scripts/tcbuilder.sh`: helper entrypoint, head, and linker for build,
  wrap, verify, state capture, package profile setup, serial console logging,
  gate checks, and ProgramStore reverse inspection.
- `scripts/tcbuilder/`: sourced helper modules for shared utilities, CLI
  parsing, OpenWrt build logic, ProgramStore operations, mode handlers, and the
  auto build/wrap/verify flow.
- `scripts/wsl-safe.ps1`: WSL-safe PowerShell wrapper for host-side flows.

## Normal Aliases

- `tcbuild`: canonical helper entrypoint; opens the interactive menu in a TTY.
- `tcresearch`: enter the repo.
- `tcstatus`: show git and helper status.
- `tcwrap`: build/wrap/verify compatibility mode.
- `tccheck`: build/wrap/verify compatibility mode.
- `tcverify`: build/wrap/verify compatibility mode.
- `tcstate`: capture current build/image state.
- `cfe-tftp`: start the one-shot CFE TFTP server.
- `cte-tftp`: alias to `cfe-tftp`.

## Records Layout

- `records/bring-up/`: bring-up, console, and boot baseline notes.
- `records/ethernet/`: Ethernet-focused investigation notes.
- `records/flash/`: flash map and load-address notes.
- `records/image-format/`: wrapper, header, and image-format notes.
- `records/runtime-probes/`: runtime experiment notes and probe analysis.
- `records/source-research/`: external source and similar-platform research.
- `records/status/`: status, provenance, and repo-organization notes.
- `records/reverse/`: reverse-engineering notes, labels, scripts, and
  extracted ProgramStore material.
- `records/logs/serial/`: picocom, UART, boot, and runtime serial logs.
- `records/logs/cfe/`: CFE, HCS, and recovery logs.
- `records/logs/devmen/`: raw devmem/devmen capture logs kept under the
  current directory name.
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
- `records/notes/`: wrong legacy path still present in the worktree; do not
  add new files here.

## Reverse Workspace

- `reverse/d60242_ghidra/`: live Ghidra workspace kept outside `records/`.

## Patches

- `patches/README.md`: patch inventory and old-path map.
- `patches/bcm3383-technicolor-tc7200u.dts`: current live diagnostic DTS snapshot.
- `patches/bcm3384_viper.dtsi`: carried DTSI snapshot.
- `patches/config-6.12.current`: current OpenWrt config snapshot.
- `patches/openwrt-current-devmem-net-work.patch`: carried current OpenWrt
  patch snapshot.
- `patches/openwrt-tc7200u-current.patch`: carried TC7200U patch snapshot.
- `patches/openwrt-bmips/998-bmips-tc7200u-gmac-init.patch`: BCM3383 GMAC
  pinmux/clock/reset quirk.
- `patches/openwrt-bmips/`: BMIPS/OpenWrt patch copies.
- `patches/openwrt-bmips/experiments/`: historical experiment patch sets.
- `patches/disabled/`: disabled patch history.

## Important Output

```text
\\wsl.localhost\Ubuntu\mnt\c\tftp\openwrt-ps-irqfallback.bin
```

Required wrapper marker:

```text
size_ok=True
```
