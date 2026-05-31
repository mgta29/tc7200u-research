# 2026-05-24 split run (`picocom-20260524-213235.log` + `pkt-split.txt`)

## Findings
- Router neighbor was pinned and stable for the full run:
  - `192.168.77.2 lladdr bc:ec:a0:2d:6c:9b PERMANENT`
  - `/proc/net/arp` entry flags `0x6` throughout.
- Router netdev counters stayed flat across all phases:
  - RX remained `0`
  - TX remained `44695 bytes / 473 packets / 19 errors`
- Router IRQ counters kept increasing:
  - IRQ64 `41553 -> 42431 -> 43148`
  - IRQ66 stayed `0`
- Router register probes remained unchanged:
  - `0x12c03804`, `0x12c03808`, `0x12c03c44`, `0x12c02c44` all `0x00000001`
- Host capture remained one-way only:
  - `dir_tx=177`, `dir_rx=0`
  - `to_owrt=177`, `from_owrt=0`
  - `icmp_req=90`, `icmp_reply=0`
  - no ARP traffic in this run (`arp_req=0`, `arp_reply=0`)

## Interpretation
- ARP dependency is removed, but behavior is unchanged.
- Driver `tx submit` logging alone is not evidence of successful egress; descriptors are consumed but no observed wire-level receive on host and no netdev TX stat progress.
- Current hypothesis focus shifts to link mode / PHY timing / MAC-DMA completion path rather than host routing/filtering.

## Next test
- OpenWrt: `/home/mgta29/send-next-linkmode-100-split-v1.txt`
- Windows: `/home/mgta29/send-next-host-linkmode-100-split-v1.ps1.txt`

Goal:
- Force both ends to 100/full (where possible) and rerun split phases to see whether packet exchange and TX completions recover.
