# TC7200.U GENET TX descriptor present but TDMA does not consume

Scope:
- RAM/TFTP boot only.
- Do not flash.
- No parent IRQ enable writes.
- TXPOLL diagnostic active.

Observed while eth0 was up:
- TDMA enabled:
  - DMA_CTRL = 0x00020001
  - DMA_STATUS = 0x00000000
- Ring16:
  - READ_PTR = 0
  - CONS_INDEX = 0
  - PROD_INDEX = 1
- Descriptor 0:
  - 0x12c03000 = 0x00066FC0
  - 0x12c03004 = 0x00083002

Interpretation:
- Driver writes descriptor 0 into GENET descriptor RAM.
- Driver writes producer index 1.
- TDMA remains enabled.
- TDMA consumer index never advances.
- Descriptor flags include SOP/EOP/CRC/qtag-like bits, but not DMA_OWN=0x8000.
- The TX path currently writes len_stat without DMA_OWN.
- Do not assume DMA_OWN is the fix yet; first verify TX mapping size and descriptor fields from bcmgenet_xmit().

Next:
- Add temporary XMITDESC debug around dmadesc_set() in bcmgenet_xmit().
- Print i, nr_frags, size, mapping, len_stat, bd_addr, ring index, write_ptr, prod_index, free_bds.
- Then decide whether to test DMA_OWN for GENET_V1 only.

Do not do next:
- Do not enable parent IRQ bits 16/17.
- Do not add B53/DSA yet.
- Do not change NAND/SPI.
- Do not debug IP/firewall yet.
