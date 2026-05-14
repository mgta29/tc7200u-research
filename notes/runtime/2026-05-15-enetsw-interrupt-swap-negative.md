# TC7200.U runtime result: bcm6368-enetsw interrupt swap negative

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

## Test

Known-booting `brcm,bcm6368-enetsw` node was restored, then only interrupt order was swapped.

```dts
interrupts = <1>, <0>;
interrupt-names = "rx", "tx";
dma-rx = <0>;
dma-tx = <1>;
```

## Runtime confirmation

```text
/proc/device-tree/ubus/ethernet@14e01000/interrupts = 00 00 00 01 00 00 00 00
/proc/device-tree/ubus/ethernet@14e01000/dma-rx = 00 00 00 00
/proc/device-tree/ubus/ethernet@14e01000/dma-tx = 00 00 00 01
```

## Result

Boot reached userspace and console shell.

```text
bcm6368-enetsw 14e01000.ethernet: mtd mac 86:8a:92:10:80:4b
bcm6368-enetsw 14e01000.ethernet: eth0 at 0xb4e01000, IRQ 0
init: Console is alive
```

Packet test still failed.

```text
ping -I eth0 -c 3 -W 1 192.168.77.2
3 packets transmitted, 0 packets received, 100% packet loss
```

Counters:

```text
eth0 rx_bytes=0
eth0 rx_packets=0
eth0 tx_bytes=262
eth0 tx_packets=3
eth0 IRQ counts=0/0
byte_queue_limits/inflight=176
```

## Conclusion

Interrupt swap alone is negative. It does not fix RX, TX completion, or eth0 interrupt delivery.

Current tested matrix:

- enetsw original: boots, eth0 exists, no packet I/O
- enetsw DMA swap only: boots, no improvement
- enetsw interrupt swap only: boots, no improvement
- minimal AMAC: bgmac probes, then hangs before userspace

Next possible final enetsw matrix test: combined DMA + interrupt swap.
