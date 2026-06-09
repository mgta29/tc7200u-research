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

## Source notes

Derived from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-08-ghidra-enet-genet-consolidated-summary.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-08-ghidra-enet-genet-consolidated-summary-addendum.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-08-ghidra-mdio-read-write-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-08-gmac-ghidra-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-08-ghidra-mbdma-static-dma-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse\2026-06-08-enet-gmac-step1-mdio-profile-findings.md`

## Preservation

Created as a new dated bring-up note. No old logs or notes were edited or deleted.

## Refresh after full reverse reread

This section was added after rereading the full reverse-note set under:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse`

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
