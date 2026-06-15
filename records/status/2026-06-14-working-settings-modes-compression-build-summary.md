# TC7200U summary: working settings, modes, compression, build info (2026-06-14)

## Scope

This summary consolidates the currently useful facts from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\bring-up`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\ethernet`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\image-format`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\runtime-probes`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\source-research`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\status`

The goal is to separate:

- what is confirmed working now
- what modes/settings are available from OEM reverse or runtime tests
- what compression/container settings are known-good vs known-bad
- what build identities are worth preserving as control baselines

## Executive summary

Current stable baseline:

- CFE TFTP RAM boot works.
- A825-wrapped OpenWrt images can boot to full userspace shell on ttyS0.
- The current control image family is the `tc7200-stage2-console-good.bin` lineage.
- Ethernet link can be brought up, but the data path is still broken:
  - TX submit path can move
  - watchdog can be reproduced
  - RX remains hard zero in all good observation runs
  - host never sees router-originated frames on the target path

Most important distinction:

- Boot/container format is no longer the main blocker.
- Current blocker is Ethernet/GENET/FPM/RX-TX completion behavior.

## Confirmed working settings

### CFE and board baseline

From serial logs and preserved bring-up notes:

- SoC family detected at boot: `BCM3383Z-B0`
- Bootloader:
  - `BootLoader Version: 2.4.0alpha18p1 Pre-release Gnu spiboot dual-flash reduced DDR drive linux`
  - `Build Date: Aug 14 2012`
  - `Build Time: 09:48:58`
- Memory:
  - `MemSize: 128 M`
- Flash geometry reported by CFE:
  - SPI: `0xc22014`, `1MB`
  - NAND: `64 MB`, `16 KB` erase block, `512 B` page
- Bootloader network defaults:
  - board IP `192.168.77.1`
  - common host/TFTP peer `192.168.77.2`
- OEM boot Ethernet clues:
  - `Switch detected: 53125`
  - `ProbePhy: Found PHY 0, MDIO on MAC 0, data on MAC 0`
  - `Using GMAC0, phy 0`
  - OEM CFE can report `Enet link up: 1G full`

### OpenWrt userspace baseline

Known-good OpenWrt control image family:

- `tc7200-stage2-console-good.bin`
- `tc7200-next-control.bin`
- recorded as byte-identical in the baseline note:
  - `sha256=a2b9fa164d092387dc0382698cbdff940bb97cce6c41a029ac70c1b357497c4b`

Known-good userspace markers:

- `OpenWrt kernel loader for BMIPS`
- `Decompressing kernel... done!`
- `Run /init as init process`
- `procd: - init -`
- `Please press Enter to activate this console.`
- `BusyBox v1.37.0`

Observed OpenWrt build identity from the good serial baseline:

- kernel:
  - `Linux version 6.12.87`
  - toolchain string includes `OpenWrt GCC 14.3.0 r34427-6865d489d2`
- userspace banner:
  - `OpenWrt SNAPSHOT, r34428+1-ded2d0b714`
- target/config note:
  - `bmips / bcm63268 / technicolor_tc7200u / Linux 6.12`

### Core hardware blocks already proven usable enough for bring-up

- UART works on `0x14e00500`.
- OpenWrt reaches shell on ttyS0.
- BCM3380 L2 interrupt controller registers correctly.
- GENET/ethernet probe path is live enough to instantiate `eth0`.
- `bcmgenet` active path is the right direction; `bcm6368-enetsw` is not the primary path for this board.

## Ethernet settings and modes

### Reverse-derived supported PHY mode values

OEM reverse notes recovered these BMCR-style values:

- `1000 half -> 0x0040`
- `1000 full -> 0x0140`
- `100 half  -> 0x2000`
- `100 full  -> 0x2100`
- `10 half   -> 0x0000`
- `10 full   -> 0x0100`

These are useful as supported/control values, but not all of them are confirmed working in OpenWrt runtime yet.

### Runtime-confirmed useful Ethernet settings

1. OEM/CFE baseline:
- link up at `1G full` is confirmed in stock bootloader context

2. OpenWrt link-enable quirk:
- setting `0x14e000ec |= 0x100` is confirmed to stick
- after that write, OpenWrt can bring `eth0` link up at `1Gbps/Full`
- this is a real and useful enable quirk, but it does not fix packet I/O

3. Stable experimental host/router mode:
- forced `10 Mbps / Half Duplex` on both ends is the main validated test mode
- under this matched mode:
  - router TX counters can increase
  - watchdog can be reproduced
  - host setup remains valid and pinned
  - RX still remains zero

### Modes/settings that were tested but are not validated as working data-path modes

`100/full` mismatch run:

- host was forced to `100 Mbps Full Duplex`
- router-side force request did not hold; observed router state still became `10Mb/s Half`
- no packet exchange occurred
- conclusion: this does not validate `100/full` as a working OpenWrt mode on the current port

### Persistent Ethernet failure signature

Across the cleanest forced-link runs:

- host sends directed unicast to the OpenWrt MAC correctly
- host capture shows `dir_tx > 0`, `dir_rx = 0`
- no ICMP echo replies from OpenWrt
- OpenWrt `rx_packets`, `rx_bytes`, RX queue stats, and RX error counters stay at `0`
- `IRQ64` moves, `IRQ66` stays `0`
- `NETDEV WATCHDOG` is reproducible in TX-stress runs

Best current interpretation:

- link establishment is no longer the main problem
- RX path is still non-functional
- TX submit can happen, but TX completion/egress behavior is not correct

## Key OEM/OpenWrt ENET constants now available

High-value physical bases from reverse:

- main GENET window: `0x12c00000`
- MDIO0: `0x12c00600`
- MDIO1: `0x12c02600`
- profile/control-related block:
  - `0x14e001c4`
  - `0x14e00002`
  - `0x14e00264`

Confirmed MDIO layout:

- `+0x2c` command/control
- `+0x2e` read data
- `+0x30` write data
- `+0x32` status
- busy bit is `bit0` at `base + 0x32`

Important current OpenWrt-facing control points:

- `0x14e000ec` is a proven link-enable related control point
- `0x12c00070` is a confirmed GMAC mode/control register
- newer notes indicate the more accurate observed effect is:
  - final runtime value seen: `0x00030003`
- newer reverse/bring-up notes also make FPM side control important:
  - `0x12200040`
  - `0x12200044`
  - `0x12200200`
  - `0x12200208`
  - `0x12200210`
  - `0x12200218`

Current direction:

- compare both FPM-side and GENET-side programming
- do not assume GENET-only replay is sufficient

## Compression and container findings

### Outer container / ProgramStore wrapper

Confirmed wrapper family:

- ProgramStore signature: `0xa825`
- CFE accepts correctly wrapped OpenWrt test images

Known-good accepted OpenWrt wrapper example from image-format note:

- `openwrt-ps-irqfallback.bin`
- received bytes: `5696426`
- HCS passed
- CFE accepted image and executed the OpenWrt kernel loader

Known-good A825 header example from the same line of testing:

- signature `a825`
- embedded filename `openwrt-initramfs.bin`
- load address seen in good image metadata: `0x82000000`

### Important historical wrapper split

There are two useful historical wrapper states in the notes:

1. Earlier successful stage-2 bring-up combination:
- `control=0x0000`
- `load_addr=0x80004000`
- CFE reported:
  - `Loading non-compressed image 4...`
  - then the OpenWrt BMIPS loader performed kernel decompression

2. Later canonical maintained flow:
- preserve the known-good A825 envelope from the console-good baseline
- current surfaced policy note says:
  - canonical preserve-from template is `records/artifacts/rescue/tc7200-stage2-console-good.bin`
  - canonical auto-build header/load policy is `0x82000000`

Practical conclusion:

- `0x80004000` matters as an earlier proven working stage-2 boot profile
- the newer maintained build flow standardizes on the console-good preserved A825 envelope
- when the older and newer notes disagree, treat the June 1 to June 7 baseline/canonical flow as the current operator baseline

### Known-bad compressed-mode experiment

From the staged `preserve-from d60242` experiment:

- d60242-style compressed wrapper settings led CFE to:
  - detect an LZMA-compressed image
  - fail during CFE-side decompression

Meaning:

- OEM compressed-mode settings are not automatically reusable for the OpenWrt payload
- wrapper acceptance and payload decompression behavior must be treated separately

### LZMA findings

Known-good/preferred iterative test choice:

- `8 MiB` dictionary image is preferred for repeated TFTP tests

Tested alternate:

- `16 MiB` dictionary image also boots
- but kernel decompression is slower
- therefore it was explicitly rejected for routine test use

Concrete 16 MiB test image facts:

- file: `openwrt-ps-irqfallback-lzma16m.bin`
- size: `5684200`
- signature: `a825`
- load address: `0x82000000`

Source-level BMIPS image recipe clue:

- OpenWrt BMIPS legacy CFE recipe uses `lzma-cfe`
- parameters recorded in the notes:
  - `-d22 -fb64 -a1`

### OEM stage1 compressed image facts

From the `TC7200U-D6.02.42-180321-F-1C1.bin` reverse note:

- ProgramStore header:
  - `signature=0xa825`
  - `control=0x0005`
  - `load_address=0x80004000`
- payload:
  - LZMA1 raw decode successful
  - `lc=3 lp=0 pb=2`
  - `dict=1048576`

## Build and helper modes

### Current helper surface

The helper workflow is consolidated around:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tcbuilder.sh`

Current command surface recorded in the status notes:

- build/wrap/check/verify path
- `state`
- `check-gates`
- `ensure-packages`
- `serial-console`
- `reverse-stage1`

### Current default mode behavior

As of the June 7 note:

- default mode is `interactive` when running in a TTY
- fallback mode is `auto` for non-interactive use

Operational conclusion:

- manual operator sessions should expect the interactive menu by default
- scripted runs should still work through automatic fallback without hanging

### Canonical build flow

Current documented build policy:

- `tcbuild` is the canonical entrypoint surface
- compatibility aliases remain, but are not the preferred public surface
- canonical preserve-from template:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\artifacts\rescue\tc7200-stage2-console-good.bin`

### Important build lineage markers

Useful build identity strings to preserve in future comparisons:

- filename
- file length
- raw SHA256
- wrapped SHA256

The notes explicitly call this out as the rule to avoid mixing different payload families and drawing false regression conclusions.

## Build identities worth keeping as controls

### OpenWrt control family

Best current OpenWrt control lineage:

- `tc7200-stage2-console-good.bin`
- `tc7200-next-control.bin`
- Linux line:
  - `Linux version 6.12.87`
  - toolchain tied to `r34427-6865d489d2`
- userspace banner:
  - `OpenWrt SNAPSHOT, r34428+1-ded2d0b714`

### Later build/update line

Additional tracked build note:

- active OpenWrt target path remains `bmips / bcm63268 / technicolor_tc7200u / Linux 6.12`
- GMAC patch work was being applied against the active BMIPS `bcmgenet.c`
- a later build note records successful `target/linux/compile` on commit `6865d489d2`

### OEM/stock lineage clues

Useful OEM and family identifiers preserved in the notes:

- OEM stage1 file:
  - `TC7200U-D6.02.42-180321-F-1C1.bin`
- family/version evidence only:
  - `STDC.01.31`
  - `STCF.01.44`
  - `CF.01.20`
  - `CF.01.23`
  - `CF.01.44`
  - `DC.01.31`
  - `ED.01.02`

These are useful for lineage comparison only, not as flashing targets.

## Bottom line

Current facts that should guide the next work:

1. Boot format is solved well enough for controlled RAM-boot experiments.
2. The right OpenWrt baseline is the console-good A825-wrapped control family, not arbitrary rebuilt variants.
3. The most useful runtime Ethernet test mode remains forced `10 Mbps Half Duplex`, because it reproduces the failure cleanly while keeping host setup controlled.
4. OpenWrt can also achieve `1Gbps/Full` link after the `0x14e000ec |= 0x100` quirk, but packet I/O still fails there too.
5. The next real discriminator is not another wrapper tweak; it is matching OEM FPM + GENET programming closely enough to explain:
   - RX stuck at zero
   - missing router-originated host-visible traffic
   - broken TX completion/watchdog behavior

## Preservation

Created as a new dated summary note.

- No old logs were edited.
- No old notes were overwritten.
