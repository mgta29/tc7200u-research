# 2026-05-19 - `eth0 nomaster` bridge-off sanity check (negative)

## Setup

- Detached `eth0` from bridge (`ip link set eth0 nomaster`).
- Configured standalone address: `192.168.77.1/24`.
- Ran `ping -c 5 -W 1 192.168.77.2`.
- Captured PRE/POST:
  - `ip -s link show dev eth0`
  - `/proc/interrupts` (`64`, `66`)
  - `0x12c02c0c`, `0x12c03c0c`
  - `0x12c03000..0x12c0300c`

## Observed

- PRE and POST netdev counters unchanged:
  - RX `0/0`
  - TX `3715 bytes / 10 packets / 9 errors`
- IRQ pattern unchanged:
  - hwirq `64` increments (`17674` in this sample)
  - hwirq `66` remains `0`
- Register words unchanged across traffic:
  - `0x12c02c0c=0x06f163c0`
  - `0x12c03c0c=0x06f163c0`
  - `0x12c03000=0x000de37a`
  - `0x12c03004=0x00085f4d`
  - `0x12c03008=0x000b30b5`
  - `0x12c0300c=0x000f190a`

## Interpretation

Bridge membership is not the blocker. The failure signature is unchanged even
with `eth0` detached from `br-lan`, so further runtime topology pokes are
unlikely to provide new signal.
