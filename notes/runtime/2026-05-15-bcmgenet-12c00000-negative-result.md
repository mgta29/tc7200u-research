# TC7200.U runtime: bcmgenet 12c00000 negative result

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

## Summary

A test image booted OpenWrt userspace with a bcmgenet Ethernet node at `12c00000` instead of the earlier `14e01000` bcm6368-enetsw path.

Result:
- Kernel boots to OpenWrt shell.
- `bcmgenet 12c00000.ethernet` probes.
- `eth0` is created.
- UniMAC MDIO bus appears.
- Link stays down.
- Ping over eth0 fails with 100% packet loss.
- `/proc/interrupts` shows no Ethernet IRQ.
- Later runtime shows memory/page-table corruption and RCU stalls, so this image is not a stable baseline.

## Important boot evidence

```text
bcmgenet 12c00000.ethernet: GENET 1.0 EPHY: 0x0000
bcmgenet: Invalid GPHY revision detected: 0x0000
unimac-mdio unimac-mdio.-19: Broadcom UniMAC MDIO bus
bcmgenet 12c00000.ethernet: configuring instance for internal PHY
bcmgenet 12c00000.ethernet eth0: Link is Down

/proc/iomem:
12c00000-12c03fff : 12c00000.ethernet ethernet@12c00000
  12c00e14-12c00e1c : unimac-mdio.-19
14e00500-14e00517 : 14e00500.serial serial@14e00520

/proc/interrupts:
  7: timer
  8: periph_intc@14e00048 2 14e00500.serial
ERR: 9698

ip addr add 192.168.77.1/24 dev eth0
ip link set eth0 up
ping -I eth0 -c 3 -W 1 192.168.77.2
3 packets transmitted, 0 packets received, 100% packet loss

mm/pgtable-generic.c:54: bad pgd
WARNING at mm/memory.c:3993 do_swap_page
get_swap_device: Bad swap file entry
rcu_sched detected stalls
Interpretation

This is not a successful Ethernet path.

The 12c00000 GENET path is useful evidence because it proves a GENET-compatible node can bind and expose UniMAC MDIO, but it currently reads invalid PHY/GPHY data (0x0000), has no delivered Ethernet IRQ, keeps link down, and later destabilizes the kernel.

Do not use this as the new baseline.

Next direction
Preserve the serial log for comparison.
Do not flash.
Compare this DTS against the previous stable 14e01000 enetsw DTS.
Investigate why GENET has no IRQ in /proc/interrupts.
Investigate whether internal PHY is wrong for this board and whether external switch/MDIO/B53 wiring is required.
Treat Kernel sections are not in the memory maps and later bad pgd as serious memory-map/load-address warnings before further GENET testing.

