# NAND periph_intc negative result

Test: changed nand@14e02200 interrupt-parent from &iop_intc to &periph_intc.

Result: OpenWrt still boots, but NAND still fails with timeout waiting for command 0x9.

Observed log:
```text
bcm6368_nand 14e02200.nand: timeout waiting for command 0x9
bcm6368_nand 14e02200.nand: intfc status c0000000
nand: No NAND device found
```

Conclusion: NAND failure is not solved by changing interrupt-parent to periph_intc. Next target is register map, clock/reset, pinmux, CS timing, or wrong compatible/controller path.

Safety: RAM/TFTP boot only. No flash writes.
