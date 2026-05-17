# TC7200.U GENET descriptor RAM appears to truncate high bits

Scope:
- RAM/TFTP boot only.
- Do not flash.
- GENET fixed-link diagnostic.
- XMITDESC, TXPOLL, and GENET_V1 DMA_OWN test patches active.

Observed:
- Driver prints:
  - mapping=0x06c0f802
  - len_stat=0x00c2efc0
- Raw descriptor RAM reads:
  - devmem 0x12c03000 32 = 0x0002EFC0
  - devmem 0x12c03004 32 = 0x0000F802
  - devmem 0x12c03008 32 = 0x000B30B5
  - devmem 0x12c0300c 32 = 0x000F110E
- TDMA still does not consume:
  - tdma_ctrl=0x00020001
  - tdma_stat=0x00000000
  - sw_prod=1
  - hw_p=1
  - hw_c=0
  - free_bds=255

Interpretation:
- DMA_OWN is active but did not fix TDMA consumption.
- Descriptor RAM view appears to lose upper bits:
  - len_stat 0x00c2efc0 becomes 0x0002efc0
  - mapping 0x06c0f802 becomes 0x0000f802
- This would give TDMA an invalid buffer address.
- Current blocker is descriptor RAM write/read format, descriptor window, endian/address-width behavior, or BCM3383-specific GENET DMA init.

Next:
- Add read-back debug immediately after dmadesc_set().
- Print descriptor words using the driver's own descriptor accessors.
- Compare driver readback against devmem.
- Inspect OEM GENET/TDMA descriptor handling.

Do not do next:
- Do not enable parent IRQ bits 16/17.
- Do not add B53/DSA yet.
- Do not change NAND/SPI.
- Do not debug IP/firewall.
