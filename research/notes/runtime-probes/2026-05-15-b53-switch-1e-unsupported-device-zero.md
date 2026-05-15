# TC7200.U B53 switch@1e diagnostic result

## Result

The B53/DSA test image booted to OpenWrt userspace.

Device tree contained:

- ethernet@12c00000
- mdio@600
- switch@1e
- compatible = "brcm,bcm53125"

## Important dmesg

- bcmgenet 12c00000.ethernet: GENET 1.0 EPHY: 0x0000
- bcmgenet: Invalid GPHY revision detected: 0x0000
- bcmgenet 12c00000.ethernet: using random Ethernet MAC
- bcm53xx unimac-mdio--19:1e: Unsupported device: 0x00000000
- unimac-mdio unimac-mdio.-19: Broadcom UniMAC MDIO bus
- could not attach to PHY
- bcmgenet 12c00000.ethernet eth0: failed to connect to PHY

## Runtime

- No lan1-lan4 DSA ports appeared.
- eth0 existed but stayed DOWN.
- /proc/net/dev showed zero eth0 RX/TX packets.
- /proc/device-tree confirmed switch@1e exists.

## Conclusion

B53 driver probed MDIO address 0x1e but read device ID 0x00000000.
This suggests wrong MDIO switch address, inaccessible switch management path, or missing vendor init/pinmux.
Do not keep switch@1e as proven-good.
