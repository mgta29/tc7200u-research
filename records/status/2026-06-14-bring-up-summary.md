# TC7200U bring-up summary

Date: 2026-06-14
Scope: summarize the bring-up notes currently under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up`

## Executive summary

The bring-up record shows that OpenWrt already crossed the main early-boot barrier on 2026-05-13: the TC7200U reaches OpenWrt userspace shell over `ttyS0`, the BCM3380/BCM7120 L2 interrupt path is active, and serial login works. The durable blocker across the technical notes is Ethernet bring-up, with repeated confirmation that only loopback is present and no usable `eth0`/MDIO/switch path is online yet. Storage is also still incomplete in the earliest full-boot note, where `/proc/mtd` is empty.

The 2026-06-01 notes separate two payload families that were previously being mixed together. One family is a known console-working baseline and was revalidated as a clean PASS run; the other family reaches `Run /init as init process` and then crashes with `SIGSEGV`, so later comparisons must track exact file identity instead of treating all boots as reruns of the same image.

The 2026-06-08 Ethernet note does not report a successful fix. Instead, it converts OEM reverse-engineering work into concrete OpenWrt bring-up inputs: confirmed GENET and MDIO base addresses, register offsets, command encodings, and a short debug checklist for the next Ethernet experiments. The 2026-06-09 git-organization note is administrative and does not change the technical bring-up state.

## Timeline

### 2026-05-13: first confirmed OpenWrt shell

Sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-05-13-openwrt-console-success.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-05-13-openwrt-ramboot-status.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-05-13-ramboot-serial-ok-ethernet-missing.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-05-13-openwrt-first-real-boot.md`

What was established:

- Normal OpenWrt RAM boot works.
- `CONFIG_BCM7120_L2_IRQ=y` is the key serial-related fix called out in multiple notes.
- The BCM3380 L2 interrupt controller registers correctly.
- `ttyS0` comes up from `0x14e00500` and maps to Linux IRQ 8.
- OpenWrt reaches shell and root login over serial.

What was still missing:

- No Ethernet netdev beyond loopback.
- No MDIO, B53, or DSA probe path online yet.
- The first full-boot note also reports no visible MTD devices and an empty `/proc/mtd`.

### 2026-06-01: clean baseline revalidated

Source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-06-01-console-pass-baseline-refresh.md`

What changed:

- A pinned control image was booted again and passed the gate set cleanly through console readiness.
- The note records a rescue copy at `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\artifacts\rescue\tc7200-console-good-20260601-193010.bin`.

What did not change:

- Ethernet remained blocked.
- The note explicitly warns that another run from the same date showed repeated `SIGSEGV` in `ubus` and must not be used as the clean baseline claim.

### 2026-06-01: payload-family split explained

Source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-06-01-init-segv-regression-and-baseline-lineage.md`

Main conclusion:

- The project had been alternating between two different payload families.

Family A:

- Known console-working baseline.
- Reaches `procd` and the interactive shell prompt path.
- Tied to the `openwrt-ps-irqfallback.bin` lineage in the source note.

Family B:

- Newer failing payload family.
- Reaches `Run /init as init process` and then panics with `SIGSEGV` in `init`.

Operational rule recorded by the note:

- Every future boot comparison should log `Filename`, `File Length`, `raw_sha256`, and `wrapped_sha256` before calling something a regression or a fix.

### 2026-06-08: Ethernet bring-up constants extracted

Source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-06-08-openwrt-tc7200u-enet-usable-values.md`

What this note contributes:

- High-confidence GENET base `0x12c00000`.
- MDIO bases `0x12c00600` and `0x12c02600`.
- Confirmed MDIO register layout at offsets `0x2c`, `0x2e`, `0x30`, `0x32`.
- Confirmed MDIO busy-bit behavior on bit 0.
- OEM-derived MDIO read/write command encodings.
- Candidate early-mode register `0x12c00070`.
- Several MBDMA/global offsets worth tracing during OpenWrt bring-up.

Why it matters:

- This is the strongest bridge between the earlier "serial works, Ethernet missing" state and a concrete next debug plan.
- The note still treats some profile-control and DMA values as comparison targets only, not final Linux constants.

### 2026-06-09: repository organization note

Source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-06-09-git-organization.md`

Relevance to bring-up:

- This note documents git-cleanup constraints and preservation rules.
- It does not provide new boot, console, Ethernet, or storage results.

## Current bring-up baseline from this directory

Based on the notes in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up`, the current durable baseline is:

- OpenWrt boots to userspace shell over serial on TC7200U.
- The serial path depends on the BCM7120/BCM3380 L2 interrupt fix and the `ttyS0` mapping at `0x14e00500`.
- A clean console-working rescue baseline exists and was revalidated on 2026-06-01.
- Ethernet is still the main bring-up blocker.
- The directory also records a known failing payload family that dies in `init`, so image identity discipline is mandatory.
- The most actionable next-step data currently available is the 2026-06-08 OEM-derived ENET/MDIO register set.

## Suggested next-use reading order

For someone resuming work from this directory alone, the fastest read order is:

1. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-05-13-openwrt-first-real-boot.md`
2. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-06-01-console-pass-baseline-refresh.md`
3. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-06-01-init-segv-regression-and-baseline-lineage.md`
4. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\bring-up\2026-06-08-openwrt-tc7200u-enet-usable-values.md`

## Change log

- 2026-06-14: created this summary in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\summary` from the existing bring-up notes.
- 2026-06-14: no older log or note file was edited by this summary pass.
