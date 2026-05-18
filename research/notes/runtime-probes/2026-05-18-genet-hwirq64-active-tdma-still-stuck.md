# TC7200.U GENET hwirq64 active, TDMA still stuck

Date: 2026-05-18

## Result

The `PeriphIRQ0_2` DTS override is confirmed:

```text
grep -E 'eth0|CPU' /proc/interrupts
           CPU0
 64:        961  periph_intc@14e00048  64  eth0
 66:          0  periph_intc@14e00048  66  eth0
```

Extended periph mask/status:

```text
eth0 down:
0x14e00338=0x00000000
0x14e0033c=0x045A0409
0x14e00350=0x00000000
0x14e00354=0x00000000

eth0 up:
0x14e00338=0x00000005
0x14e0033c=0x045A0409
0x14e00350=0x00000000
0x14e00354=0x00000000
```

Interpretation:

- Linux now unmasks extended bits 0 and 2 when `eth0` is up.
- hwirq 64 counts heavily.
- hwirq 66 remains idle.
- The console remains usable; this is not the old blind parent IRQ storm.
- Keep the extended IRQ mapping, probably with only hwirq 64 later.

## TDMA state

Ring16 still does not move:

```text
tdma_ctrl=0x00020001 tdma_stat=0x00000000
r16_read=0x00000000 r16_cons=0x00000000 r16_prod=0x00000001
r16_size=0x01000800 r16_start=0x00000000 r16_end=0x000001ff
r16_mbuf=0x00000001 r16_write=0x00000000
desc0_len=0x000e009a desc0_addr=0x00080000
```

Down-state ring/global dump:

```text
0x12c03c00=0x00000000
0x12c03c04=0x00000000
0x12c03c08=0x00000001
0x12c03c0c=0x01000800
0x12c03c10=0x00000000
0x12c03c14=0x000001FF
0x12c03c18=0x00000001
0x12c03c40=0x00020000
0x12c03c44=0x00000000
0x12c03c4c=0x00000010
0x12c03c70=0x00000002
```

The up-state paste lost `0x12c03c40` as `c40`, but the kernel timeout dump
already shows TDMA enabled as `0x00020001`.

## Next branch

Test GENET v1 DMA SCB burst size `0x08` instead of the generic Linux default
`0x10`.

Reason:

- Current dumps show `rdma_scb=0x00000010` and `tdma_scb=0x00000010`.
- Broadcom U-Boot GENET code uses `DMA_MAX_BURST_LENGTH=0x08`.
- Mainline Linux already has a platform quirk using `.dma_max_burst_length =
  0x08` for another GENET integration.
- This is a narrower test than changing ring start/end semantics.

## Burst-size result

The `0x08` burst-size branch programmed the intended registers:

```text
rdma_scb=0x00000008
tdma_scb=0x00000008
```

It did not change the failure:

```text
r16_read=0x00000000 r16_cons=0x00000000 r16_prod=0x00000001
r16_write=0x00000000 desc0_len=0x000e009a desc0_addr=0x00080000
sw_prod=1 sw_c=0 hw_p=1 hw_c=0
```

So burst length `0x10` is not the root cause.

## Next branch after burst test

The next stronger hypothesis is the GENET v1 global DMA register map.

Current register evidence:

```text
0x12c03c40=0x00020000  # down
0x12c03c40=0x00020001  # up, from RAWDMA tdma_ctrl
0x12c03c44=0x00000000
0x12c03c4c=0x00000008
0x12c03c70=0x00000002
```

This resembles the v2-style map:

- `+0x00`: `DMA_RING_CFG`
- `+0x04`: `DMA_CTRL`
- `+0x08`: `DMA_STATUS`
- `+0x0c`: `DMA_SCB_BURST_SIZE`

The current Linux v1 map treats `+0x00` as `DMA_CTRL`, which may leave the real
DMA control register at `+0x04` disabled.

Next OpenWrt patch:

- `9990-bcmgenet-tc7200u-v1-dma-regmap-v2-test.patch`

Expected signature:

```text
tdma_cfg=0x00010000
tdma_ctrl=0x00020001
```

Equivalent raw MMIO expectation:

```text
0x12c03c40=0x00010000
0x12c03c44=0x00020001
```

## DMA regmap result

The v2-style global DMA regmap branch programmed the intended registers:

```text
rdma_cfg=0x00010000 rdma_ctrl=0x00020001 rdma_stat=0x00000000
tdma_cfg=0x00010000 tdma_ctrl=0x00020001 tdma_stat=0x00000000
0x12c03c40=0x00010000
0x12c03c44=0x00020001
0x12c03c48=0x00000000
0x12c03c4c=0x00000008
0x12c03c70=0x00000002
```

TDMA still did not consume descriptor 0:

```text
r16_read=0x00000000 r16_cons=0x00000000 r16_prod=0x00000001
r16_write=0x00000000 desc0_len=0x000e009a desc0_addr=0x00080000
sw_prod=1 sw_c=0 hw_p=1 hw_c=0
```

Keep `9990`; it fixes the global DMA register interpretation. It is necessary
but not sufficient.

## Next branch after DMA regmap

Repeat the normal Linux descriptor status format on top of the fixed DMA
regmap:

- `9991-bcmgenet-tc7200u-v1-standard-desc-after-regmap-test.patch`

Reason:

- Earlier original-status tests were run before `9990`.
- With `9990`, the real DMA control register at `+0x04` is enabled.
- This test should log `len_stat=0x009aefc0` for the first 154-byte frame
  instead of compact `0x000e009a`.

Pass/fail:

- Pass: `r16_read`, `r16_cons`, `r16_write`, or `hw_c` moves.
- Fail: hardware still shows `r16_read=0`, `r16_cons=0`, `r16_write=0`,
  `hw_c=0`.

## Standard descriptor result after DMA regmap

Normal Linux descriptor status was retested on top of the fixed DMA regmap and
burst-size `0x08`.

The descriptor write/readback path behaved as expected for the 20-bit GENET v1
descriptor RAM:

```text
TC7200U XMITDESC ... len_stat=0x009aefc0
TC7200U RESVTX ... len_stat=0x009aefc0
TC7200U DESCRB ... wrote_len=0x009aefc0 ... rb_len=0x000aefc0 rb_addr=0x00080000
```

TDMA still did not consume descriptor 0:

```text
tdma_cfg=0x00010000 tdma_ctrl=0x00020001 tdma_stat=0x00000000
r16_read=0x00000000 r16_cons=0x00000000 r16_prod=0x00000001
r16_write=0x00000000 desc0_len=0x000aefc0 desc0_addr=0x00080000
```

So the normal Linux status word is not enough once the real DMA control register
is enabled. Because the 20-bit descriptor RAM truncates the upper status bits,
compact status remains the more plausible descriptor format, but compact status
also fails to make TDMA start.

## Manual swapped descriptor result after DMA regmap

Manual slot-0 rewrites were tested after `9990`, with the descriptor words
swapped so word 0 held the low address and word 1 held the status/length.

Swapped standard status:

```text
devmem 0x12c03000 32 0x00080000
devmem 0x12c03004 32 0x000aefc0
devmem 0x12c03c08 32 0x00000001

0x12c03c00=0x00000000
0x12c03c04=0x00000000
0x12c03c08=0x00000001
0x12c03c20=0x00000000
```

Swapped compact status:

```text
devmem 0x12c03000 32 0x00080000
devmem 0x12c03004 32 0x000e009a
devmem 0x12c03c08 32 0x00000001

0x12c03c00=0x00000000
0x12c03c04=0x00000000
0x12c03c08=0x00000001
0x12c03c20=0x00000000
```

Both swapped layouts failed. After the DMA-regmap fix, the descriptor format
matrix is now negative for:

- normal order, compact status
- normal order, standard Linux status
- swapped order, compact status
- swapped order, standard/truncated Linux status

## Next branch after descriptor matrix

The next narrow diagnostic is to keep the fixed DMA regmap and compact status,
but zero the surrounding descriptor RAM words before reposting slot 0. This
checks whether the BCM3383 TDMA path is sensitive to adjacent/stale descriptor
words before it fetches descriptor 0.

Pass/fail remains the same:

- Pass: `r16_read`, `r16_cons`, `r16_write`, or `hw_c` moves.
- Fail: all stay at zero with `r16_prod=1`.

## Adjacent descriptor clear result

Descriptor words `0x12c03000..0x12c0301c` were cleared, then slot 0 was
reposted as compact status plus low TX buffer address:

```text
0x12c03000=0x000E009A
0x12c03004=0x00080000
0x12c03008=0x00000000
0x12c0300c=0x00000000
```

TDMA still did not move:

```text
0x12c03c00=0x00000000
0x12c03c04=0x00000000
0x12c03c08=0x00000001
0x12c03c20=0x00000000
```

Adjacent/stale descriptor RAM words are not the blocker.

## Next branch after adjacent clear

Probe the TDMA control ring-enable bit. With the fixed regmap, current state is:

```text
tdma_cfg=0x00010000
tdma_ctrl=0x00020001
```

Mainline uses `DMA_RING_BUF_EN_SHIFT=1`, so ring16 enable becomes bit 17 in
`DMA_CTRL`. If BCM3383 v1 expects bit 16 instead, TDMA would accept producer
writes but never service ring16. The next manual test should write
`tdma_ctrl=0x00030001` to enable both candidate bits and then repost slot 0.

## TDMA control bit result

The dual control-enable write latched:

```text
0x12c03c40=0x00010000
0x12c03c44=0x00030001
```

TDMA still did not move:

```text
0x12c03c00=0x00000000
0x12c03c04=0x00000000
0x12c03c08=0x00000001
0x12c03c20=0x00000000
```

So the `DMA_CTRL` ring-enable bit alone is not the missing piece.

## Next branch after TDMA control bit

Probe the paired `DMA_RING_CFG` bit. Current state only enables bit 16:

```text
tdma_cfg=0x00010000
tdma_ctrl=0x00030001
```

The next manual test should write `tdma_cfg=0x00030000` and
`tdma_ctrl=0x00030001`, enabling both bit 16 and bit 17 candidates in both
places before reposting compact slot 0.

## TDMA ring config bit result

The paired config/control write latched:

```text
0x12c03c40=0x00030000
0x12c03c44=0x00030001
```

TDMA still did not move:

```text
0x12c03c00=0x00000000
0x12c03c04=0x00000000
0x12c03c08=0x00000001
0x12c03c20=0x00000000
```

So neither the `DMA_CTRL` ring-enable bit nor the paired `DMA_RING_CFG` bit
explains the stuck descriptor fetch.

## Next branch after ring config bit

Probe ring-register layout. The fixed global DMA map indicates BCM3383 GENET v1
does not exactly match the mainline v1 global register map. It may also use the
wider/v4-style ring register spacing while still using 2-word descriptor RAM.

The next manual test should initialize ring16 using the v4 ring layout:

```text
read=0x3c00
cons=0x3c08
prod=0x3c0c
size=0x3c10
start=0x3c14
end=0x3c1c
mbuf=0x3c24
write=0x3c2c
```

Then repost compact slot 0 and advance the v4-layout producer at `0x12c03c0c`.
If this moves `0x12c03c08` or `0x12c03c2c`, the ring layout is the missing
piece.
