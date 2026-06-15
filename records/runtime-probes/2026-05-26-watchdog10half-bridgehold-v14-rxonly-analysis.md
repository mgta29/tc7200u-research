# 2026-05-26 watchdog10half-bridgehold v14-rxonly analysis

## Inputs

- Host packet capture: `records/logs/tftp/2026-05-26-v14-rxonly/pkt-watchdog10half-bridgehold-v14-rxonly.txt`
- Host ping window: `records/logs/tftp/2026-05-26-v14-rxonly/host-ping-window-watchdog10half-bridgehold-v14-rxonly.txt`
- Host route/link/neighbor/meta proofs:
  - `records/logs/tftp/2026-05-26-v14-rxonly/host-route-proof-watchdog10half-bridgehold-v14-rxonly.txt`
  - `records/logs/tftp/2026-05-26-v14-rxonly/host-link-proof-watchdog10half-bridgehold-v14-rxonly.txt`
  - `records/logs/tftp/2026-05-26-v14-rxonly/host-neigh-proof-watchdog10half-bridgehold-v14-rxonly.txt`
  - `records/logs/tftp/2026-05-26-v14-rxonly/host-meta-watchdog10half-bridgehold-v14-rxonly.txt`
- OpenWrt serial: `records/logs/serial/picocom-20260526-015553.log`

## Observed facts

- Host setup is correct:
  - Link forced to `10 Mbps Half Duplex`.
  - Static route `192.168.77.0/24` via host NIC.
  - Permanent ARP entry for `192.168.77.1 -> C2-52-A8-6D-4C-41`.
- Ping outcome:
  - `reply_count=0`
  - `timeout_count=601`
  - `unreach_count=0`
- PktMon outcome:
  - `dir_tx=1206`, `dir_rx=0`
  - `icmp_req=1204`, `icmp_rep=0`
  - `arp_req=2`, `arp_rep=0`
  - `host_to_owrt=1204`, `owrt_to_host=0`
  - Unique ICMP request sequences: `601` (double capture lines per request across components).
- OpenWrt runtime (rx-only observe phase):
  - Every tick: `rx_delta=0`, `tx_delta=0`, `rxerr_delta=0`, `watchdog_new=0`.
  - Post stats: `tx_packets=655`, `rx_packets=0`, `tx_errors=24`, `rx_errors=0`, `tx_dropped=1`, `rx_dropped=0`.
  - IRQ lines: `64` increases, `66` remains `0`.
  - No `NETDEV WATCHDOG` block in this run.

## Conclusion

This run confirms a strict one-way host transmit pattern with zero observed ingress at OpenWrt network stats level. The host is sending correctly to the current OpenWrt MAC, but OpenWrt still reports no RX packet accounting and no RX-side interrupt activity in this window.

## Next test objective (v15-rxmib)

Differentiate between:

1. No ingress reaching GMAC hardware at all.
2. Ingress reaches GMAC, but RX DMA/driver accounting/IRQ path is broken.

Method:

- Keep the same host-side rx-only traffic generation.
- On OpenWrt, enable `promisc` and record GMAC MIB register window snapshots before/after traffic:
  - `0x12c00400..0x12c005fc`.
- Continue tick logging of `rx_packets`, `rx_bytes`, `multicast`, and watchdog deltas.

If MIB registers move while `rx_packets` stays zero, issue is likely RX DMA/driver path.
If MIB registers do not move, issue is likely below DMA path (GMAC ingress or external switch/port path).
