# TC7200U OpenWrt ENET usable values from OEM reverse

## Purpose

This is the maintained main document in this directory for OpenWrt-facing TC7200U ENET/GMAC/MDIO reverse findings.

It extracts only the values and mechanics that are directly usable for OpenWrt ENET/GMAC/MDIO bring-up on TC7200U.

It is derived from the reverse-note set and later control-pass updates. Dated bring-up notes remain historical snapshots.

## Address translation rules

These two rules are immediately usable:

- OEM KSEG1 MMIO alias to physical:
  - `physical = kseg1 - 0xa0000000`
- OEM cached KSEG0 DMA pointer to DMA-visible physical:
  - `dma_phys = cached_addr & 0x1fffffff`

## Candidate base addresses

High-confidence physical base addresses:

- `0x12c00000` - main GENET window
- `0x12c00600` - MDIO0 block
- `0x12c02600` - MDIO1 block

Related board/profile block addresses seen in OEM init:

- `0x14e001c4` - ENET/profile control register
- `0x14e00002` - ENET/profile status register
- `0x14e00264` - candidate ENET/profile one-time setup register

Useful KSEG1 aliases for firmware cross-checking:

- `0xb2c00000 -> 0x12c00000`
- `0xb2c00600 -> 0x12c00600`
- `0xb2c02600 -> 0x12c02600`
- `0xb4e001c4 -> 0x14e001c4`
- `0xb4e00002 -> 0x14e00002`
- `0xb4e00264 -> 0x14e00264`

## Candidate OpenWrt constants

These are the most useful values to turn into temporary driver constants or debug print targets:

```c
#define TC7200_GENET_BASE                 0x12c00000
#define TC7200_GENET_REG_MODE70          0x00000070

#define TC7200_GENET_MBDMA_GLOB_08       0x00000008
#define TC7200_GENET_MBDMA_GLOB_CTRL     0x0000000c
#define TC7200_GENET_MBDMA_GLOB_10       0x00000010
#define TC7200_GENET_MBDMA_GLOB_4C       0x0000004c
#define TC7200_GENET_MBDMA_GLOB_50       0x00000050
#define TC7200_GENET_MBDMA_GLOB_54       0x00000054
#define TC7200_GENET_MBDMA_GLOB_58       0x00000058

#define TC7200_GENET_MDIO0_BASE          0x12c00600
#define TC7200_GENET_MDIO1_BASE          0x12c02600
#define TC7200_GENET_MDIO_CMD_OFF        0x0000002c
#define TC7200_GENET_MDIO_RDATA_OFF      0x0000002e
#define TC7200_GENET_MDIO_WDATA_OFF      0x00000030
#define TC7200_GENET_MDIO_STATUS_OFF     0x00000032

#define TC7200_ENET_PROFILE_CTRL         0x14e001c4
#define TC7200_ENET_PROFILE_STATUS       0x14e00002
#define TC7200_ENET_PROFILE_CTRL2        0x14e00264
```

## Confirmed MDIO register layout

Both MDIO blocks use the same layout:

- `+0x2c` - command/control
- `+0x2e` - read data
- `+0x30` - write data/control
- `+0x32` - busy/status

Confirmed status behavior:

- busy bit is `bit0` of `base + 0x32`
- OEM code polls until `bit0 == 0`

Concrete physical addresses:

- MDIO0 command: `0x12c0062c`
- MDIO0 read data: `0x12c0062e`
- MDIO0 write data: `0x12c00630`
- MDIO0 status: `0x12c00632`
- MDIO1 command: `0x12c0262c`
- MDIO1 read data: `0x12c0262e`
- MDIO1 write data: `0x12c02630`
- MDIO1 status: `0x12c02632`

## MDIO command values

Confirmed OEM read command builder:

```c
cmd = 0x20000000 | 0x08000000 |
      ((phy_addr & 0x1f) << 21) |
      ((reg_num  & 0x1f) << 16);
```

Confirmed OEM write command builder:

```c
cmd = 0x10000000 | 0x08000000 |
      ((phy_addr & 0x1f) << 21) |
      ((reg_num  & 0x1f) << 16);
```

Confirmed OEM write-data rule:

- low 16 bits of write value are placed in `base + 0x30`

Confirmed OEM default-PHY convention:

- `phy_addr == 0xff` means use stored/default PHY address for that MDIO bus

Confirmed OEM bus clamp:

- if `mdio_bus > 1`, OEM code falls back to bus `0`

## Known MDIO/PHY control bits and values

Confirmed reset value:

- BMCR reset bit: `0x8000`

Confirmed link/speed command values used by OEM path:

- `1000 half -> 0x0040`
- `1000 full -> 0x0140`
- `100 half  -> 0x2000`
- `100 full  -> 0x2100`
- `10 half   -> 0x0000`
- `10 full   -> 0x0100`

Observed OEM PHY register-7 writes during command path:

- `0x90ff`
- `0x90fb`

Useful PHY-ID masks from OEM probe logic, using PHY register `3`:

- `(reg3 & 0x3f0) == 0x1e0` -> BCM5221
- `(reg3 & 0x3f0) == 0x210` -> BCM5201 / BCM5202
- `(reg3 & 0x3f0) == 0x0f0` -> BCM3345 / BCM3360
- `(reg3 & 0x3f0) == 0x260` -> B50612E

## Confirmed GENET mode/control register

Confirmed physical register:

- `0x12c00070`

Best current OEM step2 interpretation:

- core/interface `0` path sets `0x00000003`
- nonzero core/interface path sets `0x00030000`

Inverse disable behavior seen in paired helper:

- core/interface `0` path clears `0x00000003`
- nonzero core/interface path clears `0x00030000`

Direct development value:

- `0x12c00070` is a strong candidate early mode/enable register to dump before and after OpenWrt GENET bring-up

## Confirmed MBDMA/global register offsets

Confirmed OEM writes exist to:

- `0x12c00008`
- `0x12c0000c`
- `0x12c00010`
- `0x12c0004c`
- `0x12c00050`
- `0x12c00054`
- `0x12c00058`

Direct development use:

- these are the first registers to trace when comparing OEM descriptor/DMA programming against OpenWrt behavior

## DMA-visible address value recovered from OEM path

Recovered OEM DMA address:

- cached base returned by allocator: `0x81848740`
- DMA-visible physical after mask: `0x01848740`

Confirmed conversion:

```c
0x81848740 & 0x1fffffff = 0x01848740
```

Direct development use:

- use `0x01848740` only as a comparison value when validating register programming against OEM behavior
- do not hardcode `0x01848740` into Linux/OpenWrt unless the same reserved memory layout is proven valid on the running system

## Profile-control values seen in OEM init

Observed on `0x14e001c4`:

- `(old & 0xffffe3ff) | 0x1000`
- later `(old & 0xffffe3ff) | 0x1400`

Observed in one-time profile-select helper on `0x14e00264`:

- `(old & 0xfffff3ff) | 0x0400`

Observed status tests on `0x14e00002`:

- `(status & 0xf0) != 0x10`
- `(status & 0xf0) != 0x20`

Direct development use:

- these values are suitable for debug comparison and temporary register tracing
- they are not yet safe to promote to final driver semantics without confirming what the `0x14e0xxxx` block actually is

## Values safe to use now vs values for comparison only

Safe to use now for OpenWrt experiments:

- main GENET base `0x12c00000`
- MDIO bases `0x12c00600` and `0x12c02600`
- MDIO offsets `0x2c`, `0x2e`, `0x30`, `0x32`
- MDIO busy bit `bit0`
- MDIO read/write command encodings
- `0x12c00070` as a candidate mode/enable register
- MBDMA/global offsets `0x08`, `0x0c`, `0x10`, `0x4c`, `0x50`, `0x54`, `0x58`
- KSEG1-to-physical conversion rule
- DMA mask `0x1fffffff`

Comparison only, not safe to hardcode yet:

- DMA base `0x01848740`
- profile-control registers `0x14e001c4`, `0x14e00002`, `0x14e00264`
- exact meaning of hidden control value flowing into `0x12c0000c`
- runtime source of allocator backing/base field `0x8184874c`

## Immediate OpenWrt debug checklist

Recommended next bring-up checks:

1. Add debug reads/writes around:
   - `0x12c00070`
   - `0x12c00008`
   - `0x12c0000c`
   - `0x12c00010`
   - `0x12c0004c`
   - `0x12c00050`
   - `0x12c00054`
   - `0x12c00058`
2. If MDIO is still failing, probe both `0x12c00600` and `0x12c02600` using the confirmed offset layout and `bit0` busy poll.
3. Compare any programmed DMA/descriptor physical address against OEM comparison value `0x01848740`.
4. Trace whether OpenWrt ever produces an equivalent of the OEM selected-core enable on `0x12c00070`:
   - `0x00000003` for core/interface `0`
   - `0x00030000` for nonzero core/interface
5. Log `0x14e001c4`, `0x14e00002`, and `0x14e00264` during early Ethernet init for board/profile gating evidence.

## Runtime control pass: 2026-06-17/18 OpenWrt status comparison

This section folds the current OpenWrt runtime status notes into the maintained ENET carry note:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-17-fresh-openwrt-console-success.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-devmem-fpm-genet-baseline.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-genet-fixedlink-probe-watchdog.md`

### Runtime result now proven

The OpenWrt image has moved past the old bring-up blockers:

- fresh initramfs boots to an interactive OpenWrt userspace console
- `CONFIG_BCMGENET=y`, `CONFIG_PHYLIB=y`, `CONFIG_FIXED_PHY=y`, `CONFIG_DEVMEM=y`, and `CONFIG_BCM7120_L2_IRQ=y` are present in the tested image
- DTS has `ethernet@12c00000`, `compatible = "brcm,genet-v1"`, `reg = <0x12c00000 0x4000>`, `interrupts = <16>, <17>`, `phy-mode = "rgmii"`, and fixed-link 1000/full
- BCMGENET binds and creates `eth0`
- fixed-link reports link up at `1Gbps/Full`
- IRQs `16` and `17` are allocated to `eth0`

Current runtime failure:

- `NETDEV WATCHDOG` fires on transmit queue `0`
- `tx_packets = 10`, `tx_errors = 8`, `rx_packets = 0`
- IRQ counts for `eth0` IRQs `16` and `17` stay at `0` during the watchdog window
- the current blocker is TX DMA, completion, interrupt, or MBDMA/FPM integration, not basic kernel boot, driver binding, fixed-link, or IRQ allocation

### Runtime GENET/MBDMA comparison

The live OpenWrt `devmem` and post-probe snapshots show all sampled GENET/MBDMA registers still reading `0x00000001`:

- `0x12c00004 = 0x00000001`
- `0x12c00008 = 0x00000001`
- `0x12c0000c = 0x00000001`
- `0x12c00010 = 0x00000001`
- `0x12c00040 = 0x00000001`
- `0x12c00044 = 0x00000001`
- `0x12c00048 = 0x00000001`
- `0x12c0004c = 0x00000001`
- `0x12c00050 = 0x00000001`
- `0x12c00054 = 0x00000001`
- `0x12c00058 = 0x00000001`
- `0x12c00070 = 0x00000001`

These runtime values do not match the OEM-derived GENET/MBDMA expectations carried in this note:

- `0x12c00004 = (old & 0xffffe000) | 0x9010`
- `0x12c00044 = 0x02020202`
- `0x12c00048 = 0x0000000f`
- `0x12c0004c = 0x12200218`
- `0x12c00050 = 0x12200210`
- `0x12c00054 = 0x12200208`
- `0x12c00058 = 0x12200200`
- `0x12c00008 = 0x12200200`
- `0x12c00010 = aligned_fpm_ddr_backing_base & 0x1fffffff`
- `0x12c00070` should show selected-core enable behavior, currently carried as `0x00000003` or `0x00030000`

Interpretation:

- this is a live OpenWrt mismatch against the reverse-derived control set
- it supports the current hypothesis that the stock BCMGENET path is not yet reproducing TC7200U-specific MBDMA/FPM setup
- do not reinterpret the OEM expected values downward to `0x00000001`; treat `0x00000001` as the current failing OpenWrt runtime observation

### Runtime FPM and MDIO comparison

The runtime FPM reads are nonzero and prove that the FPM address space is readable:

- `0x12200010 = 0x00000000`
- `0x12200014 = 0x00000001`
- `0x12200040 = 0x06000000`
- `0x12200044 = 0x00010000`
- `0x12200050 = 0x00000000`
- `0x12200054 = 0x18007F10`
- `0x12200058 = 0x00000000`
- `0x1220005c = 0x00000000`
- `0x12200200 = 0x80130800`
- `0x12200208 = 0x90064400`
- `0x12200210 = 0xA01B8200`
- `0x12200218 = 0xB01C4100`

Interpretation:

- FPM space is accessible from OpenWrt
- the values at `0x12200200/208/210/218` should be treated as live endpoint or token-like reads, not as fixed expected constants
- the important mismatch is that the GENET/MBDMA registers which should be programmed from FPM-derived addresses still read `0x00000001`

The runtime MDIO baseline reads all sampled MDIO offsets as `0x0010`:

- `0x12c0062c/2e/30/32 = 0x0010`
- `0x12c0262c/2e/30/32 = 0x0010`

Interpretation:

- this does not invalidate the MDIO offset layout in this note
- it only shows that the current OpenWrt runtime is not yet producing useful OEM-like MDIO command activity through those registers

### Updated next action

The status-backed next action is to instrument the BCMGENET TX and DMA path before applying broad old GMAC-init or switch/B53/MDIO patches.

Recommended order:

1. Apply the BCMGENET transmit descriptor debug patch.
2. Apply the BCMGENET TX poll/completion debug patch.
3. Rebuild and boot a debug initramfs.
4. Bring `eth0` up once and capture one TX watchdog.
5. Capture dmesg for GENET, TX, DMA, IRQ, and debug lines.
6. Capture `/proc/interrupts` during the watchdog window.
7. Compare what BCMGENET actually programs against the short control set in this note.

Do not apply the old GMAC-init patch until the debug patches show whether BCMGENET is programming the TC7200U MBDMA/FPM-facing registers at all.

Recorded modification:

- 2026-06-19: folded the June 17/18 OpenWrt runtime status notes into this maintained carry note and recorded the current live mismatch between OpenWrt `0x00000001` GENET/MBDMA reads and the OEM-derived MBDMA/FPM expected values.

## Source notes

Derived from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-08-ghidra-enet-genet-consolidated-summary.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-08-ghidra-enet-genet-consolidated-summary-addendum.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-08-ghidra-mdio-read-write-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-08-gmac-ghidra-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-08-ghidra-mbdma-static-dma-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-08-enet-gmac-step1-mdio-profile-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-thread-record-datatype-correction.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-thread-exit-tsd-cleanup.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-pi-owned-wait-object-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-owner-list-wakeup-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-static-idle-timeslice.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-timeout-signal-dispatch.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-signal-object-path-dispatch-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-signal-object-type2-dispatcher-path.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-timeout-select-wait-reverse-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-16-stage1-socket-object-type2-setsockopt.md`

## Preservation

Maintained as a dateless important carry note. No old logs or notes were edited or deleted.

## Refresh after full reverse reread

This section was added after rereading the full reverse-note set under:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse`

Control correction after the 2026-06-16 reread:

- the live canonical tree is `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse`
- the old legacy path wording has been removed from this maintained carry note

## Thirteenth-pass Stage1 signal-object and select-wait correlation values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-signal-object-path-dispatch-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-signal-object-type2-dispatcher-path.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-15-stage1-timeout-select-wait-reverse-log.md`

### When to use this set

Use this thirteenth-pass set only after the earlier MMIO, Host-DQM, event-slot, thread-record, readyq, PI, timeout-object, and timeslice surfaces already look OEM-like, but worker follow-through still diverges during signal-style dispatch, select or wait wakeup, or timeout-driven progress.

### Thirteenth-pass software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- signal-object table and pool state:
  - `0x81a68120`
  - `0x81a6b508`
  - `0x81a78138`
  - `0x81a79528`
- related-object and provider state:
  - `0x8184fa18`
  - `0x8184fa58`
  - `0x8183fbf8`
  - `0x8183fc18`
- select or wait and timeout-conversion state:
  - `0x81a6ba50`
  - `0x81a6ba68`
  - `0x81803adc`
  - `0x81803ae0`
  - `0x81802ab4`
  - `0x81a6ba70`
  - `0x81a6ba90`

### Current best meanings

- Stage1 now looks to use a descriptor-like signal-object table:
  - table entry `0` means free
  - table entry `1` means reserved sentinel
  - table entry `>= 2` is a live `stage1_signal_object_candidate *`
- the signal-object dispatch layer now suggests:
  - `stage1_signal_object_candidate +0x0c` is a real ops or class callback table
  - `stage1_signal_object_candidate +0x06 == 2` gates the type2 callback family
  - `stage1_signal_object_candidate +0x18` is a type2 ops table in that path
  - `stage1_signal_object_candidate +0x1c` remains broad as provider or related-object state, not just one narrow object kind
- the select or wait layer now suggests:
  - `stage1_signal_ops_or_class_candidate +0x10` is the readiness-test callback slot
  - the main helper at `80ef6ccc` walks three class bitsets and either returns ready bits or waits
  - `80ef71c8` is the thin public wrapper that clears the auxiliary wait argument before calling that helper
- the timeout layer now suggests:
  - `stage1_timeval32_candidate` is the public relative-timeout shape
  - `0x81a6ba70` and `0x81a6ba90` are the corrected timeout-scale tables
  - `0x81a6ba68` is adjacent select-wait condition-object state and should not be collapsed into the timeout tables

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- any of the `0x81a6....`, `0x8180....`, or `0x8184....` values above as if they were ENET or Host-DQM MMIO registers
- the Stage1 signal-object table layout as if OpenWrt must reproduce the OEM software scheduler and wait internals directly
- any wrapper signatures that still rely on nonstandard register inputs through `t0` or `t1`

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup must look right
- stage 7: request-engine submit/finalize flow, selector-gate publish behavior, and mode-specific sideband output lanes must look right
- stage 8: alternate `0x80c8` runtime-family registration/activation writes, selector-output gating, and alias-window output paths must look right
- stage 9: runtime-family selection and request-model behavior must look right
- stage 10: if traffic still stalls, Host-DQM selector register blocks, dispatch-table mapping, and Stage1 event-slot wake behavior become the next most likely missing OEM-specific layer
- stage 11: if the stage-10 event-slot layer already looks OEM-like, current-context ownership, thread-record linkage, per-thread pending or blocked signal/work masks, and worker exit/join lifecycle become the next software correlation layer
- stage 12: if the stage-11 layer already looks OEM-like, readyq ownership, PI restore/requeue behavior, timeout object state, same-bucket timeslice rotation, and static idle context setup become the next software correlation layer
- stage 13: if the stage-12 layer already looks OEM-like, signal-object table state, provider/type2 callback dispatch, select-wait generation flow, and timeout-to-ticks conversion become the next software correlation layer

Practical implication:

- if OpenWrt reproduces the earlier control surfaces and even the Host-DQM/event-slot/thread-record/readyq layers still look OEM-like, compare whether any OEM-equivalent follow-through exists for:
  - `g_stage1_signal_object_table_81a6b508`
  - `g_stage1_signal_object_pool_81a79528`
  - `g_stage1_select_wait_global_mutex_81a6ba50_candidate`
  - `g_stage1_select_wait_generation_81803adc_candidate`
  - `g_stage1_timeout_usec_to_ticks_scale_table_81a6ba70_candidate`
  - `g_stage1_timeout_sec_to_ticks_scale_table_81a6ba90_candidate`
- keep these as reverse-side correlation aids only
- do not convert those software values into direct Linux MMIO constants

## Fourteenth-pass Stage1 socket-object and type2 socket-option correlation values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-16-stage1-socket-object-type2-setsockopt.md`

### When to use this set

Use this fourteenth-pass set only after the earlier signal-object and select-wait layer already looks OEM-like, but Stage1 socket-provider object creation, option setup, or close/cleanup behavior still diverges.

### Fourteenth-pass software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- socket-object vtable:
  - `0x81825d98`
- socket object helper functions:
  - `808381b4`
  - `808381f4`
  - `808385f4`
- type2 socket-option dispatch helpers:
  - `80ef80a8`
  - `80ef81ac`
- socket-option helper candidates:
  - `8006111c`
  - `800611b0`

### Current best meanings

- `808381f4` is the Stage1 socket-object create/configure helper:
  - it creates a Stage1 signal-object/provider handle through the provider-table path
  - it stores that handle at `stage1_socket_object_candidate +0x04`
  - it saves hidden incoming `t0` at `+0x0c` as create flags or option input
  - it stores the boot-context/base pointer at `+0x10` on success
- `80ef80a8` is now better treated as a type2 setsockopt-like dispatcher in the socket provider path:
  - normal arguments carry handle, level, option name, and option-value pointer
  - hidden incoming `t0` carries option length
- observed socket-option calls include:
  - `level 0xffff`, normalized option, optlen `4`
  - `level 0x29`, option `0x2e`, optlen `0x14`
  - `level 0xffff`, option `0x04`, optlen `4`
  - `level 0`, option `0x13`, optlen `4`
  - `level 0x29`, option `0x0e`, optlen `4`
- `808385f4` is the Stage1 socket-object close/cleanup helper:
  - it calls vtable `+0x38` with `level 0xffff`, option `0x1008`, and hidden `t0 = &optlen`
  - it closes the Stage1 signal-object handle through the close-index path
  - it clears `stage1_socket_object_candidate +0x04`
- `808381b4` is the socket-object destroy/free wrapper:
  - it restores the vtable at `+0x00` to `0x81825d98`
  - it runs close/cleanup and then frees the object

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- `0x81825d98` as hardware state or an MMIO register
- the socket-object vtable layout as a Linux driver interface
- hidden `t0` values as normal C arguments without explicitly modeling the nonstandard register input
- the exact public meaning of option `0x1008`, `8006111c`, or `800611b0` before those helper bodies are opened

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup must look right
- stage 7: request-engine submit/finalize flow, selector-gate publish behavior, and mode-specific sideband output lanes must look right
- stage 8: alternate `0x80c8` runtime-family registration/activation writes, selector-output gating, and alias-window output paths must look right
- stage 9: runtime-family selection and request-model behavior must look right
- stage 10: if traffic still stalls, Host-DQM selector register blocks, dispatch-table mapping, and Stage1 event-slot wake behavior become the next most likely missing OEM-specific layer
- stage 11: if the stage-10 event-slot layer already looks OEM-like, current-context ownership, thread-record linkage, per-thread pending or blocked signal/work masks, and worker exit/join lifecycle become the next software correlation layer
- stage 12: if the stage-11 layer already looks OEM-like, readyq ownership, PI restore/requeue behavior, timeout object state, same-bucket timeslice rotation, and static idle context setup become the next software correlation layer
- stage 13: if the stage-12 layer already looks OEM-like, signal-object table state, provider/type2 callback dispatch, select-wait generation flow, and timeout-to-ticks conversion become the next software correlation layer
- stage 14: if the stage-13 layer already looks OEM-like, socket-object wrapper state, type2 setsockopt/getsockopt dispatch, and socket close/cleanup behavior become the next software correlation layer

Practical implication:

- if the missing OpenWrt behavior appears only after the OEM path has reached the Stage1 socket-provider abstraction, compare whether equivalent follow-through exists for:
  - `stage1_socket_object_candidate +0x04/+0x0c/+0x10`
  - `g_stage1_socket_object_vtable_81825d98_candidate`
  - `fn_stage1_signal_object_type2_setsockopt_t0_dispatch_80ef80a8`
  - `stage1_signal_object_type2_ops_candidate +0x1c`
- keep these as reverse-side software correlation aids only
- do not convert these values into direct Linux MMIO constants

### Control values worth comparing directly in OpenWrt

These values were reinforced by the later MBDMA-focused notes and are worth explicit runtime comparison:

- `0x12c00004 = (old & 0xffffe000) | 0x9010`
- `0x12c00044 = 0x02020202`
- `0x12c00048 = 0x0000000f`
- `0x12c0000c` final low field includes `0x0c41`
- `0x12c00104 = 0x13601c10`
- `0x12c00124 = 0x13601c10`
- `0x12c00144 = 0x13601c10`
- `0x12c00184 = 0x13601c10`

These are still comparison values, not final Linux semantics.

### Important correction for `0x12c00010`

Treat `0x12c00010` carefully.

Current best interpretation:

- it is not simply `0x81848740 & 0x1fffffff`
- it comes through `fn_dma_addr_alloc_wrapper_a`
- that wrapper calls `fn_dma_translate_or_get_flag2_value`
- for the `(0,0)` call shape seen in the MBDMA init path, the value is best treated as allocator backing-base-derived, not allocator-object-base-derived

Practical OpenWrt consequence:

- if OpenWrt writes a descriptor/control pointer into the register corresponding to OEM `0x12c00010`, compare it against the OEM-style translated backing base, not the raw allocator object address

### Important correction for `0x12c0004c/50/54/58/08`

Current best interpretation of these registers:

- they are pool-class HW alloc/free control addresses returned by the sized wrapper path
- they are not best treated as ordinary data-buffer base addresses

Useful derived expectation:

- `0x12c00058` and `0x12c00008` should usually match because both are produced from requested size `0x800`

If they do not match in a traced OEM run:

- allocator state may have advanced between calls
- or the current interpretation still needs refinement

### Additional compare targets

Later notes make these additional addresses worth tracing in OpenWrt:

- `0x12c00040`
- `0x12c00100`
- `0x12c00120`
- `0x12c00140`
- `0x12c00180`

Current candidate meaning:

- `0x12c00040` status/ack-or-mask path
- `0x12c00100` core0 TX-like control
- `0x12c00120` core1 TX-like control
- `0x12c00140` core0 RX-like control
- `0x12c00180` core1 RX-like control

These direction labels are still provisional.

### Higher-level init control point

The repaired wrapper around `0x803ad8a4` indicates the OEM flow above step1/step2 does:

- one-time latch check
- `Enet Starting GMAC Init..!` log
- precheck/status helper
- step1
- step2
- optional helper near `0x803a8774`
- yield/delay

Direct OpenWrt use:

- if you add very early tracepoints around the first GENET bring-up call, compare their order against this wrapper sequence rather than only against the step1/step2 pair

### Updated practical compare list

If you only log a compact register set during OpenWrt bring-up, use this list first:

- `0x12c00004`
- `0x12c00008`
- `0x12c0000c`
- `0x12c00010`
- `0x12c00040`
- `0x12c00044`
- `0x12c00048`
- `0x12c0004c`
- `0x12c00050`
- `0x12c00054`
- `0x12c00058`
- `0x12c00070`
- `0x12c00100`
- `0x12c00104`
- `0x12c00120`
- `0x12c00124`
- `0x12c00140`
- `0x12c00144`
- `0x12c00180`
- `0x12c00184`

## Control pass: derived FPM and MBDMA values

This section folds in the newer allocator/caller-chain notes and upgrades several values from comparison guesses to derived expectations.

### High-confidence FPM constants

Board-path FPM init inputs:

- requested FPM buffer size: `0x100`
- FPM HW base KSEG1: `0xb2200000`
- FPM HW physical/register view: `0x12200000`

Derived allocation length:

- `0x100 * 0x8000 + 0x100 = 0x00800100`

Confirmed FPM buffer-size class mapping:

- `0x100 -> class 7`
- `0x200 -> class 0`
- `0x400 -> class 2`
- `0x800 -> class 6`

Board-path encoded class:

- allocator `+0x04 = 7`
- HW field written at `0x12200040`, bits `26:24`

### High-confidence pool-size table

Confirmed default pool-size table values:

- `0x800`
- `0x400`
- `0x200`
- `0x100`

Derived allocator state:

- size shift bits: `8`
- largest/default pool size: `0x800`

Derived pool-class map used by the sized MBDMA path:

- `class(0x100) = 3`
- `class(0x200) = 2`
- `class(0x400) = 1`
- `class(0x800) = 0`

### Derived FPM HW alloc/free addresses

With FPM HW base `0xb2200000`, the sized-wrapper path resolves to:

- size `0x100 -> 0xb2200218 -> 0x12200218`
- size `0x200 -> 0xb2200210 -> 0x12200210`
- size `0x400 -> 0xb2200208 -> 0x12200208`
- size `0x800 -> 0xb2200200 -> 0x12200200`

These are now the best current expected values for the corresponding GMAC/MBDMA registers:

- `0x12c0004c = 0x12200218`
- `0x12c00050 = 0x12200210`
- `0x12c00054 = 0x12200208`
- `0x12c00058 = 0x12200200`
- `0x12c00008 = 0x12200200`

### Correct interpretation of `0x12c00010`

This value is now stronger than “backing-base-derived.”

Best current interpretation:

- `0x12c00010 = aligned_fpm_ddr_backing_base & 0x1fffffff`

Driver/FW side assignment:

- allocator `+0x0c = (allocated_ptr + 0xff) & 0xffffff00`
- `0x12200044 = (allocated_ptr + 0xff) & 0x1fffff00`
- `0x12c00010 = allocator[+0x0c] & 0x1fffffff`

Practical meaning:

- `0x12c00010` is the aligned FPM DDR backing base in bus-visible form
- it is not the allocator object pointer
- it is not a simple ring-base constant

### Additional FPM compare addresses

Add these to the OpenWrt compare set:

- `0x12200040`
- `0x12200044`
- `0x12200200`
- `0x12200208`
- `0x12200210`
- `0x12200218`

### Updated control list

If you want the shortest high-value cross-check set spanning both FPM and GENET, use:

- `0x12200040`
- `0x12200044`
- `0x12200200`
- `0x12200208`
- `0x12200210`
- `0x12200218`
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

### Development implication

The OEM path now strongly suggests:

- FPM allocator hardware init at `0x12200000`
- FPM DDR backing allocation
- pool lookup-table construction
- GMAC/MBDMA register programming from FPM-derived alloc/free addresses

If OpenWrt only initializes GENET-side DMA state and does not reproduce the FPM side, token/descriptor consumption can still fail even if MDIO, link, and basic GMAC probe appear correct.

## Final control pass

This section freezes the current best OpenWrt-facing value set after another full reread of the reverse-note set.

### Frozen values to compare first

If you want the shortest high-value set for OpenWrt trace or `devmem` comparison, use these as the frozen control set:

- FPM side:
  - `0x12200040`
  - `0x12200044`
  - `0x12200200`
  - `0x12200208`
  - `0x12200210`
  - `0x12200218`
- GENET/MBDMA side:
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

### Frozen expected values

Current best expected values:

- `0x12c00004 = (old & 0xffffe000) | 0x9010`
- `0x12c00044 = 0x02020202`
- `0x12c00048 = 0x0000000f`
- `0x12c0004c = 0x12200218`
- `0x12c00050 = 0x12200210`
- `0x12c00054 = 0x12200208`
- `0x12c00058 = 0x12200200`
- `0x12c00008 = 0x12200200`
- `0x12c00010 = aligned_fpm_ddr_backing_base & 0x1fffffff`
- `0x12c00070` step2 behavior:
  - core/interface `0` path sets `0x00000003`
  - nonzero core/interface path sets `0x00030000`

### Frozen board-path setup values

Current best board-path setup values:

- FPM HW base: `0x12200000`
- requested FPM buffer size: `0x100`
- FPM allocation length: `0x00800100`
- FPM pool classes:
  - size `0x100 -> class 3 alloc/free address 0x12200218`
  - size `0x200 -> class 2 alloc/free address 0x12200210`
  - size `0x400 -> class 1 alloc/free address 0x12200208`
  - size `0x800 -> class 0 alloc/free address 0x12200200`

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- actual runtime value of `aligned_fpm_ddr_backing_base`
- exact semantic meaning of `0x12c0000c` high preserved bits
- exact TX/RX semantics of:
  - `0x12c00100`
  - `0x12c00120`
  - `0x12c00140`
  - `0x12c00180`
- semantic meaning of the `0x14e0xxxx` board/profile block

### Final OpenWrt control conclusion

For TC7200U, the working hypothesis should now be:

- OpenWrt must be checked against both the `0x12200000` FPM side and the `0x12c00000` GENET/MBDMA side
- if only the GENET-side sequence is reproduced, descriptor/token consumption may still fail
- the first successful control comparison should focus on whether OpenWrt ever produces OEM-equivalent values for:
  - `0x12200044`
  - `0x12c00010`
  - `0x12c0004c/50/54/58/08`

## Control pass: additional usable FPM/token values

This section was added after the June 9 full reread. It folds in the new packet-token reverse note and extracts the values that are directly usable for OpenWrt bring-up control.

### Control result

No contradiction was found against the June 8 frozen value set. The June 9 note adds usable FPM/token-side facts that explain why matching only GENET-side register writes may still be insufficient.

### Additional hardware addresses to control

Add these FPM-side addresses to the short OpenWrt compare set:

- `0x12200010`
- `0x12200014`
- `0x12200040`
- `0x12200044`
- `0x12200200`
- `0x12200208`
- `0x12200210`
- `0x12200218`

Current best meanings:

- `0x12200010` = FPM interrupt/control enable-mask candidate
- `0x12200014` = FPM interrupt pending/status + ack/clear candidate
- `0x12200040` = encoded buffer-size class field location
- `0x12200044` = low bus-visible aligned backing-base field
- `0x12200200 + pool_class * 8` = sized FPM alloc/free endpoints

### Additional frozen software-side constants

These are not MMIO values, but they are now high-value development constants for interpreting the vendor datapath:

- main DMA/FPM allocator object: `0x81848740`
- secondary packet allocator object: `0x8187bc70`
- secondary allocator init latch: `0x8187bc68`
- packet-header slot size: `0xe0`
- packet-header arena allocation size: `0x700010`
- FPM data-buffer stride per token index: `0x100`

### Additional frozen token-format values

Current best token model:

- valid bit: `0x80000000`
- high-bits field: `bits29:28`
- token-index field: `bits27:12`
- token-index mask: `0x0ffff000`
- per-token backing-buffer stride: `0x100`

Practical OpenWrt implication:

- vendor DMA/FPM free and translation paths do not treat the data address as an isolated descriptor-owned pointer
- they derive or reconstruct it through `backing_base + extra_offset + token_index * 0x100`

### What to check first in OpenWrt

For the TC7200U OpenWrt port, the next control questions should be:

- does anything program `0x12200040` and `0x12200044` with OEM-like timing and values
- does anything ever produce an OEM-like `0x12c00010` backing-base value
- are `0x12c0004c/50/54/58/08` treated as FPM endpoint addresses instead of descriptor-ring bases
- does the RX/TX path assume plain linear buffer pointers where the OEM path appears to use token-backed FPM buffers

### Updated bring-up conclusion

The usable development model is now:

- GENET/MBDMA global setup depends on prior FPM allocator setup at `0x12200000`
- the sized MBDMA values are best treated as FPM alloc/free endpoints
- the backing-base value at `0x12c00010` is part of the token/data-address translation model
- if OpenWrt does not reproduce the FPM-side setup or at least account for the token-backed address model, RX/TX descriptor or buffer consumption can remain stalled even when link and basic MAC init look correct

## Control pass: corrected step2 masks and additional status values

This section folds in the newer June 9 control logs that closed the step2-mask ambiguity and added more FPM/MBDMA compare values.

### Corrected `0x12c00070` interpretation

The earlier `0x00003000` interpretation is superseded.

Current best interpretation:

- selected core/interface `0` path sets `0x00000003`
- selected nonzero core/interface path sets `0x00030000`
- the paired disable path clears the corresponding selected core-pair

Practical implication:

- OpenWrt should be checked for selected-core pair control, not for an unconditional `0x00003000` write

### Additional frozen compare values

New high-value compare values and reads from the newer notes:

- `0x12c00040 = status | 0xdea9` candidate status/ack/mask write
- `0x12200050` FPM overflow/underflow count register
- `0x12200054` FPM FIFO/token status register
- `0x12200058` FPM invalid token free count register
- `0x1220005c` FPM invalid token multifree count register

These do not replace the earlier endpoint values. They add control/status coverage around the same FPM-backed datapath.

### Additional frozen software-side facts

- `0x8187bc60` is active packet-allocator static state, not heap-header space
- `0x8187bc70` remains the fixed packet-allocator object storage
- token `bits0..11` carry requested allocation-size low bits on the allocation path

### Updated high-value compare set

If you want the compact current control set for OpenWrt instrumentation, include:

- `0x12200040`
- `0x12200044`
- `0x12200050`
- `0x12200054`
- `0x12200058`
- `0x1220005c`
- `0x12200200`
- `0x12200208`
- `0x12200210`
- `0x12200218`
- `0x12c00004`
- `0x12c00008`
- `0x12c0000c`
- `0x12c00010`
- `0x12c00040`
- `0x12c00044`
- `0x12c00048`
- `0x12c0004c`
- `0x12c00050`
- `0x12c00054`
- `0x12c00058`
- `0x12c00070`

## Daily control pass after full reread

This section records the result of another full reread of the reverse-note set in `reverse`.

### Daily control result

No contradiction was found against the current FPM-backed GENET/MBDMA model.

The daily reread confirms that the highest-value OpenWrt-facing facts remain:

- `0x12c00010` is FPM backing-base-derived
- `0x12c0004c/50/54/58/08` are FPM endpoint addresses
- `0x12c00070` must be compared with selected-core masks:
  - `0x00000003`
  - `0x00030000`
- `0x12c00040` is worth tracing as candidate `status | 0xdea9`

### Daily short compare set

If you want the shortest current control set for OpenWrt tracepoints or `devmem` checks, use:

- `0x12200040`
- `0x12200044`
- `0x12200050`
- `0x12200054`
- `0x12200058`
- `0x1220005c`
- `0x12200200`
- `0x12200208`
- `0x12200210`
- `0x12200218`
- `0x12c00004`
- `0x12c00008`
- `0x12c0000c`
- `0x12c00010`
- `0x12c00040`
- `0x12c00044`
- `0x12c00048`
- `0x12c0004c`
- `0x12c00050`
- `0x12c00054`
- `0x12c00058`
- `0x12c00070`

### Daily software-side constants worth keeping nearby

- main allocator: `0x81848740`
- packet-allocator static state: `0x8187bc60`
- packet-allocator init latch: `0x8187bc68`
- packet-allocator object: `0x8187bc70`
- packet-header arena allocation: `0x700010`
- packet-header slot size: `0xe0`
- token stride: `0x100`

## Additional usable values from DQM/CP2 and RX-token reread

This section was added after another full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-09-dqm-cp2-fpm-progress-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-09-ghidra-fpm-datatypes.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-09-ghidra-fpm-packet-token-rx-roundtrip.md`

### Second-pass MMIO values to trace if first-pass GENET/FPM values look correct

DQM-side FPM endpoint mirror/programming values:

- `0x16090038 = 0x12200200`
- `0x16090044 = 0x12200044 & 0x0fffffff`
- `0x16090128 = 0x12200208`
- `0x1609012c = 0x12200210`
- `0x16090130 = 0x12200218`
- `0x16090068 = 0xc0001617`

DQM/CP2 event and submit registers worth tracing:

- `0x16045740`
- `0x16045a00`
- `0x16045a04`
- `0x16045a08`
- `0x16045a0c`
- `0x16045a10`
- `0x16045a18`
- `0x16045a1c`
- `0x16045a80`
- `0x13401910`

Current best meanings:

- `0x16045740` = DQM event FIFO
- `0x16045a80` = DQM event/status
- `0x16045a00` = CP2 event pull control
- `0x16045a04` = CP2 submit trigger
- `0x16045a08` = CP2 token submit
- `0x16045a0c` = CP2 aux submit
- `0x16045a10` = CP2 result token
- `0x16045a18` = CP2 submit status
- `0x16045a1c` = CP2 pull status
- `0x13401910` = CP2/DQM ack write

These are not first-pass Linux driver constants. They are second-pass control points if OEM-equivalent FPM and GENET/MBDMA values are present but token or packet consumption still fails.

### Additional software-side values now usable

Working structure sizes:

- `tc7200_fpm_allocator = 0x20048`
- `tc7200_fpm_packet_allocator = 0x24`
- `tc7200_fpm_packet_header = 0xe0`
- `tc7200_fpm_packet_inner_header = 0x30`

Working packet-header model values:

- packet-header slot size: `0xe0`
- packet-header arena allocation: `0x700010`
- packet-header `+0x04 -> +0x20`
- packet-header `+0x08 -> +0x20`
- inner-header `+0x18 -> outer +0x64`
- RX worker wrote outer `+0x12 = 0x64` in one path
- RX worker wrote outer `+0x12 = 0x78` in alternate path
- RX-specific path uses token low12 as payload length

Working token/FPM values reinforced by the RX/release pass:

- common token return/free port: `0x12200200`
- valid-token bit: `0x80000000`
- special pre-return mailbox condition: `bit30`
- token index field: `bits27:12`
- saved high-bits field: `bits29:28`
- token low-size field on allocation path: `bits11:0`
- token-indexed backing-buffer stride: `0x100`

### Runtime-overlay values for correlation only

Do not hardcode these into Linux. Use them only when correlating OEM runtime behavior:

- `0x80004040..0x800056xx` acts as mutable DQM runtime overlay in this subsystem
- `0x800040e8 + queue_id*4` queue class/mode table
- `0x80004168 + queue_id*4` service timestamp/age table
- `0x800041f8` token-or-command reject counter
- `0x800041fc` invalid-token counter candidate
- `0x80004220` direct-token path count
- `0x8000423c..0x80004250` low12 mismatch patch words

### Updated development use

Use the existing first-pass control set first:

- FPM side `0x12200000`
- GENET/MBDMA side `0x12c00000`

If those compare cleanly against OEM values and RX/TX still stalls, use this second-pass control set:

- confirm tokens are actually written to `0x12200200`
- compare DQM-side mirror programming at:
  - `0x16090038`
  - `0x16090044`
  - `0x16090128`
  - `0x1609012c`
  - `0x16090130`
- check whether the OpenWrt path is assuming plain linear DMA buffer ownership where OEM code reconstructs packet headers and data addresses from token index, packet-header slot size `0xe0`, and backing-buffer stride `0x100`

## Third-pass DQM/CP2 control values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-09-dqm-fpm-cp2-ghidra-progress.md`

### When to use this set

Use this third-pass set only after:

- first-pass FPM values around `0x12200000`
- second-pass GENET/MBDMA values around `0x12c00000`

already look OEM-like, but packet movement still fails.

### Third-pass MMIO values to trace

CP2 pull / submit / result block:

- `0x16045a00`
- `0x16045a04`
- `0x16045a08`
- `0x16045a0c`
- `0x16045a10`
- `0x16045a18`
- `0x16045a1c`
- `0x16045a20`
- `0x16045a24`
- `0x16045a28`
- `0x16045a2c`
- `0x16045a30`
- `0x16045a80`
- `0x16045a84`
- `0x16045a88`
- `0x16045a8c`

Current best meanings:

- `0x16045a00` CP2 event pull control
- `0x16045a04` CP2 submit trigger
- `0x16045a08` CP2 submit token
- `0x16045a0c` CP2 submit aux
- `0x16045a10` CP2 result token
- `0x16045a18` CP2 submit status
- `0x16045a1c` CP2 pull status
- `0x16045a20` queue command word
- `0x16045a24` queue command trigger
- `0x16045a28` queue command result token
- `0x16045a2c` queue command busy-mask low
- `0x16045a30` queue command busy-mask high
- `0x16045a80` DQM event/status
- `0x16045a84` queue/event enable mask candidate
- `0x16045a88` queue cfg/status candidate
- `0x16045a8c` queue mode/control candidate

Per-queue and table regions:

- `0x16045c00..0x16045d04`
- `0x16082000 + queue_id*0x100`
- `0x16045000`
- `0x16045100`
- `0x16045200`
- `0x16050000`
- `0x16001de0..0x16001dfc`

Current best meanings:

- `0x16045c00..0x16045d04` per-queue CP2 pull programming
- `0x16082000 + queue_id*0x100` per-queue control
- `0x16045000` queue table A
- `0x16045100` queue table B
- `0x16045200` queue table C
- `0x16050000` queue clear/index table region
- `0x16001de0..0x16001dec` control-mailbox input words
- `0x16001df0..0x16001dfc` control/event mailbox output words

### Third-pass software-state values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- `0x800040c4` event07 / CP2 pull queue mask
- `0x800040e8 + queue_id*4` queue class/mode table
- `0x80004168 + queue_id*4` queue service timestamp/age table
- `0x800050a8 + queue_id*0x2c` per-queue policy table base
- `0x800050b8 + queue_id*0x2c` budget limit
- `0x800050bc + queue_id*0x2c` budget used
- `0x800050c0 + queue_id*0x2c` budget high-water
- `0x800050c4 + queue_id*0x2c` per-queue flags
- `0x800050c6 + queue_id*0x2c` per-queue low12 limit
- `0x800050cc + queue_id*0x2c` per-queue extended mode field
- `0x800050d0 + queue_id*0x2c` per-queue overhead field

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: if packet movement still stalls, DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state become the next most likely missing OEM-specific layer

## Fourth-pass DQM mailbox and slot-service control values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-11-ghidra-dqm-fpm-cp2-progress-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-11-ghidra-dqm-mailbox-region-progress-log.md`

### When to use this set

Use this fourth-pass set only after:

- first-pass FPM values around `0x12200000`
- second-pass GENET/MBDMA values around `0x12c00000`
- third-pass DQM/CP2 queue-control values around `0x16045a00..0x16082000`

already look OEM-like, but packet movement or token return still fails.

### Fourth-pass MMIO values to trace

Queue-profile and mailbox cluster:

- `0x16001804`
- `0x1600180c`
- `0x16001810`
- `0x16001818`
- `0x16001a00 + queue_id * 0x10`
- `0x16001d00..0x16001d0c`
- `0x16001d10`
- `0x16001d14`
- `0x16001d20`
- `0x16001d24`
- `0x16001028`

Slot-control and per-slot region cluster:

- `0x16040084`
- `0x1604008c`
- `0x16040090`
- `0x16040120`
- `0x16040144`
- `0x16040194`
- `0x16040198`
- `0x160401a0`
- `0x16040500`
- `0x16040510`
- `0x16040700 + slot*4`
- `0x16041000 + slot*0x20`
- `0x16042000 + slot*0x40`
- `0x16043000 + slot*0x40`
- `0x16046000 + slot*0x10`
- `0x16050000`
- `0x16052000`

Service-path control values:

- `0x160400c0`
- `0x160400c4`
- `0x160400e0`
- `0x160400e4`

### Current best meanings

- `0x16001804` = DQM queue bitmap A
- `0x1600180c` = queue update or apply trigger
- `0x16001810` = DQM queue bitmap B or paired mask
- `0x16001818` = queue IRQ, status, or ack path
- `0x16001a00 + queue_id * 0x10` = queue profile entry base
- `0x16001d00..0x16001d0c` = mailbox command input words
- `0x16001d10` = mailbox reply or state low word
- `0x16001d14` = mailbox reply mode or status
- `0x16001d20` = command or selector word used by local DQM helpers
- `0x16001d24` = return-PC or context carry for the cmd06 helper
- `0x16001028` = status or value sink used by small command helpers
- `0x16040084 = 0x12200200` = shared FPM pool0 endpoint carried into DQM static init
- `0x1604008c` = submit or busy register with observed forms:
  - `(selector << 12) | 0x580`
  - `slot | 0x780`
  - `slot | 0x880`
- `0x16040090` = ctrl580 status word, with low 7 bits consumed by slot-selection logic
- `0x16040198` = slot commit request bitmask
- `0x160401a0` = slot commit done or ack bitmask
- `0x16040500` = low 16 bits behave like a free-slot bitmap
- `0x16040510` = slot validation or service bitmap
- `0x16040700`, `0x16041000`, `0x16042000`, `0x16043000`, and `0x16046000` = per-slot hardware region banks
- `0x160400c0`, `0x160400c4`, `0x160400e0`, and `0x160400e4` = temporary service-control registers rewritten around the CP2 or FPM drain path
- `0x16040144` can be mirrored into `0x12200200` during the CP2 or FPM service path
- `0x16040120` is written with `0x13`, `0x11`, and `0x10` around slot service or finalize paths
- `0x16040194 = 0x19151617` appears in the fixed batch queue recipe
- `0x16050000` remains a useful queue clear or index table compare region
- `0x16052000` receives swapped word-pair table copies

### Queue-profile recipe values worth carrying

The fixed direct batch recipe at `0x80c7b95c` is now worth carrying as a concrete DQM compare set.

Tuple format below is:

- `(queue_type_count, total_units, step_low16_or_extra)`

Observed direct installs:

- `queue 0x11 -> (2, 0x10, 0)`
- `queue 0x12 -> (2, 0x10, 0)`
- `queue 0x10 -> (4, 0x20, 0)`
- `queue 0x13 -> (2, 0x80, 0)`
- `queue 0x14 -> (1, 0x40, 0)`
- `queue 0x1b -> (3, 0x0c, 0)`
- `queue 0x15 -> (3, 0x30, 0)`
- `queue 0x16 -> (3, 0xc0, 0)`
- `queue 0x17 -> (3, 0xc0, 0)`
- `queue 0x18 -> (3, 0x30, 0)`
- `queue 0x19 -> (1, 0x10, 0)`
- `queues 0x00..0x07 -> (2, 0x40, 0)`
- `queues 0x08..0x0f -> (2, 0xc8, 0)` with profile limit `0x64`
- `queue 0x1a -> (2, 0x40, 0)`

Additional fixed writes seen in the same recipe:

- `0x16001b5c = 0x08`
- `0x16001b6c = 0x38`
- `0x16001b7c = 0x38`
- `0x16001b9c = 0x08`
- `0x16001bac = 0x20`
- `0x16040194 = 0x19151617`

### Runtime and software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- `0x80007000` = runtime allocation cursor
- `0x80007004` = runtime remaining free byte count
- `((addr - 0x80004000) >> 2) & 0xffff` = DQM backing-address to word-index rule
- `0x80007048` = serviced-slot runtime mask
- `0x8000704c` = total active quota input for slot rebalance
- `0x80007068 + slot*0x10` = per-slot quota table
- `0x80007174` = mailbox command `0x70` runtime table
- `0x8000800c bit 0x10000` = mailbox work or pending gate
- `0x800080d4 bit 0x80` = ctrl880 busy flag
- `0x800080e8 bit0/bit1` = CP2 or FPM drain-state flags
- `0x80008100 + slot*4 bit 0x10` = slot needs CP2 or FPM service

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: if packet movement still stalls, DQM mailbox command handling, queue-profile writes, slot commit, and CP2 or FPM service plumbing become the next most likely missing OEM-specific layer

Practical implication:

- if OpenWrt starts matching OEM values in the first three stages but traffic still fails, check whether anything equivalent exists for:
  - queue profile writes to `0x16001a00 + queue_id * 0x10`
  - queue apply or ack around `0x1600180c` and `0x16001818`
  - slot commit through `0x1604008c`, `0x16040198`, and `0x160401a0`
  - token-return service back into `0x12200200`

## Fifth-pass DQM event1800008 selector and FPM request values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-11-dqm-event1800008-path-progress-log.md`

### When to use this set

Use this fifth-pass set only after:

- first-pass FPM values around `0x12200000`
- second-pass GENET/MBDMA values around `0x12c00000`
- third-pass DQM/CP2 queue-control values around `0x16045a00..0x16082000`
- fourth-pass DQM mailbox and slot-service values around `0x160018xx`, `0x16001dxx`, and `0x160400xx`

already look OEM-like, but event-driven packet movement, selector dispatch, or token request/return still fails.

### Fifth-pass MMIO values to trace

Event mask, ack, and selector-publish cluster:

- `0x16001010`
- `0x16001014`
- `0x16001810`
- `0x16001818`
- `0x16001c00 + selector * 0x10`
- `0x16001d30`
- `0x16001d40`
- `0x16001d50`

Selector request and event-routing block:

- `0x16001320`
- `0x16001324`
- `0x16001328`
- `0x1600132c`
- `0x16001dbc`
- `0x16001902`
- `0x16001906`
- `0x1600190a`
- `0x1600190e`
- `0x16052000`

GENET target and FPM endpoint values:

- `0x12c00500`
- `0x12c00510`
- `0x12200218`
- `0x12200210`
- `0x12200208`
- `0x12200200`
- `0x12200224`

### Current best meanings

- `0x16001010` = global DQM event mask or enable side register
- `0x16001014` = global DQM event ack or enable side register
- `0x16001810` = queue/event mask or bitmap side register
- `0x16001818` = queue/event ack/status side register
- `0x16001c00 + selector * 0x10` = selector index or port publish and ack base
- `0x16001d30`, `0x16001d40`, and `0x16001d50` = event source-index slots for three direct pending-bit helpers
- `0x16001320` = selector request word B
- `0x16001324` = selected FPM token or value
- `0x16001328` = selector request context pointer
- `0x1600132c` = payload size with flags `| 0x16000`
- `0x16001dbc` = selector request selector latch
- `0x16001902`, `0x16001906`, `0x1600190a`, and `0x1600190e` = queue/event halfword gates initialized to `0x40`
- `0x16052000` = DQM pair-copy table/window loaded during runtime init
- `0x12c00510` and `0x12c00500` = selector-routed GENET target registers for service selectors `0x0a..0x0d`
- `0x12200218`, `0x12200210`, `0x12200208`, and `0x12200200` = size-selected FPM request/return endpoints
- `0x12200224 = (record_word_b & 0xfffff000) | 0x801` in several selector-driven or event-driven routing paths

### Event1800008 path values worth carrying

Current best staged interpretation of the event `0x01800008` path:

- runtime init installs queue profiles, selector state, pair-copy tables, and event masks
- event handler masks `0x01800008`, services pending work, acknowledges DQM queue/global bits, then re-arms the event
- central dispatcher checks pending mask `0x40383c08`
- selector path routes selectors `0x0a..0x0d` either into CP2 `f801` GENET-target pushes or, for unexpected selectors, back into `0x12200200`
- selector FPM request gate chooses endpoint by payload size plus `4`:
  - `< 0x101 -> 0x12200218`
  - `< 0x201 -> 0x12200210`
  - `< 0x401 -> 0x12200208`
  - otherwise `0x12200200`

### Runtime and software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- `0x80007110` and `0x80007114` = runtime selector gate state
- `0x80007118 = 0x12c00510` and `0x8000711c = 0x12c00500` = runtime GENET target pointers
- `0x80007120` = runtime output mode for one direct pending-bit helper path
- `0x80007128` = selector/FPM request enable gate
- `0x8000712c` = selector/FPM request attempt counter
- `0x80007138` = selector fallback counter
- `0x80007148` = selector busy-return counter
- `0x8000800c & 0x40383c08` = event pending-mask state
- `0x80008160` bits `0x04`, `0x20`, and `0x40` = event-service wait-state bits on this path

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: if traffic still stalls, the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior become the next most likely missing OEM-specific layer

Practical implication:

- if OpenWrt reproduces the earlier control surfaces but still fails to move packets, compare whether there is any OEM-equivalent behavior for:
  - event mask and ack writes around `0x16001010/14` and `0x16001810/18`
  - selector activity at `0x16001c00`
  - request-block programming at `0x16001320..0x1600132c`
  - target routing toward `0x12c00500` and `0x12c00510`
  - size-selected token request/return use at `0x12200218/10/08/00`
  - page-plus-flag programming at `0x12200224`

## Sixth-pass selector lookup, preload, and b604 setup values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-12-dqm-cp2-fpm-selector-cleanup-log.md`

### When to use this set

Use this sixth-pass set only after:

- first-pass FPM values around `0x12200000`
- second-pass GENET/MBDMA values around `0x12c00000`
- third-pass DQM/CP2 queue-control values around `0x16045a00..0x16082000`
- fourth-pass DQM mailbox and slot-service values around `0x160018xx`, `0x16001dxx`, and `0x160400xx`
- fifth-pass event `0x01800008` selector/request values

already look OEM-like, but selector-driven packet movement or event-fed token work still fails.

### Sixth-pass MMIO values to trace

Queue/profile preload and selector port values:

- `0x16001c00 + selector * 0x10`
- `0x16001dc0`
- `0x16001dd0`

CP2 or DQM global and table-root values:

- `0x16040010`
- `0x1604007c`
- `0x16040080`
- `0x16040084`
- `0x16040564`
- `0x16040568`
- `0x160405c0`
- `0x160405c4`
- `0x16040640`
- `0x16040644`

Related fixed target values:

- `0x13401900`
- `0x13401904`
- `0x14201908`
- `0x1420190c`
- `0x12c00510`
- `0x12c00500`
- `0x12200200`
- `0x12200224`

### Current best meanings

- `0x16001dc0` = DQM queue/profile preload port B used by queue/profile `0x1c`
- `0x16001dd0` = DQM queue/profile preload port A used by queue/profile `0x1d`
- `0x16040010` = packed three-enable-bit register:
  - bit2 from arg2
  - bit1 from arg1
  - bit0 from arg0
- `0x1604007c = 0x11001cef` = global CP2/DQM control word candidate
- `0x16040080 = 1` = global enable
- `0x16040084 = 0x12200200` = shared FPM pool0 endpoint carried into the global `b604` setup
- `0x16040564` and `0x16040568` = selector-derived command words
- `0x160405c0` and `0x160405c4` = low29 GENET target addresses
- `0x16040640` and `0x16040644` = fixed CP2 command word `0x04208000`
- `0x12c00510` and `0x12c00500` remain selector-routed GENET target registers
- `0x12200224` remains endpoint-like but still not safe to assign a final hardware identity

### Selector lookup and preload facts worth carrying

Mechanically-proven selector/preload behavior:

- queue/profile `0x1c` preload helper installs a small descriptor and preloads values `0..7`
- queue/profile `0x1d` preload helper installs a descriptor and preloads `0x50` backing addresses:
  - `0x16010000 + entry_index * 0x140`
- selector record-field normalization rule:
  - record field `0x0d..0x1c -> lookup index 0..15`
  - invalid values return `0xff`
- repeated CP2 selector command word:
  - `0x04208000`
- repeated bus-visible address conversion:
  - `mapped_addr & 0x1fffffff`

### Runtime and software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- `0x80007124` = selector context allocation cursor
- `0x80007128` = selector lookup enable gate
- selector lookup/context table base `0x8000714c`, stride `0x18`
- table layout currently worth carrying:
  - `+0x04` mapped context A pointer
  - `+0x08` mapped context B pointer
  - `+0x0c` per-entry counter
  - `+0x10` context A backing address
  - `+0x14` context B backing address
- selector/FPM counters:
  - `0x8000712c`
  - `0x80007130`
  - `0x80007134`
  - `0x80007138`
  - `0x8000713c`
  - `0x80007140`
  - `0x80007144`
  - `0x80007148`

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- exact row or column meanings of the table body at `0x16040400..0x160406c4`
- final hardware identity of `0x12200224`
- exact semantic meaning of the selector context table halfword fields at `+0x00` and `+0x02`
- exact semantic meaning of context byte6 values `0x60` and `0x00`

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: if traffic still stalls, selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup become the next most likely missing OEM-specific layer

Practical implication:

- if OpenWrt reproduces the earlier control surfaces but still fails to move packets, compare whether there is any OEM-equivalent behavior for:
  - preload writes to `0x16001dc0` and `0x16001dd0`
  - selector lookup/context setup around `0x80007124`, `0x80007128`, and `0x8000714c + index * 0x18`
  - `0x16040010` three-bit enable programming
  - selector-derived globals `0x1604007c`, `0x16040080`, and `0x16040084`
  - repeated command word `0x04208000`
  - repeated low29 address conversion with `& 0x1fffffff`

## Seventh-pass event1800008 finalize, publish, and lane-routing values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-12-dqm-event1800008-cleanup-log.md`

### When to use this set

Use this seventh-pass set only after:

- first-pass FPM values around `0x12200000`
- second-pass GENET/MBDMA values around `0x12c00000`
- third-pass DQM/CP2 queue-control values around `0x16045a00..0x16082000`
- fourth-pass DQM mailbox and slot-service values around `0x160018xx`, `0x16001dxx`, and `0x160400xx`
- fifth-pass event `0x01800008` selector/request values
- sixth-pass selector lookup, preload, and `b604` setup values

already look OEM-like, but event-driven request submit, finalize, publish, or sideband output behavior still fails.

### Seventh-pass MMIO values to trace

Request engine and finalize block:

- `0x16001300`
- `0x16001304`
- `0x16001308`
- `0x1600130c`
- `0x1600131c`
- `0x16001320`
- `0x16001324`
- `0x16001328`
- `0x1600132c`
- `0x16001330`
- `0x16001334`
- `0x1600133c`
- `0x16001da0`
- `0x16001da4`
- `0x16001da8`
- `0x16001dac`

Direct request and event-source words:

- `0x16001c30`
- `0x16001c34`
- `0x16001d30`
- `0x16001d40`
- `0x16001d50`

Gate and output-lane values:

- `0x16001902`
- `0x16001906`
- `0x1600190a`
- `0x1600190e`
- `0x16001912`
- `0x16001916`
- `0x16001d60`
- `0x16001d64`
- `0x16001d70`
- `0x16001d74`
- `0x13401ca0`
- `0x13401ca4`
- `0x13401cd0`
- `0x13401cd4`
- `0x14201c00`
- `0x14201c04`
- `0x14201c10`
- `0x14201c14`
- `0x14201c80`
- `0x14201c90`
- `0x12200224`

### Current best meanings

- `0x16001300..0x1600130c` = direct/shared request engine submit words
- `0x1600131c` = request engine result low bits
- `0x16001320..0x1600132c` = selector request block:
  - word B
  - FPM token/value
  - selected context
  - payload size flags
- `0x16001330..0x1600133c` = selector-request metadata/result block
- `0x16001da0..0x16001dac` = shared request metadata block
- `0x16001c30` and `0x16001c34` = direct request words A and B
- `0x16001d30`, `0x16001d40`, and `0x16001d50` = source index/token words for event `0x00080000`, `0x00100000`, and `0x00200000`
- `0x16001902` and `0x16001906` = mode1 lane gates
- `0x1600190a` and `0x1600190e` = mode2 lane gates
- `0x16001912` and `0x16001916` = selector16/17 special gates
- `0x16001d60/64/70/74` = default event100000 lane words
- `0x13401ca0/a4/cd0/cd4` = mode1 output lanes
- `0x14201c00/04/10/14` = mode2 output lanes
- `0x14201c80/90` = selector16/17 special output words
- `0x12200224` = repeatedly programmed page-bits-plus-`0x801` endpoint-like target, still not safe to finalize semantically

### Gate and finalize rules worth carrying

Current best behavior model:

- shared finalize helper rebuilds completed value from:
  - saved page bits
  - low result bits
- selector finalize helper does the same for the selector-request block
- if the selector gate value is zero, the completed value is returned to `0x12200200`
- if the selector gate value is nonzero, the result is published into the selector table/window
- mode1/mode2 and selector16/17 lane helpers use the same signed-positive halfword gate rule:
  - `0x0001..0x7fff = pass`
  - `0x0000 = fail`
  - `0x8000..0xffff = fail`
- after publish, several helpers write `0xffff`, likely as a consumed/busy/closed marker

### Runtime and software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- `0x8000800c` = event pending/status word
- `0x80008160` = service-state flags
- `0x80007100` = special mode used by selector16/17 special lane path
- `0x80007060` = forced selector/FPM gate mode
- `0x80007064` and `0x80007068` = default selector request contexts
- `0x80008014 + service_selector * 4` = cautious selector gate expression/value reference only

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- exact data-structure identity of `0x80008014 + service_selector * 4`
- exact final semantic identity of `0x12200224`
- rewritten logic for the suspicious dispatcher test `(0x80008160 & 0x10) != 1` before assembly proof
- forced-gate-mode per-index update behavior when the lookup index may remain `0xff`

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup must look right
- stage 7: if traffic still stalls, request-engine submit/finalize flow, selector-gate publish behavior, and mode-specific sideband output lanes become the next most likely missing OEM-specific layer

Practical implication:

- if OpenWrt reproduces the earlier control surfaces but still fails to move packets, compare whether there is any OEM-equivalent behavior for:
  - request-engine writes around `0x16001300..0x1600133c`
  - shared metadata writes around `0x16001da0..0x16001dac`
  - selector-gated publish behavior around `0x16001c00` and `0x80008014 + selector * 4`
  - direct request input at `0x16001c30` and `0x16001c34`
  - lane-gate values at `0x16001902/06/0a/0e/12/16`
  - default/mode1/mode2/special output words at `0x16001d60/64/70/74`, `0x13401ca0/a4/cd0/cd4`, and `0x14201c00/04/10/14/80/90`

## Eighth-pass alternate 0x80c8 family registration and selector-output values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-12-dqm-event1800008-80c8-family-cleanup-log.md`

### When to use this set

Use this eighth-pass set only after:

- first-pass FPM values around `0x12200000`
- second-pass GENET/MBDMA values around `0x12c00000`
- third-pass DQM/CP2 queue-control values around `0x16045a00..0x16082000`
- fourth-pass DQM mailbox and slot-service values around `0x160018xx`, `0x16001dxx`, and `0x160400xx`
- fifth-pass event `0x01800008` selector/request values
- sixth-pass selector lookup, preload, and `b604` setup values
- seventh-pass event1800008 finalize/publish/lane-routing values

already look OEM-like, but the active runtime family, selector-output port behavior, or alternate activation path still appears mismatched.

### Eighth-pass MMIO values to trace

Alternate-family activation values:

- `0x16001010`
- `0x16001014`
- `0x16001028`
- `0x1600163c`
- `0x16001640`
- `0x16001810`
- `0x16001818`
- `0x16001902`
- `0x16001906`
- `0x1600190a`
- `0x1600190e`

Selector output and page-translate values:

- `0x80008014 + selector * 4`
- `0x16001c00 + selector * 0x10`
- `0x16001c04 + selector * 0x10`
- `0x16001ca0`
- `0x16001cb0`
- `0x16001cc0`
- `0x16001cd0`
- `0x16001d80`
- `0x16001d90`
- `0x16001408`
- `0x1600140c`

Alias-window output values:

- `0x13401ca0`
- `0x13401ca4`
- `0x13401cd0`
- `0x13401cd4`
- `0x14201c00`
- `0x14201c04`
- `0x14201c10`
- `0x14201c14`
- `0x14201c80`
- `0x14201c90`

### Current best meanings

- the correct alternate registered handler is `0x80c8a118`, not `0x80c9a118`
- `0x16001640 = 0x8000003f` and `0x1600163c = 0x14` are now concrete alternate-family queue-control setup writes
- `0x16001818 = 0x40383c08` and `0x16001014 = 0x000c0000` remain queue/global rearm or ack-side writes in the alternate family
- `0x80008014 + selector * 4` remains a cautious selector-output gate expression/value reference
- `0x16001c00 + selector * 0x10` and `0x16001c04 + selector * 0x10` are now clearer as selector output word0/word1 bases in the alternate publish paths
- `0x16001408` and `0x1600140c` are the page-translate input/result pair used by direct request and selector10/11 request paths
- `0x1340xxxx` and `0x1420xxxx` remain active output-lane MMIO aliases, not code regions

### Alternate-family rules worth carrying

Current best alternate-family model:

- the `0x80c8` family services the same major pending bits as the earlier `0x80c7` family:
  - `0x00000008`
  - `0x00080000`
  - `0x00100000`
  - `0x00200000`
  - `0x40000000`
- selector A priority:
  - pending `0x800 -> selector 0x0b`
  - pending `0x400 -> selector 0x0a`
  - if both pending, `0x0b` wins
- selector B priority:
  - pending `0x2000 -> selector 0x0d`
  - pending `0x1000 -> selector 0x0c`
  - if both pending, `0x0d` wins
- fallback selector publish and selector18/19 publish use the same gate-and-publish pattern
- selector16/17 can route either:
  - into normal selector output word0/word1 pairs
  - or into special `0x14201c80/90` lanes when special mode and field tests pass

### Runtime and software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- alternate handler function address `0x80c8a118`
- alternate parent init function `fn_dqm_alt_runtime_init_register_event1800008_genet500_510_80c89cb4_candidate`
- selector A state at `0x80007110`
- selector B state at `0x80007114`
- active selector bitmap `0x80008000`
- selector state word `0x80008004`
- event pending/status `0x8000800c`
- service-state flags `0x80008160`

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- exact final semantic identity of `0x16001818` and `0x16001014` as pure ack vs enable vs mixed rearm writes
- exact data-structure identity of `0x80008014 + selector * 4`
- exact physical/bus meaning of the `0x1340xxxx` and `0x1420xxxx` alias windows
- any assumption that the `0x80c8` family is definitively the only active runtime path without more runtime proof

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup must look right
- stage 7: request-engine submit/finalize flow, selector-gate publish behavior, and mode-specific sideband output lanes must look right
- stage 8: if traffic still stalls, the alternate `0x80c8` runtime-family registration/activation writes, selector-output gating, and alias-window output paths become the next most likely missing OEM-specific layer

Practical implication:

- if OpenWrt reproduces the earlier control surfaces but still fails to move packets, compare whether there is any OEM-equivalent behavior for:
  - alternate activation writes around `0x1600163c`, `0x16001640`, `0x16001810/18`, and `0x16001010/14`
  - selector-output gating around `0x80008014 + selector * 4`
  - selector output words at `0x16001c00 + selector * 0x10` and `0x16001c04 + selector * 0x10`
  - page translation via `0x16001408/0x1600140c`
  - alias-window output paths under `0x1340xxxx` and `0x1420xxxx`

## Ninth-pass runtime selector and request-model values

This section carries forward a prior June 13 runtime-selector and request-model extraction pass.

Current control note:

- the standalone June 13 source log for that pass is not currently present in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse`
- keep this section as maintained carry-forward reverse data, not as a claim that the current-tree June 13 note set adds new hardware values by itself
- the current-tree June 13 note `2026-06-13-ghidra-cleanup-repair-plan.md` is process guidance only and does not change the OpenWrt MMIO or control compare set below

### When to use this set

Use this ninth-pass set only after:

- first-pass FPM values around `0x12200000`
- second-pass GENET/MBDMA values around `0x12c00000`
- third-pass DQM/CP2 queue-control values around `0x16045a00..0x16082000`
- fourth-pass DQM mailbox and slot-service values around `0x160018xx`, `0x16001dxx`, and `0x160400xx`
- fifth-pass event `0x01800008` selector/request values
- sixth-pass selector lookup, preload, and `b604` setup values
- seventh-pass event1800008 finalize/publish/lane-routing values
- eighth-pass alternate `0x80c8` registration/activation values

already look OEM-like, but the active runtime family, startup path, or request-model behavior still appears mismatched.

### Ninth-pass values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- runtime selector split value:
  - `0x8184006c`
- runtime startup vector slots:
  - `0x81917904`
  - `0x81917908`
  - `0x8191790c`
  - `0x81917910`
  - `0x81917914`
- alternate MSG_PROC slot target:
  - `0x8191790c = fn_dqm_alt_runtime_init_register_event1800008_genet500_510_80c89cb4_candidate`
- selector defaults and alternate-family state:
  - `0x80007110 = 0x0e`
  - `0x80007114 = 0x0c`
  - `0x80007118 = 0x12c00510`
  - `0x8000711c = 0x12c00500`
  - `0x80007064`
  - `0x80007068`
- request-model correlation surfaces:
  - `0x16001408`
  - `0x1600140c`
  - `0x16001300..0x1600130c`
  - `0x16001320..0x1600132c`
  - `0x16001330`
  - `0x16001334`
  - `0x1600133c`
  - `0x16001da0..0x16001dac`
  - `0x16001dbc`
  - `0x12200200`
  - `0x12200208`
  - `0x12200210`
  - `0x12200218`
  - `0x12200224`

### Current best meanings

- `0x8184006c` is now a concrete runtime-family threshold:
  - `< 0x00b0 -> older or legacy vector family`
  - `>= 0x00b0 -> alternate 0x80c8 vector family`
- the alternate event1800008 path is now tied to the MSG_PROC startup vector slot rather than to a direct call:
  - runtime selector writes `0x8191790c`
  - processor start helper launches the MSG_PROC core with that slot
- the alternate parent init helper now cleanly owns the previously-separated work for:
  - selector defaults
  - default selector contexts
  - queue/profile `0x1d` selector-context preload
  - queue/profile `0x1c` index preload
  - selector lookup-context table init
  - pair-copy bootstrap
  - `b604` CP2/DQM enable and table programming
  - lane-gate initialization
  - queue/global IRQ mask writes
  - event `0x01800008` registration and enable
- the direct request pending-bit `0x00000008` path is not an FPM-allocation path:
  - it page-translates through `0x16001408/0x1600140c`
  - it writes the shared request-engine block and request metadata block
  - it does not write `0x12200224`
  - it does not read the sized FPM endpoints `0x12200218/10/08/00`
  - it does not use the finalize helpers
- the selector `0x10/0x11` request path remains distinct:
  - endpoint selection uses `payload_size + 0xc0`
  - it writes `0x12200224`
  - it uses the shared request-engine and metadata block
- the selector `0x0a..0x0d` request path remains distinct:
  - endpoint selection uses `payload_size + 4`
  - it uses the selector-request block `0x16001320..0x1600132c`
  - it finalizes through `0x16001330/34/3c`
- selector `0x16/0x17` special-lane handling has an important no-fallback rule:
  - if the special condition matches but the special halfword gate is closed, the helper returns without falling back to normal selector output

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- exact final identity of `0x8184006c` beyond a runtime-family threshold or profile discriminator
- startup vector slot addresses `0x81917904..0x81917914` as if they were Linux-side hardware registers
- exact final semantic identity of `0x12200224`
- exact final hardware role of the `0xb340xxxx` and `0xb420xxxx` output-lane aliases
- any assumption that OpenWrt should reproduce the OEM processor-start sequence rather than only the resulting MMIO state

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup must look right
- stage 7: request-engine submit/finalize flow, selector-gate publish behavior, and mode-specific sideband output lanes must look right
- stage 8: alternate `0x80c8` runtime-family registration/activation writes, selector-output gating, and alias-window output paths must look right
- stage 9: if traffic still stalls, compare whether the active OEM runtime family and request model are mismatched:
  - runtime selector threshold at `0x8184006c`
  - MSG_PROC startup-vector installation at `0x8191790c`
  - direct request path versus selector `0x10/0x11` request path versus selector `0x0a..0x0d` request path

Practical implication:

- if OpenWrt reproduces the earlier MMIO control surfaces but still diverges from OEM behavior, do not assume that every event1800008 path:
  - uses `0x12200224`
  - allocates through `0x12200218/10/08/00`
  - enters through the same request block
  - finalizes through the same publish-or-return rule
- keep the runtime-selector and startup-vector findings as correlation aids, not as candidate Linux constants

## Tenth-pass Host-DQM selector and Stage1 wake-chain values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-13-host-dqm-msp-comms-guarded-enable-path-updated.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-13-stage1-event-slot-wait-chain-update.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-scheduler-post-signal-wake-chain.md`

### When to use this set

Use this tenth-pass set only after:

- first-pass FPM values around `0x12200000`
- second-pass GENET/MBDMA values around `0x12c00000`
- third-pass DQM/CP2 queue-control values around `0x16045a00..0x16082000`
- fourth-pass DQM mailbox and slot-service values around `0x160018xx`, `0x16001dxx`, and `0x160400xx`
- fifth-pass event `0x01800008` selector/request values
- sixth-pass selector lookup, preload, and `b604` setup values
- seventh-pass event1800008 finalize/publish/lane-routing values
- eighth-pass alternate `0x80c8` registration/activation values
- ninth-pass runtime-selector and request-model values

already look OEM-like, but packet workers still appear not to wake, MSG_PROC-side coordination still appears mismatched, or the remaining gap seems to be Host-DQM or Stage1 software wake plumbing rather than plain ENET/FPM register setup.

### Tenth-pass MMIO values to trace

Derived physical compare surfaces from the OEM KSEG1 aliases:

- selector `1` / MSP Host-DQM block:
  - `0xb8201814 -> 0x18201814`
  - `0xb8201818 -> 0x18201818`
  - `0xb8201820 -> 0x18201820`
- selector `3` / MSG_PROC Host-DQM block:
  - `0xb8601814 -> 0x18601814`
  - `0xb8601818 -> 0x18601818`
  - `0xb8601820 -> 0x18601820`

Additional selector bases worth correlating:

- `0xb8001800 -> 0x18001800`
- `0xb8401800 -> 0x18401800`
- `0xb8801800 -> 0x18801800`
- `0xb8a01800 -> 0x18a01800`

### Tenth-pass software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- Host-DQM dispatch tables and object list:
  - `0x81916fd8`
  - `0x819172d8`
  - `0x819175d8`
- Stage1 event-slot table base:
  - `0x81909698`
- Stage1 callback, unlock-callback, and post/signal state:
  - `0x819dcc38`
  - `0x819dcc4c`
  - `0x81a67cd0`
  - `0x81a67cec`
  - `0x81a67cf0`
  - `0x81803acc`

### Current best meanings

- the MSP comms channel object created by the OEM init wrapper is not selector `1` / MSP for this path:
  - it is selector `3` / MSG_PROC
  - queue index A is `0x1e`
  - channel index is `0x1f`
  - enable-path bit is `0x80000000`
  - guarded enable waits for `0xb8601820` bit31 clear, then sets bit31 in `0xb8601818` and `0xb8601814`
- selector-to-block mapping now worth carrying:
  - selector `0` -> UTP -> `0xb8001800`
  - selector `1` -> MSP -> `0xb8201800`
  - selector `2` -> FAP -> `0xb8401800`
  - selector `3` -> MSG_PROC -> `0xb8601800`
  - selector `4` -> MPEG_PROC -> `0xb8a01800`
  - selector `5` -> PMC -> `0xb8801800`
- Host-DQM dispatch tables now have useful read-side meanings:
  - `0x81916fd8` = dispatch table A = raise masks
  - `0x819172d8` = dispatch table B = `1`-based Stage1 event-slot ids
- selector `3` / MSG_PROC pending dispatch now reads:
  - `0xb8601814`
  - `0xb8601818`
  - table base index `0x60`
- selector `1` / MSP pending dispatch now reads:
  - `0xb8201814`
  - `0xb8201820`
  - table base index `0x20`
- the Host-DQM bridge is now better treated as:
  - selector pending bit
  - dispatch-table lookup
  - Stage1 event-slot raise
  - waiter wake
- Stage1 event-slot wait and clear behavior now worth carrying:
  - slot ids are `1`-based
  - wake path stores the full pending-mask snapshot for the waiter
  - outer wait-side clear is `slot->pending_mask_00 &= ~observed_mask`
- Stage1 post/signal and wake chain now worth carrying as a software correlation model:
  - scheduler callback can map an id to a target index
  - post helper can set a pending signal bit
  - wake helper can set `wait_state_98 = 0` and `resume_status_9c = 4`
  - make-runnable can clear context block flags and return the context to readyq

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- dispatch-table addresses `0x81916fd8` and `0x819172d8` as if they were hardware registers
- Stage1 slot-table, callback-pair, post-state, or queue-node globals as if they were MMIO blocks
- exact semantic meaning of selector `1` / MSP bits `18`, `19`, and aggregate mask `0x13f3ffff`
- exact final semantic meaning of `context->waitq_owner_or_link_owner_28`
- any assumption that OpenWrt must reproduce the OEM Stage1 scheduler internals rather than only the necessary externally-visible hardware state

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup must look right
- stage 7: request-engine submit/finalize flow, selector-gate publish behavior, and mode-specific sideband output lanes must look right
- stage 8: alternate `0x80c8` runtime-family registration/activation writes, selector-output gating, and alias-window output paths must look right
- stage 9: runtime-family selection and request-model behavior must look right
- stage 10: if traffic still stalls, Host-DQM selector register blocks, dispatch-table mapping, and Stage1 event-slot wake behavior become the next most likely missing OEM-specific layer
- stage 11: if traffic still stalls after the event-slot layer looks OEM-like, current-context ownership, thread-record linkage, per-thread signal/work-mask behavior, and worker exit/join lifecycle become the next software correlation layer

Practical implication:

- if OpenWrt reproduces the earlier control surfaces but packet movement still fails, compare whether any OEM-equivalent coordination exists for:
  - selector `3` / MSG_PROC block `0x18601814/18/20`
  - selector `1` / MSP block `0x18201814/18/20`
  - dispatch-table mapping through `0x81916fd8` and `0x819172d8`
  - Stage1 event-slot wake behavior rooted at `0x81909698`
- treat the Stage1 scheduler and post/signal globals only as reverse-side correlation aids
- do not convert those software values into direct Linux MMIO constants

## Eleventh-pass Stage1 thread-record and signal-mask owner values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-scheduler-post-signal-wake-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-thread-record-datatype-correction.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-thread-exit-tsd-cleanup.md`

### When to use this set

Use this eleventh-pass set only after the earlier MMIO and Host-DQM or event-slot surfaces already look OEM-like, but workers still do not continue, signal-driven progress still appears mismatched, or the remaining gap looks more like thread ownership or wake-state follow-through than a plain ENET or DQM register mismatch.

### Eleventh-pass software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- current-context and signal-state globals:
  - `0x819dcc54`
  - `0x81a67cec`

### Current best meanings

- `stage1_context_candidate +0xac` is not a detached signal-select-state pointer in the current carried model:
  - it is `stage1_thread_record_candidate *thread_record_ac_candidate`
- carried per-thread signal/work ownership fields now worth keeping visible:
  - `stage1_thread_record_candidate +0x48 = pending_signal_or_work_mask_48_candidate`
  - `stage1_thread_record_candidate +0x4c = blocked_signal_mask_or_wait_mask_4c_candidate`
- embedded ownership relation now matters for later software correlation:
  - `stage1_thread_record_candidate +0x50` embeds the owning `stage1_context_candidate`
  - `embedded_context_50.thread_record_ac_candidate` points back to the containing thread record
- current-thread helper behavior now reads better as:
  - current-context lookup returns `g_stage1_current_context_819dcc54_candidate->thread_record_ac_candidate`
  - the unmasked pending-signal view is better treated as `(global_signal_state | thread_pending) & ~thread_blocked`
  - current-thread id or handle comes from `thread_record->thread_id_or_handle_04`
- if workers appear to terminate or never complete join/teardown after wakeup, these thread-lifecycle fields are now also worth keeping visible:
  - `stage1_thread_record_candidate +0x1c = exit_value_or_status_1c_candidate`
  - `stage1_thread_record_candidate +0x44 = cleanup_handler_head_44_candidate`
  - `stage1_thread_record_candidate +0x178 = embedded_join_condition_178`
  - absolute thread-record offset `+0x180 = embedded_join_condition_178.tsd_value_slots_base_08_candidate`

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- `0x819dcc54` or `0x81a67cec` as if they were MMIO registers
- `0x81a64f18` or `0x81a64f28` as if they were MMIO registers
- the per-thread pending or blocked masks as if they mapped directly to Linux-visible hardware status bits
- the older detached `signal_select_state_ac_candidate` interpretation for `stage1_context_candidate +0xac`
- the thread-exit or join-lifecycle fields as if they were direct Linux-visible hardware state
- any assumption that OpenWrt must reproduce the OEM scheduler internals rather than only the externally-visible hardware state that those internals eventually drive

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup must look right
- stage 7: request-engine submit/finalize flow, selector-gate publish behavior, and mode-specific sideband output lanes must look right
- stage 8: alternate `0x80c8` runtime-family registration/activation writes, selector-output gating, and alias-window output paths must look right
- stage 9: runtime-family selection and request-model behavior must look right
- stage 10: if traffic still stalls, Host-DQM selector register blocks, dispatch-table mapping, and Stage1 event-slot wake behavior become the next most likely missing OEM-specific layer
- stage 11: if the stage-10 event-slot layer already looks OEM-like, current-context ownership, thread-record linkage, per-thread pending or blocked signal/work masks, and worker exit/join lifecycle become the next software correlation layer

Practical implication:

- if OpenWrt reproduces the earlier control surfaces and even the Host-DQM or event-slot bridge still looks OEM-like, compare whether any OEM-equivalent follow-through exists for:
  - `current_context -> thread_record` ownership at `0x819dcc54`
  - per-thread pending and blocked masks at `stage1_thread_record_candidate +0x48/+0x4c`
  - the software-side unmasked pending-signal view rooted at `0x81a67cec`
- if workers appear to terminate, never rejoin, or fail during teardown after wakeup, also compare:
  - `stage1_thread_record_candidate +0x1c/+0x44/+0x178`
  - absolute thread-record offset `+0x180`
  - TSD correlation globals `0x81a64f18` and `0x81a64f28`
- keep these as reverse-side correlation aids only
- do not convert those software values into direct Linux MMIO constants

## Twelfth-pass Stage1 readyq, PI, timeout, and timeslice correlation values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-pi-owned-wait-object-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-owner-list-wakeup-chain.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-readyq-static-idle-timeslice.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-14-stage1-timeout-signal-dispatch.md`

### When to use this set

Use this twelfth-pass set only after the earlier MMIO, Host-DQM, event-slot, and thread-record ownership/lifecycle surfaces already look OEM-like, but runnable ordering, wait-object wake follow-through, timeout-driven progress, same-priority round-robin behavior, or signal/timeout-driven reschedule behavior still diverge.

### Twelfth-pass software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- scheduler and readyq globals:
  - `0x819dcc50`
  - `0x819dcc54`
  - `0x819dcc58`
  - `0x819dcc5c`
  - `0x819dcce0`
- static idle/bootstrap area:
  - `0x819dc308`
  - `0x819dc310`
  - `0x819dc438`
- timeout and signal-side globals:
  - `0x81a67cd0`
  - `0x81a67ce4`
  - `0x81a67cec`
  - `0x81a67cf0`

### Current best meanings

- lower `readyq_bucket_20` now reads as higher scheduler priority
- `owner_list_head_ref_28` is not an owner object:
  - it is a pointer to the exact external list-head slot that currently owns `context->readyq_node_18`
- the PI and wake chain now suggests:
  - `base_readyq_bucket_48_candidate` tracks the base/requested bucket during PI handling
  - `resume_status_9c = 7` is the normal success/wake result in wait-object and PI wake paths
- the timeslice chain now suggests:
  - `scheduler_timeslice_flag_24_candidate` gates same-bucket timeslice rotation
  - `g_stage1_scheduler_timeslice_or_budget_reload_819dcc50` reloads to `50000`
  - timeslice expiry can rotate the same-priority readyq bucket and set `g_stage1_scheduler_dispatch_needed_flag_819dcc58`
- the timeout and signal model now suggests:
  - `stage1_context_candidate +0x68` is better treated as `timeout_object_68_candidate`, a structured `0x30`-byte timeout object
  - the signal/post-state cluster is better treated as objects rather than overlapping scalar globals
- the static idle path now suggests:
  - `0x819dc310` is the static idle/bootstrap context record
  - `0x819dc438` is the static idle stack/work area base for slot 0

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- `0x819dcc50`, `0x819dcc58`, `0x819dcc5c`, or `0x819dcce0` as if they were MMIO registers
- `0x819dc308`, `0x819dc310`, or `0x819dc438` as if they were hardware state instead of OEM scheduler/runtime storage
- `context +0x24`, `context +0x28`, `context +0x48`, or `context +0x68` as if they directly mapped to Linux-visible hardware bits
- any assumption that OpenWrt must reproduce the OEM readyq, timeout, or timeslice internals rather than only the externally-visible hardware state they eventually drive

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup must look right
- stage 7: request-engine submit/finalize flow, selector-gate publish behavior, and mode-specific sideband output lanes must look right
- stage 8: alternate `0x80c8` runtime-family registration/activation writes, selector-output gating, and alias-window output paths must look right
- stage 9: runtime-family selection and request-model behavior must look right
- stage 10: if traffic still stalls, Host-DQM selector register blocks, dispatch-table mapping, and Stage1 event-slot wake behavior become the next most likely missing OEM-specific layer
- stage 11: if the stage-10 event-slot layer already looks OEM-like, current-context ownership, thread-record linkage, per-thread pending or blocked signal/work masks, and worker exit/join lifecycle become the next software correlation layer
- stage 12: if the stage-11 layer already looks OEM-like, readyq ownership, PI restore/requeue behavior, timeout object state, same-bucket timeslice rotation, and static idle context setup become the next software correlation layer

Practical implication:

- if OpenWrt reproduces the earlier control surfaces and even the Host-DQM/event-slot/thread-record layers still look OEM-like, compare whether any OEM-equivalent follow-through exists for:
  - `g_stage1_scheduler_timeslice_or_budget_reload_819dcc50`
  - `g_stage1_scheduler_dispatch_needed_flag_819dcc58`
  - `g_stage1_scheduler_readyq_table_819dcc5c`
  - `g_stage1_context_switch_counter_819dcce0`
  - `stage1_context_candidate +0x24/+0x28/+0x48/+0x68`
  - `0x819dc310` and `0x819dc438`
- keep these as reverse-side correlation aids only
- do not convert those software values into direct Linux MMIO constants

## Fifteenth-pass Stage1 netif, aux-context, and route-output correlation values

This section was added after rereading:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-19-stage1-netif-aux-context-route-output.md`

### When to use this set

Use this fifteenth-pass set only after the earlier MMIO, Host-DQM, scheduler, signal-object, and socket-provider surfaces already look OEM-like, but the remaining gap looks like interface selection, route-output state, source-address selection, or aux object rebinding rather than a plain ENET register mismatch.

### Fifteenth-pass software values for correlation only

Do not hardcode these into Linux. Use them only to correlate OEM runtime behavior:

- socket create-flag and interface-name tables:
  - `0x80f99618 = stage1_socket_create_flag_iface_name_record_candidate[8]`
  - `0x8146f660 = g_stage1_socket_create_flag_iface_name_ptr_table_8146f660_candidate`
  - `0x8146f690 = g_stage1_socket_create_flag_netif_table_8146f690_candidate`
- netif runtime globals:
  - `0x81840370 = g_stage1_netif_list_head_81840370_candidate`
  - `0x81840378 = g_stage1_netif_aux_object_array_81840378_candidate`
  - `0x818403b4 = g_stage1_ip_id_counter_818403b4_candidate`
  - `0x81802fb4 = g_stage1_netif_registered_count_81802fb4_candidate`
  - `0x81802fb8 = g_stage1_netif_object_array_81802fb8_candidate`
  - `0x81802fbc = g_stage1_netif_table_capacity_81802fbc_candidate`
  - `0x81a60b70 = g_stage1_netif_list_initialized_81a60b70_candidate`
- aux-context and route-output globals:
  - `0x81a60b98 = g_stage1_netif_aux_context_stats_81a60b98_candidate`
  - `0x81a60ba4 = g_stage1_netif_aux_active_context_count_81a60ba4_candidate`
  - `0x81bfcf00 = g_stage1_route_output_global_level_81bfcf00_candidate`
  - `0x81c0cf10 = g_stage1_netif_aux_keyclass_ops_table_81c0cf10_candidate`

### Current best meanings

- socket create-flag indexes `1..8` map to the static OEM names `bcm0` through `bcm7`
- `bcm0` resolves as base name `bcm` plus unit `0`, not as a plain full-string compare
- `0x81802fb8` is a pointer variable to the heap-allocated global netif pointer array; do not apply an embedded `stage1_netif_object_candidate *[8]` at that address
- `stage1_netif_object_candidate +0x10/+0x14` carries the per-netif aux-object list head and tail slot
- `stage1_netif_aux_object_candidate +0x00/+0x04/+0x08` carries primary, secondary, and mask key blobs
- `stage1_netif_aux_object_candidate +0x5c` links back to the parent netif
- `stage1_netif_aux_object_candidate +0x68` is the aux callback and `+0x70` is the aux hold count
- `stage1_netif_aux_event_context_candidate +0x34` is the hold or ref count
- `stage1_netif_aux_event_context_candidate +0x38` carries event/context flags
- `stage1_netif_aux_event_context_candidate +0x40` is the current aux object
- `stage1_netif_aux_event_context_candidate +0x44/+0x4c` carries route/key and route-mask or route-state data
- route-output processing validates binary key class/type bytes below `0x21`, uses keyclass callbacks at `+0x1c/+0x20`, can rebind `current_aux_40_candidate`, and writes success/error status back to the route buffer
- observed route-output status values worth keeping nearby are `0x16`, `0x145`, `0x147`, `0x149`, and `0x163`

### What not to hardcode yet

Do not hardcode these as final Linux semantics yet:

- `0x80f99618`, `0x8146f660`, `0x8146f690`, `0x81840370`, `0x81802fb8`, `0x81a60b98`, `0x81a60ba4`, `0x81bfcf00`, or `0x81c0cf10` as if they were MMIO registers
- `bcm0` through `bcm7` as Linux interface names that OpenWrt must expose
- route-output error values as if they directly map to Linux errno without another translation layer
- aux event-context refs or aux hold counts as if they were hardware queue occupancy counters
- any assumption that OpenWrt must reproduce the OEM netif/aux object model rather than only the hardware-visible state that the OEM model eventually drives

### Updated OpenWrt development meaning

Current best staged model for the TC7200U port:

- stage 1: FPM allocator/backing-base values must look right
- stage 2: GENET/MBDMA endpoint and control values must look right
- stage 3: DQM/CP2 queue control, mailbox, per-queue pull programming, and queue-policy state must look right
- stage 4: DQM mailbox command handling, queue-profile writes, slot commit, and CP2/FPM service plumbing must look right
- stage 5: the `0x01800008` event path, selector dispatch, request-block programming, and size-selected FPM request/return behavior must look right
- stage 6: selector lookup/context initialization, preload-port state, and selector-derived `b604` command-table setup must look right
- stage 7: request-engine submit/finalize flow, selector-gate publish behavior, and mode-specific sideband output lanes must look right
- stage 8: alternate `0x80c8` runtime-family registration/activation writes, selector-output gating, and alias-window output paths must look right
- stage 9: runtime-family selection and request-model behavior must look right
- stage 10: if traffic still stalls, Host-DQM selector register blocks, dispatch-table mapping, and Stage1 event-slot wake behavior become the next most likely missing OEM-specific layer
- stage 11: if the stage-10 event-slot layer already looks OEM-like, current-context ownership, thread-record linkage, per-thread pending or blocked signal/work masks, and worker exit/join lifecycle become the next software correlation layer
- stage 12: if the stage-11 layer already looks OEM-like, readyq ownership, PI restore/requeue behavior, timeout object state, same-bucket timeslice rotation, and static idle context setup become the next software correlation layer
- stage 13: if the stage-12 layer already looks OEM-like, signal-object table state, select or wait generation flow, provider or related-object callback dispatch, and timeout-to-ticks conversion become the next software correlation layer
- stage 14: if the stage-13 layer already looks OEM-like, socket-object wrapper state, type2 setsockopt/getsockopt dispatch, and socket close/cleanup behavior become the next software correlation layer
- stage 15: if the stage-14 layer already looks OEM-like, socket create-flag to netif mapping, netif aux-object lookup, keyclass ops, route-output aux-context rebinding, and route-status writeback become the next software correlation layer

Practical implication:

- if OpenWrt reproduces the earlier control surfaces and the socket-provider layer still looks OEM-like, compare whether any OEM-equivalent follow-through exists for:
  - create-flag index `1..8` to `bcm0..bcm7`
  - `g_stage1_socket_create_flag_netif_table_8146f690_candidate`
  - `g_stage1_netif_list_head_81840370_candidate`
  - `stage1_netif_object_candidate +0x10/+0x14`
  - `stage1_netif_aux_object_candidate +0x00/+0x04/+0x08/+0x5c/+0x68/+0x70`
  - `stage1_netif_aux_event_context_candidate +0x34/+0x38/+0x40/+0x44/+0x4c`
  - `g_stage1_netif_aux_keyclass_ops_table_81c0cf10_candidate`
- keep these as reverse-side correlation aids only
- do not convert those software values into direct Linux MMIO constants

## Runtime control pass: 2026-06-19 FPM live, MBDMA/TDMA still stuck

This section was added from the current June 19 runtime status notes only:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-fpm-live-mbdma-unprogrammed.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-txdump-tdma-stuck.md`

The older `2026-05-31-stage1-reverse-findings.md` note is intentionally not used for this update.

### Runtime result now proven

The current OpenWrt image reaches the driver and fixed-link layer:

- BCMGENET binds at `0x12c00000`
- fixed-link `eth0` reports `1Gbps/Full`
- TX descriptors are actually queued
- descriptor addresses advance at `b2c03000`, `b2c03008`, `b2c03010`
- descriptor mappings such as `0x06e20002`, `0x06e21802`, `0x068f2a02`, `0x06e22002`, `0x068f2282`, and `0x06e23802` are observed
- `NETDEV WATCHDOG` still follows because TDMA does not consume/completion-process the queued descriptors

This rules out the old broad blockers:

- missing BCMGENET driver
- missing DTS node
- missing fixed-link carrier
- missing IRQ allocation as the first-order failure
- switch/B53 wiring as the first-order failure
- MDIO topology as the first-order failure

### FPM is live and readable

The June 19 control dump proves FPM register space is not the missing MMIO window:

```text
0x12200010 = 0x00000000
0x12200014 = 0x00000001
0x12200040 = 0x06000000
0x12200044 = 0x00010000
0x12200050 = 0x00000000
0x12200054 = 0x18007EFA
0x12200058 = 0x00000000
0x1220005c = 0x00000000
0x12200200 = 0x80170800
0x12200208 = 0x9008C400
0x12200210 = 0xA01B8200
0x12200218 = 0xB0324100
```

Development meaning:

- keep FPM compare probes in the debug image
- do not treat FPM address space itself as absent or unreadable
- do not move to switch/B53/MDIO work because the TX datapath still dies before that layer matters

### GENET/MBDMA state is not OEM-like

The same run shows OpenWrt is still not programming the frozen GENET/MBDMA control state:

```text
0x12c00004 = 0x00000001
0x12c00008 = 0x00000001
0x12c0000c = 0x00000001
0x12c00010 = 0x00000001
0x12c00040 = 0x00000001
0x12c00044 = 0x00000001
0x12c00048 = 0x00000001
0x12c0004c = 0x00000001
0x12c00050 = 0x00000001
0x12c00054 = 0x00000001
0x12c00058 = 0x00000001
0x12c00070 = 0x00000001
0x12c00100 = 0x00000001
0x12c00104 = 0x00000001
0x12c00120 = 0x00000001
0x12c00124 = 0x00000001
0x12c00140 = 0x00000001
0x12c00144 = 0x00000001
0x12c00180 = 0x00000001
0x12c00184 = 0x00000001
```

This does not match the carried OEM-like expected set:

- `0x12c00008 != 0x12200200`
- `0x12c0004c != 0x12200218`
- `0x12c00050 != 0x12200210`
- `0x12c00054 != 0x12200208`
- `0x12c00058 != 0x12200200`
- `0x12c00044 != 0x02020202`
- `0x12c00048 != 0x0000000f`
- `0x12c00070 != 0x00000003/0x00030000`

Development meaning:

- the current blocker is earlier than descriptor-width alone
- add or keep read-only dumps around BCMGENET open and timeout for `0x12c00004/08/0c/10/44/48/4c/50/54/58/70`
- only add a minimal TC7200U FPM/MBDMA init patch after confirming the correct placement for these writes

### TDMA/ring timeout state

The TX timeout dump confirms descriptor queueing is alive but TDMA consumption is not:

```text
tdma_ctrl=0x00003000
tdma_stat=0x00000800
hw_p=0
hw_c=14340
free_bds=0
clean=0
write=0
```

Repeated timeouts keep the same pattern. After timeout/reclaim, later TX logs report impossible software counters such as:

```text
prod=17920
free=65792
```

Interpretation:

- the TX descriptor write path is alive
- the TDMA consume/completion path is not alive
- `hw_c=14340` equals `0x3804`, which looks address/offset-shaped rather than like a sane consumer index
- the debug read model or upstream ring/index layout may still not match the BCM3383/TC7200U hardware path

### Updated immediate development target

Current next work should stay narrow:

- keep GENET base `0x12c00000`
- keep fixed-link RGMII
- keep no B53/DSA/MDIO child changes
- keep parent IRQ masks untouched
- keep read-only FPM probes at `0x12200040`, `0x12200044`, and `0x12200200/208/210/218`
- keep read-only GENET/MBDMA probes at `0x12c00004/08/0c/10/44/48/4c/50/54/58/70`
- test the temporary GENET_V1 `words_per_bd` branch from `2` to `3` only as a controlled descriptor-width experiment
- compare XMITDESC, TXDUMP, and TDMA/ring state after one watchdog

Do not prioritize switch/B53/DSA/MDIO work until TDMA consumes descriptors and the GENET/MBDMA control state looks OEM-like.

## Runtime control pass: 2026-06-20/21 IRQ13, DQM mailbox, and FPM endpoint carry

Source notes:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-20-dqm-fpm-runtime-overlay-ghidra-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-20-dqm-mailbox-extphy-spi-genet-selector-ghidra-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-20-ghidra-isr0guard-new-data-next-steps.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-21-bcm-periph-irq-im5-ghidra-log.md`

### FPM and DQM token control

Confirmed FPM endpoint map:

```text
0x12200200 / 0xb2200200 = FPM_ENDPOINT_800
0x12200208 / 0xb2200208 = FPM_ENDPOINT_400
0x12200210 / 0xb2200210 = FPM_ENDPOINT_200
0x12200218 / 0xb2200218 = FPM_ENDPOINT_100
```

`0x40000000` in the recovered DQM/FPM paths is a DQM/FPM token flag. It is cleared with `& 0xbfffffff` before a cleaned token or data word is returned to `B2200200`. Do not label that DQM token bit as peripheral IRQ bit30, and do not merge it with the OpenWrt runtime observation `periph_stat=0x40000004`.

The `0x80004000` and `0x80008000` DQM state is runtime overlay state, not static boot code to retype in the main Ghidra image. Keep the static program intact and use a separate runtime-overlay analysis copy for those volatile objects.

### DQM mailbox to GENET-adjacent selector path

The DQM mailbox dispatcher at `80c7c5d0` copies four mailbox words from `b6001de0..b6001dec` and dispatches on the command byte at `sp+0x03`.

Case `0x11` routes selector output toward GENET-adjacent targets:

```text
sp+0x08 == 0  -> selector 0x0c, target b2c00500
sp+0x08 != 0  -> selector 0x0e, target b2c00510
```

Case `0x12` performs B604/B605 window programming: it clears bit `0x100` on B604 entry control/flags words, waits for B604 idle/status bits, calls the B6052000 word-pair copy helper, and restores bit `0x100`.

Keep `MMIO_IOP_DQM_KSEG1_B6000000` as the broad DQM/IOP block covering `b6000000-b609ffff`; do not split a separate `MMIO_DQM_CP2_B6040000` block unless a later control pass proves it is necessary.

### IRQ13 and IM5 parent dispatcher

The OpenWrt ISR0 guard run proves IRQ13 reaches `bcmgenet_isr0()`. The capture did not show Data bus error, Oops, panic, NETDEV WATCHDOG, `get_swap_device`, or RCU-stall markers, but it did flood roughly 5.5k guard prints. Representative values were:

```text
irq=13
raw_stat=0x80a11a00 early, then often 0xffffbd95
raw_mask=0xb2c00000
pending=0xb2c00000
periph_stat=0x40000004
periph_mask=0x00002000
```

Control caveat: the current OpenWrt guard re-reads registers inside the log path, so `raw_stat`, `raw_mask`, and `pending` are not coherent. Do not treat `pending=0xb2c00000` as a valid GENET status bitfield yet, and do not force an upstream GENET INTRL2 layout onto TC7200U from this capture alone.

The OEM peripheral interrupt path is now a stronger lead:

```text
8002adbc  fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate
b4e00050  PERIPH_IRQ_IM5_MASK_OR_ENABLE_B4E00050_candidate
b4e00054  PERIPH_IRQ_IM5_STATUS_OR_PENDING_B4E00054_candidate
```

`FUN_8002adbc` reads active parent interrupt bits from `b4e00050 & b4e00054`, dispatches each active parent bit through `FUN_8002ae48`, then re-enables CP0 Status bit `0x2000`. The registration block at `80860330..80860360` installs this function as CP0 interrupt-line 5 handler and enables the parent group bit with:

```text
b4e00050 |= 1u << (group_id - 0x23)
```

If the OpenWrt `periph_mask=0x00002000` bit is the same parent bank, parent bit13 maps to OEM group id `0x30` / decimal `48`.

Child IRQ dispatch model:

```text
handler table root       = 0x81743214
group 0x23 handler base  = 0x81745514
group 0x30 handler base  = 0x81746214
child-bank base table    = 0x81745b14 + parent_bit_index * 4
child active bits        = *(child_base + 0x08) & *(child_base + 0x0c)
child clear path         = clear handled bit from child_base + 0x08
handler entry address    = 0x81743214 + ((group_id * 32) + child_bit) * 8
```

### Updated immediate development target

- Fix the OpenWrt ISR guard to snapshot locals once before logging: `raw_stat`, `raw_mask`, then `status = raw_stat & ~raw_mask`.
- Limit the guard flood with a static counter and optionally mask/disable IRQ13 after the first few lines.
- Investigate OEM handler group `0x30` child entries and child-bank base-table values before changing the GENET interrupt register layout.
- Keep DQM/FPM endpoint and token work separate from the TDMA descriptor-width experiment.
- Keep B53/DSA/MDIO changes out of scope until TDMA consumption and coherent IRQ clear behavior are proven.

### Modification log

- 2026-06-21: added the June 20/21 DQM runtime-overlay, mailbox selector, ISR0 guard, and IM5 parent-dispatcher findings to the OpenWrt development carry document.
## Runtime control pass: 2026-06-21 late Host-DQM IM5, NATP, and net-config carry

Source notes:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-21-bcm-periph-host-dqm-im5-reenable-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-21-natp-host-dqm-ghidra-log.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-21-net-config-heap-natp-gfap-ghidra-log.md`

### Superseding IRQ13 and Host-DQM correction

The later IM5 re-enable pass corrects the earlier group-`0x30` hypothesis. The mapped OEM Host-DQM IM5 path currently proves encoded IRQ groups `0x23..0x28`, not `0x30`:

```text
CP0 Status IM5
  -> fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate
  -> parent active = b4e00050 & b4e00054
  -> fn_bcm_periph_irq_child_bank_dispatch_8002ae48_candidate(parent_bit_index)
  -> child active = child_bank+0x08 & child_bank+0x0c
  -> Host-DQM selector pending-bit handler
  -> Host-DQM dispatch table bridge to stage1 event-slot raise
  -> fn_bcm_irq_return_reenable_8003d184_candidate(encoded_irq_id)
```

Correct child-bank semantics for OpenWrt probing:

```text
child_bank+0x08  mask/control/enable latch
child_bank+0x0c  status/pending source
```

Do not add blind ack/clear writes to the OpenWrt guard path. First snapshot parent, child, and GENET INTRL2 locals once, then print those saved locals:

```text
b4e00050  parent IM5 mask/enable candidate
b4e00054  parent IM5 status/pending candidate
child+08  child mask/control/enable latch
child+0c  child status/pending source
GENET INTRL2 stat/mask saved before printk
```

Child-bank bases now carried for the proven Host-DQM group range:

```text
parent_bit 0 / group 0x23 -> b3000000, child regs at b3001000
parent_bit 1 / group 0x24 -> b3200000, child regs at b3201000
parent_bit 2 / group 0x25 -> b4200000, child regs at b4201000
parent_bit 3 / group 0x26 -> b3600000, child regs at b3601000
parent_bit 4 / group 0x27 -> b3400000, child regs at b3401000
parent_bit 5 / group 0x28 -> b3e00000, child regs at b3e01000
```

The Host-DQM dispatch tables are data tables, not callback pointers:

```text
81916fd8[index] = event raise mask
819172d8[index] = 1-based stage1 event-slot id
```

### Host-DQM and NATP no-match carry

Required Host-DQM MMIO windows remain:

```text
b8000000..b8001fff  UTP selector 0
b8200000..b8201fff  MSP selector 1
b8400000..b8401fff  FAP selector 2
b8600000..b8601fff  MSG_PROC selector 3
b8a00000..b8a01fff  MPEG_PROC selector 4
b8800000..b8801fff  PMC selector 5
```

NATP/no-match RX manager creates a Host-DQM object on selector `4` / MPEG_PROC with queue index `0x10` and channel index `0x11`. Useful MMIO-derived fields for cross-checking:

```text
host_dqm_base                  = b8a00000
register_block                 = b8a01800
tx_submit_window_3c            = b8a01d00
tx_credit_or_depth_ptr_40      = b8a01f40
record_words                   = b8a01d10
queue_index_or_cursor_ptr_44   = b8a01f44
```

No new OpenWrt memory block is required from the NATP Host-DQM object pass itself. The current high-value target is the table-population path for `81916fd8` and `819172d8`.

### Net-config and heap carry for Ghidra control

The NATP/GFAP manager thread is now identified at `8053d514`; do not leave that ops slot as an unknown method. The heap-free path starts at `8002a280`, not `8002a2f0`, and uses a 12-byte heap block header at `payload - 0x0c`.

`0x81470000` is only a high-half global anchor. Keep precise globals on the individual words instead of typing the whole anchor as an object or MMIO block:

```text
81470008  g_net_config_cache_entry_count_81470008_candidate
81470020  g_net_config_requested_flag_81470020_candidate
81470024  g_net_config_indexed_cache_count_81470024_candidate
81470028  g_net_config_context_ptr_81470028_candidate
```

The net-config large cache requires resizing the current small Ghidra block:

```text
Old name: RAM_FPM_TOKEN_MANAGER_STATE_8187BC60
New name: RAM_STAGE1_FPM_NETCFG_RUNTIME_8187BC60_candidate
Start:    8187bc60
End:      81883daf
Size:     0x8150
```

After resizing, apply `net_config_indexed_cache_entry_400_candidate[32]` at `8187bdb0`. Do not touch `81883e00..81883fff`; the large cache ends before the existing `BSS_STAGE1_FAP_BYPASS_81883E00_candidate` block.

### Late-pass development target

- Fix the OpenWrt ISR guard around saved local snapshots before changing interrupt clear behavior.
- Treat `periph_mask=0x00002000 -> group 0x30` as unproven for Host-DQM until a parent/child snapshot proves it.
- Apply corrected child-bank labels with `+0x08` as mask/control/enable and `+0x0c` as status/pending.
- Keep NATP selector `4` / MPEG_PROC Host-DQM windows as reverse-control targets, not immediate OpenWrt driver constants.
- Resize the `8187bc60` Ghidra block before applying the net-config indexed cache table.

### Modification log

- 2026-06-21: added the late Host-DQM IM5 correction, Host-DQM dispatch table semantics, NATP no-match Host-DQM selector/window facts, heap-free correction, and net-config memory-block resize requirement.
