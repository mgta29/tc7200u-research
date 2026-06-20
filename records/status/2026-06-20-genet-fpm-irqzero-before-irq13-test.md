# 2026-06-20 GENET/FPM control run before IRQ13 DTS branch

## Scope

This log records the TC7200U / BCM3383 OpenWrt image build, boot, Ethernet runtime result, GENET/FPM debug output, interrupt state, and later module-loading panic observed before starting the next proposed DTS-only IRQ13 branch.

This is an additive status/runtime log. No old logs should be deleted. The next IRQ13 test has not yet been applied in this record.

## Image/build result

The helper build/wrap path completed successfully after using `--skip-precheck`, because the prepared Linux tree already contained the local TC7200U patch markers and the precheck was trying to apply the same patches a second time.

Successful helper result:

```text
CHECK OK: size_ok=True
OK: wrapped image matches raw payload and expected header fields
AUTO: ready for cfe-tftp. CFE request: 2026-06-20.bin ; served file: C:\tftp\2026-06-20.bin.
Generated state capture:

records/generated/2026-06-20-143054-current-state.txt

Relevant build logs from this run:

records/logs/builds/2026-06-20-141826-build-provenance.log
records/logs/builds/2026-06-20-141826-ensure-debug-packages.log
records/logs/builds/2026-06-20-141826-openwrt-config-before-debug-packages
records/logs/builds/2026-06-20-141826-openwrt-config-after-debug-packages
records/logs/builds/2026-06-20-141826-patch-precheck.log
records/logs/builds/2026-06-20-142737-build-provenance.log
records/logs/builds/2026-06-20-142737-ensure-debug-packages.log
records/logs/builds/2026-06-20-142737-openwrt-config-before-debug-packages
records/logs/builds/2026-06-20-142737-openwrt-config-after-debug-packages
records/logs/builds/2026-06-20-142737-target-linux-install.log
records/logs/builds/2026-06-20-142737-wrap.log
records/logs/builds/2026-06-20-142737-verify.log

Patch repair backup from the same work window:

records/backups/patch-repair-20260620-141716/
Boot result

The image booted far enough to load the BCMGENET driver and bring eth0 up.

Important boot markers:

irq_bcm7120_l2: registered BCM3380 L2 intc (/ubus/periph_intc@14e00048, parent IRQ(s): 1)
14e00500.serial: ttyS0 at MMIO 0x14e00500 (irq = 8, base_baud = 1687500) is a bcm63xx_uart
bcmgenet 12c00000.ethernet: GENET 1.0 EPHY: 0x0000
bcmgenet: Invalid GPHY revision detected: 0x0000
bcmgenet 12c00000.ethernet: using random Ethernet MAC
bcmgenet 12c00000.ethernet: unable to find MDIO bus node
bcmgenet 12c00000.ethernet: configuring instance for external RGMII (no delay)
bcmgenet 12c00000.ethernet eth0: Link is Up - 1Gbps/Full - flow control off
Ethernet runtime result

The run did not fix packet movement.

Observed behavior:

eth0 reaches UP,LOWER_UP.
Link reports 1Gbps/Full.
TX descriptors are queued by bcmgenet.
NETDEV WATCHDOG repeats.
TX completion does not occur.
RX is not shown as working.
ping 192.168.77.2 failed with Network unreachable, because no IPv4 route/address was configured during that command window.

Representative TX descriptor logs:

TC7200U XMITDESC i=0 nr_frags=0 size=154 mapping=0x06d85002 len_stat=0x009a6fc0 bd_addr=b2c03000 ring=0 write_ptr=1 prod=0 free=256
TC7200U XMITDESC i=0 nr_frags=0 size=154 mapping=0x06d84802 len_stat=0x009a6fc0 bd_addr=b2c03008 ring=0 write_ptr=2 prod=1 free=255

Representative watchdog log:

NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out

Representative timeout dump:

TC7200U TXDUMP timeout_entry periph_stat=0x40030004 periph_mask=0x00002000 intr0_stat=0xffffffea intr0_mask=0x8680dcb4 intr1_stat=0x00000136 intr1_mask=0x80a2ece8 tdma_ctrl=0x00003000 tdma_stat=0x00000800 sw_prod=0 sw_c=0 hw_p=0 hw_c=14340 free_bds=0 clean=0 write=0
Interrupt result

The useful hard result from this run is that the currently assigned GENET Linux IRQs did not count.

Observed /proc/interrupts after eth0 up:

16:          0  periph_intc@14e00048  16  eth0
17:          0  periph_intc@14e00048  17  eth0

The serial IRQ counted normally:

8:        3396  periph_intc@14e00048   2  14e00500.serial

The debug timeout dump repeatedly showed:

periph_stat=0x40030004
periph_mask=0x00002000

Current interpretation:

IRQ16/17 as currently assigned to eth0 are not receiving/completing interrupts.
periph_mask=0x00002000 is bit 13, which makes a DTS-only IRQ13 test a reasonable next branch.
This does not prove IRQ13 is correct yet; it only proves the current IRQ16/17 branch still has zero eth0 counts during watchdog.
FPM-side result

FPM registers are readable and active-looking.

Stable FPM control values seen repeatedly:

12200010=0x00000000
12200014=0x00000001
12200040=0x06000000
12200044=0x00010000
12200050=0x00000000
12200058=0x00000000
1220005c=0x00000000

12200054 changed monotonically downward during the run:

12200054=0x18007df3
12200054=0x18007de4
12200054=0x18007dd5
12200054=0x18007dc6
12200054=0x18007db7
12200054=0x18007da8

FPM endpoint/token-like reads changed between samples:

12200200=0x80260800
12200208=0x90070400
12200210=0xa0288200
12200218=0xb0080100

Later samples:

12200200=0x802d0800
12200208=0x900ec400
12200210=0xa0292200
12200218=0xb0099100

Current interpretation:

FPM space is readable.
Endpoint/token-like values are live, not fixed constants.
This run still does not show OpenWrt programming the OEM-style GENET/MBDMA values or completing TX.
GENET/GMAC dump caveat

The TC7200U CTRL GMAC offset debug output is suspicious.

Examples:

GMAC_A off0004=0x86d999e0 off0008=0xb2c00000 off000c=0xb2c00000 off0010=0xb2c00000
GMAC_B off0040=0x86d999e0 off0044=0xb2c00000 off0048=0xb2c00000 off004c=0xb2c00000
GMAC_C off0050=0x86d999e0 off0054=0xb2c00000 off0058=0xb2c00000 off0070=0xb2c00000

Current interpretation:

These values look like address/base echo or bad debug-read plumbing, not trustworthy register values.
Do not draw conclusions from the GMAC offset dump until the debug macro/read method is audited.
The IRQ-zero evidence and FPM-side reads are higher-confidence than this GMAC offset dump.
Profile/control block observations

Observed profile/control values:

14e001c4=0xda492010
14e00002=0x00a2
14e00264=0x00000000

Current interpretation:

These values are useful comparison evidence.
They are not yet safe to promote to final driver semantics.
Later panic

A later crash occurred after the Ethernet watchdog evidence was already captured.

Crash marker:

Instruction bus error, epc == 8e03f0f0, ra == 80010244
CPU: 0 PID: 508 Comm: kmodloader
epc: init_module+0x0/0x134 [nf_tables]
Kernel panic - not syncing: Fatal exception

Current interpretation:

This panic is from kmodloader loading nf_tables.
It is not the primary Ethernet root failure.
For the next Ethernet-only branch, disable firewall/nftables module loading early after boot or use a smaller module/package profile if needed.

Suggested runtime avoidance command for next boot:

for f in /etc/modules.d/*nf* /etc/modules.d/*nft* /etc/modules.d/*flow*; do [ -e "$f" ] && mv "$f" "$f.off"; done; /etc/init.d/firewall stop 2>/dev/null || true
Current conclusion before IRQ13 branch

The image is bootable and the GENET debug patch set works well enough to collect evidence.

The active Ethernet blocker remains:

GENET TX descriptors are queued, but TX completion does not happen and eth0 IRQ16/17 stay at zero.

The highest-value next experiment is a narrow DTS-only IRQ mapping test:

change ethernet@12c00000 interrupts from <16>, <17> to <13>, <17>

Rules for the next branch:

do not combine IRQ13 with DMA/FPM changes
do not add B53/DSA
do not reinterpret the suspicious GMAC offset dump until the debug read method is audited
avoid the unrelated nf_tables panic during the Ethernet run
preserve all old serial/build logs
