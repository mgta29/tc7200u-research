# TC7200.U runtime result: bcm6368-enetsw combined DMA/IRQ swap negative

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

## Test

Final simple `bcm6368-enetsw` channel-order matrix test.

```dts
interrupts = <1>, <0>;
interrupt-names = "rx", "tx";
dma-rx = <1>;
dma-tx = <0>;
```

## Runtime confirmation

```text
/proc/device-tree/ubus/ethernet@14e01000/interrupts = 00 00 00 01 00 00 00 00
/proc/device-tree/ubus/ethernet@14e01000/dma-rx = 00 00 00 01
/proc/device-tree/ubus/ethernet@14e01000/dma-tx = 00 00 00 00
```

## Result

Boot reached userspace and console shell.

```text
bcm6368-enetsw 14e01000.ethernet: mtd mac 86:8a:94:10:80:4b
bcm6368-enetsw 14e01000.ethernet: eth0 at 0xb4e01000, IRQ 0
init: Console is alive
```

Packet test failed.

```text
ping -I eth0 -c 3 -W 1 192.168.77.2
3 packets transmitted, 0 packets received, 100% packet loss
```

Counters:

```text
eth0 rx_bytes=0
eth0 rx_packets=0
eth0 tx_bytes=306
eth0 tx_packets=3
eth0 IRQ counts=0/0
byte_queue_limits/inflight=216
```

## Conclusion

Combined DMA + interrupt swap is negative.

The simple `bcm6368-enetsw` channel-order matrix is exhausted:

- original IRQ/DMA: boots, eth0 exists, no packet I/O
- DMA swap only: boots, no improvement
- interrupt swap only: boots, no improvement
- combined DMA + interrupt swap: boots, no improvement

This suggests the failure is not simple RX/TX DMA or IRQ ordering. The `bcm6368-enetsw` node can bind and create eth0, but packet I/O does not complete on TC7200.U/BCM3383 with the tested minimal resources.

Next direction: stop testing channel-order permutations and investigate missing SoC-specific switch/MAC init, MDIO/B53 wiring, or safer bgmac/AMAC bring-up with required PHY/MDIO resources.
