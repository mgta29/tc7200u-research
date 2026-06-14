# Ghidra FPM/MBDMA labeling next steps

Labels completed for GENET/MBDMA and FPM MMIO blocks.

Next reverse targets:

- fn_dma_addr_alloc_wrapper_a
- fn_dma_addr_alloc_wrapper_sized
- FPM HW init writer for 0xb2200040 and 0xb2200044
- token translation/free path using 0x80000000 and 0x0ffff000

Confirmed correction:

- 0x12c00070 uses low core mask 0x00000003 and high core mask 0x00030000, not 0x00003000.

Do not patch OpenWrt until allocator/token path is confirmed.
