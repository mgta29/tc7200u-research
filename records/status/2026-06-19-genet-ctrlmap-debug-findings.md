# 2026-06-19 GENET ctrlmap debug findings

## Scope

This log records the TC7200U/OpenWrt Ethernet bring-up work up to the point immediately before the next proposed repair step: **repair `998` again with single-register `CTRL2` accessor comparison**.

It covers:

- BCMGENET fixed-link runtime behavior.
- `996` TX descriptor logging.
- repaired `997` TX timeout dump logging.
- runtime `devmem` FPM/GENET/MBDMA/Profile control dump.
- `998` control-dump patch placement and mapped-read attempt.
- serial run for `fresh-genet-ctrlmap-20260619-085019.bin` served as `gc.bin`.
- current conclusion before any `CTRL2` patch is applied.

This log intentionally does **not** include the later planned `CTRL2` single-register accessor-comparison repair.

## Repository and artifact context

Project: `tc7200u-research`

OpenWrt tree: `~/src/openwrt`

Target image family:

- target: `bmips/bcm63268`
- device: `technicolor_tc7200u`
- kernel observed in tested image: `Linux 6.12.93`
- CFE ProgramStore wrapper load address: `0x82000000`
- ProgramStore signature/PID: `a825`

Relevant image tested in this pass:

```text
fresh-genet-ctrlmap-20260619-085019.bin
```

The long filename initially caused TFTP trouble. The same wrapped image was later served as a short filename:

```text
gc.bin
```

CFE image header from the successful `gc.bin` transfer still preserved the original wrapped filename:

```text
Filename: fresh-genet-ctrlmap-20260619-085019.bin
File Length: 5709238 bytes
Load Address: 82000000
Signature: a825
Control: 0000
```

## Source/carry-note baseline

The maintained ENET carry note establishes the current usable reverse-derived control model:

### Address rules

```text
KSEG1 physical conversion: physical = kseg1 - 0xa0000000
cached DMA-visible physical: dma_phys = cached_addr & 0x1fffffff
```

### High-confidence hardware bases

```text
0x12200000  FPM / packet allocator hardware
0x12c00000  main GENET window
0x12c00600  MDIO0 block
0x12c02600  MDIO1 block
0x14e001c4  ENET/profile control candidate
0x14e00002  ENET/profile status candidate
0x14e00264  ENET/profile one-time setup candidate
```

### Frozen GENET/MBDMA expected values

Current OEM-derived comparison anchors:

```text
0x12c00004 = (old & 0xffffe000) | 0x9010
0x12c00044 = 0x02020202
0x12c00048 = 0x0000000f
0x12c0004c = 0x12200218
0x12c00050 = 0x12200210
0x12c00054 = 0x12200208
0x12c00058 = 0x12200200
0x12c00008 = 0x12200200
0x12c00010 = aligned_fpm_ddr_backing_base & 0x1fffffff
0x12c00070 = 0x00000003 for core/interface 0, or 0x00030000 for nonzero path
```

### Frozen FPM endpoint model

Current FPM/FPM-backed endpoint expectations:

```text
FPM HW base: 0x12200000
requested FPM buffer size: 0x100
FPM allocation length: 0x00800100
size 0x100 -> class 3 -> endpoint 0x12200218
size 0x200 -> class 2 -> endpoint 0x12200210
size 0x400 -> class 1 -> endpoint 0x12200208
size 0x800 -> class 0 -> endpoint 0x12200200
```

The carry note says matching only generic GENET state is not enough. OpenWrt must be compared against both:

- FPM side at `0x12200000`.
- GENET/MBDMA side at `0x12c00000`.

## Patch/change chronology

### Existing base DTS/config state

The test branch already had:

- `CONFIG_BCMGENET=y`
- `CONFIG_PHYLIB=y`
- `CONFIG_FIXED_PHY=y`
- `CONFIG_DEVMEM=y`
- `CONFIG_BCM7120_L2_IRQ=y`
- DTS `ethernet@12c00000` with `compatible = "brcm,genet-v1"`
- fixed-link `1000/full`
- no B53/DSA
- no MDIO child
- no manual parent IRQ forcing

### `996-bcmgenet-tc7200u-xmit-desc-debug.patch`

Purpose:

- Log each TX descriptor queued by BCMGENET.
- Confirm whether Linux actually reaches the xmit path and writes BD state.

Observed fields:

```text
TC7200U XMITDESC i=0 nr_frags=0 size=<len> mapping=<dma> len_stat=<desc word> bd_addr=<bd base> ring=0 write_ptr=<n> prod=<n> free=<n>
```

Result:

- TX descriptor queueing is real.
- `bd_addr` advances by `8` bytes on initial descriptors.
- mapping values are DMA-looking bus addresses.
- initial `prod/free` values are sane before timeout.

### repaired `997-bcmgenet-tc7200u-timeout-dump-debug.patch`

Purpose:

- Dump timeout-time state from `bcmgenet_timeout()`.
- Avoid the earlier broken patch placement that inserted calls in `bcmgenet_netif_stop()`.

Confirmed patch points:

```text
bcmgenet_timeout()
  timeout_entry
  timeout_exit
```

Observed fields:

```text
periph_stat
periph_mask
intr0_stat
intr0_mask
intr1_stat
intr1_mask
tdma_ctrl
tdma_stat
sw_prod
sw_c
hw_p
hw_c
free_bds
clean
write
```

Stable timeout signature:

```text
tdma_ctrl=0x00003000
tdma_stat=0x00000800
sw_prod=0
sw_c=0
hw_p=0
hw_c=14340
free_bds=0
clean=0
write=0
```

Important interpretation:

```text
14340 decimal = 0x3804
```

That value is suspicious as a consumer index because it looks like a TDMA register offset/address-shaped value rather than a real ring consumer counter.

After timeout/recovery, software ring counters become invalid:

```text
prod=17920
free=65792
```

This confirms that the timeout path exposes corrupted or mismatched ring/index state after TDMA does not consume descriptors.

### `998-bcmgenet-tc7200u-control-dump-debug.patch` first generation

Purpose:

- Read-only dump of FPM, GENET/MBDMA, and profile registers.
- Insert dumps at:
  - `bcmgenet_open()` entry
  - `bcmgenet_open()` exit
  - `bcmgenet_timeout()` entry
  - `bcmgenet_timeout()` exit

Initial helper used hardcoded physical/KSEG1 reads for all control registers.

Problem:

- Hardcoded KSEG1 reads did not match earlier `devmem` observations.
- Values looked pointer-like or garbage-like.

### `998` mapped-read regeneration

The later `998` regeneration changed GMAC/GENET reads to use BCMGENET's own mapped base:

```c
#define TC7200U_G32(priv, off) bcmgenet_readl((priv)->base + (off))
```

Confirmed patch grep output showed:

```text
#define TC7200U_G32(priv, off) bcmgenet_readl((priv)->base + (off))
open_entry
open_exit
timeout_entry
timeout_exit
```

This was an improvement in method because the upstream BCMGENET driver already uses `priv->base` for TDMA/RDMA helpers:

```c
bcmgenet_readl(priv->base + GENET_TDMA_REG_OFF + ...)
bcmgenet_readl(priv->base + GENET_RDMA_REG_OFF + ...)
```

However, the mapped `998` output still produced invalid-looking GMAC values. See below.

## Runtime result: fixed-link BCMGENET still reaches xmit and then fails

At runtime:

```text
bcmgenet 12c00000.ethernet: configuring instance for external RGMII (no delay)
bcmgenet 12c00000.ethernet eth0: Link is Up - 1Gbps/Full - flow control off
```

Example initial descriptor from the `998` serial run:

```text
TC7200U XMITDESC i=0 nr_frags=0 size=154 mapping=0x06834002 len_stat=0x009a6fc0 bd_addr=b2c03000 ring=0 write_ptr=1 prod=0 free=256
```

First watchdog:

```text
NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out 2010 ms
```

First timeout dump:

```text
TC7200U TXDUMP timeout_entry periph_stat=0x40030004 periph_mask=0x00002000 intr0_stat=0xffffffea intr0_mask=0x8680dcb4 intr1_stat=0x0000007d intr1_mask=0x80a2ece8 tdma_ctrl=0x00003000 tdma_stat=0x00000800 sw_prod=0 sw_c=0 hw_p=0 hw_c=14340 free_bds=0 clean=0 write=0
```

After timeout, the descriptor path continues with invalid ring counters:

```text
TC7200U XMITDESC i=0 nr_frags=0 size=154 mapping=0x06e3e802 len_stat=0x009a6fc0 bd_addr=b2c03000 ring=0 write_ptr=1 prod=17920 free=65792
```

Conclusion from xmit/timeout:

- Linux can bring up `eth0`.
- The fixed link reports carrier.
- The xmit path queues real descriptors.
- TDMA does not consume them.
- Timeout/recovery exposes invalid ring state.
- The issue remains before switch/B53/MDIO integration.

## Runtime result: user `devmem` control dump

A direct runtime `devmem` dump was captured before the mapped `998` repair. It showed FPM/profile readable, but GENET/MBDMA frozen controls not programmed.

### FPM

```text
FPM_A
0x12200010 = 0x00000000
0x12200014 = 0x00000001
0x12200040 = 0x06000000
0x12200044 = 0x00010000

FPM_B
0x12200050 = 0x00000000
0x12200054 = 0x18007EFA
0x12200058 = 0x00000000
0x1220005c = 0x00000000

FPM_C
0x12200200 = 0x80170800
0x12200208 = 0x9008C400
0x12200210 = 0xA01B8200
0x12200218 = 0xB0324100
```

Interpretation:

- FPM space is readable and live.
- `0x12200040` contains the expected encoded class-looking value `0x06000000`.
- `0x12200044 = 0x00010000` is nonzero and stable enough to remain a control target.
- Endpoint locations produce live token/status-like values and should not be treated as fixed constants.

### GENET/MBDMA

```text
GMAC_A
0x12c00004 = 0x00000001
0x12c00008 = 0x00000001
0x12c0000c = 0x00000001
0x12c00010 = 0x00000001

GMAC_B
0x12c00040 = 0x00000001
0x12c00044 = 0x00000001
0x12c00048 = 0x00000001
0x12c0004c = 0x00000001

GMAC_C
0x12c00050 = 0x00000001
0x12c00054 = 0x00000001
0x12c00058 = 0x00000001
0x12c00070 = 0x00000001

GMAC_CH1
0x12c00100 = 0x00000001
0x12c00104 = 0x00000001
0x12c00120 = 0x00000001
0x12c00124 = 0x00000001

GMAC_CH2
0x12c00140 = 0x00000001
0x12c00144 = 0x00000001
0x12c00180 = 0x00000001
0x12c00184 = 0x00000001
```

Interpretation:

- The frozen GENET/MBDMA expected values were not present through `devmem`.
- This supported the hypothesis that the stock upstream BCMGENET path was not reproducing TC7200U-specific FPM/MBDMA programming.

### Profile block

```text
PROFILE
0x14e001c4 = 0xDA492010
0x14e00002 = 0x00A2
0x14e00264 = 0x00000000
```

Interpretation:

- Profile/control register space is readable.
- `0x14e001c4` is nonzero and likely carries board/profile state.
- Semantics remain comparison-only.

## Runtime result: `998` mapped control dump

The image `fresh-genet-ctrlmap-20260619-085019.bin` was successfully transferred as `gc.bin` after multiple long-name and stale-session TFTP failures.

Successful CFE transfer markers:

```text
Tftp complete
Received 5709330 bytes
File Length: 5709238 bytes
Load Address: 82000000
Filename: fresh-genet-ctrlmap-20260619-085019.bin
Executing Image 4
Linux version 6.12.93
```

### `998` placement worked

The serial log proves all intended `998` dump points executed:

```text
TC7200U CTRL open_entry
TC7200U CTRL open_exit
TC7200U CTRL timeout_entry
TC7200U CTRL timeout_exit
```

So the patch placement is valid:

- `bcmgenet_open()` entry point reached.
- `bcmgenet_open()` success/exit path reached.
- `bcmgenet_timeout()` entry reached.
- `bcmgenet_timeout()` exit reached.

### `998` FPM reads are plausible

Example open-entry FPM values:

```text
TC7200U CTRL open_entry FPM_A 12200010=0x00000000 12200014=0x00000001 12200040=0x06000000 12200044=0x00010000
TC7200U CTRL open_entry FPM_B 12200050=0x00000000 12200054=0x18007eaf 12200058=0x00000000 1220005c=0x00000000
TC7200U CTRL open_entry FPM_C 12200200=0x80348800 12200208=0x900fc400 12200210=0xa01b8200 12200218=0xb00db100
```

Example timeout-entry FPM values:

```text
TC7200U CTRL timeout_entry FPM_A 12200010=0x00000000 12200014=0x00000001 12200040=0x06000000 12200044=0x00010000
TC7200U CTRL timeout_entry FPM_B 12200050=0x00000000 12200054=0x18007e91 12200058=0x00000000 1220005c=0x00000000
TC7200U CTRL timeout_entry FPM_C 12200200=0x800a8800 12200208=0x90324400 12200210=0xa01bc200 12200218=0xb00fa100
```

Interpretation:

- FPM KSEG1 reads continue to look plausible and consistent with `devmem`.
- `0x12200040` and `0x12200044` remain stable.
- endpoint registers vary as live token/status surfaces.

### `998` GMAC/mapped GENET reads are invalid evidence

The mapped `998` GENET/MBDMA values looked pointer-shaped rather than register-shaped:

```text
TC7200U CTRL open_entry GMAC_A off0004=0x86e399e0 off0008=0xb2c00000 off000c=0xb2c00000 off0010=0xb2c00000
TC7200U CTRL open_entry GMAC_B off0040=0x86e399e0 off0044=0xb2c00000 off0048=0xb2c00000 off004c=0xb2c00000
TC7200U CTRL open_entry GMAC_C off0050=0x86e399e0 off0054=0xb2c00000 off0058=0xb2c00000 off0070=0xb2c00000
```

Timeout-entry showed the same problem:

```text
TC7200U CTRL timeout_entry GMAC_A off0004=0x8680dbc8 off0008=0xb2c00000 off000c=0xb2c00000 off0010=0xb2c00000
TC7200U CTRL timeout_entry GMAC_B off0040=0x8680dbc8 off0044=0xb2c00000 off0048=0xb2c00000 off004c=0xb2c00000
TC7200U CTRL timeout_entry GMAC_C off0050=0x8680dbc8 off0054=0xb2c00000 off0058=0xb2c00000 off0070=0xb2c00000
```

Important observation:

```text
0xb2c00000 is the KSEG1 alias of physical 0x12c00000
```

Therefore, repeated `0xb2c00000` in register-value fields is not credible register content. It indicates one or more of:

- accessor misuse,
- logging/varargs/evaluation problem,
- non-normal mapped-base handling in this context,
- wrong assumption about direct offset access from `priv->base`,
- compiler/format interaction with the helper as written.

Current rule:

- Treat `998` GMAC values as invalid evidence.
- Do not use them to justify `999` writes.
- Do not reinterpret OEM expected values downward to the bad `998` values.

## Functions touched or discussed

### `bcmgenet_open(struct net_device *dev)`

Patch role:

- Inserted control dump at `open_entry`.
- Inserted control dump at `open_exit`.

Purpose:

- Compare control registers before and after BCMGENET open path performs driver setup.

Result:

- Dump placement works.
- FPM reads plausible.
- GMAC reads invalid/pointer-shaped in current `998` helper.

### `bcmgenet_timeout(struct net_device *dev, unsigned int txqueue)`

Patch role:

- `997` dumps TX timeout/ring state at entry and exit.
- `998` dumps control state at timeout entry and exit.

Result:

- Timeout path is reproducible.
- TDMA state remains stuck:
  - `tdma_ctrl=0x00003000`
  - `tdma_stat=0x00000800`
  - `hw_p=0`
  - `hw_c=14340`
- Post-timeout software ring state becomes invalid:
  - `prod=17920`
  - `free=65792`

### `tc7200u_genet_tx_timeout_dump(struct net_device *dev, const char *tag)`

Added by repaired `997`.

Purpose:

- Dump BCMGENET timeout-time TX/RX/IRQ/TDMA/ring fields.

Result:

- Useful and still valid.
- Proves TDMA does not consume queued TX descriptors.
- Proves timeout recovery reveals invalid ring state.

### `tc7200u_genet_ctrl_dump(struct net_device *dev, const char *tag)`

Added by `998`.

Purpose:

- Dump FPM, GENET/MBDMA, and profile registers at open/timeout points.

Result:

- Patch placement is valid.
- FPM/profile reads look useful.
- GMAC/GENET reads are invalid in the current helper implementation.

### Existing BCMGENET helper/accessor functions

Observed existing helper patterns:

```c
bcmgenet_readl(...)
bcmgenet_tdma_readl(...)
bcmgenet_rdma_readl(...)
bcmgenet_tdma_ring_readl(...)
bcmgenet_rdma_ring_readl(...)
```

The tree uses `priv->base` for TDMA/RDMA accesses. This justified trying a mapped `998`, but the serial output shows the helper still needs repair before its GMAC values are trusted.

## Structures and datatypes

No Ghidra datatype or structure definition was changed in this pass.

Runtime/kernel-side structures involved:

| Structure/type | Role in this pass | Status |
|---|---|---|
| `struct net_device` | passed into BCMGENET open/timeout/xmit paths | unchanged |
| `struct bcmgenet_priv` | carries BCMGENET private state including mapped base and ring structures | unchanged |
| BCMGENET TX ring state | exposed indirectly through `prod`, `free_bds`, `clean`, `write`, `hw_p`, `hw_c` | current logged values indicate mismatch/corruption after timeout |
| TX descriptor/BD fields | logged by `996` as `bd_addr`, DMA mapping, `len_stat` | descriptor queueing proven real |
| FPM allocator/token endpoint model | reverse-side hardware model carried from OEM notes | not a Linux datatype; used as comparison model |
| GENET/MBDMA frozen-control model | reverse-side register/control model carried from OEM notes | still comparison target; not yet reproduced by OpenWrt |

Reverse-side structures/datatypes relevant but not modified:

- FPM allocator object and packet-token model.
- GENET/MBDMA control registers derived from OEM reverse notes.
- DQM/CP2/FPM layers remain later-stage correlation surfaces only.

## Memory/register labeling implications for Ghidra

No new Ghidra memory-block or datatype changes were made, but the runtime evidence reinforces the existing naming/layout scheme:

| Block | Physical | KSEG1 alias | Meaning |
|---|---:|---:|---|
| `MMIO_FPM_B2200000` | `0x12200000` | `0xb2200000` | FPM / token allocator hardware |
| `MMIO_GENET_B2C00000` | `0x12c00000` | `0xb2c00000` | GENET / UMAC / MBDMA-facing window |
| `MMIO_PERIPH_B4E00000` | `0x14e00000` | `0xb4e00000` | profile, clock, reset, IRQ, UART region |

Recommended Ghidra annotation style for this pass:

```text
Runtime FPM reads are plausible through {@address b2200000}; GENET/MBDMA control reads through current 998 are invalid evidence because repeated value {@address b2c00000} appears as a register value.
```

Suggested function comments if annotating a matching decompiled flow later:

```text
TC7200U OpenWrt 998 result: FPM/profile dump placement is valid, but GMAC values from current helper are not trusted; repeated {@address b2c00000} in value fields indicates accessor/logging bug, not OEM-equivalent MBDMA state.
```

## Final interpretation before the next repair

The evidence supports these conclusions:

1. The OpenWrt image still boots correctly to userspace.
2. BCMGENET still binds at `0x12c00000` and creates `eth0`.
3. Fixed-link RGMII still reports link up.
4. The xmit path queues real TX descriptors.
5. TDMA still does not consume queued descriptors.
6. The repaired `997` timeout dump is valid and useful.
7. FPM and profile register spaces are readable and active.
8. The direct `devmem` GENET/MBDMA frozen-control set still reads as `0x00000001` and does not match OEM-derived expected values.
9. The current `998` GMAC/GENET mapped read output is invalid because it reports pointer-shaped values, especially repeated `0xb2c00000`.
10. A `999` write/init patch is **not yet justified** from the current `998` GMAC output.

## Current blocker

The blocker is no longer whether BCMGENET probes or whether TX descriptors are queued. Those are proven.

The active blocker is:

```text
Need trustworthy kernel-side GENET/MBDMA register reads before applying any TC7200U-specific MBDMA/FPM writes.
```

## Next action after this log

Next action should be the planned `CTRL2` repair of `998`, using:

- one register per log line,
- local variables,
- printed `base` and computed `addr`,
- comparison of:
  - `bcmgenet_readl(addr)`,
  - `__raw_readl(addr)`,
  - `readl(addr)`.

This should determine whether the current invalid GMAC values come from:

- accessor choice,
- mapped address interpretation,
- logging/varargs behavior,
- or the register window itself.

Do not apply `999` before this is resolved.

## Git commit note

Suggested commit message:

```text
records: capture TC7200U GENET ctrlmap diagnostics
```

Suggested files to add in the real WSL repository:

```text
records/status/2026-06-19-genet-ctrlmap-debug-findings.md
records/logs/serial/picocom-20260619-223316.log
records/logs/builds/2026-06-19-bcmgenet-998-mapped-ctrl-build.log
records/generated/last-console-candidate-bin.txt
```

If some build/generated files do not exist in the repository, commit only the present files.
