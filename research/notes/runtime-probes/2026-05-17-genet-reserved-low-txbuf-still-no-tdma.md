# TC7200.U GENET reserved low TX buffer still does not make TDMA consume

Scope:
- RAM/TFTP boot only.
- Do not flash.
- Diagnostic image:
  - compact GENET v1 status/length descriptor packing
  - ADDRDBG
  - DESCRB
  - TXPOLL
  - reserved low physical TX buffer test

Test:
- Reserved low physical buffer:
  - phys = 0x01680000
  - size = 0x1000
  - no-map in DTS
- Driver ioremap:
  - virt = a1680000
- Driver copied TX packet into the reserved buffer with memcpy_toio().
- Descriptor mapping forced to 0x01680000.

Observed:
- RESV map succeeded:
  - TC7200U RESV map phys=0x01680000 virt=a1680000 size=0x1000
- RESVTX used reserved buffer:
  - dma=0x01680000
  - low20=0x80000
- Descriptor readback:
  - wrote_map=0x01680000
  - rb_addr=0x00080000
  - rb_len=0x000e009a / 0x000e00c2
- TDMA:
  - sw_prod=1
  - hw_p=1
  - hw_c=0
  - tdma_ctrl=0x00020001
  - tdma_stat=0x00000000

Conclusion:
- A real reserved physical TX buffer at `0x01680000` is not enough as a
  standalone fix.
- The failure is not only caused by Linux allocating TX buffers in high 0x06xxxxxx RAM.
- The descriptor still reads back only the low 20 bits, `0x00080000`, so this
  result points at the missing DMA window/base/translation question rather than
  another normal allocator problem.
- TDMA still does not walk/consume ring16 even with a controlled reserved TX buffer.
- Remaining suspect area:
  - BCM3383 GENET DMA window/base/init
  - TDMA/SCB/UBUS setup
  - GENET v1 descriptor/ring semantics not matching mainline bcmgenet for this SoC

Do not repeat:
- mem=16M / mem=32M
- fatal DMA_BIT_MASK(20)
- non-fatal DMA_BIT_MASK(20)
- GFP_DMA coherent bounce
- ADDRSHIFT8
- LOWLIT 0x00080000
- reserved low TX buffer at 0x01680000 as a standalone fix
- blind parent IRQ enable

Next:
- Read current clock/reset state around `0x14e00000`, especially
  `ClkCtrlUBus`.
- Compare current `bcm3383_init_gmac()` against the BCM3383 clock definitions:
  it enables low/high GMAC clocks and reset, but not the named UBUS GMAC clock
  bit.
- Search OEM/source for bcm3383_init_gmac(), GENET DMA/SCB/window/base setup,
  and TDMA/RDMA initialization.
- Do not move to B53/DSA until TDMA consumes descriptors.
