# 2026-05-18 — linux-technicolor-tc7200 Viper GENET findings

## Summary

Mining `~/src/linux-technicolor-tc7200` produced useful TC7200-specific evidence.

The tree contains actual TC7200 support commits:

```text
3fe5f69e3208 bmips: add Technicolor TC7200 support
71fb5d9de30b bmips: add Technicolor TC7200 support
88a5b8ec5f45 bmips: add Technicolor TC7200 support
GENET layout split

The old tree has two BCM3383 layouts:

bcm3383.dtsi:
  ethernet@12c00000
  compatible = "brcm,genet-v1"
  reg = <0x12c00000 0x4000>
  interrupts = <0 16 0>, <0 17 0>

bcm3383_viper.dtsi:
  ethernet@12c02600
  compatible = "brcm,genet-v1"
  reg = <0x12c02600 0x2000>
  interrupts = <26>

The old README/boot log identifies the machine as Technicolor TC7200 Viper, making the Viper GENET base 0x12c02600 important.

GMAC init quirk

arch/mips/bmips/setup.c contains bcm3383_init_gmac() and calls it during BCM3383 quirks.

The old init sequence toggles GMAC-related reset and clock bits:

soft_resetb_low bits 6 and 8
clk_ctrl_low bit 6
clk_ctrl_high bit 8
clk_ctrl_low bits 1, 6, 8, 11
clk_ctrl_ubus bit 8
pinmux_select(10)

It also has a broad clock-enable fallback:

clk_ctrl_low = 0xf636f04b
clk_ctrl_high = 0xff
clk_ctrl_ubus = 0x7ffff
Impact

Before continuing descriptor-width/high-word tests, test the Viper GENET base geometry against OpenWrt:

reg = <0x12c02600 0x2000>

Do this as a controlled DTS-only test first, keeping the currently useful IRQ mapping unchanged. If that fails, test the old Viper IRQ style separately.
