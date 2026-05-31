# TC7200 stage1 reverse findings (2026-05-31)

Scope:
- Log findings from `tc7200-stage1-map-d60242.bin` reverse extraction.
- Cross-check against `TC7200.20-DC.01.03-140425-F-1FF.bin` (`dc0103`) and serial runtime logs.

Inputs:
- Wrapped image: `/mnt/c/tftp/tc7200-stage1-map-d60242.bin`
- Source OEM image: `/home/mgta29/src/bcm2-dumps/tc7200/TC7200.20-DC.01.03-140425-F-1FF.bin`
- Serial log: `records/logs/serial/picocom-mapp-20260531-011944.log`
- Tooling: `tc reverse-stage1`

## Verified image facts (d60242)

- ProgramStore header:
  - `signature=0xa825`
  - `control=0x0005`
  - `major=0x0100`
  - `minor=0x04ff`
  - `load_address=0x80004000`
  - `filename=TC7200U-D6.02.42-180321-F-1C1.bin`
  - `hcs=0x08a7` and `expected_hcs=0x08a7`
- Payload:
  - `payload_size=5598848`
  - LZMA1 raw decode successful (`lc=3 lp=0 pb=2 dict=1048576`)
  - `raw_image_size=25411336`
  - `raw_image_sha256=c3071953854d151256efa3905df44b6bc31a6a0d3939de84f5df91a377bd2edb`

## Runtime anchors (d60242, base 0x80004000)

- Boot and Linux handoff:
  - `0x80fc9cb8` `Booting Linux on TP1...`
  - `0x810a8e80` `Linux Boot Args: %s`
- DOCSIS control thread:
  - `0x80fe9278` `Creating DOCSIS Control Thread...`
  - `0x80fe9d00` `CM DOCSIS Control Thread Commands`
- TR-069:
  - `0x80fb38fc` `Creating TR-069 Thread...`
  - `0x80fb3924` `BcmBfcTr69Thread::Singleton mutex`
  - `0x80fb3bb4` `BcmBfcTr69Thread: Initializing Core`
- TP handshake strings:
  - `0x810a074c` `<<<<< %s sent initial handshake >>>>>>`
  - `0x810a07a0` `Error: getHostDqmMessage(handshake) on %s`
  - `0x810a07cc` `Error: handshake rx unexpected message`
  - `0x810a07f4` `<<<<< %s sent reply handshake message >>>>>>`
  - `0x810a0a2c` `init_service_handshake`
  - `0x810a8afc` `%s unexpected message %08lx`
  - `0x810a8b9c` `%s: unexpected message %d`
- NAND/bad-block path strings:
  - `0x810746cc` `NandFlashRead: Failed to find replacement block!`
  - `0x81074738` `NandFlashRead: Detected out-of-order block...`
- TP processor handshake status:
  - `0x8138410c` `Thread processor handshake. Secondary app initialized properly.`

## Serial/runtime correlation

From `picocom-mapp-20260531-011944.log`:
- Boot reaches Linux handoff path.
- Immediately reports NAND replacement failure:
  - `NandFlashRead: Detected out-of-order block @offset 0x2b90000, tagged offset 0xffffff00, expected offset 0x450000`
  - `NandFlashRead: Failed to find replacement block!`
- Then enters a long message loop:
  - first `HandShakeMsg = 00000001`
  - last observed `HandShakeMsg = 0089ca60`
  - `unhandled message` count: `4782`
- After loop/flood, unit returns to CFE bootloader banner (`Board IP Address [192.168.77.1]` appears again).

Interpretation:
- Boot does not fail at header/wrap/load stage.
- Failure occurs in post-handoff runtime control path, consistent with bad NAND replacement and/or TP message path divergence.
- The exact literals `HandShakeMsg = ...` and `unhandled message ...` are not found as static strings in this image, suggesting those prints may come from another component path (e.g., alternate runtime/monitor context) despite neighboring handshake strings being present in the image.

## d60242 vs dc0103 comparison

dc0103 extraction confirms:
- Same load base (`0x80004000`) and valid decode.
- DOCSIS/TR-069 markers exist but at different addresses.
- `d60242` contains explicit TP handshake error strings; `dc0103` did not expose the same handshake string set in static scan.
- Both families include NAND out-of-order replacement failure strings.

Marker diff highlights (`d60242` vs `dc0103`):
- `Booting Linux on TP1...` exists in `d60242` (`0x80fc9cb8`), absent in `dc0103`.
- `Linux Boot Args: %s` exists in both but at different addresses:
  - `d60242`: `0x810a8e80`
  - `dc0103`: `0x80ee2464`
- `d60242` has explicit handshake/error format strings (`0x810a074c`..`0x810a8b9c`); these are absent from `dc0103` marker scan.
- Both images contain NAND read/replacement error strings with equivalent semantics:
  - `d60242`: `0x810746cc`, `0x81074738`
  - `dc0103`: `0x80ea46ac`, `0x80ea46e0`
- ITC literal set differs:
  - `dc0103` contains `>>> ITC Initialized!!! <<<` (`0x80ee20fa`) and explicit ITC RX thread creation-failure strings.
  - `d60242` scan does not expose these specific ITC init/failure literals.

## Code xrefs and disassembly anchors

String-reference xrefs (MIPS `lui` + `addiu`) identified from raw image:

- `d60242`:
  - handshake init string `0x810a074c` referenced at code `0x804971e4 -> 0x804971e8`
  - handshake unexpected string `0x810a07cc` referenced at `0x804972ac -> 0x804972d0`
  - unexpected message formatter `0x810a8afc` referenced at `0x804c8f6c -> 0x804c8f70`
  - NAND replacement-fail string `0x810746cc` referenced at `0x803f6e14 -> 0x803f6e1c`
  - NAND out-of-order string `0x81074738` referenced at `0x803f6f40 -> 0x803f6f44`

- `dc0103`:
  - NAND replacement-fail string `0x80ea46ac` referenced at `0x8039aab4 -> 0x8039aabc`
  - NAND out-of-order string `0x80ea46e0` referenced at `0x8039ab8c -> 0x8039ab90`
  - DOCSIS command table `0x80e1fb58` referenced at `0x8018db90 -> 0x8018db94`

Disassembly windows:
- `d60242` NAND read path function starts around `0x803f6da0` and contains:
  - print `NandFlashRead: Detected out-of-order block...` then
  - call to replacement-block resolver (`jal 0x803f6cac`) and
  - hard fail path printing `NandFlashRead: Failed to find replacement block!` followed by return with error.
- `dc0103` equivalent NAND path starts around `0x8039aa40` and is instruction-level equivalent in control structure:
  - out-of-order detection, replacement attempt (`jal 0x8039a950`), replacement-found print, and same fail path semantics.
- `d60242` handshake-supporting string block is used by code around `0x80497180..0x8049731c`.
- `dc0103` still contains ITC HAL infrastructure (`ITC HAL Commands` xref around `0x8046c1fc`), but the same direct handshake-string/xref cluster seen in `d60242` is not present in static string scans.

## Side-by-side function map (d60242 vs dc0103)

All addresses are runtime virtual addresses (base `0x80004000`).

1. NAND read path with out-of-order/replacement handling
- `d60242`: function window starts near `0x803f6da0`
  - replacement-fail log xref: `0x803f6e14 -> 0x810746cc`
  - out-of-order log xref: `0x803f6f40 -> 0x81074738`
  - replacement resolver call: `jal 0x803f6cac`
- `dc0103`: function window starts near `0x8039aa40`
  - replacement-fail log xref: `0x8039aab4 -> 0x80ea46ac`
  - out-of-order log xref: `0x8039ab8c -> 0x80ea46e0`
  - replacement resolver call: `jal 0x8039a950`
- Conclusion: this subsystem is structurally equivalent between both families.

2. DOCSIS control thread creation/init helpers
- `d60242`:
  - helper window around `0x801cd700` with create-string xref at `0x801cd780 -> 0x80fe9278`
  - broader init window around `0x801cd7f0`
  - command-table xref: `0x801cf1cc -> 0x80fe9d00`
- `dc0103`:
  - helper window around `0x8018c100` with create-string xref at `0x8018c148 -> 0x80e1f220`
  - broader init window around `0x8018c1b8`
  - command-table xref: `0x8018db90 -> 0x80e1fb58`
- Conclusion: this subsystem is strongly analogous, with expected address drift.

3. TR-069 thread creation/init
- `d60242`: init window around `0x800dc5c0`, xref `0x800dc63c -> 0x80fb38fc`
- `dc0103`: init window around `0x800aa620`, xref `0x800aa69c -> 0x80dec260`
- Conclusion: TR-069 init path exists in both with similar structure.

4. Boot handoff / Linux boot-args logger
- `d60242`: window around `0x804c9b40`, xref `0x804c9b80 -> 0x810a8e80` (`Linux Boot Args: %s`)
- `dc0103`: window around `0x8046de80`, xref `0x8046dea0 -> 0x80ee2464` (`Linux Boot Args: %s`)
- Conclusion: boot-args handoff logger exists in both; address drift only.

5. ITC/TP messaging divergence indicators
- `d60242`:
  - handshake cluster xrefs around `0x804971e4..0x804972d0` to
    `0x810a074c`, `0x810a07a0`, `0x810a07cc`, `0x810a07f4`
  - unexpected-message formatter xref at `0x804c8f6c -> 0x810a8afc`
- `dc0103`:
  - explicit ITC HAL registration window around `0x8046c1e4`
  - ITC HAL command-table xref at `0x8046c1fc -> 0x80ee16e4`
  - contains `>>> ITC Initialized!!! <<<` literal (`0x80ee20fa`) but no direct static hits for the `d60242` handshake format string set.
- Conclusion: likely divergence in TP/ITC messaging instrumentation/path, not in A825 wrapping or base NAND pipeline.

## Ghidra rename script targets

- Script added:
  - `records/reverse/ghidra/tc7200_stage1_label_map.py`
- Profiles:
  - `PROFILE = "d60242"` for `tc7200-stage1-map-d60242.bin`
  - `PROFILE = "dc0103"` for `TC7200.20-DC.01.03-140425-F-1FF.bin`
- Behavior:
  - Applies address labels for function windows, key xrefs, and string anchors.
  - Adds plate comments at labeled addresses.
  - Optional function creation/renaming via `CREATE_FUNCTIONS = True`.

## Current working hypothesis

1. The trigger point is after Linux handoff and before steady application bring-up.
2. NAND bad-block replacement failure at `0x2b90000` is likely a primary destabilizer.
3. TP/host handshake code then enters repeated unexpected-message handling until watchdog/reset path returns control to CFE.
4. Next RE focus should be code flow around:
   - `0x810746cc` / `0x81074738` (NAND replacement failure path),
   - `0x810a074c`..`0x810a8b9c` (TP handshake/unexpected message path).

## Ethernet init decode (d60242, confirmed in Ghidra)

Confirmed function/label map from current RE session:
- `0x803a8b30` `fn_enet_gmac_init_step2`
- `0x803a8c10` `fn_enet_gmac_init_core`
- `0x803ae840` `fn_enet_gmac_init_step6`
- `0x803aefec` `fn_enet_build_core_cmd`
- `0x803aed40` `fn_enet_poll_or_wait_ready`
- `0x803a2d94` `fn_enet_snmp_register_handlers`
- `0x803a2f10` is an in-function location inside `fn_enet_snmp_register_handlers`
  (not a standalone function entry).

`fn_enet_gmac_init_step2` behavior (board profile gate):
- Uses `gv_board_profile` and `reg_gmac_cmd`.
- For lower profile path (active on this image), it sets command bits by
  interface selector:
  - interface0 path sets `reg_gmac_cmd |= 0x1`, then `|= 0x2`
  - interface1 path sets upper-half equivalents (`0x10000`, `0x20000`)

`fn_enet_build_core_cmd` confirms link-mode to BMCR-style command encoding:
- 1000/full -> `0x140`
- 1000/half -> `0x40`
- 100/full -> `0x2100`
- 100/half -> `0x2000`
- 10/full -> `0x100`
- 10/half -> `0x0`

This matches Linux `mii.h` constants semantics:
- `BMCR_SPEED1000=0x0040`
- `BMCR_FULLDPLX=0x0100`
- `BMCR_SPEED100=0x2000`

## Ghidra validation: NAND fail branch semantics (d60242)

Validated with `mips-linux-gnu-objdump -EB` and Ghidra (`MIPS:BE:32`, base `0x80004000`).

- Function entry is `0x803f6d90` (not `0x803f6da0`).
  - Prologue at `0x803f6d90..0x803f6dbc`.
  - `0x803f6da0` is inside prologue, not a true standalone function start.

- Out-of-order block check and replacement attempt:
  - `0x803f6f3c`: compares live block/tag state (`s1`) vs expected offset (`s4`).
  - If mismatch, logs via `0x81074738` at `0x803f6f40..0x803f6f54`.
  - Calls replacement resolver `0x803f6cac` at `0x803f6f5c`.

- Hard fail condition:
  - `0x803f6f64`: `beqz v0, 0x803f6e14`
  - Meaning: resolver returned `0` (no replacement candidate) -> jump to fail path.

- Fail path (`0x803f6e14`):
  - Logs `NandFlashRead: Failed to find replacement block!` (`0x810746cc`).
  - Writes `-1` to globals at `0x8148a56c` and `0x8148a570`.
  - Sets return value `v0=1` and exits via common epilogue.

- Success return path:
  - Normal completion stores current pointer/state to `0x8148a570` at `0x803f70cc`.
  - Returns `v0=0` at `0x803f70d0`.
  - So this routine uses `0` as success and `1` as failure in the observed fail branch.

- Resolver helper (`0x803f6cac`) behavior summary:
  - Aligns/normalizes probe address by NAND geometry (`0x8148a554` / `0x8148a578`).
  - Iterates candidate blocks, checking validity/readability (`0x803f6c64`, `0x803f6398`, `0x803f62a0`).
  - Returns candidate address in `v0` on success (`move v0,v1` with nonzero `v1`).
  - Returns `0` on failure (`move v1,zero` -> `move v0,v1`).
