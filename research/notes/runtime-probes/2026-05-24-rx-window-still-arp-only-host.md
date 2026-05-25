# 2026-05-24 - RX window rerun: host traffic still ARP-only

## Inputs

- Serial log:
  - `evidence/serial/picocom-20260524-202946.log`
- Host packet trace text:
  - `C:/tftp/pkt.txt`

## OpenWrt-side result

Run used the `send-next-rx.txt` style 20-second receive window with `eth0` as
`192.168.77.1/24`.

Pre:

- RX: `0 bytes, 0 packets`
- TX: `30167 bytes, 301 packets, 18 errors`
- IRQ64: `6366`
- IRQ66: `0`
- ERR: `28013`

Post:

- RX: `0 bytes, 0 packets`
- TX: unchanged (`30167 bytes, 301 packets, 18 errors`)
- IRQ64: `7174` (increased)
- IRQ66: `0` (unchanged)
- ERR: `30268` (increased)

Observed dmesg tail in this window:

- only two `tc7200u tx submit` lines near setup time
- no new watchdog burst in this short window

## Host pkt trace result

Decoded `pkt.txt` shows:

- `Direction Tx`: `22`
- `Direction Rx`: `0`
- ARP requests: `22`
- ARP replies: `0`
- all ARP requests are:
  - `BC-EC-A0-2D-6C-9B > FF-FF-FF-FF-FF-FF`
  - `who-has 192.168.77.1 tell 192.168.77.2`
- no frames from OpenWrt MAC `16:d8:10:6e:9d:33`
- no ICMP echo request/reply packet lines in the capture payload

## Interpretation

This run did not actually validate forced unicast host->OpenWrt traffic. The
host side still emitted only ARP broadcast retries and never reached a
neighbor-resolved unicast ICMP phase. OpenWrt remained RX-dead (`RX=0`,
`IRQ66=0`) during the window.

## Next test (stricter)

Use:

- OpenWrt serial block: `/home/mgta29/send-next-rx-verify-host.txt`

During the 30s wait window, run host commands that explicitly verify static
neighbor pinning before pinging:

```powershell
$ifName   = "Ethernet"
$routerIp = "192.168.77.1"
$routerMac = "16-d8-10-6e-9d-33"   # from OpenWrt pre output

netsh interface ipv4 delete neighbors "$ifName" "$routerIp" | Out-Null
netsh interface ipv4 add neighbors "$ifName" "$routerIp" "$routerMac"

# Verify pinning actually exists on the intended interface
Get-NetNeighbor -AddressFamily IPv4 -IPAddress $routerIp | Format-Table ifIndex,InterfaceAlias,IPAddress,LinkLayerAddress,State

pktmon stop | Out-Null
pktmon filter remove
pktmon start --etw

ping -n 200 $routerIp

pktmon stop
pktmon format PktMon.etl -o C:\tftp\pkt-next.txt
```

Pass condition for this branch:

- `pkt-next.txt` contains unicast ICMP frames addressed to `16-d8-10-6e-9d-33`.

If that pass condition is missing, host-side neighbor forcing is still not
being applied to the active adapter, so RX-path conclusions remain blocked by
test setup rather than device behavior.
