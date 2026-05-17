# TC7200.U GENET DMA address / bounce / TDMA status findings

Scope:
- RAM/TFTP boot only.
- Do not flash.
- Active useful diagnostics:
  - compact 20-bit GENET_V1 status/length descriptor test
  - ADDRDBG
  - DESCRB
  - TXPOLL
  - coherent TX bounce-buffer diagnostic

Confirmed:
- OpenWrt boots to serial shell with normal bootargs:
  - console=ttyS0,115200 earlycon
- GENET probes.
- eth0 fixed-link reports up.
- TX descriptor is posted.
- TDMA ring16 producer becomes 1.
- TDMA ring16 consumer stays 0.
- TX watchdog repeats.

Descriptor status/length:
- Compact 20-bit status/length test works.
- Example:
  - wrote_len=0x000e009a
  - rb_len=0x000e009a
- Therefore descriptor status/length packing is no longer the main blocker.

Descriptor address:
- Linux DMA mapping gives high physical DMA addresses:
  - dma=0x06835002
  - dma=0x069b0002
- GENET descriptor RAM stores only low 20 bits:
  - 0x06835002 -> 0x00035002
  - 0x069b0002 -> 0x000b0002
- ADDRDBG showed:
  - dma_mask=0xffffffff
  - coherent_dma_mask=0xffffffff
  - bus_dma_limit=0x0
  - dma_range_map=00000000

Failed address tests:
- ADDRSHIFT8 test:
  - dma=0x06837002
  - desc=0x00068370
  - rb_addr=0x00068370
  - hw_c=0
- Conclusion:
  - descriptor address is not simply dma >> 8.

Failed memory tests:
- mem=16M:
  - invalid Ethernet test
  - kernel panic before userspace
- mem=32M:
  - invalid Ethernet test
  - initramfs/rootfs unpack OOM
  - panic before GENET runtime test
- Conclusion:
  - stop mem= testing with current initramfs size.

Bounce-buffer test:
- dma_alloc_coherent(... GFP_DMA) succeeded, but still allocated high DMA:
  - bounce_dma=0x06e01000
  - rb_addr=0x00001000
  - hw_c=0
- Conclusion:
  - normal coherent/GFP_DMA bounce allocation is not a low-address test on this platform.

TDMA ring/global status:
- Ring16 state:
  - TDMA_READ_PTR        = 0x00000000
  - TDMA_CONS_INDEX      = 0x00000000
  - TDMA_PROD_INDEX      = 0x00000001
  - DMA_RING_BUF_SIZE    = 0x01000800
  - DMA_START_ADDR       = 0x00000000
  - DMA_END_ADDR         = 0x000001ff
  - DMA_MBUF_DONE_THRESH = 0x00000001
  - TDMA_WRITE_PTR       = 0x00000000
- Global TDMA:
  - TDMA_CTRL            = 0x00020000
  - TDMA_STATUS          = 0x00000000
  - TDMA_SCB_BURST_SIZE  = 0x00000010
  - TDMA_ARB_CTRL        = 0x00000002
- Interpretation:
  - ring metadata is sane enough to show one posted descriptor
  - no useful global TDMA error is reported
  - descriptor/data address reachability remains the primary blocker

Current working theory:
- BCM3383 GENET_V1 descriptor address field is only 20-bit offset-like.
- Missing piece is likely:
  - BCM3383 GENET DMA base/window setup
  - SoC-specific DMA translation
  - reserved low physical TX bounce buffer
  - or descriptor address interpretation not implemented by mainline bcmgenet

Do not repeat:
- mem=16M / mem=32M
- Zephyr-style dma-ranges on /ubus
- fatal DMA_BIT_MASK(20) probe path
- ADDRSHIFT8
- blind parent IRQ enable
- B53/DSA before GENET TDMA consumes descriptors
- IP/firewall debugging

Next planned test:
- Later: non-fatal DMA_BIT_MASK(20) diagnostic, or reserved low physical TX buffer test.
- IRQ <13 4> remains a separate branch and should not be combined with DMA address tests.
