# 2026-06-08 ENET GMAC reverse findings: string anchors, MDIO helper, step1/profile setup

## Scope

This note records the current additive reverse-engineering findings for the TC7200.U / BCM3383 ENET/GMAC path. This is reverse-analysis labeling only, not source-symbol recovery. Preserve previous logs and notes.

## High-signal ENET/GMAC string anchors

Found relevant GMAC/UNIMAC/MBDMA strings in Ghidra string search:

- 0x81064c24: Enet Starting GMAC Init..!
- 0x81064bf4: Enet Config GMAC UNIMAC Core: 0x%x Phy: 0x%x
- 0x81065094: Starting Enet UNIMAC/MBDMA/PHY Init..!
- 0x810650c0: Enet UNIMAC Core: 0x%x
- 0x810650d8: Enet UNIMAC Iface Interrupts: 0x%x
- 0x810650fc: GMAC Core Cmd: 0x%x
- 0x81065114: GMAC Speed: 0x%x
- 0x81065168: Enet Config GMAC UNIMAC Core: %d Phy: %d

Interpretation: these strings are the correct branch for low-level ENET/GMAC/UNIMAC/MBDMA init work. CAM, DSG, DTP, and GMAC Explicit/Promiscuous strings are lower priority because they appear to relate to forwarding/filtering/DSG logic rather than core GENET/GMAC bring-up.

## MDIO helper

Function labeled:

- fn_enet_mdio_write_phy_reg

Observed behavior:

- Selects GENET MDIO base 0x12c00600 or 0x12c02600.
- Uses g_enet_selected_mdio_mode and an incoming MDIO bus/index register.
- Clears bit 0x80 at MDIO + 0x30 before transaction.
- Builds MDIO command from phy_addr and reg_num.
- Writes first value from argument register a3 to MDIO + 0x2c.
- Polls busy/status bit at MDIO + 0x32 until bit 0 clears.
- Writes second command/value using an incoming scratch register with 0x04000000 set.
- Polls busy/status again.
- Restores bit 0x80 at MDIO + 0x30.

Prototype warning:

- Ghidra shows second_write_value_or_shadow and mdio_bus_index as locals, but they are likely incoming t0/t1-style registers.
- Final prototype is not trusted until callers are inspected.

Suggested local names:

- unused -> unused_a0_or_core
- mdio_base -> keep
- second_write_value_or_shadow -> keep as incoming-register candidate
- mdio_bus_index -> keep as incoming-register candidate
- uVar1 -> mdio_cmd_base

## Profile/control helper

Original label seen as fn_enet_gmac_init_core, but body is not full GMAC init.

Better label:

- fn_enet_gmac_profile_select_once_14e0_candidate

Observed behavior:

- Checks latch DAT_81479f50.
- If latch is zero, sets DAT_81479f50 = 1.
- Applies mask/value sequence: value = value & 0xfffff3ff | 0x400.
- This clears bits 11:10 and sets bit 10, making field[11:10] = 01.
- Applies this to _REG_14e00026_enet_profile_ctrl and _DAT_b4e00264.
- Calls no-return FUN_808ff3f8(2).

Suggested names:

- DAT_81479f50 -> g_enet_gmac_profile_select_done_candidate
- _DAT_b4e00264 -> REG_14e00264_kseg1_enet_profile_ctrl_candidate
- FUN_808ff3f8 -> fn_platform_restart_or_handoff_808ff3f8_candidate until proven

Interpretation:

- This is one-time ENET/GMAC profile-control selection or board/profile setup.
- It is pre-GMAC setup, not the full 0x12c00000 GENET/GMAC init body.

## Step1 wrapper

Function:

- fn_enet_gmac_init_step1

Body:

- Calls fn_enet_gmac_profile_select_once_14e0_candidate.
- Returns.

Interpretation:

- Early GMAC init step 1 is only a wrapper around one-time ENET/GMAC profile-control selection.
- It does not directly touch GENET 0x12c00000 registers.

Suggested comment for fn_enet_gmac_init_step1:

Early GMAC init step 1. Wrapper around one-time ENET/GMAC profile-control selection. This does not touch GENET 0x12c00000 registers directly.

## Current ENET chain

fn_enet_gmac_init_step1
  -> fn_enet_gmac_profile_select_once_14e0_candidate
      -> set 14e0xxxx ENET/profile-control field once
      -> call no-return platform helper on first run

MDIO helper branch:

fn_enet_mdio_write_phy_reg
  -> select MDIO0 0x12c00600 or MDIO1 0x12c02600
  -> build command from phy/reg/value
  -> poll busy bit
  -> write second shadow/value command

## Current conclusion

We are now on the correct ENET/GMAC branch. The MDIO helper and step1/profile selector are useful but do not yet expose the full GENET/GMAC init sequence needed for TDMA/GMAC bring-up. The next target should be the caller or sibling function that references Enet Starting GMAC Init..!, GMAC Core Cmd, GMAC Speed, or Starting Enet UNIMAC/MBDMA/PHY Init..!

## Next Ghidra targets

1. fn_enet_gmac_init
2. fn_enet_gmac_init_step2
3. fn_enet_gmac_init_step6
4. xrefs to str_enet_gmac_core_cmd at 0x810650fc
5. xrefs to str_enet_gmac_speed at 0x81065114
6. xrefs to str_enet_cfg_gmac_core_phy_hex at 0x81064bf4
7. xrefs to s_Starting_Enet_UNIMAC/MBDMA/PHY_I_81065094

Search/register anchors to keep using:

- 0x12c00000 GENET base
- 0x12c00600 MDIO0 base
- 0x12c02600 MDIO1 base
- 0x12c00580 likely command/control area of interest
- 0x12c004a8, 0x12c004e8, 0x12c004ec, 0x12c004f0 MIB/status counters from prior tests
- 0x12c03c44 and nearby TDMA/GENET areas from prior experiments

## Naming caution

Do not rename the MDIO helper prototype as final while Ghidra still shows incoming t0/t1-style registers as locals. Do not treat fn_enet_gmac_profile_select_once_14e0_candidate as full GMAC init; it only selects profile/control bits and triggers a no-return platform helper on first run.
