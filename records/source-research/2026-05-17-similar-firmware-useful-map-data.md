# Similar Firmware Useful Map Data

Date: 2026-05-17.

Source trees inspected:

- `/home/mgta29/src/linux-technicolor-tc7200`
- `/home/mgta29/src/TC72XX_LxG1.0.10mp5_OpenSrc`
- `/home/mgta29/src/tc72xx-oem-lxg1`

The two TC72XX OEM trees are effectively the same Broadcom 93383/TC72XX family
codebase for the mapping questions here. The Technicolor Linux tree is more
useful for DTS shape; the OEM trees are more useful for KSEG1 constants,
interrupt-bank layout, boot/link addresses, and flash behavior.

## Build Identities

Relevant target profiles in the OEM trees:

- `93383LxG`: `BRCM_3383=y`, `BRCM_CHIP=3383`,
  `BRCM_BOARD_ID=93383LxG`, squashfs root.
- `93383LxGNand`: same chip and board ID, `DEFCONFIG_EXT=3383Nand`,
  UBIFS root/apps, 128 KiB block, 2 KiB page NAND profile.
- `93383APRouter`: same chip and board ID, `DEFCONFIG_EXT=3383APRouter`.
- `93383LxGTP1` / `93383LxGTP1Nand`: same family with board ID
  `93383LxGTP1`.

The normal OEM profile explicitly disables the classic Broadcom Ethernet and
VLAN selections. The included VENET driver is an IPC/DQM path to firmware/eCos,
not a direct OpenWrt GENET driver match.

## RAM And Link Addresses

OEM `kernel/linux/arch/mips/bcm9338x/Kconfig` sets:

- `CONFIG_MIPS_BRCM_TEXT = 0x84010000` for `BCM93383`.

OEM 93383 setup defines:

- `CM_SDRAM_SIZE = 0x04000000`
- `CM_SDRAM_BASE = 0x04000000`
- non-ramdisk reserved size `0x00200000`
- Linux RAM added as `add_memory_region(0x04000000, 0x03e00000, BOOT_MEM_RAM)`

Current TC7200.U wrapper evidence still says the RAM-boot payload is loaded at
`0x82000000`, backing physical `0x02000000`. So there are two distinct address
models:

- Observed CFE/OpenWrt RAM boot: `0x82000000`.
- OEM 93383 Linux reference: `0x84010000` with RAM starting at `0x04000000`.

Do not mix these blindly. The OEM layout likely reflects a split cable-modem
environment where Linux runs above a lower firmware/DOCSIS region.

## MMIO Constants

OEM `3383_map_part.h` maps these blocks:

| Block | Physical | OEM KSEG1 |
| --- | ---: | ---: |
| interrupt controller | `0x14e00000` | `0xb4e00000` |
| UART0 | `0x14e00500` | `0xb4e00500` |
| UART1 | `0x14e00520` | `0xb4e00520` |
| HSSPI | `0x14e01000` | `0xb4e01000` |
| EHCI | `0x12e00000` | `0xb2e00000` |
| OHCI | `0x12e00100` | `0xb2e00100` |
| USB control | `0x12e00200` | `0xb2e00200` |
| NAND regs | `0x14e02200` | `0xb4e02200` |
| NAND cache | `0x14e02600` | `0xb4e02600` |
| IO processor | `0x16000000` | `0xb6000000` |

It also defines `LtoP(x) = x & 0x1fffffff`, which is directly relevant for
debugging descriptor DMA addresses.

## DTS Evidence

Technicolor/OpenWrt-adjacent DTS evidence:

- `bcm3383.dtsi` maps `spi@14e01000` as `brcm,bcm6328-hsspi`.
- `bcm3383.dtsi` maps `nand@14e02200` with cache at `0x14e02600`.
- `bcm3383.dtsi` maps `ethernet@12c00000` as `brcm,genet-v1`,
  interrupts 16/17 through `periph_intc`, `phy-mode = internal`.
- `bcm3383_viper.dtsi` maps a different Ethernet node at `0x12c02600`,
  interrupt 26, `phy-mode = rgmii`.
- The TC7200 Viper board file sets RAM to `0x00000000 0x08000000`, enables
  UART/EHCI/SPI/NAND, and has fixed NAND partitions.

The Viper `0x12c02600` Ethernet mapping is a clue, not enough to override the
current TC7200.U runtime evidence at `0x12c00000`.

## Interrupt Evidence

OEM `3383_intr.h` uses `INTERNAL_ISR_TABLE_OFFSET = 8`, then:

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

OEM `3383_map_part.h` lays out the interrupt controller registers and aliases
`IrqMask` / `IrqStatus` to `PeriphIrq[0]` for `CONFIG_BCM93383`.

This matters because the current OpenWrt DTS has used `periph_intc@14e00048`,
which corresponds to `PeriphIrq[3].iMask`. Blindly enabling GENET parent bits
16/17 there caused an IRQ storm. The next interrupt work should be status-first
bank identification, not broad mask writes.

## Flash Evidence

OEM NAND profile:

- `BRCM_KERNEL_ROOTFS=ubifs`
- `BRCM_NANDFLASH_BLOCK_SIZE=131072`
- `BRCM_NANDFLASH_PAGE_SIZE=2048`
- `BRCM_NANDFLASH_PAD_SIZE=100`
- apps image is built as a `linuxapps` UBI volume with `autoresize`.

Runtime init script:

- On 3383-style systems, `/apps` is mounted from `ubi1:linuxapps` when UBIFS is
  active.
- If not UBIFS, `/apps` falls back to `/dev/mtdblock4` as JFFS2.

OEM `vflash.c`:

- Reads a bootloader flash map from `FLASH_MAP_RAM_OFFSET`.
- Copies `NUM_FLASH_PARTITIONS` entries from that RAM map.
- For NAND, only exposes rootfs and apps MTD partitions.
- Subtracts erase/fetch slack from exposed NAND rootfs/apps partitions.

This argues for read-only bootloader map discovery before writing any static
OpenWrt partition table.

## Ethernet/DQM Evidence

The OEM VENET/DQM objects for 3383 contain strings for:

- `bcmvenet`
- `DQM_ITC_DATA_RX_Q` / `DQM_ITC_DATA_TX_Q`
- `DQM_ITC_CTL_RX_Q` / `DQM_ITC_CTL_TX_Q`
- `Can not send DQM msg!`
- `IOP IrqMask` / `IOP IrqStatus`
- remote switch read/write API strings.

That means the OEM network path is heavily firmware/IOP/DQM mediated. It is
useful for DQM/interrupt clues but is not a direct replacement for OpenWrt's
GENET bring-up.

## Immediate Porting Advice

- Keep `0x14e01000` classified as HSSPI. It is not the Ethernet block.
- Keep GENET testing focused on `0x12c00000` until a runtime probe disproves
  it.
- Treat `0x12200000` `BCM3383_GMAC0_BASE` as clock/reset/pinmux evidence, not
  proof of the packet DMA register window.
- Add a status-only IRQ bank probe for `PeriphIrq[0..3]` before any new GENET
  interrupt enabling.
- Log descriptor CPU virtual, DMA physical, `len_stat`, producer index, and
  consumer index together in the next TX experiment.
- Keep NAND/MTD read-only and first try to discover the bootloader flash map
  semantics rather than hardcoding the OEM runtime partition view.
