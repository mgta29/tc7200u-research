# TC7200.U manual periph_intc mask test caused GENET IRQ storm

Scope: RAM/TFTP boot only. Do not flash.

Test:
- eth0 down:
  - devmem 0x14e00048 32 = 0x40000004
  - devmem 0x14e0004c 32 = 0x00002010
- manually wrote:
  - devmem 0x14e0004c 32 0x00032010
- eth0 up afterwards.

Result:
- bcmgenet request_irq succeeded.
- bcmgenet_isr0 started firing continuously on IRQ16.
- Debug showed repeated:
  - active=0x30000000
  - raw=0xb2c00000
  - mask=0xb2c00000
- Console became flooded; input became unusable.

Conclusion:
- periph_intc bits 16/17 are involved in dispatching GENET interrupts.
- Previous failure was caused by parent L2 mask/gate state.
- Blindly enabling 16/17 causes an interrupt storm.
- Next patch must clear/mask GENET INTRL2 status correctly before enabling parent IRQ bits, and must disable parent bits on eth0 close.
