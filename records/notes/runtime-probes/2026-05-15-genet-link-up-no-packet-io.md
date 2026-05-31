# GENET link up but no packet I/O

## Test

OpenWrt RAM/TFTP boot. GENET `eth0` comes up and joins `br-lan`.

Manual IP test:

```text
br-lan = 192.168.77.1/24
target PC/TFTP host = 192.168.77.2
Observed result
bcmgenet 12c00000.ethernet eth0: Link is Up - 1Gbps/Full - flow control off
br-lan: port 1(eth0) entered forwarding state

ping -c 3 192.168.77.2
3 packets transmitted, 0 packets received, 100% packet loss

ip neigh
192.168.77.2 dev br-lan FAILED
Interrupts
cat /proc/interrupts | grep -Ei 'genet|eth|12c|irq'
16: 0  periph_intc@14e00048  16  eth0
17: 0  periph_intc@14e00048  17  eth0
ethtool
Speed: 1000Mb/s
Duplex: Full
Port: MII
PHYAD: 0
Transceiver: external
Link detected: yes
Statistics summary
rx_packets: 0
tx_packets: 10
rx_bytes: 0
tx_bytes: 3715
tx_errors: 10
rxq16_packets: 0
txq16_packets: 10

Many hardware counters showed the same bogus-looking value 2998927360, suggesting the statistics/register view is not reliable yet.

Conclusion

GENET link state comes up, but packet I/O is not working. TX attempts happen, TX errors increase, RX stays zero, ARP fails, and eth IRQ counters remain zero.

This points to GENET DMA/IRQ/init/switch wiring, not simple IP configuration.

CFE reports:

Switch detected: 53125
ProbePhy: Found PHY 0, MDIO on MAC 0, data on MAC 0
Using GMAC0, phy 0

Next Ethernet direction: compare CFE/OEM GMAC0 + BCM53125 setup against OpenWrt GENET DTS/driver init. Do not treat link-up alone as working Ethernet.
