# TC7200.U GENET XMITDESC result: real TX frame queued but TDMA does not consume

Scope:
- RAM/TFTP boot only.
- Do not flash.
- No parent IRQ manual enable.
- TXPOLL and XMITDESC diagnostics active.

Observed:
- eth0 fixed-link reports up.
- bcmgenet_xmit queues one TX descriptor on ring16.
- XMITDESC:
  - i=0
  - nr_frags=0
  - size=154
  - mapping=0x06837002 / 0x06a1f002
  - len_stat=0x009a6fc0
  - bd_addr=b2c03000
  - ring=16
  - write_ptr=1
  - prod=0
  - free=256
- TXPOLL after timeout:
  - tdma_ctrl=0x00020001
  - tdma_stat=0x00000000
  - sw_prod=1
  - sw_c=0
  - hw_p=1
  - hw_c=0
  - free_bds=255

Interpretation:
- The frame is not a 6-byte dummy; the first queued TX frame is 154 bytes.
- DMA mapping looks like low physical RAM.
- Descriptor RAM is written.
- Producer index is written to hardware.
- TDMA is enabled but does not advance consumer index.
- Current len_stat lacks DMA_OWN=0x8000.
- Next experiment: GENET_V1-only DMA_OWN OR test.

Do not do next:
- Do not enable parent IRQ bits 16/17.
- Do not add B53/DSA yet.
- Do not change NAND/SPI.
- Do not debug IP/firewall.
