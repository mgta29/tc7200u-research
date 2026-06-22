# 2026-06-21 daily reverse summary

## Scope control

- Requested source path `records/notes/reverse` is absent in this workspace.
- Live reverse corpus used for this pass: `records/reverse`.
- Control read covered `66` reverse markdown files and the current Ghidra export set under `records/reverse/exports`.

## New source notes carried today

- `2026-06-20-dqm-fpm-runtime-overlay-ghidra-log.md`
- `2026-06-20-dqm-mailbox-extphy-spi-genet-selector-ghidra-log.md`
- `2026-06-20-ghidra-isr0guard-new-data-next-steps.md`
- `2026-06-21-bcm-periph-irq-im5-ghidra-log.md`

## OpenWrt ENET development carry

- `0x40000000` in the cleaned DQM/FPM paths is a DQM/FPM token flag. It must not be merged with the OpenWrt `periph_stat=0x40000004` IRQ13 observation.
- Confirmed FPM endpoint map: `0x12200200/B2200200` for `0x800`, `0x12200208/B2200208` for `0x400`, `0x12200210/B2200210` for `0x200`, and `0x12200218/B2200218` for `0x100`.
- DQM runtime state at `0x80004000` and `0x80008000` is an overlay problem. Keep the static image intact and use a separate runtime-overlay analysis copy for volatile DQM state.
- DQM mailbox case `0x11` routes selector output toward GENET targets `b2c00500` and `b2c00510`; case `0x12` performs B604/B605 window programming.
- The OpenWrt IRQ13 guard run reached `bcmgenet_isr0()` without panic/watchdog in the capture, but the current raw GENET status/mask reads are incoherent because the debug print re-reads registers inside the log expression.
- OEM peripheral interrupt path now has a concrete parent dispatcher: `fn_bcm_periph_irq_cp0_im5_pending_dispatcher_8002adbc_candidate`.
- Parent IM5 bank uses `b4e00050` as mask/enable and `b4e00054` as status/pending in the recovered dispatcher model.
- If the OpenWrt `periph_mask=0x00002000` bit is the same parent bank, it maps to OEM group id `0x30` / decimal `48`.
- Child IRQ dispatch uses table root `0x81745b14`, child-bank active bits from offsets `+0x08/+0x0c`, and handler table root `0x81743214`; group `0x30` starts at `0x81746214`.

## Immediate next controls

- Fix the OpenWrt ISR guard to snapshot `raw_stat`, `raw_mask`, and `status` once before printing.
- Rate-limit or mask IRQ13 after a small number of guard prints to avoid serial flood.
- Investigate OEM handler group `0x30` child entries before forcing an upstream GENET INTRL2 layout onto TC7200U.
- Keep FPM/DQM token work separate from TDMA descriptor-width experiments and B53/MDIO work.

## Second 2026-06-21 control update

- Requested source path `records/notes/reverse` is still absent; the controlled live source remains `records/reverse`.
- Control read now covers `69` reverse markdown files and `23662` reverse markdown lines before this summary update.
- Newly carried live notes: `2026-06-21-bcm-periph-host-dqm-im5-reenable-log.md`, `2026-06-21-natp-host-dqm-ghidra-log.md`, and `2026-06-21-net-config-heap-natp-gfap-ghidra-log.md`.
- Corrected the OpenWrt IRQ carry: the OEM Host-DQM IM5 path proves groups `0x23..0x28`; it does not prove encoded group `0x30` for Host-DQM. Treat the older group-`0x30` mapping as a hypothesis only.
- Corrected child-bank semantics: `child_bank+0x08` is the mask/control/enable latch and `child_bank+0x0c` is the status/pending source. Do not add blind clear/ack writes until parent and child snapshots are coherent.
- Carried Host-DQM selector facts: dispatch tables `81916fd8` and `819172d8` hold event raise masks and one-based stage1 event-slot ids, not callback pointers.
- Carried NATP no-match Host-DQM facts: selector `4` / MPEG_PROC uses the `b8a00000` Host-DQM window, queue index `0x10`, channel index `0x11`, and windows around `b8a01800`, `b8a01d00`, `b8a01f40`, and `b8a01f44`.
- Carried net-config/heap facts: the heap-free entry starts at `8002a280`, `0x81470000` is a high-half global anchor and not an object, and the net-config large cache requires resizing the current `8187bc60` block through `81883daf`.
## Documentation updates from this pass

- Added this daily reverse summary.
- Updated `important-openwrt-tc7200u-enet-usable-values.md` with the June 20/21 DQM/FPM, mailbox, ISR0 guard, and IM5 IRQ findings.
- Updated `important-reverse-structure-reference.md` with the newly carried DQM runtime, DQM mailbox, FPM endpoint, IM5 IRQ, and BCM34xx-support structures.
