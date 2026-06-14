# Ghidra ENET PHY/profile probe findings

## Main probe flow

`fn_enet_probe_mac_phy_id @ 803af53c` is the main ENET MAC/PHY profile probe selector.

Observed sequence:

- calls `fn_enet_gmac_init_step1()`
- calls `fn_enet_gmac_init_step2(0)`
- calls `fn_enet_gmac_init_step2(1)`
- sets `REG_14e001c4_enet_profile_ctrl = (old & 0xffffe3ff) | 0x1000`
- loops candidate tables `DAT_81479fc0`, `DAT_81479fc1`, `DAT_81479fc2`
- toggles MDIO1 ctrl bit `0x400` when candidate mode requires it
- saves selected profile to `DAT_81479fa8`, `DAT_81479fb0`, `DAT_81479fb8`
- reads PHY register 2 with `fn_enet_mdio_read_phy_reg(phy_addr, 2, &wait_count, 0)`

Suggested names:

- `DAT_81479fc0 -> tbl_enet_candidate_mdio_mode`
- `DAT_81479fc1 -> tbl_enet_candidate_phy_addr`
- `DAT_81479fc2 -> tbl_enet_candidate_flag`
- `DAT_81479fa8 -> g_enet_selected_phy_addr`
- `DAT_81479fb0 -> g_enet_selected_mdio_mode`
- `DAT_81479fb8 -> g_enet_selected_flag`
- `DAT_81479fd0 -> g_enet_probe_needed`

## MDIO1 mode bit helpers

`fn_enet_mdio1_clear_ctrl_0400 @ 803af504` clears bit `0x400` at `GENET_MDIO_BASE_12c02600`.

`fn_enet_mdio1_set_ctrl_0400 @ 803af4d4` sets bit `0x400` at `GENET_MDIO_BASE_12c02600`.

`GENET_MDIO_BASE_12c02600` maps:

- KSEG1: `0xb2c02600`
- physical: `0x12c02600`

## Profile control helper

`fn_enet_clear_profile_ctrl_0140 @ 803a8cd8` clears bits `0x40` and `0x100` in `_DAT_b4e0008c`.

Suggested name:

- `_DAT_b4e0008c -> REG_14e0008c_enet_profile_ctrl`

Mapping:

- KSEG1: `0xb4e0008c`
- physical: `0x14e0008c`

`fn_enet_delay_10_wrapper @ 803a8d00` only calls `FUN_808ff3f8(10)` and was not chased further.

## PHY reset and diagnostics

`fn_enet_phy_soft_reset_wait @ 803af2f8` writes PHY reg0 BMCR reset bit `0x8000` through MDIO using default PHY address `0xff`, then polls reg0 until bit 15 clears or timeout.

`fn_enet_dump_phy_mii_regs @ 803af3bc` dumps PHY/MII registers using default PHY address `0xff` over selected MDIO bus. It reads ranges `0x00-0x07` and `0x10-0x1e` and logs wait/timing data.

## Core command builder

`fn_enet_build_core_cmd` builds PHY BMCR speed/duplex values:

- 1000 half -> `0x0040`
- 1000 full -> `0x0140`
- 100 full -> `0x2100`
- 100 half -> `0x2000`
- 10 full -> `0x0100`
- 10 half -> `0x0000`

It applies those through `fn_enet_write_phy_bmcr_cmd`, then reads PHY regs 4 and 3 for advertisement and PHY type detection.

## Next targets

Inspect fallback and cleanup helpers:

- `803a8ac0`
- `803a8720`

Also continue searching `DAT_b2c0....` and `DAT_b4e0....` for GENET DMA, TDMA, RX/TX enable, and descriptor setup registers.

## Preservation

Created as a new timestamped note. No old logs or records were deleted.
