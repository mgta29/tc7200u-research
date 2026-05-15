# TC7200.U NAND v5.0 int-base test result

## Test goal

Check whether changing the Broadcom NAND core compatible from v4.0 to v5.0 changes NAND detection.

## DTS tested

NAND node used:

- compatible = "brcm,nand-bcm6368", "brcm,brcmnand-v5.0", "brcm,brcmnand"
- reg-names = "nand", "nand-int-base", "nand-cache"
- reg = <0x14e02200 0x180>, <0x14e000f0 0x10>, <0x14e02600 0x200>
- nandcs@0
- nand-ecc-strength = <1>
- nand-ecc-step-size = <512>

## Runtime result

Same result as v4.0 int-base test:

- bcm6368_nand 14e02200.nand: timeout waiting for command 0x9
- bcm6368_nand 14e02200.nand: intfc status c0000000
- nand: No NAND device found

Runtime checks:

- /proc/mtd empty
- /sys/class/mtd empty

## Conclusion

Changing brcmnand core compatible from v4.0 to v5.0 did not improve NAND detection.

Progress from earlier tests remains:

- invalid-resource/null problem is fixed by adding nand-int-base = 0x14e000f0
- controller now reaches NAND command execution
- current blocker is command timeout / no NAND response

Next suspects:

- chip-select configuration
- NAND ready/interrupt handling
- pinmux/enable/reset
- wrong NAND wrapper behavior despite compatible match
- ECC/chip geometry mismatch
