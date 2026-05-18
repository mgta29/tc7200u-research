# GENET ring0 address-first 3-word descriptor negative

Date: 2026-05-18

## Context

This test kept the current GENET v1 diagnostic baseline:

- GENET fixed-link RGMII reports link up.
- GENET interrupts are mapped to extended hwirqs `64/66`.
- The v2-style global DMA register map is active and should be kept.
- Reserved TX buffer physical address is `0x01680000`, represented as low word
  `0x00080000` and candidate high word `0x00000016`.
- Ring0 is used because it is the first path where TDMA read pointer movement
  was observed.

## Test

Ring0 was programmed manually with an address-first 3-word descriptor:

- `0x12c03000 = 0x00080000`
- `0x12c03004 = 0x00000016`
- `0x12c03008 = 0x000e009a`
- `0x12c0300c = 0x00000000`

Ring0/global TDMA setup:

- `tdma_cfg = 0x00000001`
- `tdma_ctrl = 0x00000003`
- ring0 producer set to `1`

TX MIB counters were reset/read before and after the replay.

## Result

After the replay:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000000`
- `0x12c03808 = 0x00000001`
- `0x12c03820 = 0x00000000`
- `0x12c03c48 = 0x00000000`
- descriptor words read back unchanged:
  - `0x12c03000 = 0x00080000`
  - `0x12c03004 = 0x00000016`
  - `0x12c03008 = 0x000e009a`
- TX MIB counters remained unchanged at `1`:
  - `0x12c004a8 = 0x00000001`
  - `0x12c004e8 = 0x00000001`
  - `0x12c004ec = 0x00000001`
  - `0x12c004f0 = 0x00000001`

## Conclusion

Address-first 3-word ring0 descriptors do not make TX complete. The lower read
pointer still advances to `3`, which suggests TDMA fetches descriptor words, but
the descriptor is not retired and no packet reaches the TX MIB path.

Descriptor word order is now unlikely to be the primary blocker. The next branch
should focus on BCM3383 GENET DMA window/address interpretation and missing
GMAC/SCB/UBUS initialization rather than repeating ring16 descriptor pokes.
