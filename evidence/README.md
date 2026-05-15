# Evidence

This directory stores raw evidence that should remain close to its original
form.

## Layout

- `serial/`: serial boot logs, picocom captures, and runtime collection logs.
- `cfe/`: CFE filename, HCS failure, and recovery notes.
- `network-scans/`: LAN, modem, and CFE/TFTP network scan evidence.
- `snapshots/`: DTS, config, and OpenWrt source snapshots.
- `backups/`: backups made before OpenWrt image makefile edits.

## Current snapshot highlights

- `evidence/snapshots/current-openwrt/bcm3383-technicolor-tc7200u-known-good-20260515-125821.dts`
- `evidence/snapshots/current-openwrt/bcm3383-technicolor-tc7200u.dts`
- `evidence/snapshots/current-openwrt/bcm3384_viper.dtsi`
- `evidence/snapshots/current-openwrt/kernel-config-6.12.87.txt`

Keep new serial and CFE logs here unless a helper script writes a generated
summary to `research/notes/generated/`.
