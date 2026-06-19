# 2026-06-19 GENET TXDUMP confirms TDMA/ring stuck after fixed-link TX

## Scope

This records the repaired BCMGENET debug run with:

- `996-bcmgenet-tc7200u-xmit-desc-debug.patch`
- repaired `997-bcmgenet-tc7200u-timeout-dump-debug.patch`

The goal was to inspect TX descriptor state and timeout-time TDMA/ring state after BCMGENET fixed-link reaches `eth0`.

## Runtime result

BCMGENET still probes and fixed-link reports carrier:

```text
bcmgenet 12c00000.ethernet: configuring instance for external RGMII (no delay)
bcmgenet 12c00000.ethernet eth0: Link is Up - 1Gbps/Full - flow control off
The TX path queues real frames before the watchdog:

TC7200U XMITDESC i=0 nr_frags=0 size=194 mapping=0x06e22002 len_stat=0x00c26fc0 bd_addr=b2c03000 ring=0 write_ptr=1 prod=0 free=256
TC7200U XMITDESC i=0 nr_frags=0 size=150 mapping=0x068f2282 len_stat=0x00966fc0 bd_addr=b2c03008 ring=0 write_ptr=2 prod=1 free=255
TC7200U XMITDESC i=0 nr_frags=0 size=194 mapping=0x06e23802 len_stat=0x00c26fc0 bd_addr=b2c03010 ring=0 write_ptr=3 prod=2 free=254

Then the TX watchdog fires:

NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out

Timeout dump pattern:

TC7200U TXDUMP timeout_entry periph_stat=0x40030004 periph_mask=0x00002000 intr0_stat=0xffffffea intr0_mask=0x8680dcb4 intr1_stat=0x0000009a intr1_mask=0x80a2cce8 tdma_ctrl=0x00003000 tdma_stat=0x00000800 sw_prod=0 sw_c=0 hw_p=0 hw_c=14340 free_bds=0 clean=0 write=0
TC7200U TXDUMP timeout_exit  periph_stat=0x40030004 periph_mask=0x00002000 intr0_stat=0x00000000 intr0_mask=0x00000000 intr1_stat=0x0000009b intr1_mask=0x00000000 tdma_ctrl=0x00003000 tdma_stat=0x00000800 sw_prod=0 sw_c=0 hw_p=0 hw_c=14340 free_bds=0 clean=0 write=0

Repeated timeouts keep the same pattern:

tdma_ctrl=0x00003000
tdma_stat=0x00000800
hw_p=0
hw_c=14340
free_bds=0
clean=0
write=0

After timeout/reclaim, new XMITDESC logs show impossible software ring counters:

prod=17920
free=65792
Interpretation

The TX descriptor write path is alive: descriptors are written and bd_addr advances by 8 bytes on initial queueing.

The TDMA consume/completion path is still not alive.

The value hw_c=14340 equals 0x3804, which is address/offset-shaped and suspicious as a consumer index. This suggests the debug read or upstream ring/index model may not match this BCM3383 hardware path.

The current failure is not:

missing BCMGENET driver
missing DTS node
missing fixed-link
missing IRQ allocation
switch/B53 wiring
MDIO topology

The active blocker remains:

GENET/TDMA descriptor format or width
TDMA ring register layout
DMA address/window translation
BCM3383-specific GMAC/MBDMA/FPM initialization
Next action

Move to the narrow kernel-side descriptor-width branch already identified in the project notes:

keep GENET base 0x12c00000
keep fixed-link RGMII
keep no B53/DSA/MDIO child
keep parent IRQ masks untouched
test temporary GENET_V1 words_per_bd from 2 to 3
compare XMITDESC, TXDUMP, and TDMA/ring state after one watchdog

Do not apply switch/B53/MDIO changes until TDMA consumes descriptors.
