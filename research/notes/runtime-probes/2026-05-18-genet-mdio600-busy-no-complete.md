# 2026-05-18 - GENET mdio@600 busy, no completion

## Context

The previous raw MDIO probe showed that the assumed GENET UMAC MDIO command
register at `0x12c00e14` was not useful on TC7200.U: all reads returned
`0x00000001`. This test moved to the documented BCM3383 `mdio@600` window:

- command candidate: `0x12c00600`
- config candidate: `0x12c00604`

GPIO14 was held high during the probe.

## Result

Before writes:

```text
0x12c00600 = 0x00000C01
0x12c00604 = 0x00000000
```

Writing `0x00000001` to `0x12c00604` latched:

```text
0x12c00604 = 0x00000001
```

PHY0 ID reads:

```text
write 0x28020000 -> read 0x28000000
write 0x28030000 -> read 0x28010000
```

Pseudo-PHY30 ID reads:

```text
write 0x2BC20000 -> read 0x2B000000
write 0x2BC30000 -> read 0x2B010000
```

## Interpretation

The `mdio@600` register window is live and writable, unlike the stale
`0x12c00e14` path. However, all reads left `MDIO_START_BUSY` set after one
second, so the MDIO transaction did not complete.

`MDIO_CFG` was zero before the test. The test only set clause-22 mode
(`0x00000001`), leaving the MDIO clock divider at zero. The next test should
configure a nonzero clock divider and use the same two-step sequence used by
`mdio-bcm-unimac.c`:

1. write command without `MDIO_START_BUSY`
2. read command back
3. write command with `MDIO_START_BUSY`
4. poll/read command until busy clears

## Next direction

Try `MDIO_CFG = 0x000013f1`:

- clause 22 enabled
- maximum divider field `0x3f << 4`
- preamble-support bit set

If busy still does not clear, the missing piece is likely an MDIO clock/reset or
interface enable bit outside the MDIO command/config pair.
