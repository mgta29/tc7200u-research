# TC7200.U runtime proof: drivers present, no Ethernet DT node

## Platform drivers present

- b53-switch
- bcm6368-enetsw
- bcm6368-mdio-mux
- bcm6368_nand
- bcm63xx-hsspi
- bcm63xx-spi
- bgmac-enet

## Platform devices present

    14e00048.periph_intc
    14e00500.serial
    151f8048.cmips_intc
    Fixed MDIO bus.0
    ubus

## Result

Only loopback exists.

    1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000

/proc/iomem only claims serial MMIO.

    14e00500-14e00517 : 14e00500.serial serial@14e00520

## Conclusion

Ethernet is not missing because of kernel config. The relevant drivers are built and registered.

Ethernet is missing because the TC7200.U DTS currently has no Ethernet / MDIO / switch node for the platform drivers to bind to.

## MMIO probe evidence

Real-looking reads:

    0x14e01000 -> 0x000d0000
    0x14e01100 -> 0x00008080
    0x14e01200 -> 0x804c5647
    0x14e02200 -> 0x00000400

Echo-like or likely invalid reads:

    0x151f8000 -> 0xb51f8000
    0x151f8010 -> 0xb51f8010
    0x151f8040 -> 0xb51f8040
    0x151f8048 -> 0xb51f8048
    0x151f804c -> 0xb51f804c
    0x151f8050 -> 0xb51f8050
    0x15100000 -> 0xb5100000
    0x15101000 -> 0xb5101000
    0x15102000 -> 0xb5102000
    0x15110000 -> 0xb5110000
    0x15111000 -> 0xb5111000
    0x15112000 -> 0xb5112000

## Current blocker

Add a temporary Ethernet DT node and test whether either bcm6368-enetsw or bgmac-enet binds.

Do not flash. RAM boot only.
