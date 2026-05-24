# 2026-05-19 - ring window `0x06f850c0` signature with RX still zero

## Setup

- OpenWrt `eth0`: `192.168.77.1/24`
- Laptop target: `192.168.77.2`
- Test: `ping -c 5 -W 1 192.168.77.2`
- Sampled after ping:
  - `0x12c02c08`, `0x12c02c0c`, `0x12c02c20`
  - `0x12c03c08`, `0x12c03c0c`, `0x12c03c20`
  - `/proc/interrupts` lines for `64` and `66`
  - `ip -s link show dev eth0`

## Observed

- Ring windows matched each other:
  - `0x12c02c08=0x00000000`
  - `0x12c02c0c=0x06f850c0`
  - `0x12c02c20=0x00000000`
  - `0x12c03c08=0x00000000`
  - `0x12c03c0c=0x06f850c0`
  - `0x12c03c20=0x00000000`
- Interrupts:
  - hwirq `64` increments (`1455` in this sample)
  - hwirq `66` remains `0`
- Link stats:
  - RX: `0 bytes`, `0 packets`
  - TX: `3715 bytes`, `10 packets`, `9 errors`

## Interpretation

This is a second stable stuck signature distinct from the earlier
`0x00000001/0x01000800` pattern. Here both ring windows expose a
`0x06f850c0` value in the `+0x0c` slot while RX remains dead and IRQ activity
is still one-sided (`64` only). This supports the view that these offsets are
not a healthy queue-progress signal and that runtime pokes should be deprioritized
in favor of source-level descriptor/ownership path validation.
