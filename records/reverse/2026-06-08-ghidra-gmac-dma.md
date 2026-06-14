
- Confirmed fn_dma_addr_alloc_core returns constant static DMA buffer base 0x81848740; Ghidra cannot go-to it because it is not mapped program memory. g_dma_static_buf_ready at DAT_81848738 gates one-time init. GMAC MBDMA callers mask returned KSEG0 address with 0x1fffffff, yielding physical DMA address 0x01848740 for GENET/MBDMA registers.
