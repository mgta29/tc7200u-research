# TC7200.U GENET extended periph IRQ evidence

Date: 2026-05-17

## Context

GENET at `0x12c00000` still probes, reports fixed-link RGMII up, queues TX,
and times out because TDMA does not consume ring16 descriptors.

The current TX timeout state remains:

```text
tdma_ctrl=0x00020001 tdma_stat=0x00000000
r16_read=0x00000000 r16_cons=0x00000000 r16_prod=0x00000001
r16_write=0x00000000 desc0_len=0x000e00d6 desc0_addr=0x00080000
sw_prod=1 sw_c=0 hw_p=1 hw_c=0 free_bds=255 clean=0 write=1
```

Reserved low TX buffer tests at physical `0x01680000` also left `hw_c=0`, so
normal high RAM DMA mapping is not the only blocker.

## RGMII OOB control write did not latch

Test:

```text
ip link set eth0 down
devmem 0x12c0008c 32
0x00000001
devmem 0x12c0008c 32 0x00010050
devmem 0x12c0008c 32
0x00000001
ip link set eth0 up
sleep 3
devmem 0x12c0008c 32
0x00000001
```

Result:

- The write to `0x12c0008c` did not persist.
- TX timeout state did not improve.
- Do not use generic `EXT_RGMII_OOB_CTRL` pokes as the next branch.

## Extended periph interrupt evidence

With `eth0` down:

```text
devmem 0x14e00338 32
0x3000007D
devmem 0x14e0033c 32
0x045A0409
devmem 0x14e00350 32
0x00000000
devmem 0x14e00354 32
0x00000000
devmem 0x12c00808 32
0x10000108
devmem 0x12c00844 32
0x00000002
devmem 0x12c00b3c 32
0x00000000
```

After `ip link set eth0 up; sleep 3`:

```text
devmem 0x14e00338 32
0x3000007D
devmem 0x14e0033c 32
0x045A0409
devmem 0x14e00350 32
0x00000000
devmem 0x14e00354 32
0x00000000
devmem 0x12c00844 32
0x00000002
devmem 0x12c00b3c 32
0x00000000
```

Interrupt counters with the pre-override DTS:

```text
           CPU0
 16:          0  periph_intc@14e00048  16  eth0
 17:          0  periph_intc@14e00048  17  eth0
```

Interpretation:

- `0x14e0033c` is active while the inherited `PeriphIRQ3_2` status at
  `0x14e00354` is zero.
- OEM `bchp_int_ext_per.h` names `PeriphIRQ0_2` bit 0 as `UNI_DMA_IRQ` and bit
  2 as `UNI0_IRQ`.
- The active mask/status pair for UniMAC0 appears to be:
  - mask: `0x14e00338 = 0x3000007D`
  - status: `0x14e0033c = 0x045A0409`
- The current DTS maps GENET to hwirqs `16/17`, but those counters remain zero.

## OpenWrt test branch

The current DTS test branch exposes `PeriphIRQ0_2` as an additional
`periph_intc` word while preserving inherited word order, then maps GENET to:

```dts
interrupts = <64>, <66>;
```

Expected boot checks:

1. Confirm `/proc/interrupts` shows eth0 on hwirqs `64` and `66`, not `16` and
   `17`.
2. Bring eth0 up and check whether the interrupt counters move.
3. Check whether TDMA consumer/read/write pointers finally advance.
4. If the console freezes or storms, the extended source is probably asserted
   but not acknowledged by the generic GENET ISR path.
5. If interrupts count but `hw_c` remains `0`, the IRQ route is fixed but DMA
   fetch/window/init is still the blocker.

## Guardrails

- Do not repeat long pasted ATW register loops over serial; the captured command
  line was corrupted and the `0x103b93xx=0x1` results are not trustworthy.
- Do not overinterpret the RAWBUF dump on GENET v1. Several guessed RBUF/TBUF
  offsets read pointer-like values such as `0xb2c00000` and `0x8680dbe8`.
- Do not repeat blind parent IRQ enables for legacy hwirqs `16/17`.
