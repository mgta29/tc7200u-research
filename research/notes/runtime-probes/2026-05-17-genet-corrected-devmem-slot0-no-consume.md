# TC7200.U GENET corrected manual descriptor still not consumed

Scope:
- RAM/TFTP boot only.
- Do not flash.
- GENET fixed-link diagnostic with compact GENET v1 descriptor packing active.
- Manual devmem descriptor-slot test.

Observed:
- `eth0` was brought up.
- Descriptor slot 0 was manually rewritten:
  - `0x12c03004 = 0x00080000`
  - `0x12c03000 = 0x000e009a`
  - `0x12c03c08 = 0x00000001`
- Descriptor readback after one second:
  - `0x12c03000 = 0x000e009a`
  - `0x12c03004 = 0x00080000`
- TDMA ring indices after one second:
  - `TDMA_CONS_INDEX = 0x00000000`
  - `TDMA_PROD_INDEX = 0x00000001`
- TXPOLL still reports:
  - `tdma_ctrl=0x00020001`
  - `tdma_stat=0x00000000`
  - `hw_p=1`
  - `hw_c=0`

Follow-up slot 1 producer-advance test:
- Descriptor slot 1 was manually written:
  - `0x12c0300c = 0x00080000`
  - `0x12c03008 = 0x000e009a`
  - `0x12c03c08 = 0x00000002`
- Descriptor readback after one second:
  - `0x12c03008 = 0x000e009a`
  - `0x12c0300c = 0x00080000`
- TDMA ring indices after one second:
  - `TDMA_CONS_INDEX = 0x00000000`
  - `TDMA_PROD_INDEX = 0x00000002`
- TXPOLL reports:
  - `tdma_ctrl=0x00020001`
  - `tdma_stat=0x00000000`
  - `sw_prod=1`
  - `hw_p=2`
  - `hw_c=0`

Full ring16/global TDMA snapshot after rewriting slots 0 and 1:
- Descriptor slots were rewritten:
  - slot 0 length/status/address: `0x000e009a`, `0x00080000`
  - slot 1 length/status/address: `0x000e009a`, `0x00080000`
  - `TDMA_PROD_INDEX = 0x00000002`
- Ring16 registers:
  - `TDMA_READ_PTR        = 0x00000000`
  - `TDMA_CONS_INDEX      = 0x00000000`
  - `TDMA_PROD_INDEX      = 0x00000002`
  - `DMA_RING_BUF_SIZE    = 0x01000800`
  - `DMA_START_ADDR       = 0x00000000`
  - `DMA_END_ADDR         = 0x000001ff`
  - `DMA_MBUF_DONE_THRESH = 0x00000001`
  - `TDMA_FLOW_PERIOD     = 0x00000000`
  - `TDMA_WRITE_PTR       = 0x00000000`
- Global TDMA registers:
  - `DMA_CTRL             = 0x00020001`
  - `DMA_STATUS           = 0x00000000`
  - `DMA_SCB_BURST_SIZE   = 0x00000010`
  - `DMA_ARB_CTRL         = 0x00000002`
- TXPOLL still reports:
  - `hw_p=2`
  - `hw_c=0`

Interpretation:
- The corrected compact descriptor word read back exactly as intended.
- TDMA still did not advance the consumer index.
- This rules out the previous typo in the manual descriptor word as the reason
  for no TDMA consumption.
- Slot 1 with producer advanced to `2` also did not move the consumer index.
- This rules out a stale producer write to the same value as the reason for no
  TDMA consumption.
- Ring16 register setup matches the driver's expected GENET v1 layout:
  256 descriptors, 2 words per descriptor, start word `0`, end word `0x1ff`,
  ring16/global enable set, no global TDMA status error.
- The remaining issue is not explained by descriptor word/address readback,
  producer writes, or obvious ring16 register setup. It points harder at a
  missing BCM3383 GENET DMA window/init bit, an SoC-specific DMA access path, or
  the need for a real kernel-side low/bus-address buffer rather than manual
  devmem descriptors.

Next:
- Stop repeating manual descriptor/producer pokes.
- Move to kernel-side diagnostics:
  - reserved low physical TX bounce-buffer test; or
  - BCM3383 GENET DMA window/base/init register probe; or
  - OEM-source comparison for SoC-specific GENET DMA setup.

Do not do next:
- Do not enable parent GENET IRQ bits manually.
- Do not add B53/DSA yet.
- Do not repeat `mem=16M`, `mem=32M`, ADDRSHIFT8, or fatal 20-bit DMA mask
  tests.
