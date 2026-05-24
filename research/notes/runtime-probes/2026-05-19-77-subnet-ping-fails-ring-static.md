# 2026-05-19 - 192.168.77.x ping fail with static ring/MIB registers

## Setup

- OpenWrt `eth0`: `192.168.77.1/24`
- Laptop target: `192.168.77.2`
- Test: `ping -c 10 -W 1 192.168.77.2`

## Observed

- `PING_RC=1` (no ping success)
- `ip -s link show eth0`:
  - TX bytes/packets increased (`9385/90` -> `10629/106`)
  - RX stayed zero (`0/0`)
  - TX errors stayed `8`
- Interrupts:
  - hwirq `64` increments
  - hwirq `66` remains `0`
- Ring/global registers unchanged after traffic:
  - `0x12c03800=0x00010003`
  - `0x12c03804=0x00000028`
  - `0x12c03808=0x00010000`
  - `0x12c0380c=0x00000000`
  - `0x12c03c40=0x00000001`
  - `0x12c03c44=0x00000001`
  - `0x12c03c48=0x00000001`
- IF0/IF1 sampled MIB windows remained unchanged in this run:
  - `0x12c004a8=0x00000001`, `0x12c004e8=0x00000001`
  - `0x12c02ca8=0x00000001`, `0x12c02ce8=0x00000001`

## Interpretation

This confirms a persistent data-path failure under correct L3 addressing:

- stack-level TX accounting moves,
- but no RX comes back,
- ring/global hardware state remains stuck in the known signature.

Runtime register pokes are unlikely to produce new signal now; next progress
should come from kernel-side GENET DMA/descriptor handling changes.
