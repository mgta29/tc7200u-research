# 2026-05-18 - UNIMAC_INTERFACE0 map stable down/up

## Context

The `mdio@600` command/config interpretation did not hold:

- `0x12c00604` only latched bit 0
- command writes to `0x12c00600` dropped the register-address bits
- the started command stayed busy

This test dumped selected `UNIMAC_INTERFACE0` offsets with safe vendor writes
restored.

## Result

The map was the same for:

- `eth0` down, GPIO14 low
- `eth0` up, GPIO14 high

Clean values:

```text
0x12c00600=0x28000000
0x12c00604=0x00000001
0x12c00608=0x00000000
0x12c0060c=0x00000000
0x12c00610=0x000005EE
0x12c00614=0x00000000
0x12c00618=0x00000000
0x12c0061c=0x00000000
0x12c00620=0x00000000
0x12c00624=0x00000000
0x12c00628=0x00000000
0x12c0062c=0x00000000
0x12c00630=0x000000A7
0x12c00634=0x00008800
0x12c00638=0x03D403D4
0x12c0063c=0x00000008
0x12c00640=0x00000002
0x12c00644=0x00000400
0x12c00648=0x00000000
0x12c0064c=0x0000006F
0x12c00650=0x0540220C
0x12c00654=0x00000000
0x12c00658=0x00000000
0x12c0065c=0x00000000
0x12c00680=0x00000000
0x12c00684=0x00000000
0x12c00688=0x00000008
0x12c0068c=0x00000000
0x12c00690=0x00000000
0x12c00694=0x00000009
0x12c00698=0x00000000
0x12c0069c=0x3B9ACA00
0x12c00700=0x00000000
0x12c00704=0x00000000
0x12c00708=0x00000000
0x12c0070c=0x00000000
0x12c00710=0x00000000
```

## Interpretation

No sampled `UNIMAC_INTERFACE0` register changed when the MAC was opened or when
GPIO14 was high. The stale `0x28000000` at `0x12c00600` is still the prior
failed busy command.

Offsets `0x12c00614` and `0x12c00618` are clean zeroes in both states. Because
Linux's GENET headers define `UMAC_MDIO_CMD` as `0x614`, the next narrow probe
should test direct GENET-base `0x12c00614` as MDIO command and `0x12c00618` as
its adjacent config/control register before spending time on wider maps.
