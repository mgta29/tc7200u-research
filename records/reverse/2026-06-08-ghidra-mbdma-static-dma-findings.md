
## 2026-06-08 02:36:45 UTC

- Ghidra TC7200U GMAC/MBDMA finding: fn_dma_addr_alloc_core at 0x8002a798 is a lazy static DMA buffer initializer, not a bump or sized allocator.
- It initializes/registers cached KSEG0 static DMA area at 0x81848740 when g_dma_static_buf_ready is zero, sets the ready flag, and always returns fixed base 0x81848740.
- GMAC/MBDMA callers mask returned KSEG0 address with 0x1fffffff, producing DMA physical address 0x01848740.
- fn_enet_gmac_mbdma_global_init at 0x803a8790 writes masked DMA addresses into GENET/MBDMA global registers 0x12c00008/10/4c/50/54/58 and control 0x12c0000c.
- No local s3 source found in fn_enet_gmac_init_step6 or its direct caller before the MBDMA wrapper call; s3 appears inherited from outer preserved-register context and flows into GENET_MBDMA_GLOBAL_CTRL_12c0000c as a hidden control template.
- Next check: confirm fn_dma_addr_alloc_wrapper_a and fn_dma_addr_alloc_wrapper_sized do not add offsets after fn_dma_addr_alloc_core returns.
