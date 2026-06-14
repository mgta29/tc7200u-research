# 2026-06-08 ENET wrapper flow repair around 803ad8a4

- Found another bad Ghidra flow split in ENET wrapper around `0x803ad89c`.
- `FUN_80e93bf0` is called with `a0=0x81a8dc00`, `a1=0`, `a2=0xb8`, strongly suggesting memset/zero-init behavior. It was incorrectly treated as no-return / call terminator, leaving valid code at `0x803ad8a4` as undefined bytes.
- Repair action: disassemble `0x803ad8a4-0x803ad940` with `D`, do not create a new function there. Remove no-return or clear flow override for `FUN_80e93bf0` / call at `0x803ad89c`.
- Suggested label: `FUN_80e93bf0` -> `fn_memset_or_zero_80e93bf0_candidate`.
- Decoded flow after repair: check one-time latch near `DAT_81479f81`, call `FUN_803aebb0`, log `Enet Starting GMAC Init..!`, save/clear CP0 Status bit, call `FUN_803ad724`, call GMAC step1 and step2, optionally call `FUN_803a8774`, then delay/yield with `a0=3`.
- Suggested labels: `DAT_81479f70` -> `g_enet_init_in_progress_or_started_81479f70_candidate`; `DAT_81479f81` -> `g_enet_gmac_init_once_latch_81479f81_candidate`; `FUN_803aebb0` -> `fn_enet_pre_gmac_init_once_803aebb0_candidate`; `FUN_803ad724` -> `fn_enet_gmac_precheck_or_status_803ad724_candidate`; `FUN_803a8774` -> `fn_enet_optional_delay_switch_helper_803a8774_candidate`.
- Still unresolved: `s2/s3/s4/s5` for `fn_enet_unimac_mbdma_phy_init_803ae840_candidate`; next paste should be caller/function-start range `0x803ad7f0-0x803ad880`.
