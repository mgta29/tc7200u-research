# TC7200 OpenWrt Port Checklist (2026-05-31)

Scope:
- Use the known-working ISP stage1 image as hardware-init reference.
- Move toward OpenWrt in controlled, RAM-boot-only steps (TFTP).
- Avoid SPI/NAND permanent writes until all runtime gates pass.

## 0. Current known-good anchors

- NAND read path function entry: `0x803f6d90`
- Replacement helper: `0x803f6cac` (`fn_find_replacement_block_candidate`)
- TP handshake main entry: `0x8049714c`
- TP unexpected logger: `0x804c8f60`
- Linux handoff/boot-args area: `0x804c9b40`

Expected NAND fail branch semantics:
- `0x803f6f64`: `beqz v0, 0x803f6e14` (resolver returned 0)
- `0x803f6e14`: log no replacement, set globals `0x8148a56c/0x8148a570=-1`, return fail (`v0=1`)
- `0x803f70d0`: normal success return (`v0=0`)

## 1. Pre-flight host checks (before each boot attempt)

Pass:
- TFTP root is exactly `C:\tftp\`
- Served filename exactly matches CFE request
- `A825` header fields are expected for test image
- Serial logging is enabled and writing to `records/logs/serial/*.log`

Fail:
- `Received packet for invalid session...` in sustained bursts
- `Received out of order data...aborting session`
- Wrong file served vs requested filename

## 2. Gate A: Transport and header acceptance

Procedure:
1. Boot from CFE using TFTP.
2. Verify banner shows valid header parse.

Pass criteria (all):
- `Tftp complete`
- `Image 3 Program Header:`
- `Signature: a825`
- `Executing Image 4...`
- No immediate `CRASH` before handoff phase

Fail criteria:
- Header parse mismatch
- Decompression failure before handoff
- Immediate exception at image entry

## 3. Gate B: Runtime stability (post-handoff)

Window:
- Observe serial for at least 120 seconds after `Executing Image 4...`

Pass criteria:
- No exception dump (`EXCEPTION TYPE:` absent)
- No automatic return to CFE banner

Fail criteria:
- Any exception dump (`Reserved instruction`, `TLB`, `Coprocessor unusable`, etc.)
- Reboot loop back to `Board IP Address [...]`

## 4. Gate C: NAND replacement health

What to watch:
- `NandFlashRead: Detected out-of-order block...`
- `NandFlashRead: Failed to find replacement block!`

Pass criteria:
- No `Failed to find replacement block!` in the boot window

Fail criteria:
- Replacement failure appears, then boot destabilizes/reset follows

### Gate C classification rule

If `NandFlashRead: Failed to find replacement block!` appears but the boot
continues into deeper runtime init (for example TR-069, DOCSIS control thread,
FPM/PCI/DQM bring-up) without exception/reset in the observation window, mark:

- `Gate C = FAIL (nonfatal/degraded)`

This means NAND mapping is not clean, but the image can still be used for
controlled runtime mapping and OpenWrt transition experiments.

## 5. Gate D: TP handshake health

What to watch:
- `Error: getHostDqmMessage(handshake) on %s`
- `Error: handshake rx unexpected message`
- `%s unexpected message %08lx`
- `%s: unexpected message %d`
- Repeating `HandShakeMsg = ...` and `unhandled message ...` floods

Pass criteria:
- Handshake progresses without repeated unexpected-message flood
- No long unhandled-message loop

Fail criteria:
- Flood behavior (thousands of repeated handshake/unhandled logs)
- Followed by watchdog/reset to CFE

## 6. OpenWrt migration sequence (strict order)

### Stage 1: Prove baseline repeatedly
Pass:
- Same known-good ISP image passes Gates A-D at least 3 consecutive boots

### Stage 2: Container/header discipline
Pass:
- OpenWrt candidate is wrapped with expected A825 fields
- Load address and compression mode are intentional for the target test

Practical run block (current repo state):

```bash
cd /home/mgta29/tc7200u-research/scripts

# Ensure raw payload exists from existing wrapped OpenWrt candidate:
./tc7200u reverse-stage1 --input /mnt/c/tftp/openwrt-ps-irqfallback.bin

# Re-wrap OpenWrt payload but preserve header control/revision/load/build/crc
# from the known-good stage1 map image.
./tc7200u-auto-build-install-wrap.sh \
  --input /home/mgta29/tc7200u-research/records/reverse/openwrt-ps-irqfallback.bin/image.raw \
  --output /mnt/c/tftp/tc7200-stage2-openwrt-preserve-d60242.bin \
  --filename tc7200-stage2-openwrt-preserve-d60242.bin \
  --preserve-from /mnt/c/tftp/tc7200-stage1-map-d60242.bin

# Verify wrapper correctness and load-address intent.
./tc7200u-auto-build-install-wrap.sh \
  --raw /home/mgta29/tc7200u-research/records/reverse/openwrt-ps-irqfallback.bin/image.raw \
  --wrapped /mnt/c/tftp/tc7200-stage2-openwrt-preserve-d60242.bin \
  --expect-load 0x80004000 \
  --expect-signature 0xa825
```

Interpretation:
- If this still fails in runtime similarly, payload incompatibility is primary.
- If behavior changes materially vs old `openwrt-ps-irqfallback.bin`, header/load
  field mismatch was a major factor.

Observed result (2026-05-31, log `picocom-20260531-044515.log`):
- Rewrap with `--preserve-from tc7200-stage1-map-d60242.bin` produced valid A825
  header/load (`0x80004000`), then CFE reported:
  - `Detected LZMA compressed image... decompressing...`
  - `Decompression failed... 1`
- Gate classification: `Gate A = FAIL (decompression_failed)`.
- Conclusion: setting control/profile to the d60242 compressed mode for this
  OpenWrt payload is incompatible at loader decompression stage.

Observed result (Stage 2b, 2026-05-31, log `picocom-20260531-044952.log`):
- Header strategy:
  - preserve from `openwrt-ps-irqfallback.bin`
  - force `control=0x0000`
  - force `load_addr=0x80004000`
- Boot result:
  - `Loading non-compressed image 4...`
  - `Executing Image 4...`
  - `OpenWrt kernel loader for BMIPS`
  - `Decompressing kernel...`
- Gate classification:
  - `Gate A: PASS (accepted)`
  - `Gate B: PASS`
  - `Gate C: PASS (clean)`
  - `Gate D: PASS`
- Conclusion:
  - The `control=0x0000` + `load=0x80004000` combination is currently the
    working Stage-2 OpenWrt entry format.

### Stage 3: Minimal change experiments
Pass:
- Change one variable per boot (filename/header/control/payload)
- Keep a boot matrix with `image -> result -> first failure marker`

Observed result (2026-05-31, repeatability on 3 consecutive logs):
- Logs:
  - `picocom-20260531-044952.log`
  - `picocom-20260531-045300.log`
  - `picocom-20260531-045431.log`
- For all three logs:
  - `Gate A: PASS (accepted)`
  - `Gate B: PASS`
  - `Gate C: PASS (clean)`
  - `Gate D: PASS`
  - `openwrt_loader_lines=1`
  - `openwrt_decompress_kernel_lines=1`
- Stage 3 status: PASS.

### Stage 4: OpenWrt runtime checkpoints
Pass indicators:
- Kernel handoff continues beyond early entry
- No immediate TP/NAND fatal path
- Stable serial progress vs flood/reset pattern

Fail indicators:
- Same NAND replacement fail branch triggers
- Same TP unexpected-message loop recurs

Observed progress (latest run `picocom-20260531-045431.log`):
- `OpenWrt kernel loader for BMIPS`
- `Decompressing kernel... done!`
- `Starting kernel at 80010000...`
- `[    0.000000] Linux version 6.12.87 ...`
- `[    0.000000] Kernel command line: console=ttyS0,115200 earlycon`

Interpretation:
- Stage 4 has started successfully and progressed beyond loader/decompress
  into Linux kernel startup.
- Next objective is to capture stable post-earlycon boot milestones
  (initcalls, rootfs mount, userspace/shell/network availability).

Observed progress (2026-05-31, log `picocom-20260531-050727.log`):
- `Starting kernel at 80010000...`
- `[    0.000000] Linux version 6.12.87 ...`
- `[    0.000000] Kernel command line: console=ttyS0,115200 earlycon`
- `[   18.540788] jffs2: version 2.2 ...`
- `[  161.734614] procd: - early -`
- `[  167.550667] procd: - init -`
- `Please press Enter to activate this console.`
- `BusyBox v1.37.0 ... built-in shell (ash)`
- Gate classification:
  - `Gate A: PASS (accepted)`
  - `Gate B: PASS`
  - `Gate C: PASS (clean)`
  - `Gate D: PASS`

Interpretation:
- Stage 4 is now PASS for this image path: boot reaches userspace shell.

## 7. Logging requirements (must keep for each attempt)

For every test image, record:
- Image filename
- SHA256 of served file
- CFE header parse block
- First failure marker (or success marker)
- Serial log path

Suggested one-liner to summarize key markers:

```bash
rg -n "Tftp complete|Signature:|Executing Image 4|EXCEPTION TYPE|NandFlashRead|handshake|unexpected message|Board IP Address" /home/mgta29/tc7200u-research/records/logs/serial/picocom-mapp-*.log
```

## 8. Stop conditions

Stop and do not continue to new payload variants if:
- Gate A fails (transport/header issue not resolved)
- Gate B fails in identical way across 3 consecutive attempts
- Gate C/D fail without any controlled variable change

When stopped, return to the last image that passed the highest gate and branch from there.

## 9. Handoff to Ethernet Stage

Porting-stage status (as of 2026-05-31):
- Stage 1: PASS
- Stage 2: PASS (via Stage 2b format)
- Stage 3: PASS
- Stage 4: PASS (kernel + userspace shell reached)

Working development boot image:
- `/mnt/c/tftp/tc7200-stage2-openwrt-c0-load80004000.bin`

Frozen boot header profile for Ethernet work:
- `signature=0xa825`
- `control=0x0000`
- `load_addr=0x80004000`
- `major=0x0100`
- `minor=0x04ff`

Ethernet-stage rule:
- Do not change wrapper/header format while debugging Ethernet.
- Use ISP image only as control/rescue baseline.
- Apply changes in DTS/driver/runtime probes only.

Ethernet-stage entry checkpoint:
- `OpenWrt kernel loader for BMIPS`
- `Decompressing kernel... done!`
- `Starting kernel at 80010000...`
- `Linux version 6.12.87 ...`
