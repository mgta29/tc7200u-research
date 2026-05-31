# 2026-05-19 - pre/post ping ring+descriptor snapshot invariant

## Setup

- OpenWrt `eth0`: `192.168.77.1/24`
- Laptop target: `192.168.77.2`
- Test: `ping -c 3 -W 1 192.168.77.2`
- Snapshot groups captured before and after ping:
  - ring windows:
    - `0x12c02c08`, `0x12c02c0c`, `0x12c02c20`
    - `0x12c03c08`, `0x12c03c0c`, `0x12c03c20`
  - descriptor words:
    - `0x12c03000`, `0x12c03004`, `0x12c03008`, `0x12c0300c`
  - IRQ and netdev stats.

## Observed

- PRE and POST were bit-identical for all sampled words.
- Ring windows:
  - `0x12c02c08=0x00000000`
  - `0x12c02c0c=0x06e72140`
  - `0x12c02c20=0x00000000`
  - `0x12c03c08=0x00000000`
  - `0x12c03c0c=0x06e72140`
  - `0x12c03c20=0x00000000`
- Descriptor words:
  - `0x12c03000=0x000de37a`
  - `0x12c03004=0x00085f4d`
  - `0x12c03008=0x000b30b5`
  - `0x12c0300c=0x000f190a`
- IRQ/stats:
  - hwirq `64` active (`7573`), hwirq `66=0`
  - RX remained `0`
  - TX stayed `3715 bytes / 10 packets / 9 errors` in this capture window.

## Interpretation

This test confirms no queue-progress signal across the sampled ring and
descriptor windows during traffic attempt. The shared value at
`0x12c02c0c/0x12c03c0c` behaves like a static/stale pointer-like field in this
state, not a progressing producer/consumer metric. Combined with RX `0` and
irq `66=0`, this remains a hard negative for data-path completion.
