# TC7200.U GMAC init + GENET fixed-link test

Date: 2026-05-16

Scope: RAM boot only. Do not flash.

Changes tested:
- Added TC7200U-specific BMIPS quirk for BCM3383 GMAC pinmux/clock/reset init.
- Ported vendor bcm3383_pinmux_select(10): GPIO mux register 0x14e001c0, mask 0x00038000, value 0x00028000.
- Ported vendor bcm3383_init_gmac clock/reset sequence: soft_resetb_low bits 6/8, clk_ctrl_low bit 6, clk_ctrl_high bit 8, 200 ms delay.
- Added temporary GENET fixed-link node at 0x12c00000 with RGMII fixed-link 1000/full.

Boot result so far:
- CFE TFTP completed.
- Wrapped image loaded and executed.
- OpenWrt BMIPS loader reached: Decompressing kernel...

Next result needed:
- Capture whether it reaches Starting kernel / OpenWrt shell, or freezes after decompression.
