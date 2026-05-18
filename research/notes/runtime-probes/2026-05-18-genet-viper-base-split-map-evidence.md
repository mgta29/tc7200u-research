# 2026-05-18 — GENET Viper base split-map evidence

## Test

Changed temporary OpenWrt TC7200.U GENET node from:

```dts
ethernet_test: ethernet@12c00000 {
        reg = <0x12c00000 0x4000>;
        interrupts = <64>, <66>;
}

to Viper-style:

ethernet_test: ethernet@12c02600 {
        reg = <0x12c02600 0x2000>;
        interrupts = <64>, <66>;
}

The Viper base was taken from the old linux-technicolor-tc7200 tree, which uses ethernet@12c02600, reg = <0x12c02600 0x2000>, and interrupts = <26> for brcm,genet-v1.

Result

The driver probed at the Viper base:

bcmgenet 12c02600.ethernet: GENET 1.0 EPHY: 0x0c01
bcmgenet 12c02600.ethernet eth0: Link is Up - 1Gbps/Full

IRQ 64 counted:

64: 1460  periph_intc@14e00048  64  eth0
66: 0     periph_intc@14e00048  66  eth0

But TX still watchdogged and RAWDMA/readback logs became invalid/pointer-like.

Manual devmem snapshot:

0x12c00000 0x000012AA
0x12c00004 0x000001FF
0x12c02600 0x00000C01
0x12c02604 0x00000001
0x12c03000 0x000DE37A
0x12c03004 0x00085F4D
0x12c03800 0x00010003
0x12c03804 0x00000028
0x12c03c00 0x00000001
0x12c03c04 0x00000001
0x12c03c08 0x00000001
0x12c03c0c 0x00000001
0x12c03c40 0x00000001
0x12c03c44 0x00000001
0x12c05600 0x00000001
0x12c05604 0x00000001
0x12c05e04 0x00000001
0x12c05e08 0x00000001
0x12c06240 0x00000001
0x12c06244 0x00000001
Interpretation

Pure Viper base 0x12c02600 is not a working OpenWrt bcmgenet resource base.

It exposes a valid identity/SYS/UMAC-looking window:

0x12c02600 = 0x00000C01
0x12c02604 = 0x00000001

but the DMA/ring/descriptor windows derived from that base are wrong or read as 0x00000001.

The evidence now suggests a split map:

0x12c02600: Viper SYS/UMAC identity/link block
0x12c00000 / 0x12c03000 / 0x12c03800: active GENET/DMA-related blocks
Action

Revert the DTS node to:

ethernet_test: ethernet@12c00000 {
        reg = <0x12c00000 0x4000>;
        interrupts = <64>, <66>;
}

Do not test old Viper IRQ <26> yet. The next useful kernel test is a split-map or BCM3383-Viper offset-table experiment.
