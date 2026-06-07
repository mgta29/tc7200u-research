# Ghidra label script refresh (2026-06-07)

Scope:
- Refresh the Java label script used for TC7200 stage1 mapping in Ghidra.
- Bring the scripted labels into line with the manual `d60242` findings captured earlier the same day.

Changed file:
- `/home/mgta29/tc7200u-research/records/reverse/ghidra/tc7200_stage1_label_map.java`

Changes:
- Added the missing `fn_boot_linux_entry` label at `0x804c99d0`.
- Moved `xref_tp_handshake_init` from the stale `0x804971e4` slot to the confirmed `0x804971e8` xref site.
- Added `str_nand_replacement_found` at `0x8107479c` so the replacement-block success log is labeled directly, not only through its xref.
- Added the shared formatting helpers:
  - `0x80e9d958` `fn_snprintf`
  - `0x80e9dd64` `fn_vfprintf_core`
- Added obsolete-label cleanup for the old `0x804971e4` handshake-init xref so rerunning the script removes the wrong label automatically.

Reasoning:
- The manual Ghidra session established that the TP handshake init string is actually referenced from `0x804971e8`, not `0x804971e4`.
- The BootLinux entry at `0x804c99d0` is now stable enough to promote into the scripted label set.
- The NAND replacement-found string and shared printf wrappers are high-value anchors that make future navigation and decompiler cleanup faster.

Expected effect after rerun:
- Cleaner TP handshake labeling with one correct init xref.
- Better entry-point visibility for the BootLinux path.
- More stable navigation around the NAND replacement and boot-argument formatting flows.
