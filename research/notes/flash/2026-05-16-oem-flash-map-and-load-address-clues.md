# TC7200.U OEM flash map and load-address clues

Scope: research only. RAM/TFTP boot only. Do not flash.

Firmware:
- TC7200U-D6.02.29-160119-F-1C1
- Linux kernel image: LNXD6.02.29-kernel-20160122.bin

Hardware:
- SoC: BCM3383A2 / BCM3383Z-B0
- RAM: 128 MB total
- OEM Linux boot args: mem=67108864@67108864 mem=0@0
- This means OEM Linux TP1 uses 64 MB at 0x04000000.

Flash:
- SPI flash JEDEC: 0xc22014
- SPI size: 1 MB
- SPI block size: 64 KB
- NAND JEDEC: 0x20762076
- NAND size: 64 MB
- NAND erase block: 16 KB
- NAND page size: 512 B

OEM image clues:
- Image 1 header offset: 0x19c0000
- Image 1 payload offset: 0x1ac0000
- Image 1 file length: 5597352
- Image 1 load address: 0x80004000
- Image 1 filename: TC7200U-D6.02.29-160119-F-1C1.bin
- Image 1 CRC: 0xbcb59d3d
- Image 1 HCS: 0x0421

- Image 3 header offset: 0x2740000
- Image 3 payload offset: 0x2840000
- Image 3 file length: 1507236
- Image 3 load address: 0x84010000
- Image 3 filename: LNXD6.02.29-kernel-20160122.bin
- Image 3 CRC: 0xa1cc5c2b
- Image 3 HCS: 0xca06

Important bootloader clue:
- CFE restores a 0x180-byte flash map from SPI offset 0xff30.
- CFE copies the partition table to 0x83fffc04 and 0x80000904.
- Decoding the 0x180-byte flash map is probably the fastest path to exact partition layout.

Ethernet clue:
- OEM log says: Powering UP switch. PIN = 14
- This should be tested later as GPIO14 switch power, likely before real BCM53125/B53 traffic testing.

Current Ethernet priority:
- Restore GENET two IRQs: interrupts = <16>, <17>
- IRQ16-only is invalid because bcmgenet requires IRQ index 1.
- If two-IRQ fixed-link still shows TX watchdog and no GENET IRQ line in /proc/interrupts, instrument bcmgenet IRQ request/status paths.
