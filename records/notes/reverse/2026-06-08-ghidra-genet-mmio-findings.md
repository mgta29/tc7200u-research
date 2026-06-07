# TC7200U Ghidra GENET/MMIO findings - 2026-06-08

## Context

Reverse-analysis pass in Ghidra on `image.raw`.

Confirmed import/decode setup:

- Raw image mapped at `ram:80004000-ram:8183ff07`.
- Correct language: `MIPS:BE:32:default`.
- `ISA_MODE` forced to `0`.
- Correct 4-byte MIPS32 decode confirmed at entry:
  - `80004000 40 80 90 00 mtc0 zero,WatchLo`
  - `80004004 00 00 00 00 nop`

## Key correction

Initial decode was wrong because Ghidra interpreted the image as low-bit/MIPS16 mode:

- Bad state: `assume ISA_MODE = 0x1`
- Fixed state: `assume ISA_MODE = 0x0`

A Java Ghidra script was used to clear the bad decode and set `ISA_MODE = 0` over the loaded range.

## Confirmed GENET MMIO access

### `fn_enet_gmac_init_step2`

Address:

- `803a8b30`

Confirmed register:

- Ghidra symbol before rename: `DAT_b2c00070`
- Renamed to: `GENET_REG_12c00070`

Address mapping:

- KSEG1 virtual: `0xb2c00070`
- Physical: `0x12c00070`
- Calculation: `0xb2c00070 - 0xa0000000 = 0x12c00070`

This is inside the known GENET block:

- `0x12c00000`

Observed behavior:

```c
if (0 < DAT_8184006c) {
    if (param_1 == 0) {
        GENET_REG_12c00070 = GENET_REG_12c00070 | 3;
        return;
    }
}
GENET_REG_12c00070 = GENET_REG_12c00070 | 0x30000;
Meaning:

fn_enet_gmac_init_step2(0) sets:
GENET_REG_12c00070 |= 0x00000003
fn_enet_gmac_init_step2(1) sets:
GENET_REG_12c00070 |= 0x00030000

Reference search showed 16 read/write references to GENET_REG_12c00070, all inside the same step2 function region.

Higher-level ENET probe/init flow
FUN_803af53c

Suggested name:

fn_enet_probe_mac_phy_id

Evidence:

Calls:
fn_enet_gmac_init_step1()
fn_enet_gmac_init_step2(0)
fn_enet_gmac_init_step2(1)
Uses string:
str_enet_probe_mac_phy_id_timeout
Loops over possible MAC/PHY profile values.

Relevant decompiler excerpt:

fn_enet_gmac_init_step1();
fn_enet_gmac_init_step2(0);
fn_enet_gmac_init_step2(1);

uVar2 = REG_14e001c4_enet_profile_ctrl & 0xffffe3ff;
REG_14e001c4_enet_profile_ctrl = uVar2 | 0x1000;
...
REG_14e001c4_enet_profile_ctrl = uVar2 | 0x1400;

FUN_803a8ac0(0);
FUN_803a8ac0(1);
FUN_803a8720();
Additional renamed profile/control registers

These were renamed conservatively because they are not yet proven GENET registers, but are clearly ENET/profile related.

_DAT_b4e001c4

Renamed to:

REG_14e001c4_enet_profile_ctrl

Address mapping:

KSEG1 virtual: 0xb4e001c4
Physical: 0x14e001c4

Observed writes:

Clears mask 0xffffe3ff
Sets 0x1000
Later sets 0x1400
_DAT_b4e00002

Renamed to:

REG_14e00002_enet_profile_status

Address mapping:

KSEG1 virtual: 0xb4e00002
Physical: 0x14e00002

Observed use:

((REG_14e00002_enet_profile_status & 0xf0) != 0x10)
((REG_14e00002_enet_profile_status & 0xf0) != 0x20)
Functions inspected
fn_enet_gmac_init_core

Address:

803a8c10

Observed as a core wrapper/helper. It checks DAT_81479f50, sets bits in DAT_b4e002c and DAT_b4e002f4, and calls FUN_808ff3f8(2).

No direct GENET 0x12c0xxxx MMIO was proven here.

fn_enet_gmac_init_step1

Observed as a wrapper:

fn_enet_gmac_init_core();
return;

No direct GENET MMIO.

fn_enet_gmac_init_step2

Confirmed GENET MMIO writer for GENET_REG_12c00070.

fn_enet_gmac_init_step6

Observed as a logging wrapper:

FUN_00031544("Starting Enet UNIMAC/MDMA/PHY ...", param_3, param_4);
return;

No direct GENET MMIO shown in this wrapper.

FUN_803c5d34

Inspected because it was called near step6. It is a dispatcher/wrapper:

if (DAT_8147a044 == 1) {
    return FUN_803cf528(param_1, param_2 & 0xff, param_3, param_4 & 0xff);
}
return 0xc000001;
FUN_803cf528

This path was identified as SPI/flash-related, not GENET:

Contains string/reference resembling:
SPIDriverWriteOffset...Failed

Do not continue this branch for GENET init.

Search notes

Scalar search for full 0x12c00000 did not find direct values because MIPS often builds addresses by upper halves or aliases.

Useful searches:

0x12c0 / decimal 4800
0xb2c0 / decimal 45760

Important mapping rule for this target:

KSEG1 virtual b2c0xxxx -> physical 12c0xxxx
KSEG1 virtual b4e0xxxx -> physical 14e0xxxx
Current reverse conclusion

Confirmed OEM code touches GENET physical register 0x12c00070 during GMAC init stage 2.

This is likely a board/profile/interface enable register or mode-control register relevant to GENET/UNIMAC bring-up.

The known OpenWrt blocker remains TDMA/descriptor consumption/RX-zero behavior, so next reverse work should focus on locating OEM code that configures:

GENET DMA/TDMA registers under 0x12c0xxxx
descriptor base/size/count registers
RX/TX enable sequencing
clock/reset/profile gates around 0x14e0xxxx
Next targets

Inspect these next in Ghidra:

FUN_803af890
likely MAC/PHY ID probe helper
FUN_803a8ac0
called with 0 and 1 during cleanup/fallback
FUN_803a8720
called after profile fallback
FUN_803af504
FUN_803af4d4
Symbol Table filter:
b2c0
b4e0
Preservation note

This is a new dated reverse note. No old logs or records were deleted.
