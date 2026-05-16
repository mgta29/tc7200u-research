# TC7200.U GENET TXPOLL result: TDMA not consuming descriptor

Scope:
- RAM/TFTP boot only.
- Do not flash.
- No live devmem writes.

Image:
- GENET at 0x12c00000.
- interrupts = <16>, <17>.
- Parent IRQ bits not manually enabled.
- TXPOLL diagnostic patch active.
- No B53/DSA.
- SPI disabled.
- NAND unchanged.

Result:
- OpenWrt reached shell.
- eth0 link reported 1Gbps/full fixed-link.
- Console remained usable.
- No IRQ storm.
- TX watchdog repeated.
- TXPOLL repeatedly showed:
  - periph_stat=0x40030004
  - periph_mask=0x00002010
  - tdma_ctrl=0x00020001
  - tdma_stat=0x00000000
  - sw_prod=1
  - sw_c=0
  - hw_p=1
  - hw_c=0
  - free_bds=255
  - clean=0
  - write=1
- before_reclaim and after_reclaim were unchanged.

Interpretation:
- Driver queues one TX descriptor and writes producer index.
- Hardware TDMA consumer index never advances.
- Polling reclaim cannot recover any completed TX.
- Parent periph IRQ bits 16/17 still become pending, but interrupt delivery is not the primary question now.
- GENET internal register readings look suspicious:
  - intr0_stat=0xffffffea
  - intr0_mask values look like RAM/kernel addresses
  - intr1_mask=0x80a26c78
- Next target: verify BCM3383 GENET v1 register layout, TDMA/RDMA/INTRL2 offsets, and missing SoC DMA/clock/reset init.

Do not do next:
- Do not add B53/DSA yet.
- Do not change NAND.
- Do not enable parent IRQ bits 16/17 again.
- Do not debug IP/ARP/firewall yet.
