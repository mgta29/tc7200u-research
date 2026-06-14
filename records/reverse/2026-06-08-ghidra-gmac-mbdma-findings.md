# 2026-06-08 Ghidra GMAC/MBDMA findings

- 2026-06-08T03:55:22: fn_dma_addr_alloc_core returns cached static DMA buffer base 0x81848740 when g_dma_static_buf_ready is set; callers mask returned KSEG0 address with 0x1fffffff, producing physical DMA address 0x01848740 for GENET/GMAC MBDMA descriptor/control programming. DAT_81848738 now appears renamed as g_dma_static_buf_ready in decompiler, so searching DAT_81848738 may fail.
