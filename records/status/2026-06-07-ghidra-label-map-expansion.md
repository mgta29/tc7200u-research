# Ghidra label map expansion (2026-06-07)

Scope:
- Expand the `d60242` profile in `tc7200_stage1_label_map.java`.
- Add more labels for the TC7200U `D6.02.42` stage1 image imported at base `0x80004000`.

Files:
- source script: `records/reverse/ghidra/tc7200_stage1_label_map.java`

Added label groups:
- NAND flow:
  - `0x803f6f3c` out-of-order compare site
  - `0x803f6f64` no-replacement branch site
  - `0x803f70d0` success return site
- TP / runtime status:
  - `0x8138410c` secondary-app-initialized handshake string
- AVS / boot path:
  - `0x80fc7454` AVS thread constructor
  - `0x80fc7e44` AVS reboot-for-margin-change string
  - `0x810fc3cc` `Powering on USB`
- EMTA / DQM boot strings:
  - `0x81055b2c` `Creating BcmEmtaCommandTable`
  - `0x81056234` `Creating BcmEmtaEndptCommandTable`
  - `0x8116dbd0` host FAP DQM manager create string
  - `0x8116dc70` host MSG PROC DQM manager create string
  - `0x8116dcd4` host PMC DQM manager create string
- ProgramStore validation strings:
  - `0x80fcd670` HCS-failed string
  - `0x80fcd69c` signature-incorrect string
  - `0x80fcd714` control-incorrect string
  - `0x810d3a38` `ProgramStoreDriverInit`
  - `0x810d3d88` `ProgramStoreDriverIsHeaderValid`
  - `0x810d3f34` `CombinedProgramStoreDriverIsHeaderValid`
  - `0x810d48f0` combined-header-verified string

Notes:
- This update keeps `CREATE_FUNCTIONS = false`.
- The new labels are intended to improve first-pass navigation in Ghidra without forcing function creation on ambiguous addresses.
