# TC7200.U Memory Map Notes

Last updated: 2026-05-17.

This page is the working address ledger for BCM3383 / TC7200.U bring-up. Keep
it conservative: only move an address from candidate to current after a
source match or a runtime probe.

## Address Rules

- MIPS cached RAM virtual addresses are normally `0x80000000 + physical`.
- MIPS uncached KSEG1 MMIO addresses are normally `0xa0000000 | physical`.
- OEM headers use KSEG1 MMIO constants such as `0xb4e00500`; the matching DTS
  physical address is `0x14e00500`.
- DMA hardware wants physical addresses. The OEM BCM3383 map defines
  `LtoP(x) = x & 0x1fffffff` and `PtoL(x) = LtoP(x) | 0xa0000000`.

## RAM And Load Addresses

Known CFE/TFTP wrapper evidence for the current OpenWrt RAM boot:

- ProgramStore/A825 payload load address: `0x82000000`.
- This is a KSEG0-style address, so it backs physical `0x02000000`.
- If a kernel image is linked outside the declared RAM window, the boot will
  fail with memory-map warnings before driver work matters.

OEM BCM93383 evidence from the TC72XX source trees:

- `CONFIG_MIPS_BRCM_TEXT` defaults to `0x84010000`.
- The OEM 93383 setup defines `CM_SDRAM_BASE = 0x04000000`.
- It adds RAM as `0x04000000 .. 0x07dfffff` in the non-ramdisk build
  (`64 MiB - 2 MiB reserved`).

OpenWrt TC7200.U evidence:

- The current TC7200-style DTS uses a 128 MiB RAM window in the Viper board
  file.
- Do not blindly copy the OEM `0x04000000` base into OpenWrt. The OEM tree is
  a split cable-modem reference layout with Linux running above a lower
  eCos/DOCSIS area.
- Treat `0x82000000` and `0x84010000` as separate boot/link experiments:
  `0x82000000` matches the observed CFE wrapper, while `0x84010000` matches
  OEM BCM93383 Linux.

## Current MMIO Map

| Block | Physical | OEM KSEG1 | Current use |
| --- | ---: | ---: | --- |
| Interrupt controller | `0x14e00000` | `0xb4e00000` | parent IRQ banks, clocks, resets |
| UART0 | `0x14e00500` | `0xb4e00500` | current serial console path |
| UART1 | `0x14e00520` | `0xb4e00520` | OEM `UART_BASE`, not current console |
| GPIO | `0x14e00100` | `0xb4e00100` | pinmux/GPIO area |
| HSSPI | `0x14e01000` | `0xb4e01000` | SPI, not Ethernet |
| NAND regs | `0x14e02200` | `0xb4e02200` | candidate NAND controller |
| NAND cache | `0x14e02600` | `0xb4e02600` | candidate NAND cache window |
| USB EHCI | `0x12e00000` | `0xb2e00000` | OEM platform device |
| USB OHCI | `0x12e00100` | `0xb2e00100` | OEM platform device, often disabled |
| USB control | `0x12e00200` | `0xb2e00200` | OEM clock/reset setup |
| IO processor | `0x16000000` | `0xb6000000` | DQM/vflash/venet IPC area |
| GENET candidate | `0x12c00000` | `0xb2c00000` | current OpenWrt Ethernet direction |
| GMAC0 header constant | `0x12200000` | `0xb2200000` | clock/reset header evidence only |

## Interrupt Controller Notes

OEM `3383_map_part.h` defines the controller layout from `0x14e00000`:

- `ClkCtrlLow`: offset `0x04`.
- `ClkCtrlHigh`: offset `0x08`.
- `ClkCtrlUBus`: offset `0x0c`.
- `DocsisIrq[3]`: offsets `0x14..0x28`.
- `IntPeriphIrqStatus`: offset `0x2c`.
- `PeriphIrq[0].iMask/iStatus`: offsets `0x30/0x34`.
- `PeriphIrq[1].iMask/iStatus`: offsets `0x38/0x3c`.
- `PeriphIrq[2].iMask/iStatus`: offsets `0x40/0x44`.
- `PeriphIrq[3].iMask/iStatus`: offsets `0x48/0x4c`.
- `IopIrq[0].iMask/iStatus`: offsets `0x50/0x54`.
- `IopIrq[1].iMask/iStatus`: offsets `0x58/0x5c`.
- `PeriphIrqSense`: offset `0x64`.
- `IopIrqSense`: offset `0x68`.
- `IrqOutMask`: offset `0x78`.
- `SoftResetBLow`: offset `0x8c`.
- `SoftResetBHigh`: offset `0x90`.
- `SoftReset`: offset `0x94`.

For `CONFIG_BCM93383`, OEM `IrqMask` / `IrqStatus` aliases use
`PeriphIrq[0]`, not `PeriphIrq[3]`. This is important because the current
OpenWrt DTS path has used `periph_intc@14e00048`; blind parent-bit enables for
GENET bits 16/17 already caused an IRQ storm.

## Peripheral IRQ IDs

OEM `3383_intr.h` uses logical IRQ IDs offset by `8`:

- timer: `8`
- SPI: `9`
- UART0: `10`
- UART1: `11`
- I2C: `14`
- HSSPI: `15`
- PCIe RC: `23`
- USB OHCI: `31`
- USB EHCI: `32`
- UNI IRQ: `33`
- GPHY IRQB: `34`
- DQM IRQ: `43`
- mailbox in/out: `44` / `45`
- MSP IRQ in non-LOT1 builds: `75`

Use these as bank/offset evidence, not as drop-in Linux IRQ numbers.

## Flash And Storage

OpenWrt/Technicolor DTS evidence:

- HSSPI is at `0x14e01000`.
- SPI flash child is compatible with `mx25l8008e`, max frequency `10 MHz`.
- NAND controller is at `0x14e02200`, cache window at `0x14e02600`.
- NAND ECC in the TC7200 DTS snapshot is BCH-4 style:
  `nand-ecc-strength = <4>`, `nand-ecc-step-size = <512>`.

OEM TC72XX NAND profile evidence:

- 93383 NAND profile uses UBIFS root/apps images.
- NAND build profile uses 128 KiB erase blocks and 2 KiB pages.
- `linuxapps` is created as a UBI volume with `autoresize`.
- Runtime rcS mounts `ubi1:linuxapps` at `/apps` when UBIFS is active.
- The virtual flash driver reads a bootloader flash map from RAM before
  creating MTD partitions; do not assume a static OEM partition table is
  complete.

## Ethernet Map Advice

The useful split is:

- `0x14e01000` is HSSPI. Stop testing it as Ethernet.
- `0x12c00000` is the current GENET candidate and has runtime evidence:
  fixed-link up, real TX frame queued, descriptor RAM populated.
- `0x12c02600` appears in the Viper DTS as a different GENET mapping. Treat it
  as a separate SoC/profile clue, not proof for TC7200.U.
- `0x12200000` appears as `BCM3383_GMAC0_BASE` in OpenWrt headers. Use it for
  clock/reset/pinmux context, but do not collapse it with GENET until a runtime
  probe proves the relationship.

Current Ethernet blocker is descriptor/DMA behavior: TDMA is enabled but does
not consume the queued descriptor. Focus next on GENET v1 descriptor ownership,
TDMA/RDMA offsets, DMA address translation, and interrupt bank mapping.

## Fast Development Process

Use this sequence to avoid repeating slow dead ends:

1. Start from this memory map before changing DTS `reg` or `interrupts`.
2. Convert all OEM KSEG1 constants to physical DTS addresses explicitly.
3. Keep a small runtime probe for every new candidate: read ID/status, write
   only documented clear/set bits, and log before/after values.
4. For RAM boot changes, check both the CFE wrapper load address and the kernel
   link address before testing drivers.
5. For DMA bugs, log CPU virtual, physical DMA, descriptor address, and
   producer/consumer index in the same boot.
6. Do not enable broad interrupt masks while debugging Ethernet; prove the bank
   and bit with status-only reads first.
7. Keep flash work read-only until Ethernet and the boot memory window are no
   longer moving targets.
