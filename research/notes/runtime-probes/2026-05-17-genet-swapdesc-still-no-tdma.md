# TC7200.U GENET swapped descriptor word-order test still does not make TDMA consume

Scope:
- RAM/TFTP boot only.
- Do not flash.
- Diagnostic image:
  - ADDRDBG
  - TXPOLL
  - reserved low physical TX buffer at 0x01680000
  - swapped descriptor word-order test

Observed:
- Reserved-memory DTS was active:
  - 0x01680000..0x01680fff
  - genet-txbuf@1680000
- SWAPDESC mapping succeeded:
  - phys=0x01680000
  - virt=a1680000
  - size=0x1000
- SWAPDESC wrote descriptor as:
  - word0 = address
  - word1 = length/status
- Readback:
  - rb0=0x00080000
  - rb4=0x000aefc0
- TDMA:
  - tdma_ctrl=0x00020001
  - tdma_stat=0x00000000
  - sw_prod=1
  - hw_p=1
  - hw_c=0

Conclusion:
- Descriptor word order is not the missing fix.
- A reserved low physical TX buffer is not enough.
- Upstream/original status format is not enough.
- Compact status format was also not enough.
- Remaining suspect area is BCM3383 GENET TDMA/SCB/window/init, not descriptor address/status/word order alone.

Do not repeat:
- mem=16M / mem=32M
- fatal or non-fatal DMA_BIT_MASK(20)
- GFP_DMA coherent bounce
- ADDRSHIFT8
- LOWLIT 0x00080000
- manual low16 status
- reserved low TX buffer as standalone fix
- reserved + upstream status
- reserved + swapped descriptor word order
- blind parent IRQ enable
- B53/DSA before TDMA consumes descriptors

Next:
- Probe BCM3383 GENET TDMA/SCB/window/init registers and compare before/after open.
