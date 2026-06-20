# 2026-06-20 GENET IRQ13 DTS branch result

## Scope

This log records the DTS-only IRQ13 branch after the previous IRQ16/17-zero run.

The test changed the TC7200U GENET DTS interrupt mapping from:

```dts
interrupts = <16>, <17>;
```

to:

```dts
interrupts = <13>, <17>;
```

No DMA/FPM changes were intentionally combined with this branch.

## Result

IRQ13 is not a simple negative result.

The system booted and bcmgenet probed:

```text
bcmgenet 12c00000.ethernet: GENET 1.0 EPHY: 0x0000
bcmgenet: Invalid GPHY revision detected: 0x0000
bcmgenet 12c00000.ethernet: using random Ethernet MAC
bcmgenet 12c00000.ethernet: unable to find MDIO bus node
unimac-mdio unimac-mdio.-19: Broadcom UniMAC MDIO bus
```

eth0 reached the TC7200U debug open path:

```text
TC7200U CTRL open_entry FPM_A 12200010=0x00000000 12200014=0x00000001 12200040=0x06000000 12200044=0x00010000
TC7200U CTRL open_entry FPM_B 12200050=0x00000000 12200054=0x18007ee3 12200058=0x00000000 1220005c=0x00000000
TC7200U CTRL open_entry FPM_C 12200200=0x801e0800 12200208=0x900a0400 12200210=0xa01b8200 12200218=0xb01d0100
```

Then the system hit an RCU stall with the last-running CPU context inside the GENET interrupt handler:

```text
rcu: INFO: rcu_sched detected stalls on CPUs/tasks
CPU: 0 PID: 315 Comm: ip
epc   : 80594700 bcmgenet_isr0+0x34/0xfc
ra    : 800a2514 __handle_irq_event_percpu+0x58/0x178
Cause : 0080001c (ExcCode 07)
```

The register dump included IRQ-like value decimal 13 / 0x0d while inside this ISR path:

```text
$ 4   : 0000000d ...
$16   : ... 0000000d
```

## Interpretation

This branch proves IRQ13 can enter the upstream GENET ISR path. It is not the same as the previous IRQ16/17-zero result.

However, IRQ13 is unsafe as currently mapped:

- it stalls/faults inside bcmgenet_isr0
- it may be an unacknowledged or uncleared parent interrupt condition
- it may be the wrong L2 event for the upstream GENET ISR
- it must not be combined with DMA/FPM experiments

## Conclusion

```text
IRQ13 branch: live but bad. ISR entered; system stalls/faults in bcmgenet_isr0.
```

Next work should be parent interrupt bank/status/ack mapping and bcmgenet_isr0 entry instrumentation, not packet DMA.

## Required cleanup

Revert DTS interrupt mapping back to the prior baseline before the next branch:

```dts
interrupts = <16>, <17>;
```

Keep IRQ13 evidence as a separate logged branch.
