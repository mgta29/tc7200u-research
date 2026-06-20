# TC7200U OpenWrt ENET usable status

## Purpose

This is the maintained status companion to:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\important-openwrt-tc7200u-enet-usable-values.md`

Use the values note for carried MMIO bases, MDIO encodings, and OEM-derived compare constants.

Use this file for the current OpenWrt-facing bring-up status, proven runtime control baseline, active blocker, and development order.

## Current status as of 2026-06-20

The TC7200U OpenWrt port now has a fresh-tree userspace-console baseline again, and BCMGENET fixed-link probing reaches `eth0`, but Ethernet is still blocked before TDMA consumes TX descriptors.

The current ENET state should be read this way:

1. OpenWrt userspace console is proven on a fresh-tree control image.
2. BCMGENET binds at `0x12c00000` and creates `eth0`.
3. Fixed-link RGMII reports carrier.
4. Linux queues real TX descriptors.
5. TDMA does not consume them.
6. FPM runtime state is live.
7. The direct GENET/MBDMA compare registers still do not look OEM-like.
8. The first mapped kernel-side GMAC dump is not trustworthy enough yet to justify a TC7200U-specific write/init patch.

## Known-good OpenWrt control baseline

Current best OpenWrt control source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-17-fresh-openwrt-console-success.md`

What is already proven by that control pass:

- fresh OpenWrt tree plus fresh A825 wrapper reached interactive userspace console
- `Run /init as init process`
- `procd: - early -`
- `procd: - ubus -`
- `procd: - init -`
- kernel config proof included:
  - `CONFIG_DEVTMPFS=y`
  - `CONFIG_DEVTMPFS_MOUNT=y`
  - `CONFIG_BCM7120_L2_IRQ=y`
  - `CONFIG_TMPFS=y`
- runtime release proof recorded:
  - `Linux OpenWrt 6.12.93`
  - `OpenWrt SNAPSHOT r34962-d6f5c2685f`

Development meaning:

- the current ENET branch does not need more wrapper or console recovery work before the next Ethernet-focused pass
- use the June 17 fresh-tree console baseline as the OpenWrt-side control for ENET regression checks

## Current Ethernet progression

### 1. Pre-enable devmem baseline

Source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-devmem-fpm-genet-baseline.md`

High-value baseline facts:

- FPM space at `0x12200000` is readable and nonzero
- GENET/MBDMA compare points at `0x12c00000` family still read as `0x00000001`
- MDIO compare points at both buses also read as `0x0010` in that baseline

Development meaning:

- the hardware windows are not completely dead
- before Ethernet enablement, OpenWrt was not yet reproducing OEM-like GENET/MBDMA programming

### 2. First BCMGENET probe milestone

Source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-genet-fixedlink-probe-watchdog.md`

What is now proven:

- DTS `ethernet@12c00000` plus fixed-link is enough for Linux to bind BCMGENET
- `eth0` exists
- link comes up as `1Gbps/Full`
- IRQs `16` and `17` are allocated to `eth0`

What still fails there:

- `NETDEV WATCHDOG` fires on TX
- IRQ counts stay zero during the watchdog window
- `tx_packets = 10`
- `tx_errors = 8`
- `rx_packets = 0`

Development meaning:

- the failure is after probe and after link-up
- the problem is in the TX completion or TDMA or GENET-MBDMA-FPM integration layer, not in basic device creation

### 3. Current live runtime stop state

Sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-fpm-live-mbdma-unprogrammed.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-txdump-tdma-stuck.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-ctrlmap-debug-findings.md`

What the debug branch has proven:

- `XMITDESC` logs show real descriptors are queued
- FPM/profile register spaces are readable and active
- timeout dumps repeatedly show:
  - `tdma_ctrl=0x00003000`
  - `tdma_stat=0x00000800`
  - `hw_p=0`
  - `hw_c=14340`
  - `free_bds=0`
  - `clean=0`
  - `write=0`
- after timeout or reclaim, software ring counters become invalid, for example:
  - `prod=17920`
  - `free=65792`

Most important comparison result from the direct runtime dumps:

- FPM endpoint and token-like registers are live
- direct `devmem` reads still show the GENET/MBDMA compare set stuck at `0x00000001`
- the first mapped `998` kernel-side GMAC dump is not trustworthy because it reported pointer-shaped values such as repeated `0xb2c00000`

## Status-carry values worth checking during development

These are the current live status checkpoints worth re-reading during each narrow ENET pass.

### FPM side

Keep comparing:

- `0x12200040`
- `0x12200044`
- `0x12200200`
- `0x12200208`
- `0x12200210`
- `0x12200218`

Current status meaning:

- these locations are readable and live
- treat the endpoint values as runtime state, not as fixed constants to hardcode

### GENET/MBDMA side

Keep comparing:

- `0x12c00004`
- `0x12c00008`
- `0x12c0000c`
- `0x12c00010`
- `0x12c00044`
- `0x12c00048`
- `0x12c0004c`
- `0x12c00050`
- `0x12c00054`
- `0x12c00058`
- `0x12c00070`

Current status meaning:

- these still do not match the OEM-derived expected control state
- direct runtime reads keep returning `0x00000001` at the major compare points
- until that changes or the mapped-read bug is fixed, a TC7200U-specific write/init patch is still under-constrained

### Profile block

Current readable comparison-only status values:

- `0x14e001c4 = 0xDA492010`
- `0x14e00002 = 0x00A2`
- `0x14e00264 = 0x00000000`

Development meaning:

- the profile block is readable and nonzero
- semantics are still comparison-only; do not hardcode them as final Linux policy

## Current blocker

The blocker is not:

- A825 ProgramStore wrapping
- TFTP or CFE handoff
- UART or console recovery
- missing BCMGENET probe
- missing fixed-link
- missing `eth0`
- missing TX descriptor queueing

The blocker is:

- OpenWrt still does not reproduce trustworthy OEM-like GENET/MBDMA control state
- TDMA does not consume queued descriptors
- the current mapped kernel-side GMAC dump still needs repair before it can justify targeted TC7200U write placement

## Current development order

Follow this order unless a new log disproves it:

1. Keep the June 17 fresh-tree userspace-console image family as the control baseline.
2. Keep the fixed-link BCMGENET branch narrow.
3. Keep read-only dumps around BCMGENET open and timeout for the FPM, GENET/MBDMA, and profile compare points.
4. Repair the kernel-side GENET read helper so `bcmgenet_readl(...)`, `__raw_readl(...)`, and `readl(...)` can be compared cleanly.
5. Only after trustworthy reads exist, test the smallest TC7200U-specific FPM/MBDMA init change.

Do not prioritize yet:

- B53 or DSA work
- MDIO topology expansion
- switch child nodes
- broad descriptor-format changes
- a `999` write/init patch based only on the current invalid mapped GMAC output

The only still-defensible narrow side experiment from the current note set is:

- a controlled `GENET_V1 words_per_bd` branch from `2` to `3`, and only with matching `XMITDESC`, `TXDUMP`, and ring-state capture

## Source notes

This maintained status note currently depends most directly on:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\important-openwrt-tc7200u-enet-usable-values.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-17-fresh-openwrt-console-success.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-devmem-fpm-genet-baseline.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-genet-fixedlink-probe-watchdog.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-fpm-live-mbdma-unprogrammed.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-txdump-tdma-stuck.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-ctrlmap-debug-findings.md`

## Change log

- 2026-06-20: created this maintained status companion so the OpenWrt-facing ENET live state, blocker, and development order are separated cleanly from the longer reverse-derived values note.
- 2026-06-20: carried forward the June 17 console baseline and the June 18 through June 19 GENET, FPM, and TDMA status findings without editing the older dated logs.
