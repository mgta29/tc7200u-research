# TC7200.U GENET + MDIO diagnostic result

## Image result

- CFE accepted wrapped a825 initramfs image.
- Kernel booted to OpenWrt userspace.
- GENET at 0x12c00000 still probes.
- DT now contains mdio@600 under ethernet@12c00000.
- Runtime confirms /proc/device-tree/ubus/ethernet@12c00000/mdio@600 exists.

## Important dmesg

- bcmgenet 12c00000.ethernet: GENET 1.0 EPHY: 0x0000
- bcmgenet: Invalid GPHY revision detected: 0x0000
- unimac-mdio unimac-mdio.-19: Broadcom UniMAC MDIO bus
- bcmgenet 12c00000.ethernet: configuring instance for external RGMII (no delay)
- eth0: Link is Up - 1Gbps/Full
- eth0: NETDEV WATCHDOG: transmit queue 0 timed out
- eth0: Link is Down

## Runtime counters

/proc/net/dev showed:

- RX packets: 0
- TX packets: 12
- TX errors: 7
- TX dropped: 1

## Interrupt observation

/proc/interrupts showed no visible GENET interrupt line while booted.

Only serial IRQ was visible:

- periph_intc@14e00048 interrupt 2: 14e00500.serial

ERR count was high.

## Conclusion

The GENET + MDIO node is accepted and boots, but TX still times out.
The next blocker is likely GENET IRQ/DMA completion or missing vendor init/pinmux, not simple MDIO-node absence.
