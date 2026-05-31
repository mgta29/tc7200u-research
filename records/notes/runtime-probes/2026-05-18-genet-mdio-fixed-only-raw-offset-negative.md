# 2026-05-18 - GENET MDIO fixed-only and raw offset negative

## Context

After the safe vendor-side GMAC/GPIO candidates failed to move ring0 or TX MIB
counters, the next branch tested whether OpenWrt can see the BCM53125 switch
or PHY path that the OEM bootloader reports:

- `Switch detected: 53125`
- `ProbePhy: Found PHY 0, MDIO on MAC 0, data on MAC 0`
- `Using GMAC0, phy 0`

The test held GPIO14 high because the OEM firmware says `Powering UP switch.
PIN = 14`.

## Sysfs result

`/sys/bus/mdio_bus/devices` only exposed the fixed-link bus:

```text
fixed-0:00
```

The `bcm53xx` MDIO driver was present under `/sys/bus/mdio_bus/drivers`, but no
real MDIO device appeared.

## Raw MDIO result

The assumed GENET UMAC MDIO registers were probed:

- `0x12c00e18` returned `0x00000001`
- `0x12c00e14` returned `0x00000001`

Clause-22 read commands written to `0x12c00e14` for PHY0 registers 0-3 and
pseudo-PHY30 registers 0-3 all read back as:

```text
0x00000001
```

## Conclusion

The current Linux device tree/driver path does not expose the real switch MDIO
bus. The assumed UMAC MDIO command register at `0x12c00e14` is also not the
usable live MDIO command path for this target in the current OpenWrt image.

Do not keep repeating raw reads at `0x12c00e14`; find the correct BCM3383 MDIO
window or missing enable/reset first.

## Next direction

Probe the raw `mdio@600` register window directly, because the vendor source
identified the UniMAC MDIO offset as `0x600` relative to GENET:

- command candidate: `0x12c00600`
- config candidate: `0x12c00604`

Use single-line devmem reads/writes and keep `eth0` down while probing to avoid
TX watchdog log interleaving.
