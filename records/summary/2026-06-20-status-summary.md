# TC7200U status-note summary

Date: 2026-06-20
Scope: summarize the full reread of `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status`

## Control result

- full reread of the live `records/status` tree completed on 2026-06-20
- older summary note `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\summary\2026-06-14-status-summary.md` remains preserved unchanged
- this new dated summary carries the current project-state interpretation after the June 15 through June 19 status additions

## Executive summary

The main state change since the older June 14 summary is that the project now has a fresh-tree OpenWrt userspace-console baseline again, but Ethernet is still blocked after BCMGENET probe.

The highest-value current facts from `records/status` are:

- the June 14 claim that a newly rebuilt image had already recovered the known-good console was corrected on June 15; the successful run was a retest of the pinned rescue family, not proof of a new rebuilt image
- the rebuilt-image branch was then debugged through the `/init` and `rdinit=/bin/sh` stages, which proved the low-level boot path, UART path, and general BusyBox shell path were good
- a fresh OpenWrt tree finally restored a clean interactive userspace console on June 17
- Ethernet work then moved from "no `eth0`" to "BCMGENET binds, fixed-link comes up, TX descriptors queue, but TDMA never consumes them"
- host-side CFE/TFTP control flow was also tightened and validated, so it is no longer the most likely explanation for the current Ethernet stop state

## 1. Console status was corrected before it was recovered

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-15-console-recovery-claim-correction.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-15-new-image-initramfs-none-init-segv-status.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-rdinit-initramfs-userspace-diagnostic-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-011656-rdinit-shell-no-pipe-diagnostic-passed.md`

What this cluster established:

- the successful June 14 userspace-console log belonged to `tc7200-console-known-good-retest.bin`, not to the newly rebuilt `tc7200u-uart500-l2-nandoff.bin`
- the rebuilt `openwrt-try5.bin` branch did move past the old `populate_rootfs` stall and reached `/init`, but then died in userspace with `cp` and `switch_root` SIGSEGVs
- `init=/bin/sh` was not the right bypass for the initramfs path; `rdinit=/bin/sh` was the relevant diagnostic override
- the `rdinit=/bin/sh` shell proved that the current low-level boot path, `ttyS0`, BusyBox shell, `cp`, and clean one-line pipelines were viable
- the active userspace blocker in that branch narrowed to the generated initramfs `/init` logic, especially `DIRS=$(echo *)`, rather than to the A825 wrapper, the UART path, or a broad libc failure

Most important durable lesson from this phase:

- do not call a rebuilt image "working console" unless the serial log for that exact non-control filename reaches `procd: - init -` and the interactive login markers

## 2. Fresh-tree OpenWrt userspace console is re-established

Key source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-17-fresh-openwrt-console-success.md`

What this note adds:

- a fresh OpenWrt tree plus a fresh initramfs image plus a fresh A825 ProgramStore wrapper booted successfully to interactive userspace console on TC7200U
- the confirmed image was `fresh-tc7200u-20260617-224158.bin`
- kernel config proof included:
  - `CONFIG_DEVTMPFS=y`
  - `CONFIG_DEVTMPFS_MOUNT=y`
  - `CONFIG_BCM7120_L2_IRQ=y`
  - `CONFIG_TMPFS=y`
- runtime proof included:
  - `Run /init as init process`
  - `procd: - early -`
  - `procd: - ubus -`
  - `procd: - init -`
- runtime release proof recorded:
  - `Linux OpenWrt 6.12.93`
  - `OpenWrt SNAPSHOT r34962-d6f5c2685f`

What it did not solve:

- `ip link` still showed only loopback in this fresh baseline
- NAND still timed out and remained outside the active Ethernet focus

Practical consequence:

- there is now a modern, fresh-tree OpenWrt console control baseline for Ethernet work
- future Ethernet regression claims should compare against this June 17 baseline, not only against the older rescue-family console images

## 3. Ethernet progressed from "no interface" to "xmit path alive, TDMA stuck"

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-devmem-fpm-genet-baseline.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-genet-fixedlink-probe-watchdog.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-fpm-live-mbdma-unprogrammed.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-txdump-tdma-stuck.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-ctrlmap-debug-findings.md`

This status cluster records a real staged advance:

1. Pre-enable baseline:
   - FPM register space was readable and nonzero
   - GENET/MBDMA and MDIO compare points read as `0x00000001`
2. First probe milestone:
   - BCMGENET bound at `0x12c00000`
   - fixed-link RGMII came up
   - `eth0` was created
3. First failure layer captured:
   - TX watchdog fired
   - IRQs `16` and `17` were allocated to `eth0`, but their counts remained zero during the watchdog window
   - `tx_packets = 10`, `tx_errors = 8`, `rx_packets = 0`
4. First descriptor-path proof:
   - `XMITDESC` logs proved that Linux queued real TX descriptors
5. Current stop state:
   - TDMA still does not consume queued descriptors
   - timeout dumps repeatedly showed:
     - `tdma_ctrl=0x00003000`
     - `tdma_stat=0x00000800`
     - `hw_p=0`
     - `hw_c=14340`
   - post-timeout software counters became invalid, for example `prod=17920` and `free=65792`

What the June 19 control-dump work changed:

- FPM/profile spaces are now clearly readable and live during the Ethernet debug branch
- direct `devmem` GENET/MBDMA compare points still read as `0x00000001` instead of the OEM-derived expected set
- the first mapped `998` GMAC dump is not trustworthy because it produced pointer-shaped values such as repeated `0xb2c00000`

Most important current conclusion:

- the blocker is no longer probe, fixed-link, `eth0` creation, or basic descriptor queueing
- the blocker is now the TC7200U-specific GENET/MBDMA/FPM control state and the lack of trustworthy kernel-side GENET/MBDMA reads before any write-heavy init patch

## 4. Host-side CFE/TFTP control flow is better defined and no longer the main blocker

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-cfe-tftp-script-refresh.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-cfe-tftp-fastloop-benchmark.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-cfe-tftp-port69-default.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-cfe-tftp-arp-clear-required.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-cfe-tftp-arp-clear-gate-relaxed.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-cfe-tftp-listener-arp-validated.md`

What this cluster records:

- the repo now has canonical mirrored PowerShell TFTP host scripts
- the compiled fast-transfer loop produced a real improvement from `23.592s` to `21.63s` on one comparable live run
- first-block failures on the dedicated transfer socket led to a safer listener-port default on UDP port `69`
- host-side ARP state for `192.168.77.1` was identified as a real stability factor
- after the ARP-gate relax, the current known-good combination was validated with:
  - listener-socket data transfer on port `69`
  - `TimeoutMs=500`
  - `MaxRetries=10`
  - `UseFastTransferLoop=true`
  - non-blocking launcher-side ARP clear verification
- the validated June 19 listener run completed in `15.956s` at about `349.4 KiB/s`

Why this matters to the current project state:

- host transport still needs discipline, but it is no longer the strongest explanation for the GENET/TDMA stop state
- the active work should stay focused on Linux-side GENET/MBDMA/FPM correlation

## Current practical baseline

If work resumes from `records/status` alone, the best current assumptions are:

- use the June 17 fresh-tree console-success image family as the OpenWrt userspace control
- treat the June 15 correction note as authoritative for the earlier mixed-log console claim
- keep the listener-port CFE/TFTP defaults and the ARP-clear recovery habit on the host side
- keep fixed-link BCMGENET as the current narrow Ethernet branch
- compare OpenWrt runtime control state against both:
  - FPM at `0x12200000`
  - GENET/MBDMA at `0x12c00000`
- do not prioritize B53/DSA/MDIO topology work until TDMA consumes descriptors or the GENET/MBDMA control state becomes OEM-like
- do not apply a write-heavy TC7200U init patch until the kernel-side GENET/MBDMA read path is trustworthy

## Suggested reading order

For the fastest reconstruction of the current late-June state:

1. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-15-console-recovery-claim-correction.md`
2. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-rdinit-initramfs-userspace-diagnostic-log.md`
3. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-17-fresh-openwrt-console-success.md`
4. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-genet-fixedlink-probe-watchdog.md`
5. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-ctrlmap-debug-findings.md`

## Change log

- 2026-06-20: created this new summary after a full reread of the live `records/status` tree and after checking the June 15 through June 19 additions against the older June 14 summary.
- 2026-06-20: preserved the older June 14 summary unchanged and used this new dated file for the current carry state.
