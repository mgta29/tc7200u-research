# CS_SELECT test invalid: kernel panic before NAND result

## Result

A RAM/TFTP image booted but panicked before OpenWrt shell.

Expected debug line was not observed:

```text
tc7200u: force CS_SELECT
Expected NAND probe line was also not observed:

bcm6368_nand 14e02200.nand

Instead, SPI/HSSPI probed:

spi-nor spi0.0: unrecognized JEDEC id bytes: e1 10 0a 61 10 0a
bcm63xx-hsspi 14e01000.spi: Broadcom 63XX High Speed SPI Controller driver

Then kernel panic occurred:

Unhandled kernel unaligned access
epc: inode_init_always_gfp
Kernel panic - not syncing: Fatal exception
Conclusion

This boot is not valid evidence for or against the NAND CS_SELECT hypothesis. The image/tree baseline appears wrong or broken. Do not repeat this image. Restore a known-good booting baseline before retesting NAND.

Safety: RAM/TFTP only. No flash writes.
