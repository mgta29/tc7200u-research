# TC7200U Ethernet note summary

Date: 2026-06-14
Scope: summarize the notes currently under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet`

## Executive summary

The Ethernet notes in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet` capture the earliest focused investigation stage after serial/OpenWrt shell was already working. Their main result is negative but useful: the kernel already had the relevant Ethernet-related features enabled, yet runtime still exposed only loopback, which means the blocker was not simply missing config. The notes repeatedly point to missing or incomplete platform description, especially DTS nodes for GMAC/MDIO/switch wiring.

The strongest hardware-direction clue recorded in this directory is the CFE report:

- `Using GMAC0, phy 0`
- `Switch detected: 53125`
- `ProbePhy: Found PHY 0, MDIO on MAC 0, data on MAC 0`

From that evidence, the working hypothesis in this directory is that TC7200U should be approached first as a `GMAC0/AMAC + BCM53125/B53 over MDIO` platform, not as a `bcm6368-enetsw` first-choice design.

## Timeline

### 2026-05-13: runtime Ethernet missing, CFE clues identified

Sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet\2026-05-13-ethernet-investigation.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet\2026-05-13-bgmac-next-path.txt`

What was confirmed:

- After a successful RAM boot, only `lo` exists in `/sys/class/net`.
- No `eth0` exists.
- No useful runtime matches were seen for `eth`, `enet`, `mdio`, `phy`, `b53`, or `dsa`.
- The current TC7200U DTS at that point only enabled UART.

What kernel/source inspection already showed:

- Ethernet-related support was present in the tree, including `BGMAC`, `B53`, `NET_DSA`, `BCM6368_ENETSW`, and `MDIO_BUS_MUX_BCM6368`.
- `bgmac` source files existed in the kernel tree.
- The kernel in use did not show `BGMAC` actually driving the platform at runtime.

Initial conclusion from these notes:

- The next experiment should not be "add more random network config."
- The real next step is to add enough platform description for GMAC/MDIO/B53, or to identify the correct BCM3383 Ethernet driver path if `bgmac` is not the right match.

### 2026-05-14: config presence proved, platform-description gap narrowed

Sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet\2026-05-14-ethernet-config-present.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet\2026-05-14-ethernet-driver-direction.txt`

What was confirmed:

- The build already had:
  - `CONFIG_BGMAC=y`
  - `CONFIG_BGMAC_PLATFORM=y`
  - `CONFIG_B53=y`
  - `CONFIG_B53_MDIO_DRIVER=y`
  - `CONFIG_B53_MMAP_DRIVER=y`
  - `CONFIG_B53_SPI_DRIVER=y`
  - `CONFIG_NET_DSA=y`
  - Broadcom DSA tag support

Main conclusion from that config proof:

- Ethernet was blocked by missing or incomplete DTS/platform-device description, not by absent kernel options.

Driver-direction conclusion from source inspection:

- `bgmac-platform.c` only matched:
  - `brcm,amac`
  - `brcm,nsp-amac`
  - `brcm,ns2-amac`
- Therefore a TC7200U GMAC node would either need:
  - `compatible = "brcm,amac"` for initial probing, or
  - a small `bgmac-platform` patch to accept a BCM3383/BCM3384-specific compatible

Why `bcm6368-enetsw` was deprioritized:

- That driver supports several BCM63xx integrated ENETSW compatibles.
- The TC7200U CFE evidence instead points to a GMAC plus external BCM53125 switch model.
- The note explicitly says not to start with `bcm6368-enetsw` unless the GMAC/AMAC interpretation fails or register discovery later contradicts it.

## Key conclusions from this directory

- No successful Ethernet bring-up is recorded in this directory.
- The runtime failure mode is consistent: serial boot works, but only loopback is present.
- Kernel config was already sufficient for initial experiments.
- The dominant missing piece is board/platform description:
  - GMAC base address
  - IRQ
  - MDIO bus hookup
  - BCM53125/B53 switch connection
- The preferred early software path in these notes is `bgmac`/`AMAC`, not `bcm6368-enetsw`.

## Practical baseline for follow-up work

If work resumes from this directory alone, the baseline to carry forward is:

- Treat the absence of Ethernet as a platform-description problem first.
- Use the CFE `GMAC0` and `53125` clues as the primary hardware model.
- Try a minimal GMAC/AMAC DTS path before spending time on BCM63xx ENETSW-specific directions.
- Validate safe GMAC base address, IRQ, and MDIO wiring before expecting `B53` or DSA to appear at runtime.

## Suggested reading order

For the fastest review of the Ethernet-only record:

1. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet\2026-05-13-ethernet-investigation.txt`
2. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet\2026-05-14-ethernet-config-present.txt`
3. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet\2026-05-14-ethernet-driver-direction.txt`
4. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\ethernet\2026-05-13-bgmac-next-path.txt`

## Change log

- 2026-06-14: created this summary in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\summary` from the existing Ethernet notes.
- 2026-06-14: no older log or note file was edited by this summary pass.
