# TC7200U runtime-probes summary

Date: 2026-06-14
Scope: summarize the probe records under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes`

## Executive summary

The `runtime-probes` directory records the live OpenWrt-on-hardware investigation after RAM boot and serial console were already working. Its main durable result is that the Ethernet failure moved from a broad "nothing is there" problem into a narrower "GENET link comes up but the packet path is broken" problem.

The directory shows three clear phases:

1. early proof that drivers existed but the initial platform description was incomplete or wrong
2. mid-stage pivot from the false `bcm6368-enetsw @ 0x14e01000` path to the BCM3383 `GENET @ 0x12c00000` path
3. late controlled traffic experiments proving strict one-way host transmit with zero OpenWrt RX accounting, even when host route, MAC, link mode, and observation windows were tightened

The strongest current conclusion from this directory is:

- link establishment is no longer the main blocker
- host traffic reaches the test path correctly
- OpenWrt still shows `rx_packets = 0`
- host capture still shows no router-originated frames
- the next discriminating step is below normal netdev counters, such as GMAC MIB or RX-DMA visibility

## Phase 1: baseline runtime proof and the first blocker reduction

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-13-devmem-and-net-status.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-14-runtime-drivers-no-ethernet.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-15-runtime-dump-no-mdio-or-flash-evidence.md`

What these notes prove:

- OpenWrt boots and serial works.
- Early runtime initially lacked `/dev/mem` because `CONFIG_DEVMEM` was not enabled.
- The kernel already had relevant network/switch drivers built and registered.
- Only loopback existed at runtime.
- Platform devices were minimal and the DTS was still missing the real Ethernet/MDIO/switch description.

Important early narrowing:

- Ethernet was not failing simply because the build forgot to include drivers.
- The first blocker was platform description and hardware mapping.
- The runtime notes also showed that `/proc/mtd` and higher-level flash exposure were still not useful enough for safe persistent work.

## Phase 2: GENET direction and low-level DMA/ring evidence

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-16-gmac-init-genet-fixedlink-tftp-result.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-17-genet-desc-ram-truncates-high-bits.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-18-oem-boot-gmac-switch-clues.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-19-ring-window-c0-signature-rx0.md`

What changed in this phase:

- The probes moved onto a TC7200U-specific GMAC/GENET direction.
- Vendor-style GMAC pinmux/clock/reset work and a temporary `GENET` fixed-link node at `0x12c00000` were added for testing.
- Runtime analysis started focusing on descriptor RAM, producer/consumer behavior, IRQ split, and OEM boot clues.

High-value findings:

- OEM boot evidence strongly reinforced:
  - `Switch detected: 53125`
  - `Using GMAC0, phy 0`
  - `Enet link up: 1G full`
- GPIO14 became the preferred narrow switch-power hypothesis instead of random writes into unrelated diagnostic registers.
- Descriptor RAM reads suggested upper address bits were being lost or not represented correctly in the observed ring state.
- TDMA still did not consume descriptors even with active TX-side experimentation.
- IRQ behavior remained asymmetric:
  - one interrupt line moved
  - the RX-side line stayed flat

Why this phase matters:

- It changed the problem from "wrong node or no node" to "the right MAC family is probably in play, but ownership, DMA address handling, or RX/TX completion is still wrong."

## Phase 3: controlled packet-path experiments

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-24-pktmon-peer-arp-only-no-owrt-egress.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-24-next-test-rx-directed-unicast.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-24-progress-summary.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-25-watchdog10half-bridgehold-v10-rerun-225955-analysis.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-26-watchdog10half-bridgehold-v14-rxonly-analysis.md`

What these later runs prove:

- Host-side setup can be made correct and repeatable:
  - route pinned to the test NIC
  - static neighbor pinned to the current OpenWrt MAC
  - link forced to a chosen mode such as `10 Mbps Half Duplex`
- Host packet capture repeatedly shows directed unicast frames going to OpenWrt.
- OpenWrt still does not produce host-visible return traffic.
- OpenWrt RX counters, RX queue stats, and RX interrupt evidence stay at zero.

Most important late-stage runtime pattern:

- TX-side activity can grow.
- `NETDEV WATCHDOG` can be reproduced.
- RX remains hard zero.
- Host never sees router-originated frames on the target path.

Important hypothesis eliminations recorded in these notes:

- not just a missing host route
- not just a missing static neighbor
- not just an ARP-only artifact
- not just a bad host pktmon filter
- not just a link-mode mismatch

Most useful late discriminator:

- The `v14-rxonly` run removed TX-stress pressure and still showed:
  - correct host transmit
  - zero host-visible return traffic
  - zero OpenWrt RX packet accounting
  - no RX-side interrupt movement

That makes the remaining issue more likely to be:

- no ingress reaching GMAC hardware at all, or
- ingress reaching hardware but not advancing through RX DMA, driver accounting, or IRQ delivery

## Durable conclusions from this directory

- The wrong broad ENETSW matrix was exhausted and deprioritized.
- The BCM3383 `GENET` direction became the active runtime path.
- OEM clues about GMAC0, BCM53125, and switch-power behavior materially changed the probe design.
- The late experiments became good enough to rule out several host-side and link-mode-side explanations.
- The cleanest current probe conclusion is strict one-way host transmit with zero OpenWrt RX evidence.

## Practical baseline for future runtime work

If work resumes from this directory alone, the baseline to carry forward is:

- boot and serial are already solved enough for live probe work
- use `GENET`/GMAC assumptions, not the old `14e01000` ENETSW interpretation
- preserve the known-good host path discipline:
  - static neighbor
  - pinned route
  - explicit link-mode proof
- judge success by one of these only:
  - RX counters move
  - RX interrupt moves
  - host sees router-originated traffic
  - GMAC MIB counters prove ingress reached hardware

The next high-value discriminator recorded by the last note is:

- compare GMAC MIB movement against zero Linux RX accounting

## Suggested reading order

For the fastest review of the runtime-probe history:

1. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-14-runtime-drivers-no-ethernet.md`
2. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-17-genet-desc-ram-truncates-high-bits.md`
3. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-18-oem-boot-gmac-switch-clues.md`
4. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-24-progress-summary.md`
5. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\runtime-probes\2026-05-26-watchdog10half-bridgehold-v14-rxonly-analysis.md`

## Change log

- 2026-06-14: created this summary in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\summary` from the existing runtime-probe records.
- 2026-06-14: no older log or note file was edited by this summary pass.
