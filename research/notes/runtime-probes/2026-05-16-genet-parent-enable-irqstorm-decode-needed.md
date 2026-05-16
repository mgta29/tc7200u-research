# TC7200.U GENET parent-enable IRQ storm requires bit/register decode

Scope: RAM/TFTP boot only. Do not flash.

Result:
- Manual write: devmem 0x14e0004c 32 0x00032010
- This enabled periph_intc bits 16/17.
- After eth0 up, bcmgenet_isr0 started firing continuously.
- Repeated debug:
  - irq=16
  - active=0x30000000
  - raw=0xb2c00000
  - mask=0xb2c00000
- Console became unusable due to interrupt storm.

Meaning:
- Parent periph_intc gate for GENET IRQs is involved.
- IRQ16 can reach bcmgenet_isr0 if periph bits 16/17 are manually enabled.
- Blind parent enable is unsafe.
- Need to decode GENET interrupt bits 0x30000000 and verify BCM3383 GENET v1 interrupt register offsets/bit definitions before patching.

Next:
- Inspect bcmgenet.h UMAC_IRQ definitions.
- Inspect GENET v1 hw_params/intrl2 offsets.
- Compare with Technicolor vendor source for GENET/INTRL2 setup.
