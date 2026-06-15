# TC7200.U current OpenWrt bring-up baseline

Scope note:
- CFE/TFTP test record.
- Defer persistent-image work until flash map, image slots, bad-block handling, and recovery path are proven.

Core insight:
- TC7200.U stock boot is split: CFE boots eCos/BFC first, then eCos boots Linux TP1.
- Standalone OpenWrt RAM image must reproduce board initialization normally done by eCos/BFC.

Current working:
- A825 wrapping and CFE TFTP boot work.
- OpenWrt boots to shell.
- UART works.
- GENET at 0x12c00000 probes.
- TC7200U GMAC pinmux/clock/reset quirk is useful and should stay.

Current Ethernet state:
- Use GENET at 0x12c00000.
- Do not use bcm6368-enetsw at 0x14e01000; that address is HSSPI/SPI.
- Restore/keep interrupts = <16>, <17>.
- IRQ16-only is invalid because bcmgenet requires IRQ index 1.
- Fixed-link reports link up but TX watchdog occurs.
- /proc/interrupts shows no bcmgenet/eth0 handler.
- ERR rises while eth0 is up.
- Next step: instrument bcmgenet IRQ request, IRQ status/mask, and TX completion path.

Deferred:
- B53/BCM53125 switch integration until GENET IRQ/TX behavior is understood.
- NAND until Ethernet baseline is stable.
- SPI remains disabled.
- Wi-Fi deferred.

Important OEM clues:
- OEM switch power: "Powering UP switch. PIN = 14".
- OEM Linux boot args: mem=67108864@67108864 mem=0@0.
- NAND: 64 MiB, 16 KiB erase block, 512 B page.
- SPI: 1 MiB, JEDEC 0xc22014.
- CFE restores 0x180-byte flash map from SPI offset 0xff30.

## 2026-06-01 verified baseline update

Known-good OpenWrt stage2 image identity:
- `tc7200-stage2-console-good.bin`
- `tc7200-next-control.bin`
- Both files are byte-identical: `sha256=a2b9fa164d092387dc0382698cbdff940bb97cce6c41a029ac70c1b357497c4b`.

Known-good header/runtime signature (from serial logs):
- Signature: `a825`
- Load Address: `0x82000000`
- Header filename: `openwrt-initramfs.bin`
- File length: `6417987`
- Kernel line: `Linux version 6.12.87 ... r34427-6865d489d2`

Gate evidence:
- PASS reference: `records/logs/builds/2026-06-01-195304-check-gates-picocom-20260601-193010.txt`
  - Gate A/B/C/D: PASS
  - Gate E: PASS (`console_ready`)
  - Contains `procd: - init -`, `Please press Enter`, `BusyBox v1.37.0`
- Partial-capture reference: `records/logs/builds/2026-06-01-213952-check-gates-picocom-20260601-213511.txt`
  - Gate A/B/C/D: PASS
  - Gate E: WARN (`boot_not_fully_observed`)
  - Log ended at `Decompressing kernel...` (not a crash signal by itself).

Known bad/regression image to avoid as baseline:
- `tc2700-202606012056.bin`
- From `records/logs/builds/2026-06-01-213156-check-gates-picocom-20260601-210242.txt`:
  - Gate B: FAIL
  - Gate E: FAIL (`userspace_console_failed`)
  - Serial log includes SIGSEGV and `Kernel panic - not syncing: Attempted to kill init`.

Practical baseline rule:
- Treat `tc7200-stage2-console-good.bin` (`tc7200-next-control.bin`) as the control image for A/B comparisons.
- Do not mark a boot as failed when Gate E is WARN unless panic/fault lines are present; re-capture a longer serial log first.
