# TC7200 stage1 reverse findings (2026-05-31)

Scope:
- Log findings from `tc7200-stage1-map-d60242.bin` reverse extraction.
- Cross-check against `TC7200.20-DC.01.03-140425-F-1FF.bin` (`dc0103`) and serial runtime logs.

Inputs:
- Wrapped image: `/mnt/c/tftp/tc7200-stage1-map-d60242.bin`
- Source OEM image: `/home/mgta29/src/bcm2-dumps/tc7200/TC7200.20-DC.01.03-140425-F-1FF.bin`
- Serial log: `research/mapping-stage/picocom-mapp-20260531-011944.log`
- Tooling: `scripts/tc7200u reverse-stage1`

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

## Current working hypothesis

1. The trigger point is after Linux handoff and before steady application bring-up.
2. NAND bad-block replacement failure at `0x2b90000` is likely a primary destabilizer.
3. TP/host handshake code then enters repeated unexpected-message handling until watchdog/reset path returns control to CFE.
4. Next RE focus should be code flow around:
   - `0x810746cc` / `0x81074738` (NAND replacement failure path),
   - `0x810a074c`..`0x810a8b9c` (TP handshake/unexpected message path).

