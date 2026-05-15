# TC7200.U NAND int-base progress result

## Test goal

Fix the previous NAND probe failure:

- bcm6368_nand 14e02200.nand: error -EINVAL: invalid resource (null)
- probe with driver bcm6368_nand failed with error -22

## DTS tested

NAND node used:

- compatible = "brcm,nand-bcm6368", "brcm,brcmnand-v4.0", "brcm,brcmnand"
- reg-names = "nand", "nand-int-base", "nand-cache"
- reg = <0x14e02200 0x180>, <0x14e000f0 0x10>, <0x14e02600 0x200>
- nandcs@0
- nand-ecc-strength = <1>
- nand-ecc-step-size = <512>

## Source evidence

Vendor TC72XX / 3384a0 headers show:

- BCHP_NAND_INT_BASE_PER_REG_START = 0x14e000f0
- BCHP_NAND_FLASH_PER_REG_START = 0x14e02200
- BCHP_NAND_CACHE_PER_REG_START = 0x14e02600

U-Boot bcm6838 example also uses:

- reg-names = "nand", "nand-int-base", "nand-cache"
- reg = <0x14e02200 ...>, <0x14e000f0 ...>, <0x14e02600 ...>

## Runtime result

The previous invalid-resource error is gone.

New NAND result:

- bcm6368_nand 14e02200.nand: timeout waiting for command 0x9
- bcm6368_nand 14e02200.nand: intfc status c0000000
- nand: No NAND device found

Runtime checks:

- /proc/mtd empty
- /sys/class/mtd empty

## Meaning

Progress was made.

The driver now maps required resources and reaches real NAND command execution.
The remaining failure is no longer missing DT resource.
Next suspects:

- wrong controller wrapper/version
- chip-select configuration
- NAND ready/interrupt path
- pinmux/enable/reset
- ECC/chip parameter mismatch

## OpenWrt driver support check

Current OpenWrt tree shows:

- bcm6368_nand.c matches only brcm,nand-bcm6368
- brcmnand core supports brcm,brcmnand-v4.0 and brcm,brcmnand-v5.0
- no dedicated brcm,nand-bcm6838 wrapper was found in the active bmips build tree
