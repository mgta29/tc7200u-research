# TC7200.U next Ethernet debug plan

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

## Current state

The simple `bcm6368-enetsw` RX/TX DMA and IRQ order matrix is exhausted:

- original IRQ/DMA: boots, eth0 exists, no packet I/O
- DMA swap only: boots, no improvement
- interrupt swap only: boots, no improvement
- combined DMA + interrupt swap: boots, no improvement

The minimal AMAC test also produced a useful but unsafe result:

- `brcm,amac` / `bgmac-enet` probes at `14e01000`
- boot hangs before userspace

Current baseline DTS is restored to the known console-safe `bcm6368-enetsw` node:

```dts
compatible = "brcm,bcm6368-enetsw";
interrupts = <0>, <1>;
interrupt-names = "rx", "tx";
dma-rx = <0>;
dma-tx = <1>;
```

## Direction decision

Do not continue with more DMA/IRQ swaps.

Next technical direction should be one of:

1. investigate missing `bcm6368-enetsw` switch/MAC init
2. safer AMAC bring-up with required PHY/MDIO/B53 resources
3. dump original vendor DT, registers, or MDIO state if available

The best immediate path is option 1: add temporary debug prints to `bcm6368-enetsw.c` while keeping the known-booting DTS baseline.

## Why driver debug first

`bcm6368-enetsw` is the only path that currently:

- reaches userspace reliably
- creates `eth0`
- does not hang the boot

The driver currently queues TX packets, but runtime counters show:

```text
rx_bytes=0
rx_packets=0
tx_packets increments only from queued packets
eth0 IRQ counts=0/0
byte_queue_limits/inflight remains nonzero
```

This means TX enqueue is visible, but DMA completion and RX are not proven.

## Temporary debug patch goals

Patch `target/linux/bmips/files/drivers/net/ethernet/broadcom/bcm6368-enetsw.c` to print:

- selected `rx_chan` and `tx_chan`
- selected `irq_rx` and `irq_tx`
- DMA base/resource pointers
- RX/TX ring DMA addresses
- DMA config register after `open`
- RX/TX channel config registers
- RX/TX interrupt status registers
- RX/TX interrupt mask registers
- RX/TX ring start registers
- TX descriptor index, DMA address, and `len_stat` in `start_xmit`
- whether the ISR ever fires

## Question to answer

The debug boot should determine whether:

- TX descriptors are queued but DMA never starts
- DMA starts but never completes
- completion status appears but IRQ is not delivered
- ring start registers are wrong or zero
- descriptor DMA addresses look outside usable RAM
- wrong MMIO registers are being accessed

## Test procedure after patch

Keep DTS baseline unchanged.

Build and wrap through the normal safe path:

```sh
cd ~/src/openwrt; make target/linux/compile V=s
cd ~/src/openwrt; make target/linux/install V=s
cd ~/tc7200u-research; scripts/tc7200u-wrap-current-openwrt.sh
```

Only TFTP if the wrapper manifest reports:

```text
size_ok=True
```

Runtime collection should use short serial commands:

```sh
dmesg | grep -i 'tc7200u-dma'
ip addr add 192.168.77.1/24 dev eth0
ip link set eth0 up
dmesg | grep -i 'tc7200u-dma'
ping -I eth0 -c 1 -W 1 192.168.77.2
dmesg | grep -i 'tc7200u-dma'
cat /proc/interrupts
cat /proc/net/dev
cat /sys/class/net/eth0/queues/tx-0/byte_queue_limits/inflight 2>/dev/null
```

## Follow-up after debug result

If DMA never starts, investigate missing enetsw switch/MAC init and register setup.

If DMA status changes but IRQs stay zero, investigate interrupt routing/masking.

If the debug patch shows valid DMA operation but no frames, move toward switch/MDIO/B53 wiring.

If AMAC is retried later, do not use the previous minimal node alone; add required PHY/MDIO/B53 resources first.
