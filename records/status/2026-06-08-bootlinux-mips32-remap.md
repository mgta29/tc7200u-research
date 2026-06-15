# BootLinux MIPS32 remap and helper correction (2026-06-08)

Scope:
- Record the post-cleanup `MIPS32` findings from the BootLinux path.
- Capture the helper identifications that supersede the earlier pre-cleanup label guesses.
- Track the matching Java label-script refresh.

Inputs:
- Ghidra project view of `tc7200/image.raw`
- Corrected import mode: `MIPS:BE:32:default`
- Cleaned/re-disassembled BootLinux window rooted at `0x804c99d0`

Confirmed findings:
- `0x804c99d0` remains the real `fn_boot_linux_entry`.
- `0x804c8dec` is a one-time guarded init wrapper:
  - checks `DAT_814c2634`
  - sets it to `1`
  - calls `FUN_80496e10(...)`
  - calls `FUN_80497110(1, &DAT_814c2614, 8)`
- `0x80681ab8` is a second one-time guarded init wrapper:
  - checks `DAT_814e8bbc`
  - sets it to `1`
  - calls `FUN_80496e10(...)`
  - calls `FUN_80497110(2, &DAT_814e8b94, 10)`
- `0x803e64f8` scans a boot-entry table and compares names against `s_linuxkfs_8106f960`.
- `0x80e9ffb0` is a normal returning `memcmp` implementation with:
  - aligned 32-bit fast path
  - byte fallback
  - standard difference return on first mismatch

Retractions from the older mapping pass:
- The earlier strong `lease-pool` interpretation of the BootLinux tail was derived before the `MIPS32` cleanup and is no longer considered reliable.
- The following scripted labels were removed pending fresh proof:
  - `0x804ccdec` `fn_find_and_flag_matching_entry`
  - `0x804ccf54` `fn_lookup_matching_entry`
  - `0x804cd9b8` `fn_prepare_linux_handoff_context`
  - `0x804cdee0` `fn_reconfigure_lease_pool_impl`
  - `0x804ce210` `fn_reconfigure_lease_pool_conflict_path`
  - `0x804df130` `fn_copy_entry_record`
- The location label at `0x804c9bd0` was neutralized from `loc_post_handoff_reconfigure_lease_pool` to `loc_post_handoff_stage`.

Still under review:
- `0x80e99958` has stale metadata in some views; current decompile shows a simple returning wrapper around `FUN_80e9aecc(...)`.
- `0x80e9aecc` itself still needs a semantic name.

Script refresh:
- Updated `/home/mgta29/tc7200u-research/records/reverse/ghidra/tc7200_stage1_label_map.java`
- Added:
  - `0x804c8dec` `fn_bootlinux_init_slot1_once`
  - `0x80681ab8` `fn_bootlinux_init_slot2_once`
  - `0x803e64f8` `fn_scan_boot_entries_for_linuxkfs`
  - `0x80e9ffb0` `fn_memcmp`
- Removed obsolete BootLinux helper names that came from the pre-cleanup misread.

Practical result:
- Re-running the label script on the cleaned `MIPS32` import should now:
  - keep the stable BootLinux entry labels
  - add the new init-wrapper and `memcmp` labels
  - remove the stale lease-pool-era helper names from older project state
