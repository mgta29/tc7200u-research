# TC7200.U GENET reserved low buffer, status-format, and swapdesc state

Scope:
- RAM/TFTP boot only.
- Do not flash.
- GENET at 0x12c00000 probes.
- eth0 link reports up.
- TX descriptor is posted.
- TDMA producer advances.
- TDMA consumer remains 0.

Confirmed negative tests:
- Non-fatal DMA_BIT_MASK(20):
  - dma_set_mask_and_coherent(... DMA_BIT_MASK(20)) returned -5.
  - Driver restored 32-bit mask.
  - TX still used high DMA.
- LOWLIT 0x00080000:
  - descriptor readback showed rb_addr=0x00080000.
  - TDMA still did not consume.
- Manual low16 status:
  - manually wrote 0x0000e09a.
  - TDMA consumer stayed 0.
- Reserved low physical TX buffer with compact status:
  - reserved phys=0x01680000, virt=a1680000.
  - descriptor rb_addr=0x00080000.
  - compact len/status readback looked correct.
  - TDMA consumer stayed 0.
- Reserved low physical TX buffer with upstream/original status:
  - RESVTX dma=0x01680000.
  - upstream len_stat=0x009aefc0.
  - descriptor readback rb_len=0x000aefc0, rb_addr=0x00080000.
  - TDMA consumer stayed 0.

Important interpretation:
- The failure is no longer explained only by Linux allocating TX buffers in high 0x06xxxxxx RAM.
- A controlled low physical TX buffer is not enough.
- Upstream/original status format is not enough.
- Compact status format is not enough.
- TDMA is enabled and ring producer advances, but hardware still does not walk/consume ring16.

OEM/source search:
- Local source search did not reveal a BCM3383-specific GENET GMAC/TDMA init path.
- Useful hits point back to generic/mainline Broadcom bcmgenet descriptor and ring definitions:
  - DMA_DESC_ADDRESS_LO
  - DMA_DESC_ADDRESS_HI
  - TDMA_CONS_INDEX
  - TDMA_PROD_INDEX
  - DMA_RING_BUF_SIZE
  - DMA_BUFLENGTH_SHIFT
  - DMA_OWN

Current next test:
- 9987-bcmgenet-tc7200u-v1-resv-swapped-desc-test.patch
- Purpose:
  - reserved low TX buffer at 0x01680000
  - upstream/original len_stat
  - swapped descriptor word order:
    - word0 = address
    - word1 = length/status
- This tests whether BCM3383 GENET v1 descriptor RAM expects descriptor words in the opposite order from mainline bcmgenet.

Current intended OpenWrt patch state for next test:
- Active:
  - 9979-bcmgenet-tc7200u-addr-debug.patch
  - 9987-bcmgenet-tc7200u-v1-resv-swapped-desc-test.patch
- Inactive for this test:
  - 9978-bcmgenet-tc7200u-v1-pack20-desc-test.patch
  - 9986-bcmgenet-tc7200u-v1-reserved-txbuf-test.patch

Do not repeat:
- mem=16M / mem=32M
- fatal DMA_BIT_MASK(20)
- non-fatal DMA_BIT_MASK(20)
- GFP_DMA coherent bounce
- ADDRSHIFT8
- LOWLIT 0x00080000
- manual low16 status poke
- reserved low TX buffer as standalone fix
- blind parent IRQ enable
- B53/DSA before TDMA consumes descriptors

Next decision:
- If SWAPDESC makes hw_c advance, descriptor word order was the blocker.
- If SWAPDESC still leaves hw_c=0, move to BCM3383 GENET TDMA/SCB/window/init probing.
