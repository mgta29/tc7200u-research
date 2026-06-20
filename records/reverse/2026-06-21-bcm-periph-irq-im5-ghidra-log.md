# 2026-06-21 BCM peripheral IRQ IM5 dispatcher Ghidra log

## Metadata

| Field | Value |
|---|---|
| Date | 2026-06-21 |
| Project | TC7200U / BCM3383 reverse engineering |
| Program | `image.raw` |
| Focus | OEM peripheral interrupt controller path behind the OpenWrt IRQ13 GENET ISR flood |
| Output filename | `2026-06-21-bcm-periph-irq-im5-ghidra-log.md` |
| Intended repo target | `records/reverse/2026-06-21-bcm-periph-irq-im5-ghidra-log.md` |
| Local Windows download path | `C:\Users\mgta29\Downloads\2026-06-21-bcm-periph-irq-im5-ghidra-log.md` |

## Executive summary

This Ghidra pass moved the IRQ13 investigation from dry string/scalar searches into a concrete OEM interrupt-dispatch path.

The important result is the identification of a Broadcom peripheral interrupt dispatcher rooted in the `0xb4e00000` KSEG1 peripheral block:

- `FUN_8002adbc` reads parent interrupt active bits from `b4e00050 & b4e00054`, dispatches each active parent bit through `FUN_8002ae48`, and re-enables CP0 Status bit `0x2000`.
- The registration block around `80860330..80860360` installs `FUN_8002adbc` as a CP0 interrupt-line 5 handler through `FUN_80ea4108(5, FUN_8002adbc, 0)`.
- The same registration block enables a parent interrupt group bit in `b4e00050` using `1 << (group_id - 0x23)`.
- Therefore, if the OpenWrt runtime parent bit `0x00002000` is the same bank bit 13, the matching OEM group id is `0x30` / decimal `48`.
- `FUN_8002ae48` is the second-level child-bank dispatcher. It maps the parent bit to a child MMIO bank through the table at `81745b14`, then uses child-bank offsets `+0x08` and `+0x0c` as child status/pending and mask/enable words, clears handled child status bits, and calls the registered handler from the table rooted at `81743214`.

This is now the highest-value path for mapping Linux IRQ13 back to the OEM handler group and finding the correct parent/child acknowledge behavior.

## Source evidence summarized

### Runtime OpenWrt IRQ13 clue

The OpenWrt IRQ13 branch reached the upstream GENET ISR0 path and then flooded/stalled. The key printed values were:

```text
irq=13
periph_stat=0x40000004
periph_mask=0x00002000
```

The same capture warned that raw GENET `raw_stat/raw_mask/pending` prints were not coherent because the guard re-read registers directly inside logging rather than saving one snapshot pair first. Therefore the reliable lead is the peripheral IRQ-bank state, not the raw GENET values.

Working interpretation before this Ghidra pass:

```text
IRQ13 reaches bcmgenet_isr0.
The parent peripheral interrupt is probably not being acknowledged or masked correctly.
Do not combine IRQ13 with DQM/FPM changes.
Do not blindly enable parent bits.
Find OEM parent/child IRQ clear path first.
```

### Dry searches eliminated

The previous string path was not useful:

```text
811121d0  "Periph IRQ Mask   = 0x%08X\n"
811121ec  "Periph IRQ Status = 0x%08X\n"
8112e320  "BCM interrupt enable: %08x, status: %08x\n"
8112e554  "BCM interrupt enable: %08lx, status: %08lx\n"
8116db58  "Initializing main %s DQM interrupts.\n"
8138dde8  "PeriphIrqmask0..."
8138de24  "PeriphIrqmask1..."
8138de60  "PeriphIrqmask2..."
8138de9c  "PeriphIrqmask3..."
```

In the current Ghidra database those strings had no useful direct xrefs. Treat them as diagnostic evidence only, not as the path to the handler.

The scalar/address fragment searches for the string addresses were also dry or false-positive. The direct `b4e0` operand search was the better approach.

## Findings

## 1. `b4e0` search: useful clusters vs false clusters

The `Instruction Operands` search for `0xb4e0` found many hits. The first useful split was:

- `80074b00..80074e60`: BCM34xx/BCM3422 serial register access path.
- `8080c194..8080c3fc`: another BCM34xx serial 32-bit write helper.
- `8002adbc`: real peripheral interrupt parent dispatcher.
- `80860330..80860360`: interrupt registration / parent enable block.

The BCM34xx serial cluster was useful cleanup but not the IRQ13 path. The IRQ path started at `8002adbc`.

## 2. BCM34xx serial block is not IRQ13

The `80074b00..80074e60` and `8080c194..8080c3fc` work classified this subregion:

```text
b4e00e00-b4e00e30
```

as a BCM34xx / BCM3422 serial-access register block.

Important offsets:

```text
b4e00e00  ctrl
b4e00e04  write/data/register-index word
b4e00e08  command byte 0 / low byte
b4e00e0c  command byte 1
b4e00e10  command byte 2
b4e00e14  command byte 3 / high byte
b4e00e24  transfer length
b4e00e28  opcode
b4e00e2c  command/status
b4e00e30  read FIFO
b4e00e33  read byte lane 3
```

This cluster does not touch:

```text
b4e0002c
b4e00030
b4e00034
b4e00048
b4e0004c
b4e00050
b4e00054
b4e00078
```

So it is not the missing GENET IRQ13 parent clear path.

### Function boundary correction

`8080c2a8` was not a real function start. It was an internal block inside the real function starting at `8080c194`. It used live `s1`, `s2`, `s4`, `v0`, and `v1` values already set by the outer function and had no prologue.

Correction:

```text
Delete function definition only:
  fn_bcm3422_serial_block_init_or_reset_8080c2a8

Keep a label only:
  LAB_bcm34xx_serial_program_5byte_write_command_8080c2a8
```

Real function:

```text
8080c194  fn_bcm34xx_serial_write32_register_8080c194_candidate
```

Signature:

```c
void fn_bcm34xx_serial_write32_register_8080c194_candidate
        (uint32_t register_index,
         uint32_t value);
```

Rationale for `bcm34xx` instead of final `bcm3422`: the write function's log string refers to a `3410 register`, while the other read helper has a `Read_BCM3422` string. The family-generic name preserves uncertainty.

## 3. Parent IRQ dispatcher at `8002adbc`

### Original behavior

The pasted function:

```asm
8002add0  lui   v0,0xb4e0
8002add4  lw    v1,0x50(v0)
8002add8  lw    v0,0x54(v0)
8002addc  and   s0,v1,v0
...
8002adec  clz   a0,s0
8002adf0  subu  a0,s2,a0        ; bit_index = 31 - clz(active)
8002adf4  sllv  v0,s1,a0
8002adf8  nor   v0,zero,v0
8002adfc  jal   FUN_8002ae48
8002ae00  and   s0,s0,v0
...
8002ae10  mfc0  v1,Status
8002ae14  li    v0,0x100
8002ae18  sllv  v0,v0,a0        ; a0 = 5, v0 = 0x2000
8002ae1c  or    v1,v1,v0
8002ae20  mtc0  v1,Status
```

The function computes:

```c
active = *(volatile uint32_t *)0xb4e00050 &
         *(volatile uint32_t *)0xb4e00054;

while (active != 0) {
    bit_index = 31 - clz(active);
    active &= ~(1u << bit_index);
    FUN_8002ae48(bit_index);
}

Status |= 0x2000;
```

### Corrected interpretation of `b4e00050` / `b4e00054`

A later registration snippet showed:

```asm
80860358  lw   v1,0x50(a0)
8086035c  or   v0,v0,v1
80860360  sw   v0,0x50(a0)
```

That means `b4e00050` is written with an ORed enable bit. It is therefore mask/enable-style, not pure status.

Correct labels:

```text
b4e00050  PERIPH_IRQ_IM5_MASK_OR_ENABLE_B4E00050_candidate
b4e00054  PERIPH_IRQ_IM5_STATUS_OR_PENDING_B4E00054_candidate
```

### Recommended rename

Rename:

```text
FUN_8002adbc
```

to:

```text
fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate
```

Signature:

```c
void fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate(void);
```

Function comment:

```text
BCM peripheral interrupt pending dispatcher for CP0 interrupt-mask bit IM5.

Behavior:
  - reads mask/enable candidate word at {@address b4e00050}
  - reads pending/status candidate word at {@address b4e00054}
  - computes active = mask & status
  - while active bits remain:
      selects the highest active bit using clz:
        bit_index = 31 - clz(active)
      clears that bit from the local active mask
      calls {@symbol fn_bcm_periph_irq_child_bank_dispatch_8002ae48_candidate}(bit_index)
  - after all active bits are dispatched, re-enables CP0 Status bit 0x2000:
      Status |= (0x100 << 5)

Current interpretation:
  Parent/peripheral interrupt-bank dispatcher feeding CP0 hardware interrupt
  line 5 / Status IM5. This may correspond to the Linux IRQ13 parent line.

Important:
  This function does not itself clear the final device source. The per-parent
  child handler / acknowledge path is in the child-bank dispatcher and registered
  handler callbacks.
```

Internal labels:

```text
8002adec  LAB_periph_irq_im5_dispatch_next_active_bit_8002adec
8002ae0c  LAB_periph_irq_im5_reenable_cp0_status_8002ae0c
```

## 4. Registration and parent-enable block at `80860330..80860360`

### Pasted snippet

```asm
80860300  sltiu  v0,v0,0x6
80860304  beq    v0,zero,LAB_80860390
80860308  lbu    v1,0x0(sp)
8086030c  lbu    v0,0x1(sp)
80860310  sll    v1,v1,0x5
80860314  addu   v1,v1,v0
80860318  sll    v1,v1,0x3
8086031c  lui    v0,0x8174
80860320  addiu  v0,v0,0x5514
80860324  addu   v1,v1,v0
80860328  sw     s1,-0x2300(v1)  ; handler
8086032c  sw     s2,-0x22fc(v1)  ; handler arg
80860330  li     a0,0x5
80860334  lui    a1,0x8003
80860338  addiu  a1,a1,-0x5244   ; 8002adbc
8086033c  jal    FUN_80ea4108
80860340  clear  a2
80860344  lui    a0,0xb4e0
80860348  lbu    v1,0x0(sp)
8086034c  addiu  v1,v1,-0x23
80860350  li     v0,0x1
80860354  sllv   v0,v0,v1
80860358  lw     v1,0x50(a0)
8086035c  or     v0,v0,v1
80860360  sw     v0,0x50(a0)
```

### Meaning

This block does three important things.

1. Stores callback pair into the handler table:

```c
handler_table[((group_id * 32) + sub_id)].handler = s1;
handler_table[((group_id * 32) + sub_id)].arg     = s2;
```

2. Registers the parent dispatcher for CP0 interrupt line 5:

```c
FUN_80ea4108(5, fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate, 0);
```

3. Enables the parent group bit:

```c
B4E00050 |= 1u << (group_id - 0x23);
```

Therefore:

```text
parent_bit = group_id - 0x23
group_id   = parent_bit + 0x23
```

Decimal / scalar-use values:

```text
0x23   = 35
0x30   = 48
0x100  = 256
0x1000 = 4096
0x2000 = 8192
```

### IRQ13 inference

OpenWrt runtime showed `periph_mask=0x00002000`, which is bit 13.

If this is the same parent bank:

```text
parent_bit = 13
group_id   = 0x23 + 13 = 0x30
decimal    = 48
```

So group `0x30` / decimal `48` is now the main OEM handler-table target.

### Recommended labels

```text
80860330  LAB_bcm_periph_irq_register_cp0_im5_dispatcher_80860330
80860344  LAB_bcm_periph_irq_enable_parent_group_bit_80860344
```

Comment:

```text
BCM peripheral interrupt registration/enabling block.

Behavior:
  - stores callback pair {s1, s2} into the peripheral IRQ handler table
  - table index is ((group_id * 32) + sub_id) * 8
  - registers {@symbol fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate}
    as CP0 interrupt line 5 handler through {@symbol FUN_80ea4108}
  - enables parent interrupt group bit in {@address b4e00050}:
      bit = group_id - 0x23

Important:
  If runtime parent bit 13 is the same bank, then target OEM group id is 0x30
  / decimal 48.
```

Do not rename the outer function yet until its real start and argument model are pasted.

## 5. Child-bank dispatcher at `8002ae48`

### Pasted function behavior

`FUN_8002ae48` is called by the parent dispatcher. It receives the active parent bit index.

Key operations:

```asm
8002ae60  sll   v1,param_1,0x8
8002ae68  addiu v0,v0,0x5514
8002ae6c  addu  s1,v1,v0        ; handler-table group base

8002ae70  sll   param_1,param_1,0x2
8002ae78  addiu v0,v0,0x5b14
8002ae7c  addu  param_1,param_1,v0
8002ae80  lw    v0,0x0(param_1) ; child bank base table
8002ae84  ori   s0,v0,0x1000

8002ae88  lw    v0,0x8(s0)
8002ae8c  lw    v1,0xc(s0)
8002ae90  and   v0,v0,v1        ; active child bits

...
8002aec8  lw    v0,0x8(s0)
8002aecc  and   param_1,param_1,v0
8002aed0  sw    param_1,0x8(s0) ; clear handled child status bit

8002aed4  sll   v1,v1,0x3
8002aed8  addu  v1,v1,s1
8002aedc  lw    v0,0x0(v1)      ; handler
8002aee8  jalr  v0
8002aeec  lw    param_1,0x4(v1) ; handler arg
```

### Meaning

```c
void child_dispatch(uint32_t parent_bit_index)
{
    handler_group_base = 0x81745514 + parent_bit_index * 0x100;

    child_base = *(uint32_t *)(0x81745b14 + parent_bit_index * 4);
    child_base |= 0x1000;

    active = *(uint32_t *)(child_base + 0x08) &
             *(uint32_t *)(child_base + 0x0c);

    while (active != 0) {
        child_bit = 31 - clz(active);
        bit_mask = 1u << child_bit;

        active &= ~bit_mask;

        /* clear/ack child pending/status copy */
        *(uint32_t *)(child_base + 0x08) =
            *(uint32_t *)(child_base + 0x08) & ~bit_mask;

        entry = &handler_group_base[child_bit];
        if (entry->handler != NULL) {
            entry->handler(entry->handler_arg);
        }
    }
}
```

### Recommended rename

Rename:

```text
FUN_8002ae48
```

to:

```text
fn_bcm_periph_irq_child_bank_dispatch_8002ae48_candidate
```

Signature:

```c
void fn_bcm_periph_irq_child_bank_dispatch_8002ae48_candidate
        (uint32_t parent_bit_index);
```

Function comment:

```text
BCM peripheral interrupt child-bank dispatcher.

Arguments:
  parent_bit_index = active parent bit selected by
    {@symbol fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate}

Behavior:
  - computes child handler-table base:
      {@address 81745514} + parent_bit_index * 0x100
    This is equivalent to group id 0x23 + parent_bit_index in the full
    handler table rooted at {@address 81743214}.
  - loads child MMIO bank base from {@address 81745b14} + parent_bit_index * 4
  - ORs the loaded base with 0x1000 before accessing child registers
  - reads child pending/status at child_base + 0x08
  - reads child mask/enable at child_base + 0x0c
  - active = status & mask
  - scans active child bits using clz
  - clears each handled child bit from child_base + 0x08
  - looks up handler entry:
      handler_table[parent_bit_index][child_bit]
  - if handler is non-NULL, calls handler(saved_arg)

Current interpretation:
  Second-level peripheral interrupt dispatcher under CP0 IM5.

Important:
  This is now the highest-value path for mapping Linux IRQ13 / parent bit 13
  back to the OEM handler group.
```

Internal labels:

```text
8002aea8  LAB_periph_irq_child_dispatch_next_active_bit_8002aea8
8002aef0  LAB_periph_irq_child_dispatch_loop_continue_8002aef0
8002aefc  LAB_periph_irq_child_dispatch_return_8002aefc
```

## 6. Handler-table math

### Full table root

The registration block stores entries through:

```text
base before negative offset = 81745514
store offset -0x2300       = 81743214
```

So the full handler table root is:

```text
81743214  g_bcm_periph_irq_handler_table_81743214_candidate
```

Index formula:

```text
entry_addr = 81743214 + ((group_id * 32) + child_bit) * 8
```

Each entry is:

```text
+0x00  handler pointer
+0x04  handler argument
```

### Group 0x23 alias

`FUN_8002ae48` starts from:

```text
81745514
```

This equals:

```text
81743214 + (0x23 * 32 * 8)
```

So label:

```text
81745514  g_bcm_periph_irq_handler_table_group23_base_81745514_candidate
```

In the child dispatcher:

```text
handler_group_base = 81745514 + parent_bit_index * 0x100
```

Since one group has 32 entries and each entry is 8 bytes:

```text
32 * 8 = 0x100
```

### Parent bit 13 target

If runtime parent mask bit 13 maps to this bank:

```text
parent_bit = 13
group_id   = 0x23 + 13 = 0x30
```

Group base:

```text
81743214 + 0x30 * 0x100 = 81746214
```

So inspect:

```text
81746214-81746314
```

Each child bit entry:

```text
child_bit N entry = 81746214 + N * 8
```

## 7. Labels to add

### MMIO labels

```text
b4e00050  PERIPH_IRQ_IM5_MASK_OR_ENABLE_B4E00050_candidate
b4e00054  PERIPH_IRQ_IM5_STATUS_OR_PENDING_B4E00054_candidate
```

If previous labels had `status` on `0x50` and `mask` on `0x54`, swap them.

### Data labels

```text
81743214  g_bcm_periph_irq_handler_table_81743214_candidate
81745514  g_bcm_periph_irq_handler_table_group23_base_81745514_candidate
81745b14  g_bcm_periph_irq_child_bank_base_table_81745B14_candidate
```

### Code labels

```text
8002adec  LAB_periph_irq_im5_dispatch_next_active_bit_8002adec
8002ae0c  LAB_periph_irq_im5_reenable_cp0_status_8002ae0c
8002aea8  LAB_periph_irq_child_dispatch_next_active_bit_8002aea8
8002aef0  LAB_periph_irq_child_dispatch_loop_continue_8002aef0
8002aefc  LAB_periph_irq_child_dispatch_return_8002aefc
80860330  LAB_bcm_periph_irq_register_cp0_im5_dispatcher_80860330
80860344  LAB_bcm_periph_irq_enable_parent_group_bit_80860344
```

### Function labels

```text
8002adbc  fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate
8002ae48  fn_bcm_periph_irq_child_bank_dispatch_8002ae48_candidate
8080c194  fn_bcm34xx_serial_write32_register_8080c194_candidate
80074ab4  fn_bcm3422_serial_write_bytes_80074ab4_candidate
80074ca0  fn_bcm3422_serial_write_one_byte_80074ca0_candidate
80074cd4  fn_bcm3422_serial_read_bytes_80074cd4_candidate
```

Do not keep `fn_bcm3422_serial_block_init_or_reset_8080c2a8` as a function. Convert it to:

```text
8080c2a8  LAB_bcm34xx_serial_program_5byte_write_command_8080c2a8
```

## 8. Datatype updates

Use fixed-width integer types for structures/globals and volatile MMIO types for hardware registers.

### `/tc7200u/common`

```c
typedef void bcm_periph_irq_handler_fn_candidate(uint32_t handler_arg);

typedef struct bcm_periph_irq_handler_entry_candidate {
    bcm_periph_irq_handler_fn_candidate *handler_00;
    uint32_t handler_arg_04;
} bcm_periph_irq_handler_entry_candidate;
```

Apply `bcm_periph_irq_handler_entry_candidate[?]` conceptually at:

```text
81743214
```

Do not force a fixed full array length yet unless a table extent is proven.

### `/tc7200u/mmio`

```c
typedef volatile uint32_t vuint32_t;
```

Parent bank:

```c
typedef struct tc7200_periph_irq_im5_parent_bank_candidate {
    vuint32_t mask_or_enable_00;
    vuint32_t status_or_pending_04;
} tc7200_periph_irq_im5_parent_bank_candidate;
```

Apply at:

```text
b4e00050
```

Child bank:

```c
typedef struct tc7200_periph_irq_child_bank_candidate {
    undefined field_00[8];
    vuint32_t status_or_pending_08;
    vuint32_t mask_or_enable_0c;
} tc7200_periph_irq_child_bank_candidate;
```

Do not apply globally yet. First inspect the table at `81745b14` to identify concrete child-bank bases.

BCM34xx serial register block:

```c
typedef struct tc7200_bcm34xx_serial_regs_candidate {
    vuint32_t ctrl_000;
    vuint32_t register_index_or_div_004_candidate;
    vuint32_t cmd_byte0_low_008_candidate;
    vuint32_t cmd_byte1_00c_candidate;
    vuint32_t cmd_byte2_010_candidate;
    vuint32_t cmd_byte3_high_014_candidate;
    vuint32_t config_018_candidate;
    vuint32_t config_01c_candidate;
    vuint32_t config_020_candidate;
    vuint32_t transfer_len_024;
    vuint32_t opcode_028;
    vuint32_t cmd_status_02c;
    vuint32_t read_fifo_030;
} tc7200_bcm34xx_serial_regs_candidate;
```

Apply at:

```text
b4e00e00
```

### `/tc7200u/stage1/wait_sync` or `/tc7200u/common`

The BCM34xx serial helper uses a recursive/owned access lock. Provisional structure:

```c
typedef struct bcm34xx_serial_access_lock_candidate {
    uint32_t recursion_count_00;
    uint32_t waiter_count_04;
    void *owner_context_08_candidate;
    stage1_bcm_sem_candidate *semaphore_0c;
} bcm34xx_serial_access_lock_candidate;
```

Global pointer:

```text
8173ee0c  g_bcm34xx_serial_access_lock_ptr_8173EE0C_candidate
```

Type:

```c
bcm34xx_serial_access_lock_candidate *
```

Default serial control word:

```text
8173f8f0  g_bcm3422_serial_ctrl_default_8173F8F0_candidate
```

Type:

```c
uint32_t
```

Comment:

```text
Default BCM34xx serial control word loaded before programming {@address b4e00e00}.
Observed image value: 0x000000c0.
```

## 9. Memory block updates

No new memory block is needed.

Keep these inside the existing peripheral KSEG1 block:

```text
MMIO_PERIPH_INTC_KSEG1_B4E00000_TO_B4E00FFF
```

Subregions now classified:

```text
b4e00050-b4e00057  CP0 IM5 peripheral parent IRQ mask/status pair
b4e00e00-b4e00e3f  BCM34xx / BCM3422 serial-access register sub-block
```

Do not split `b4e00e00` into a separate memory block unless readability becomes a problem. The current block already preserves the correct KSEG1 peripheral mapping.

## 10. Result for IRQ13 investigation

This pass does not yet identify the final GENET/GMAC child handler, but it gives a concrete path to find it.

Current chain:

```text
Linux IRQ13 / periph_mask 0x00002000
  -> candidate parent bit 13
  -> OEM group id 0x30 / decimal 48
  -> handler table group base 81746214
  -> child entries at 81746214 + child_bit * 8
  -> child bank base from 81745b14 + parent_bit * 4
  -> child status/mask at child_base|0x1000 + 0x08/+0x0c
```

Open questions:

```text
1. What is the child-bank base for parent bit 13?
2. Which child bit is active under parent bit 13 during the GENET flood?
3. Which registered handler corresponds to the GENET/GMAC/UniMAC source?
4. Does the OEM handler clear a child source, parent source, or both?
5. Does OpenWrt need a parent-bank mask/ack wrapper around bcmgenet_isr0?
```

## 11. Next Ghidra targets

Highest priority:

```text
81745b14-81745b60
```

Purpose:

```text
Read the parent-bit -> child-bank base table.
Entry for parent bit 13 is:
  81745b14 + 13 * 4 = 81745b48
```

Then inspect the parent bit 13 handler group:

```text
81746214-81746314
```

Purpose:

```text
Group id 0x30 handler entries.
Each child entry is 8 bytes:
  +0x00 handler pointer
  +0x04 handler argument
```

Paste the outer function around the registration block:

```text
80860240-80860390
```

Purpose:

```text
Recover the argument model:
  sp[0] = group_id
  sp[1] = child/sub id
  s1 = handler function
  s2 = handler argument
```

Then inspect all function pointers stored in the `0x30` group and prioritize names/callers containing:

```text
enet
gmac
genet
unimac
mac
phy
dma
mib
irq
interrupt
```

## 12. Next OpenWrt-side test guidance

Do not add a clear/ack write yet.

The next safe kernel probe should only snapshot and rate-limit:

```text
- parent b4e00050 mask/enable
- parent b4e00054 status/pending
- candidate child-bank base for parent bit 13
- child +0x08 status/pending
- child +0x0c mask/enable
- GENET INTRL2 stat/mask pair saved once into locals before printing
```

Important rules:

```text
- Do not combine IRQ13 with DMA/FPM changes.
- Do not blindly enable or clear parent bits.
- Do not trust raw GENET log values unless the probe snapshots coherent locals.
- Do not treat DQM/FPM 0x40000000 token/event flags as proof of peripheral IRQ bit30.
```

## 13. Commit plan

Place this file at:

```text
records/reverse/2026-06-21-bcm-periph-irq-im5-ghidra-log.md
```

Suggested commit message:

```text
reverse: document BCM peripheral IRQ IM5 dispatcher
```

Suggested WSL command after downloading this file to `C:\Users\mgta29\Downloads\`:

```sh
cd ~/tc7200u-research; install -D -m 0644 /mnt/c/Users/mgta29/Downloads/2026-06-21-bcm-periph-irq-im5-ghidra-log.md records/reverse/2026-06-21-bcm-periph-irq-im5-ghidra-log.md; git status --short --branch; git add records/reverse/2026-06-21-bcm-periph-irq-im5-ghidra-log.md; git diff --cached --name-status; git commit -m "reverse: document BCM peripheral IRQ IM5 dispatcher"
```

Do not push unless explicitly requested.
