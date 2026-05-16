# TC7200.U current OpenWrt bring-up baseline

Safety rule:
- RAM/TFTP boot only.
- Do not flash until flash map, image slots, bad-block handling, and recovery path are proven.

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
