# GENET RBUF/TBUF force negative

Date: 2026-05-18

## Context

After the ring0 address-first 3-word descriptor failed, this test checked
whether the TX path was blocked by missing RBUF/TBUF enable state rather than
descriptor order.

## Test

Before replay:

- `RBUF_CTRL` at `0x12c00300` read `0x00000001`.
- `RBUF_CHK_CTRL` at `0x12c00314` read `0x00000001`.
- `TBUF_CTRL_V1` at `0x12c00380` read `0x00000001`.
- `TBUF_BP_MC_V1` at `0x12c003a0` read `0x00000001`.
- `UMAC_CMD` at `0x12c00808` read `0x1000010b`.
- `UMAC_HD_BKP_CTRL` at `0x12c00844` read `0x00000002`.

The test then forced:

- `RBUF_CTRL = 0x00000003`
- `RBUF_CHK_CTRL = 0x00000021`
- `TBUF_CTRL_V1 = 0x00000001`

Then ring0 was replayed with canonical status-first compact descriptor words:

- `0x12c03000 = 0x000e009a`
- `0x12c03004 = 0x00080000`
- `0x12c03008 = 0x00000000`
- `0x12c0300c = 0x00000000`

## Result

After replay:

- `0x12c03800 = 0x00010003`
- `0x12c03804 = 0x00000000`
- `0x12c03808 = 0x00000001`
- `0x12c03820 = 0x00000000`
- `0x12c03c48 = 0x00000000`
- `RBUF_CTRL` read back as `0x00000001`, not forced `0x00000003`.
- `RBUF_CHK_CTRL` read back as `0x00000001`, not forced `0x00000021`.
- `TBUF_CTRL_V1` stayed `0x00000001`.
- TX MIB counters stayed unchanged at `0x00000001`.

## Conclusion

The TBUF path was already enabled, and forcing RBUF/TBUF control bits did not
make TDMA retire the descriptor or transmit a packet. The failed RBUF bit
readbacks are useful register-behavior evidence, but they do not explain the
ring0 stall.

The next branch should inspect GENET bridge/window registers and the vendor
GMAC init candidate registers before trying more writes.
