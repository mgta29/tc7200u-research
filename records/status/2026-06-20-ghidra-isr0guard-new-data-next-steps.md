# 2026-06-20 Ghidra note: GENET IRQ13 ISR0GUARD runtime data

## Source evidence

Serial log: `picocom-20260620-162444.log`

Boot/test identity:

- Requested image: `2026-06-20-5.bin`
- A825 signature: `0xa825`
- File length: `5709081`
- Load address: `0x82000000`
- CFE prompt answer: `Store parameters to flash? [n] n`
- Kernel: OpenWrt Linux `6.12.93`
- Machine: Technicolor TC7200.U / BCM3383

Runtime result:

- `eth0` probe/open reached the temporary GENET diagnostics.
- IRQ13 branch now reaches `bcmgenet_isr0()` and emits `TC7200U ISR0GUARD`.
- No `Data bus error`, `Oops`, `Kernel panic`, `NETDEV WATCHDOG`, `get_swap_device`, or RCU-stall marker was present in this capture.
- The ISR guard flooded: roughly 5.5k `TC7200U ISR0GUARD` prints from about `t=131.69s` to `t=285.16s`, around one print every 27.6 ms.

Representative ISR0GUARD values:

```text
irq=13
raw_stat=0x80a11a00 for the first few prints, then usually 0xffffbd95
raw_mask=0xb2c00000
pending=0xb2c00000
periph_stat=0x40000004
periph_mask=0x00002000
```

Important caveat: the current OpenWrt guard patch re-reads `INTRL2_CPU_STAT` and `INTRL2_CPU_MASK_STATUS` inside `netdev_err()` instead of saving one coherent pair of locals first. Therefore `raw_stat`, `raw_mask`, and `pending` in this log may not be from the same read pair. Do not treat `pending=0xb2c00000` as a mathematically coherent decode of the printed `raw_stat/raw_mask` until the probe is fixed to snapshot locals first.

Representative open-entry hardware/context values:

```text
FPM_A 12200010=0x00000000 12200014=0x00000001 12200040=0x06000000 12200044=0x00010000
FPM_B 12200050=0x00000000 12200054=0x18007edf 12200058=0x00000000 1220005c=0x00000000
FPM_C 12200200=0x80250800 12200208=0x900b0400 12200210=0xa01b8200 12200218=0xb02ab100
PROFILE 14e001c4=0xda492010 14e00002=0x00a2 14e00264=0x00000000
```

The repeated GMAC/GENET offset reads mostly returned `0xb2c00000`, and the first word of several groups returned a kernel-pointer-like value such as `0x869bb9e0`. Treat this as evidence that the current OpenWrt upstream `bcmgenet` offset assumptions are not yet aligned with the BCM3383/OEM GMAC path, not as confirmed hardware register contents.

---

## Immediate Ghidra implications

### 1. IRQ13 is now a positive mapping clue, not a full fix

In Ghidra, annotate the OEM interrupt/bank mapping around the periph interrupt controller and GMAC/GENET interrupt source code:

```text
periph_stat=0x40000004
periph_mask=0x00002000
```

Working interpretation:

- IRQ13 reaches the OpenWrt `bcmgenet_isr0()` branch.
- The interrupt source remains asserted/flooding because the current clear path is probably not clearing the real BCM3383 source.
- Do not merge IRQ13 into the baseline DMA/TDMA branch yet.
- The next question is: which OEM status/ack/mask register corresponds to `periph_stat bit 30` and why does `periph_mask bit 13` route it into Linux IRQ13?

Ghidra scalar-search decimal values:

```text
0x40000004 = 1073741828
0x00002000 = 8192
0xb2c00000 = 2998927360 unsigned / -1296039936 signed
0xffffbd95 = 4294950293 unsigned / -17003 signed
0x80a11a00 = 2158041600 unsigned / -2136925696 signed
0x14e00048 = 350224456
0x14e0004c = 350224460
```

Search both constants and nearby bit operations. In this user's Ghidra setup, scalar search uses decimal input.

### 2. Update memory block labels / datatype work

Memory block labels to verify/create:

```text
MMIO_GENET_PHYS_12c00000      0x12c00000-0x12c03fff
MMIO_GENET_KSEG1_B2C00000     0xb2c00000-0xb2c03fff
MMIO_FPM_PHYS_12200000        0x12200000-0x12200fff or proven larger window
MMIO_FPM_KSEG1_B2200000       0xb2200000-0xb2200fff or proven larger window
MMIO_PERIPH_INTC_PHYS_14e00048 / periph intc window
MMIO_PERIPH_INTC_KSEG1_B4E00048 / periph intc KSEG1 alias
```

Global/register labels to apply or confirm:

```text
GENET_BASE_B2C00000_candidate
GENET_ISR0_STATUS_OR_CPU_STAT_B2C0xxxx_candidate
GENET_ISR0_MASK_OR_CPU_MASK_STATUS_B2C0xxxx_candidate
GENET_ISR0_CLEAR_B2C0xxxx_candidate
PERIPH_IRQ_STATUS_14E00048_candidate
PERIPH_IRQ_MASK_14E0004C_candidate
FPM_HW_BASE_B2200000_candidate
FPM_ENDPOINT_800_12200200_candidate
FPM_ENDPOINT_400_12200208_candidate
FPM_ENDPOINT_200_12200210_candidate
FPM_ENDPOINT_100_12200218_candidate
```

Datatype updates:

```text
tc7200_fpm_allocator / existing FPM allocator state: keep software allocator separate from MMIO endpoints.
tc7200_fpm_endpoint_registers_candidate: add/confirm endpoint offsets +0x200/+0x208/+0x210/+0x218.
tc7200_genet_irq0_regs_candidate: only create after OEM offsets are proven; do not force upstream INTRL2 layout onto BCM3383 yet.
tc7200_periph_irq_bank_candidate: model status/mask/clear semantics only after finding OEM write sites.
```

### 3. Function labels/signatures to inspect next

Priority Ghidra targets:

```text
fn_enet_gmac_init_*_candidate
fn_enet_build_core_cmd_*_candidate
fn_enet_poll_or_wait_ready_*_candidate
fn_dma_fpm_driver_hw_init_wrapper_8009f6a8
fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate
fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate
fn_dma_fpm_alloc_buffer_ptr_for_size_8009e218
fn_dma_fpm_free_token_to_hw_8009e168
```

New reverse task from this log:

```text
Find the OEM path that unmasks/acks/clears the GMAC/GENET interrupt routed to periph IRQ13/bit 0x00002000.
```

Use Ghidra comments like:

```c
/* BCM3383 GENET/GMAC IRQ13 runtime clue.

   OpenWrt guarded run 2026-06-20 reached bcmgenet_isr0 through Linux irq=13.
   Repeated runtime values:
     periph_stat=0x40000004
     periph_mask=0x00002000

   This proves the IRQ13 branch reaches the GENET ISR path, but the source is not
   being cleared by the current upstream-style bcmgenet ISR0 clear path.

   Next: find OEM status/ack/mask write sequence for this source.
   -> {@symbol fn_enet_gmac_init_*_candidate}
   -> {@symbol fn_enet_poll_or_wait_ready_*_candidate}
*/
```

### 4. Do not do these in Ghidra yet

Do not create a final `tc7200_genet_intrl2_regs` structure from the OpenWrt upstream `bcmgenet` offsets yet. The log suggests the current offset reads are suspicious and may not represent the BCM3383 OEM layout.

Do not rename old `0x14e01000` objects back into Ethernet. That path remains HSSPI, not GENET.

Do not treat `0xb2c00000` as a valid status bitfield just because it appears in the temporary OpenWrt logs. It may be an unmapped/incorrect offset read, a base-address echo, or a stale artifact from wrong register layout assumptions.

---

## OpenWrt-side follow-up needed before more runtime tests

Fix the ISR guard probe so it snapshots locals once:

```c
raw_stat = bcmgenet_intrl2_0_readl(priv, INTRL2_CPU_STAT);
raw_mask = bcmgenet_intrl2_0_readl(priv, INTRL2_CPU_MASK_STATUS);
status = raw_stat & ~raw_mask;
```

Then print those locals. Also limit the guard with `static int count` and disable/mask IRQ13 after the first few lines, otherwise the serial flood prevents useful post-boot commands.

---

## Bottom line

This new runtime data proves IRQ13 reaches the OpenWrt GENET ISR0 path. It does not prove that upstream `bcmgenet` ISR0 status/mask/clear offsets are valid for BCM3383. In Ghidra, the next work is to find the OEM GMAC/GENET interrupt status/ack/mask sequence and compare it against the OpenWrt `bcmgenet_isr0()` assumptions.
