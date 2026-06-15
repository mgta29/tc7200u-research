# Ghidra label map expansion v2 (2026-06-07)

Scope:
- Continue expanding the `d60242` label profile for `TC7200U-D6.02.42-180321-F-1C1.bin`.
- Add more boot-path, PCI, TP1, and helper xref labels after the first expansion pass.

Files:
- source script: `records/reverse/ghidra/tc7200_stage1_label_map.java`

Added labels:
- code/xref:
  - `0x801cd780` DOCSIS create-log xref
  - `0x8049731c` late handshake-window block marker
- strings:
  - `0x80fa1dd8` FPM buffer-size prefix
  - `0x81017ba8` `cablemodem agent`
  - `0x810a8d5b` `P%s() TP1`
  - `0x810a0e5c` `RestartLinux not supported for BFC_LINUX_ON_TP1`
  - `0x810cc42c` PCI core init string
  - `0x810cc4c8` PCI no-link-status string
  - `0x810cc514` PCI link-up string
  - `0x8138428c` TP1 ITPC reset command string

Notes:
- This pass stays conservative and still does not force function creation.
- The emphasis is better first-pass navigation around runtime boot logs that were observed on serial output.
