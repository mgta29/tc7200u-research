# TC7200.U runtime check: debugfs mounted, no useful eth0 ethtool data

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

## Context

The simple `bcm6368-enetsw` RX/TX DMA and IRQ order matrix is exhausted.

Current DTS baseline:

```dts
compatible = "brcm,bcm6368-enetsw";
interrupts = <0>, <1>;
interrupt-names = "rx", "tx";
dma-rx = <0>;
dma-tx = <1>;
```

## Commands run

```sh
ls /sys/kernel/debug
mount | grep debug
find /sys/kernel/debug -maxdepth 3 -type f 2>/dev/null | head -80
ls /sys/class/net/eth0
ethtool eth0 2>/dev/null
```

## Results

debugfs is mounted:

```text
debugfs on /sys/kernel/debug type debugfs (rw,nosuid,nodev,noexec,noatime)
```

Top-level debugfs contains generic kernel areas:

```text
bdi
block
clk
gpio
mips
mtd
phy
pinctrl
regmap
ubi
ubifs
devices_deferred
pm_genpd
memblock
```

No obvious `bcm6368-enetsw`, `eth0`, `enet`, `mdio`, `b53`, or switch-specific debugfs file was exposed in the first maxdepth-3 scan.

`/sys/class/net/eth0` exists and exposes normal netdev attributes including:

```text
address
carrier
carrier_changes
duplex
operstate
speed
statistics
queues
device
```

`ethtool eth0` returned:

```text
Settings for eth0:
No data available
```

## Interpretation

The current runtime image does not expose useful Ethernet debug state through ethtool or obvious debugfs entries.

Next useful step: add a temporary debug patch to `bcm6368-enetsw.c`.

The patch should print:

- selected `rx_chan` and `tx_chan`
- selected `irq_rx` and `irq_tx`
- DMA register values after open
- DMA interrupt status and mask registers
- TX descriptor kick path in `start_xmit`
- descriptor ring physical addresses
- TX/RX reclaim activity or lack of it

Goal: determine whether TX descriptors are queued but DMA never starts, DMA starts but never completes, or completion interrupts are not delivered.
