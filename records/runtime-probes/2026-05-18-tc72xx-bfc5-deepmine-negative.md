# 2026-05-18 — TC72XX BFC5 deep mining result

## Summary

Deep mining of:

```text
~/src/tc72xx-bfc5

did not produce useful BCM3383/BCM3384 Ethernet, GENET, GMAC, UNIMAC, TDMA, RDMA, DQM, FPM, or SEGDMA evidence.

Generated output directory:

records/generated/tc72xx-bfc5-deepmine-2026-05-18
Output sizes
source-net-register-hits.txt          344 lines
object-strings-net-register-hits.txt  148 lines
mips-elf-symbol-hits.txt               50 lines
Findings

source-net-register-hits.txt contains false positives only:

ENETDOWN / ENETUNREACH from generic errno/manpage files
generic eCos RedBoot net/enet.c
SH/ARM/V850 HAL DMA examples
audio sample constants matching 0x12c* / 0x3c44 accidentally

object-strings-net-register-hits.txt contains only toolchain/library false positives:

fpmul from libgcc/libm/libc
ENETDOWN / ENETUNREACH / ENETRESET from libiberty/libc

mips-elf-symbol-hits.txt contains only startup/toolchain symbols:

_init
hardware_init_hook
software_init_hook
init
finitef
Conclusion

The BFC5 eCos source drop is not useful for the TC7200.U GENET/TDMA blocker.

It appears to be mostly generic eCos source plus an eCos MIPS toolchain. It does not include the proprietary Broadcom cable-gateway Ethernet implementation or BCM3383/BCM3384 register definitions needed for the current OpenWrt direct GENET work.

Action

Do not spend more time mining tc72xx-bfc5 for Ethernet.

Continue with the OpenWrt test chain:

9990 = v2 DMA regmap useful
9991 = standard descriptor format after v2 regmap
next if 9991 fails = descriptor-size / high-word / 16-byte descriptor handling

Keep the separate LxG1 conclusion:

TC72XX LxG1 suggests vendor BCM3384 Ethernet may use VENET + FPM/DQM + SEGDMA/UNIMAC/IOP,
but BFC5 does not expose that layer either.
