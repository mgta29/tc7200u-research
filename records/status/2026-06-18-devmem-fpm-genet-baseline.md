# 2026-06-18 devmem FPM/GENET baseline before Ethernet enablement

## Image state

Working OpenWrt initramfs console baseline with devmem enabled.

## devmem proof

Device shell confirmed:

- `/sbin/devmem`
- `/dev/mem` exists as character device `1,1`

## FPM baseline

Read with `devmem ADDR 32`:

- `0x12200010 = 0x00000000`
- `0x12200014 = 0x00000001`
- `0x12200040 = 0x06000000`
- `0x12200044 = 0x00010000`
- `0x12200050 = 0x00000000`
- `0x12200054 = 0x18007F10`
- `0x12200058 = 0x00000000`
- `0x1220005c = 0x00000000`
- `0x12200200 = 0x80130800`
- `0x12200208 = 0x90064400`
- `0x12200210 = 0xA01B8200`
- `0x12200218 = 0xB01C4100`

## GENET/MBDMA baseline

Read with `devmem ADDR 32`:

- `0x12c00004 = 0x00000001`
- `0x12c00008 = 0x00000001`
- `0x12c0000c = 0x00000001`
- `0x12c00010 = 0x00000001`
- `0x12c00040 = 0x00000001`
- `0x12c00044 = 0x00000001`
- `0x12c00048 = 0x00000001`
- `0x12c0004c = 0x00000001`
- `0x12c00050 = 0x00000001`
- `0x12c00054 = 0x00000001`
- `0x12c00058 = 0x00000001`
- `0x12c00070 = 0x00000001`

## MDIO baseline

Read with `devmem ADDR 16`:

- `0x12c0062c = 0x0010`
- `0x12c0062e = 0x0010`
- `0x12c00630 = 0x0010`
- `0x12c00632 = 0x0010`
- `0x12c0262c = 0x0010`
- `0x12c0262e = 0x0010`
- `0x12c02630 = 0x0010`
- `0x12c02632 = 0x0010`

## Interpretation

FPM is readable and nonzero.

GENET/MBDMA and MDIO are not OEM-like in this baseline and Ethernet is not active. This matches the runtime observation that `ip link` showed only loopback.

Next action should be GENET/GMAC-only enablement and tracing, not NAND.
