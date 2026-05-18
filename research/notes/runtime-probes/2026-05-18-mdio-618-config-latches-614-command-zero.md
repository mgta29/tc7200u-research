# 2026-05-18 - MDIO +0x618 config latches, +0x614 command reads zero

## Context

After mapping `UNIMAC_INTERFACE0`, offsets `0x12c00614` and `0x12c00618`
looked like plausible direct-base GENET MDIO candidates because Linux defines
`UMAC_MDIO_CMD = 0x614`.

GPIO14 was held high and safe vendor-side writes were restored.

## Result

Initial reads:

```text
0x12c00614 = 0x00000000
0x12c00618 = 0x00000000
```

Config write:

```text
write 0x12c00618 = 0x000013f1
read  0x12c00618 = 0x000003f1
```

This latched clause-22 and divider bits, but did not latch the `0x1000`
preamble-support bit.

Command writes:

```text
write 0x12c00614 = 0x08020000
read  0x12c00614 = 0x00000000
write 0x12c00614 = 0x28020000
read  0x12c00614 = 0x00000000
read  0x12c00614 = 0x00000000
```

The stale failed command at `0x12c00600` remained unchanged:

```text
0x12c00600 = 0x28000000
0x12c00604 = 0x00000001
```

## Interpretation

`0x12c00618` is the strongest MDIO config candidate so far: it accepts the
clock divider field that `0x12c00604` rejected. `0x12c00614` does not behave
like a readable upstream `UMAC_MDIO_CMD`; it may be write-only, the command may
complete with data/status somewhere else, or the command register is a
different offset.

## Next direction

With `0x12c00618 = 0x000003f1`, issue one command to `0x12c00614` and read the
nearby status/data area before and after:

- `0x12c00610`
- `0x12c00614`
- `0x12c00618`
- `0x12c0061c`
- `0x12c00620`
- `0x12c00624`

If none of these change, test the same config with command at `0x12c00600`,
because the config may have been at `+0x18` while the command path is still at
`+0x00`.
