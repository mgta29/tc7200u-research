# TC7200U Ghidra ENET/GENET consolidated summary - 2026-06-08

## Scope

This note consolidates the 2026-06-08 Ghidra reverse findings related to:

- decode/import correctness
- ENET profile probing
- GENET MMIO
- MDIO read/write paths
- GMAC/MBDMA global init
- runtime stub-patch side paths

Source notes consolidated here:

- `2026-06-08-ghidra-genet-mmio-findings.md`
- `2026-06-08-ghidra-genet-stub-patch-findings.md`
- `2026-06-08-ghidra-mdio-read-write-findings.md`
- `20260608-022107-ghidra-enet-phy-profile-probe-findings.md`
- `20260608-024340-ghidra-gmac-mbdma-global-major-findings.md`

## Decode/import baseline

Confirmed correct stage1 import/decode:

- raw image mapped at `ram:80004000-ram:8183ff07`
- language: `MIPS:BE:32:default`
- `ISA_MODE = 0`
- normal 4-byte `MIPS32` decode at entry

Important correction:

- earlier low-bit / `MIPS16`-style decode was wrong
- several earlier interpretations made under that state should not be trusted without re-checking against the corrected `MIPS32` view

## High-confidence reverse chain

Current high-confidence ENET/GENET chain:

- `fn_enet_probe_mac_phy_id @ 803af53c`
  - top-level MAC/PHY profile probe selector
- `fn_enet_gmac_init_step1`
  - wrapper around GMAC core init
- `fn_enet_gmac_init_step2 @ 803a8b30`
  - confirmed writer to `GENET_REG_12c00070`
- `fn_enet_gmac_mbdma_global_init @ 803a8790`
  - confirmed GENET MBDMA/global register setup path
- `fn_enet_mdio_read_phy_reg @ 803af890`
  - wrapper around low-level MDIO read
- `fn_enet_mdio_read16_wait @ 803af8b0`
  - direct MDIO MMIO read transaction builder/poller
- `fn_enet_mdio_write_phy_reg @ 803af940`
  - direct MDIO MMIO write transaction builder/poller

## Confirmed GENET MMIO

### `GENET_REG_12c00070`

Confirmed writer:

- `fn_enet_gmac_init_step2 @ 803a8b30`

Address mapping:

- KSEG1 virtual: `0xb2c00070`
- physical: `0x12c00070`

Observed behavior:

- `fn_enet_gmac_init_step2(0)` sets:
  - `GENET_REG_12c00070 |= 0x00000003`
- `fn_enet_gmac_init_step2(1)` sets:
  - `GENET_REG_12c00070 |= 0x00030000`

Interpretation:

- this is a confirmed GENET-side mode/control register used during GMAC init stage 2
- it is inside the main `0x12c00000` GENET window

### ENET/profile control block

Conservative related register labels:

- `0xb4e001c4 -> REG_14e001c4_enet_profile_ctrl`
- `0xb4e00002 -> REG_14e00002_enet_profile_status`
- `0xb4e0008c -> REG_14e0008c_enet_profile_ctrl`

Observed behavior includes:

- clearing mask `0xffffe3ff`
- setting `0x1000`
- later setting `0x1400`
- testing high nibble values in the status path

These are clearly ENET/profile related, but not yet proven as direct GENET MMIO.

## Confirmed MDIO MMIO

### MDIO block bases

- `GENET_MDIO_BASE_12c00600`
  - KSEG1 `0xb2c00600`
  - physical `0x12c00600`
- `GENET_MDIO_BASE_12c02600`
  - KSEG1 `0xb2c02600`
  - physical `0x12c02600`

### Shared MDIO register layout

For both bases:

- `+0x2c` command/control
- `+0x2e` read data
- `+0x30` write data/control
- `+0x32` busy/status byte, bit0

Recommended concrete labels:

- `0xb2c0062c -> GENET_MDIO0_CMD_12c0062c`
- `0xb2c0062e -> GENET_MDIO0_RDATA_12c0062e`
- `0xb2c00630 -> GENET_MDIO0_WDATA_12c00630`
- `0xb2c00632 -> GENET_MDIO0_STATUS_12c00632`
- `0xb2c0262c -> GENET_MDIO1_CMD_12c0262c`
- `0xb2c0262e -> GENET_MDIO1_RDATA_12c0262e`
- `0xb2c02630 -> GENET_MDIO1_WDATA_12c02630`
- `0xb2c02632 -> GENET_MDIO1_STATUS_12c02632`

## Confirmed MDIO helper behavior

### `fn_enet_mdio_read16_wait @ 803af8b0`

Behavior:

- bounds MDIO bus to `0` or `1`
- chooses MDIO0 or MDIO1 base depending on selected mode array state
- writes command word to `base + 0x2c`
- polls `base + 0x32` bit0 until clear
- returns `*(ushort *)(base + 0x2e)`

Command construction:

- register number -> bits `20:16`
- PHY address -> bits `25:21`
- read op bits include `0x20000000 | 0x08000000`

### `fn_enet_mdio_read_phy_reg @ 803af890`

Behavior:

- `phy_addr == 0xff` means use stored/default PHY address for that MDIO bus
- then delegates to `fn_enet_mdio_read16_wait(...)`

### `fn_enet_mdio_write_phy_reg @ 803af940`

Behavior:

- selects MDIO0 or MDIO1 base from mode array state
- writes low 16 bits of data to `base + 0x30`
- writes command word to `base + 0x2c`
- polls `base + 0x32` bit0 until clear

ABI note:

- `mdio_bus` is not passed as a normal `a0-a3` argument
- it is carried in register `t1` by the caller delay slot

## ENET candidate/profile probing

`fn_enet_probe_mac_phy_id @ 803af53c` is the top-level profile probe selector.

Observed behavior:

- calls `fn_enet_gmac_init_step1()`
- calls `fn_enet_gmac_init_step2(0)`
- calls `fn_enet_gmac_init_step2(1)`
- updates ENET/profile control state
- loops candidate tables
- toggles MDIO1 control bit `0x400` when required
- stores selected profile/mode/address globals
- reads PHY register `2` through `fn_enet_mdio_read_phy_reg(...)`

Suggested table/global names:

- `DAT_81479fc0 -> tbl_enet_candidate_mdio_mode`
- `DAT_81479fc1 -> tbl_enet_candidate_phy_addr`
- `DAT_81479fc2 -> tbl_enet_candidate_flag`
- `DAT_81479fa8 -> g_enet_selected_phy_addr`
- `DAT_81479fb0 -> g_enet_selected_mdio_mode`
- `DAT_81479fb8 -> g_enet_selected_flag`
- `DAT_81479fd0 -> g_enet_probe_needed`

## MDIO1 mode-bit helpers

Confirmed helpers:

- `fn_enet_mdio1_set_ctrl_0400 @ 803af4d4`
- `fn_enet_mdio1_clear_ctrl_0400 @ 803af504`

Behavior:

- set/clear bit `0x400` in the MDIO1 block at `GENET_MDIO_BASE_12c02600`

## PHY reset and diagnostics

Confirmed helpers:

- `fn_enet_phy_soft_reset_wait @ 803af2f8`
- `fn_enet_dump_phy_mii_regs @ 803af3bc`

Behavior:

- soft-reset helper writes BMCR reset bit `0x8000`, then polls until clear
- diagnostic helper dumps PHY/MII registers over selected MDIO bus with wait/timing data

## Core command builder and PHY identification

`fn_enet_build_core_cmd`:

- builds BMCR speed/duplex command values
- applies them through the MDIO write path
- reads PHY registers `3` and `4`
- identifies known PHY families from masked values

Observed command mapping:

- `1000 half -> 0x0040`
- `1000 full -> 0x0140`
- `100 full -> 0x2100`
- `100 half -> 0x2000`
- `10 full -> 0x0100`
- `10 half -> 0x0000`

Suggested rename:

- `FUN_803aefb8 -> fn_enet_apply_gmac_speed_duplex_cmd`

## GMAC/MBDMA global init

High-confidence function:

- `FUN_803a8790 -> fn_enet_gmac_mbdma_global_init`

Evidence:

- string `GMAC_MBDMA_Global: 0x%x`
- direct writes into the GENET KSEG1 `0xb2c00000` window

Confirmed GENET/MBDMA/global registers written:

- `0xb2c00008 -> 0x12c00008`
- `0xb2c0000c -> 0x12c0000c`
- `0xb2c00010 -> 0x12c00010`
- `0xb2c0004c -> 0x12c0004c`
- `0xb2c00050 -> 0x12c00050`
- `0xb2c00054 -> 0x12c00054`
- `0xb2c00058 -> 0x12c00058`

Recommended labels:

- `GENET_MBDMA_GLOBAL_12c00008`
- `GENET_MBDMA_GLOBAL_CTRL_12c0000c`
- `GENET_MBDMA_GLOBAL_12c00010`
- `GENET_MBDMA_GLOBAL_12c0004c`
- `GENET_MBDMA_GLOBAL_12c00050`
- `GENET_MBDMA_GLOBAL_12c00054`
- `GENET_MBDMA_GLOBAL_12c00058`

Observed behavior:

- allocates or obtains DMA-visible addresses
- masks them with `0x1fffffff`
- stores them into the GENET/MBDMA register block
- configures the control register at `0x12c0000c`

Interpretation:

- this is a confirmed non-MDIO GENET DMA/global setup path and is directly relevant to descriptor, DMA, and RX/TX bring-up

## Runtime stub-patch side path

Confirmed stub/dispatcher observations:

- runtime patch dispatchers touch:
  - `0x12c00500`
  - `0x12c00510`
- patch-record state stored at `b6001df0`
- stack/stub patch helpers update generated instruction slots near `0x80007000`

Important boundary:

- this cluster is runtime stub/board-option dispatch machinery
- it is not the main GMAC/GENET initialization path

It is still worth keeping because it proves additional GENET-related register usage:

- `GENET_REG_12c00500`
- `GENET_REG_12c00510`

## Reverse conclusion

The current strongest OEM-side ENET/GENET conclusions are:

- OEM firmware definitely uses the GENET `0x12c00000` physical window
- OEM firmware definitely uses dual MDIO blocks at:
  - `0x12c00600`
  - `0x12c02600`
- OEM firmware definitely performs a dedicated GMAC/MBDMA global init step at `803a8790`
- `fn_enet_probe_mac_phy_id` is the entry point for profile/PHY probing and mode selection
- `fn_enet_gmac_init_step2` writes a confirmed GENET mode/control register at `0x12c00070`

This is directly relevant to the active OpenWrt blocker around:

- descriptor base/size programming
- GENET DMA/TDMA bring-up
- RX/TX enable sequencing
- ENET profile/mode gates

## Best current next targets

Highest-value next reverse targets:

- `8009f6e8`
- `8009f83c`
- `803a8ac0`
- `803a8720`
- `803af7e4`

Highest-value search terms / filters:

- `b2c0`
- `12c0`
- `b4e0`
- `14e0`

Likely next label opportunities:

- additional `GENET_MBDMA_GLOBAL_*`
- descriptor allocator/buffer helper names near the `8009f6e8` and `8009f83c` paths
- RX/TX enable/status registers adjacent to known `0x12c00000` hits

## Preservation

Created as a new dated reverse note. No old notes were edited or deleted.
