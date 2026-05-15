# Patches

This directory stores patch copies and OpenWrt state snapshots used during
bring-up.

## Layout

- `openwrt-bmips/`: BMIPS/OpenWrt patch copies.
- `disabled/`: disabled patch history.
- Top-level patch/config files: current working copies captured from OpenWrt.

## Old path map

| Old path | New path |
|---|---|
| `openwrt-patches/776-net-bgmac-platform-allow-bmips.patch` | `patches/openwrt-bmips/776-net-bgmac-platform-allow-bmips.patch` |
| `disabled-patches/openwrt-bmips/910-tc7200u-mmio-boot-log.patch.disabled` | `patches/disabled/openwrt-bmips/910-tc7200u-mmio-boot-log.patch.disabled` |

The live OpenWrt tree remains `~/src/openwrt`; these files are repo evidence and
working copies, not proof that the OpenWrt tree has been updated.
