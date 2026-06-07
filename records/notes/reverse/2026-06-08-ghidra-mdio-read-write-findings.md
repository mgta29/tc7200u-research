# TC7200U Ghidra MDIO read/write findings - 2026-06-08

## Context

Follow-up Ghidra reverse pass after confirming GENET MMIO register `GENET_REG_12c00070`.

A volatile uninitialized MMIO block was added in Ghidra:

- Block name: `GENET_MMIO_KSEG1`
- KSEG1 range: `0xb2c00000-0xb2c02fff`
- Physical range: `0x12c00000-0x12c02fff`
- Mapping rule: `KSEG1 - 0xa0000000 = physical`

This made GENET/MDIO MMIO labels navigable.

## Confirmed MDIO MMIO bases

### MDIO0

- KSEG1: `0xb2c00600`
- Physical: `0x12c00600`
- Label: `GENET_MDIO_BASE_12c00600`

### MDIO1

- KSEG1: `0xb2c02600`
- Physical: `0x12c02600`
- Label: `GENET_MDIO_BASE_12c02600`

Corrected typo:

- Wrong: `GENET_MDIO_BASE_12c2600`
- Correct: `GENET_MDIO_BASE_12c02600`

## Confirmed MDIO register offsets

Both MDIO blocks use the same offsets:

```text
+0x2c = command/control
+0x2e = read data
+0x30 = write data / control
+0x32 = busy/status byte, bit0

Concrete physical addresses:

MDIO0:
  0x12c0062c = command/control
  0x12c0062e = read data
  0x12c00630 = write data/control
  0x12c00632 = busy/status

MDIO1:
  0x12c0262c = command/control
  0x12c0262e = read data
  0x12c02630 = write data/control
  0x12c02632 = busy/status

Recommended labels:

b2c0062c -> GENET_MDIO0_CMD_12c0062c
b2c0062e -> GENET_MDIO0_RDATA_12c0062e
b2c00630 -> GENET_MDIO0_WDATA_12c00630
b2c00632 -> GENET_MDIO0_STATUS_12c00632

b2c0262c -> GENET_MDIO1_CMD_12c0262c
b2c0262e -> GENET_MDIO1_RDATA_12c0262e
b2c02630 -> GENET_MDIO1_WDATA_12c02630
b2c02632 -> GENET_MDIO1_STATUS_12c02632
fn_enet_mdio_read16_wait

Address:

803af8b0

Final signature:

ushort fn_enet_mdio_read16_wait(uint phy_addr, uint reg_num, uint *wait_count, uint mdio_bus)

Behavior:

if (1 < mdio_bus) {
    mdio_bus = 0;
}

base = GENET_MDIO_BASE_12c00600;

if ((&DAT_81479fb0)[mdio_bus] != 0) {
    base = GENET_MDIO_BASE_12c02600;
}

*(uint *)(base + 0x2c) =
    (reg_num & 0x1f) << 0x10 |
    0x20000000 |
    (phy_addr & 0x1f) << 0x15 |
    0x08000000;

wait until `(base + 0x32) bit0` clears, max about 201 loops.

*wait_count = loop_count;

return *(ushort *)(base + 0x2e);

Command bit interpretation:

reg_num  -> bits 20:16
phy_addr -> bits 25:21
read op/control includes 0x20000000 | 0x08000000
fn_enet_mdio_read_phy_reg

Address:

803af890

Final signature:

ushort fn_enet_mdio_read_phy_reg(uint phy_addr, uint reg_num, uint *wait_count, uint mdio_bus)

Behavior:

if (phy_addr == 0xff) {
    phy_addr = (&DAT_81479fa0)[mdio_bus];
}

if (1 < mdio_bus) {
    mdio_bus = 0;
}

return fn_enet_mdio_read16_wait(phy_addr, reg_num, wait_count, mdio_bus);

Meaning:

phy_addr == 0xff means use the stored/default PHY address for that MDIO bus.
This wrapper is used by the ENET MAC/PHY probe flow.
fn_enet_mdio_write_phy_reg

Address:

803af940

Corrected signature:

void fn_enet_mdio_write_phy_reg(undefined4 unused, uint phy_addr, uint reg_num, uint write_value)

Important ABI note:

mdio_bus is not passed as a normal a0-a3 argument here.
mdio_bus is carried in register t1 by the caller delay slot.

Observed caller pattern:

jal  fn_enet_mdio_write_phy_reg
move t1,s0

Behavior:

base = GENET_MDIO_BASE_12c00600;

if ((&DAT_81479fb0)[t1] != 0) {
    base = GENET_MDIO_BASE_12c02600;
}

*(uint *)(base + 0x30) =
    (*(uint *)(base + 0x30) & 0xffff0000) |
    (write_value & 0xffff);

*(uint *)(base + 0x2c) =
    (reg_num & 0x1f) << 0x10 |
    0x10000000 |
    (phy_addr & 0x1f) << 0x15 |
    0x08000000;

wait until `(base + 0x32) bit0` clears.

Command bit interpretation:

reg_num     -> bits 20:16
phy_addr    -> bits 25:21
write_value -> low 16 bits written through +0x30
write op/control includes 0x10000000 | 0x08000000
fn_enet_build_core_cmd

Address region:

Around 803af050

Purpose:

Builds GMAC command and speed/duplex selection from PHY type and link mode.

Observed behavior:

fn_enet_mdio_write_phy_reg(0xff, 0, 7, 0x90ff);
fn_enet_mdio_write_phy_reg(0xff, 0, 7, 0x90fb);
fn_enet_mdio_write_phy_reg(0xff, 0, 7, 0x90fb);

Because of the corrected write-helper ABI, this means:

unused      = 0xff
phy_addr    = 0
reg_num     = 7
write_value = 0x90ff / 0x90fb
mdio_bus    = passed in t1 by caller delay slot

Speed/duplex command mapping seen in decompiler:

1000 half -> 0x0040
1000 full -> 0x0140
100 full  -> 0x2100
100 half  -> 0x2000
10 full   -> 0x0100
10 half   -> 0x0000

Then command is applied by:

FUN_803aefb8(param_1, uVar1)

Suggested rename:

FUN_803aefb8 -> fn_enet_apply_gmac_speed_duplex_cmd

PHY type detection:

uVar2 = fn_enet_mdio_read_phy_reg(0xff, 3, local_30, param_1);

if ((uVar2 & 0x3f0) == 0x1e0) {
    "BCM5221"
}
else if ((uVar2 & 0x3f0) == 0x210) {
    "BCM5201/BCM5202"
}
else if ((uVar2 & 0x3f0) == 0xf0) {
    "BCM3345/BCM3360"
}
else if ((uVar2 & 0x3f0) == 0x260) {
    "B50612E"
}
else {
    "Unknown phy"
}

Also observed:

uVar2 = fn_enet_mdio_read_phy_reg(0xff, 4, local_30, param_1);
FUN_803af7e4(0xff, 4, uVar2 | 0xe0, local_30);

Suggested next target:

G -> 803af7e4

Likely higher-level MDIO write wrapper.

Current reverse chain

Confirmed path:

fn_enet_probe_mac_phy_id
  -> fn_enet_mdio_read_phy_reg
     -> fn_enet_mdio_read16_wait
        -> GENET MDIO0/MDIO1 MMIO at 0x12c00600 / 0x12c02600

fn_enet_build_core_cmd
  -> fn_enet_mdio_write_phy_reg
     -> GENET MDIO0/MDIO1 MMIO at 0x12c00600 / 0x12c02600
Relevance to OpenWrt blocker

The active OpenWrt blocker is GENET/TDMA/RX behavior. These findings prove the OEM firmware uses GENET-side MDIO blocks inside the 0x12c00000 range and selects between two MDIO blocks at 0x12c00600 and 0x12c02600.

Next reverse work should keep searching for:

GENET DMA/TDMA descriptor base registers
TX/RX enable sequencing
DMA status/busy bits
GENET register windows near 0x12c00000
Additional DAT_b2c0.... symbols in Ghidra Symbol Table
