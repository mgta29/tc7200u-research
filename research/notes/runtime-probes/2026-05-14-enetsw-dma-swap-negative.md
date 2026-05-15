# TC7200.U runtime Ethernet test: bcm6368-enetsw DMA swap negative

Date: 2026-05-14 / 2026-05-15 Europe/Budapest session  
Device: Technicolor TC7200.U / BCM3383-class BMIPS4350  
Boot mode: RAM boot only via CFE/TFTP  
TFTP filename: `openwrt-ps-irqfallback.bin`

## Safe image manifest

DMA-swap test image was rebuilt and wrapped after the wrapper refused a stale image.

CFE accepted:

```text
Tftp complete
Received 5697999 bytes

Image 3 Program Header:
   Signature: a825
     Control: 0000
   Major Rev: 0100
   Minor Rev: 04ff
  Build Time: 2026/5/13 21:00:32 Z
 File Length: 5697907 bytes
Load Address: 82000000
    Filename: openwrt-initramfs.bin
         HCS: 24d3
         CRC: 00000000
