# 2026-06-19 GENET/FPM runtime control dump: FPM live, MBDMA unprogrammed

## Scope

This records the runtime control dump after the repaired BCMGENET TX descriptor and TX timeout debug image.

The tested image had:

- fixed-link BCMGENET `eth0`
- `996-bcmgenet-tc7200u-xmit-desc-debug.patch`
- repaired `997-bcmgenet-tc7200u-timeout-dump-debug.patch`

## Runtime behavior

`eth0` still comes up:

```text
bcmgenet 12c00000.ethernet: configuring instance for external RGMII (no delay)
bcmgenet 12c00000.ethernet eth0: Link is Up - 1Gbps/Full - flow control off
TX descriptors are queued:

TC7200U XMITDESC i=0 nr_frags=0 size=214 mapping=0x06e20002 len_stat=0x00d66fc0 bd_addr=b2c03000 ring=0 write_ptr=1 prod=0 free=256
TC7200U XMITDESC i=0 nr_frags=0 size=214 mapping=0x06e21802 len_stat=0x00d66fc0 bd_addr=b2c03008 ring=0 write_ptr=2 prod=1 free=255
TC7200U XMITDESC i=0 nr_frags=0 size=150 mapping=0x068f2a02 len_stat=0x00966fc0 bd_addr=b2c03010 ring=0 write_ptr=3 prod=2 free=254
FPM dump
FPM_A
0x12200010 = 0x00000000
0x12200014 = 0x00000001
0x12200040 = 0x06000000
0x12200044 = 0x00010000

FPM_B
0x12200050 = 0x00000000
0x12200054 = 0x18007EFA
0x12200058 = 0x00000000
0x1220005c = 0x00000000

FPM_C
0x12200200 = 0x80170800
0x12200208 = 0x9008C400
0x12200210 = 0xA01B8200
0x12200218 = 0xB0324100

Interpretation:

FPM register space is readable.
FPM endpoint/token-like values are live.
FPM is not the missing MMIO window.
GENET/MBDMA dump
GMAC_A
0x12c00004 = 0x00000001
0x12c00008 = 0x00000001
0x12c0000c = 0x00000001
0x12c00010 = 0x00000001

GMAC_B
0x12c00040 = 0x00000001
0x12c00044 = 0x00000001
0x12c00048 = 0x00000001
0x12c0004c = 0x00000001

GMAC_C
0x12c00050 = 0x00000001
0x12c00054 = 0x00000001
0x12c00058 = 0x00000001
0x12c00070 = 0x00000001

GMAC_CH1
0x12c00100 = 0x00000001
0x12c00104 = 0x00000001
0x12c00120 = 0x00000001
0x12c00124 = 0x00000001

GMAC_CH2
0x12c00140 = 0x00000001
0x12c00144 = 0x00000001
0x12c00180 = 0x00000001
0x12c00184 = 0x00000001

Interpretation:

OpenWrt is not producing the OEM-like GENET/MBDMA control state.
The frozen expected MBDMA/FPM endpoint values are absent:
0x12c00008 != 0x12200200
0x12c0004c != 0x12200218
0x12c00050 != 0x12200210
0x12c00054 != 0x12200208
0x12c00058 != 0x12200200
0x12c00044 != 0x02020202
0x12c00048 != 0x0000000f
0x12c00070 != 0x00000003/0x00030000
Profile block
PROFILE
0x14e001c4 = 0xDA492010
0x14e00002 = 0x00A2
0x14e00264 = 0x00000000

Interpretation:

board/profile register space is readable.
profile control has nonzero state.
profile/status semantics are still comparison-only.
Current conclusion

The failure is earlier than descriptor width.

Current model:

BCMGENET binds.
fixed-link comes up.
TX descriptors are written.
FPM space is readable/live.
GENET/MBDMA frozen control registers are not programmed into OEM-like state.
TDMA does not consume descriptors and TX watchdog follows.

Do not test words_per_bd yet.

Next development target:

Add read-only kernel-side TC7200U control dump around BCMGENET open/timeout:
FPM: 0x12200040, 0x12200044, 0x12200200/208/210/218
GENET/MBDMA: 0x12c00004/08/0c/10/44/48/4c/50/54/58/70
Then add a minimal TC7200U FPM/MBDMA init patch only after confirming the correct placement.
Keep B53/DSA/MDIO and descriptor-width changes out until GENET/MBDMA control state is OEM-like.
