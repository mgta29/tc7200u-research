# OEM boot GMAC and switch-power clues

Date: 2026-05-18

## Context

The OEM boot log provides a known-working Ethernet baseline before OpenWrt
GENET probing.

## Relevant OEM boot lines

The bootloader reports:

- `Switch detected: 53125`
- `ProbePhy: Found PHY 0, MDIO on MAC 0, data on MAC 0`
- `Using GMAC0, phy 0`
- `Enet link up: 1G full`

The later OEM firmware init reports:

- `Powering UP switch. PIN = 14`

## Register identity correction

Local BCM3384 headers identify:

- `0x14e00100` as `GPIO_PER_DIR_LO`
- `0x14e0012c` as `GPIO_PER_DATA_LO`
- `0x14e001c4` as `GPIO_PER_RBUS_DIAG_SEL`
- `0x14e001c8` as `GPIO_PER_Diag_Capt_Last_WrAddr0`

This means the tested `0x14e001c4` and `0x14e001c8` writes are in the GPIO_PER
block but are not direct GPIO output controls. Treat them as diagnostic-capture
or vendor side-effect writes, not as the switch power GPIO itself.

## Conclusion

The next narrow runtime probe should test whether GPIO14 is configured
output-high under OpenWrt. GPIO14 is bit `0x00004000` in `GPIO_PER_DIR_LO` and
`GPIO_PER_DATA_LO`.

If GPIO14 is already output-high and the ring0 replay still fails, return to
the remaining vendor GMAC-init candidates as a combined side-effect test.
