# TC7200.U GENET IRQ16-only test plan

Date: 2026-05-16
Scope: RAM boot only. Do not flash.

Current result:
- OpenWrt boots to shell.
- BCMGENET probes at 0x12c00000.
- Fixed-link reports eth0 up at 1Gbps/full.
- TX watchdog occurs.
- /proc/interrupts shows no bcmgenet/eth0 interrupt handler.
- ERR counter rises while eth0 is up.
- Live DT confirmed interrupts = <16>, <17> and interrupt-parent points to periph_intc.

Current change:
- Change GENET DTS interrupts from <16>, <17> to <16> only.

Purpose:
- Check whether bcmgenet registers/uses a single periph_intc IRQ 16.
- If IRQ16-only still has no GENET handler and ERR rises, test IRQ17-only next.

Expected boot test:
- hexdump /proc/device-tree/ubus/ethernet@12c00000/interrupts should show 00 00 00 10.
- /proc/interrupts should be checked before and after eth0 up.
