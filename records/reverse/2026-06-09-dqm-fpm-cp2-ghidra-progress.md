# 2026-06-09 DQM/FPM/CP2 Ghidra reverse-engineering progress

## Summary

This note records the completed Ghidra cleanup and mapping pass for the TC7200U / BCM3383 OEM DQM/FPM/CP2 queue-control path around the 0x80c80xxx..0x80c85xxx firmware region. The path is now effectively mapped end-to-end at the control-flow and functional level. Remaining uncertainty is limited to exact hardware-bit naming for some DQM/CP2 registers and table fields, not the high-level flow.

Main result:

- DQM/FPM/CP2 queue subsystem init path mapped.
- Vector 0x49 DQM interrupt/event dispatcher mapped.
- Event paths 0x07, 0x0c, 0x16, 0x17, 0x18 and unknown-event fallback mapped.
- CP2 token/event pull, reinject, budget, low12 limit, stream, and FPM return paths mapped.
- Control mailbox command dispatcher mapped and cleaned.
- Queue-create, queue-transition, CP2-pull, trace, mode, stats, resize, and diagnostic commands mapped.
- False Ghidra function splits removed and replaced with labels.
- Runtime overlay/scratch RAM treatment corrected for the 0x80004000..0x80008000 area.
- FPM token return endpoint 0xb2200200 / physical 0x12200200 confirmed through multiple independent paths.

## Repository / logging policy

No old logs were deleted. This note is a new dated reverse-engineering record under records/notes/reverse/. No git operation is part of this command.

## Address model used during analysis

OEM firmware uses MIPS KSEG aliases:

- KSEG1 MMIO physical conversion: physical = kseg1 - 0xa0000000.
- Cached/KSEG0 DMA-visible conversion observed in allocator paths: dma_phys = cached_addr & 0x1fffffff.

Important converted bases:

- 0xb2200000 -> physical 0x12200000 = FPM register block.
- 0xb2200200 -> physical 0x12200200 = FPM pool0 token endpoint.
- 0xb6000000 -> physical 0x16000000 = DQM/queue register window family.
- 0xb6040000 -> physical 0x16040000 = DQM queue tables / control registers.
- 0xb6080000 -> physical 0x16080000 = per-queue control region.
- 0xb6090000 -> physical 0x16090000 = stream/trace/queue-side region.
- 0xb3800000 -> physical 0x13800000 = DQM/service/status side registers.
- 0xb3400000 -> physical 0x13400000 = CP2 event ack/status register area.

## Important runtime overlay correction

Ghidra static listing around 0x80004000 shows early boot/vector code, but the DQM path reuses low RAM as writable runtime overlay/scratch. Writes to 0x800040xx, 0x800041xx, 0x800042xx, 0x80004exx, 0x800050xx, and 0x800080xx must be interpreted as runtime DQM data, not normal immutable code.

Important runtime overlay addresses:

- 0x80004040 = DQM init/state.
- 0x80004042 = trace disable byte.
- 0x80004044 = event07 optional helper enable.
- 0x80004045 = normal queue count/debug byte.
- 0x8000404a = CP2 pool/debug class short.
- 0x80004050 = trace queue mask / gate.
- 0x80004054 = event07 mode flags.
- 0x80004068 = DQM service mask.
- 0x80004070..0x80004094 = control-dispatcher staging/config/reply area.
- 0x800040a4 = resize secondary count staging.
- 0x800040a6 = resize primary count staging.
- 0x800040a8 = CP2 stream debug.
- 0x800040ac = CP2 stream debug value.
- 0x800040b0 = normal active queue mask.
- 0x800040b4 = special service queue mask.
- 0x800040bc = active queue mask.
- 0x800040c4 = event07 CP2 pull queue mask.
- 0x800040c8 + q*2 = runtime dynamic limit RAM table.
- 0x800040e8 + q*4 = runtime queue class/mode table.
- 0x80004168 + q*4 = queue service timestamp/age table.
- 0x800041e8..0x80004264 = shared DQM counters/debug block.
- 0x800041f0 = event0c aggregate reject/token count sum.
- 0x800041f4 = event0c aggregate low12 sum.
- 0x800041f8 = DQM queue token/cmd/reject counter.
- 0x800041fc = invalid token counter.
- 0x80004200 / 0x80004208 = token low12 path counters.
- 0x8000420c = event0c busy-mask timeout counter.
- 0x80004210 = CP2 submit timeout counter.
- 0x80004218 = DQM queue error/debug code counter.
- 0x80004220 = CP2 direct token path count.
- 0x80004228 = unknown-event debug/patch word.
- 0x80004234 = CP2 token debug word.
- 0x80004238 = event18 debug/patch word.
- 0x8000423c..0x80004250 = CP2 low12 mismatch runtime patch/stub words.
- 0x80004268.. = per-queue CP2 alternate/event stats.
- 0x80004280 / 0x80004284 = event0c per-queue command count/size stats, stride 0x20.
- 0x80004ea8 + q*0x20 = CP2 budget/fallback stats.
- 0x800050a8 + q*0x2c = per-queue CP2/event07 policy table.
- 0x800050d0 + q*0x2c = per-queue event07/CP2 overhead field.
- 0x8000800c, 0x80008014, 0x80008074, 0x800081c0 = runtime masks/gates used by event07/CP2 paths.

Ghidra read-only decompiler assumptions should remain disabled for these DQM/CP2/FPM functions. Otherwise Ghidra can remove real runtime branches based on false static constants.

## Confirmed FPM token model

Token-like words use:

- bit31 = valid/negative token bit, 0x80000000.
- bit30 = mailbox-before-return marker, 0x40000000.
- bits29:28 = token class/high selector bits.
- bits27:12 = token index field, mask 0x0ffff000.
- low12 = size/count/status subfield used heavily in accounting.

Confirmed behavior:

- Valid tokens are returned to FPM pool endpoint 0xb2200200 / physical 0x12200200.
- If bit30 is set, several paths clear bit30 and emit a DQM mailbox command before returning token.
- Mailbox command forms observed:
  - {0x6c, 4, token} in event07 / CP2 selector / event17 paths.
  - {0x6c, 0, token} in event0c and CP2 event-body paths.
- Invalid/non-negative token paths increment runtime counters such as 0x800041fc or 0x800041f8.

## Queue subsystem init path

### fn_dqm_queue_subsystem_init_80c80c6c_candidate

Mapped as the DQM/queue/FPM-side subsystem init wrapper. It is not the simple GENET TDMA register setup. It initializes runtime low-RAM overlay, configures DQM registers/tables, and registers vector 0x49.

Important init sequence:

- Clears/initializes runtime region around 0x80004040.
- Calls early control init.
- Sets several global DQM/queue hardware registers.
- Enables CP0 Status bit 0x40000000.
- Calls profile/table/preload/config helpers:
  - fn_dqm_queue_early_ctrl_init_80c80e50_candidate
  - fn_dqm_queue_profile_init_80c80b1c_candidate
  - fn_dqm_queue_status_check_set_mode0c_80c80f54_candidate
  - fn_dqm_queue_preload_index_ports_80c80830_candidate
  - fn_dqm_queue_table_init_80c80884_candidate
  - fn_dqm_queue_set_small_cfg_80c80c3c_candidate
  - fn_dqm_or_queue_fpm_endpoint_setup_80c809f0_candidate
  - fn_dqm_queue_set_global_field0c_80c809c8_candidate
- Registers vector 0x49:
  - FUN_80c739f8(fn_dqm_queue_vector49_handler_80c81960_candidate, 0x49)
  - FUN_8005fa08(0x49, 1)

### fn_dqm_or_queue_fpm_endpoint_setup_80c809f0_candidate

Programs DQM/FPM endpoint registers in 0xb609xxxx / physical 0x1609xxxx.

Writes:

- 0xb6090038 = 0x12200200.
- 0xb6090044 = *(0xb2200044) & 0x0fffffff.
- 0xb6090128 = 0x12200208.
- 0xb609012c = 0x12200210.
- 0xb6090130 = 0x12200218.
- 0xb6090068 = 0xc0001617.

Meaning:

- Links DQM/queue hardware to FPM pool endpoints and the FPM backing-base low address.
- Direct full-address scalar searches for 0x12200044 did not reveal a writer because the firmware builds the address using high-half 0xb220 plus offsets.

### fn_dqm_or_queue_fpm_endpoint_setup_80c73f74_candidate

Second endpoint setup/config function. Also reads FPM backing-base low register 0xb2200044 and writes derived addresses into the 0xb609xxxx / 0x1609xxxx family.

### fn_dqm_queue_set_global_field0c_80c809c8_candidate

Sets a field in 0xb6080000 / physical 0x16080000. Clears bits 21:16 and sets field value 0x0c.

### fn_dqm_queue_set_small_cfg_80c80c3c_candidate

Writes small DQM config block:

- 0xb6001758 -> DQM_QUEUE_CFG_16001758_candidate.
- 0xb600175c -> DQM_QUEUE_CFG_1600175c_candidate.
- 0xb6001760 -> DQM_QUEUE_CFG_16001760_candidate.
- 0xb6045700 -> DQM_QUEUE_CTRL_OR_IRQ_16045700_candidate.

### fn_dqm_queue_table_init_80c80884_candidate

Initializes queue tables and clear-table region:

- 0xb6050000 -> DQM_QUEUE_CLEAR_TABLE_16050000_candidate.
- 0xb6045000 -> DQM_QUEUE_TABLE_A_16045000_candidate.
- 0xb6045100 -> DQM_QUEUE_TABLE_B_16045100_candidate.
- 0xb6045200 -> DQM_QUEUE_TABLE_C_16045200_candidate.

Important correction:

- Ghidra expression iVar1 + -0x49fb0000 is MMIO/global 0xb6050000 + offset, not stack/RAM.

### fn_dqm_queue_preload_index_ports_80c80830_candidate

Preloads queue/free-list/token indices:

- Writes 0x000..0x1ff into 0xb6001dd0.
- Writes 0x200..0x7ff into 0xb6001dc0.
- Reads 0xb6001404 afterward.

Mapped globals:

- DQM_QUEUE_PRELOAD_PORT_A_16001dd0_candidate.
- DQM_QUEUE_PRELOAD_PORT_B_16001dc0_candidate.
- DQM_QUEUE_STATUS_16001404_candidate.

### fn_dqm_queue_profile_init_80c80b1c_candidate

Initializes DQM queue profiles and fixed queue ranges.

Fixed queue profile observations:

- Queue 0x1e: count/type 4, size 0x40.
- Queue 0x1f: count/type 4, size 0x80.
- Queue 0x1b: count/type 1, size 0x08.
- Queue 0x1a: count/type 4, size 0x100.
- Queue 0x19: count/type 4, size 0x100.
- Queue 0x18: count/type 3, size 0xc0.
- Queues 0x00..0x0f: count/type 2, size 0x80.
- Queues 0x20..0x2f: count/type 3, size 0xc0.

### fn_dqm_queue_write_profile_entry_80c80a70_candidate

Writes queue profile entries into low/high profile tables:

- 0xb6001a00 / 1a04 / 1a08 for low queues.
- 0xb6002200 / 2204 / 2208 for high queues.

Important correction:

- param_4 is the accumulated queue offset cursor; each call writes current offset and then advances by queue_size.

### fn_dqm_queue_early_ctrl_init_80c80e50_candidate

Early DQM control/state setup:

- 0x80004040 = runtime init state.
- 0xb6001640 = DQM_QUEUE_CTRL_MASK_16001640_candidate.
- 0xb600163c = DQM_QUEUE_CTRL_VALUE_1600163c_candidate.

### fn_dqm_queue_status_check_set_mode0c_80c80f54_candidate

Reads/sets DQM config/status:

- 0xb6001634 -> DQM_QUEUE_STATUS_16001634_candidate.
- 0xb6045a88 -> DQM_QUEUE_CFG_STATUS_16045a88_candidate.
- 0xb6045a8c -> DQM_QUEUE_MODE_CTRL_16045a8c_candidate.

### fn_dqm_queue_clear_status30_set_bit1_delay_80c80e7c_candidate

Clears bits 5:4 and sets bit1 with delay handling. Correction: this is not a simple bit1 pulse-clear; the second write does not clear bit1.

### fn_dqm_queue_enable_cfg_bits70_80c80ec8_candidate

Sets DQM cfg/status bits 0x70. Two-write sequence should be preserved because hardware may require bit6 before bits5:4.

### fn_dqm_queue_cfg_bits54_clear_80c80fcc_candidate

Returns true if bits 5:4 of 0xb6045a88 are both clear.

### fn_dqm_queue_cfg_pulse_bit5_clear_bit6_80c80ee8_candidate

Pulses DQM cfg/status bits:

1. Set bit5, clear bit4.
2. Delay.
3. Clear bits5:4.
4. Delay.
5. Clear bit6.

Used by selector 0x1c maintenance.

## Vector 0x49 DQM interrupt path

### fn_dqm_queue_vector49_handler_80c81960_candidate

Top-half vector 0x49 handler.

Behavior:

- Reads/updates DQM IRQ/status registers.
- Disables or masks vector while processing.
- Calls event dispatcher body.
- Clears/acks DQM IRQ/status bits.
- Sets bit31 in global IRQ/control register.
- Re-enables vector 0x49.

Key globals:

- 0xb6001818 -> DQM_QUEUE_IRQ_STATUS_OR_ACK_16001818_candidate.
- 0xb6045704 -> DQM_QUEUE_IRQ_MASK_OR_STATUS_16045704_candidate.
- 0xb600103c -> DQM_QUEUE_GLOBAL_IRQ_CTRL_1600103c_candidate.

False split fixed:

- 0x80c8199c is label-only: lab_dqm_vector49_reenable_irq_80c8199c_candidate.

### fn_dqm_queue_vector49_event_dispatch_80c819cc_candidate

Main DQM event dispatcher/drain for vector 0x49.

Main event source:

- 0xb6045740 / physical 0x16045740 = DQM_QUEUE_EVENT_FIFO_16045740_candidate.

Main status source:

- 0xb6045a80 / physical 0x16045a80 = DQM_QUEUE_EVENT_STATUS_16045a80_candidate.

Event type extraction:

- event_type = event_word >> 26.

Status handler:

- If DQM_QUEUE_EVENT_STATUS_16045a80 & 0x3c1a80ea, calls fn_dqm_queue_handle_status_bits_80c82d34_candidate.

Event dispatch:

- event_type 0x07 -> token/FPM-like path, may return tokens to FPM endpoint and use mailbox {0x6c,4,token}.
- event_type 0x0c -> command/count/doorbell completion path, optional call to fn_dqm_event0c_queue_cmd_completion_80c83fc4_candidate.
- event_type 0x16 / 0x17 -> fn_dqm_event16_17_fifo_token_mailbox_80c80494_candidate.
- event_type 0x18 -> fn_dqm_event18_fifo_snapshot_mailbox_dump_80c80568_candidate.
- other -> fn_dqm_unknown_event_fifo_drain_mailbox_80c8065c_candidate.

False split functions inside dispatcher were deleted and replaced with labels.

## Mailbox writer

### fn_dqm_queue_write_4word_mailbox_80c807ac_candidate

Writes a 4-word mailbox command to:

- 0xb6001df0 -> word0.
- 0xb6001df4 -> word1.
- 0xb6001df8 -> word2.
- 0xb6001dfc -> word3.

Physical:

- 0x16001df0..0x16001dfc.

Known payloads:

- {0x6c,4,token}: event07/CP2 selector paths and event17 bit30 path.
- {0x6c,0,token}: event0c and CP2 event-body result-token paths.
- {0x18..0x1b, snapshot...}: event18 FIFO snapshot dump.
- {0x76,...}: event07 context forwarding/trace path.
- Control dispatcher replies use local 4-word command/reply words.

## CP2 token/event handlers

### fn_dqm_cp2_token_event_handler_80c8138c_candidate

CP2 selector 0x19 token event handler.

Reads CP2 after setCopReg(2,0x800,0x19):

- d802 -> cp2_event_meta.
- d801 -> cp2_token_word.
- d803 -> cp2_aux_word.

queue_id = (cp2_event_meta >> 20) & 0x1f.

If queue class at 0x800040e8 + queue_id*4 is below 0x13:

- Valid token goes to FPM endpoint 0xb2200200 / 0x12200200.
- If bit30 is set, mailbox {0x6c,4,cleaned_token} is emitted first.

If queue class is >= 0x13:

- Updates alternate event stats.
- Writes stream sequence to 0xb609d000 / physical 0x1609d000.

### fn_dqm_cp2_sel1a_token_event_handler_80c81654_candidate

CP2 selector 0x1a token event handler.

Reads:

- d800 -> cp2_event_meta.
- d801 -> cp2_token_word.
- d802 -> cp2_aux_word.
- d803 -> cp2_flags_word.

Special behavior:

- If cp2_flags_word has bit 0x02000000, switches to CP2 bank 0x1b and reinjects token through CP2 d800.
- Counts selector 0x1a events at 0x80004294 + q*0x60.
- Uses same class-based split: FPM return if class <0x13, stream path if class >=0x13.

### fn_dqm_cp2_sel1a_overlay_token_or_stream_80c833c0_candidate

Alternate overlay selector 0x1a handler.

Behavior:

- Reads CP2 d802/d800/d801/d803.
- queue_id = (cp2_d802_meta >> 20) & 0x1f.
- If class <0x13: returns valid token to FPM endpoint; bit30 emits {0x6c,4,token}.
- If class >=0x13 and low byte of cp2_d802_meta is zero: builds context and calls fn_dqm_cp2_overlay_ctx_limit_or_route_80c8381c_candidate.
- If class >=0x13 and low byte nonzero: writes 5-word stream sequence to 0xb609d000.

### fn_dqm_cp2_sel19_overlay_token_or_stream_80c835ec_candidate

Selector 0x19 counterpart to 0x833c0.

Behavior:

- Selects CP2 bank 0x19.
- Reads d802/d800/d801/d803.
- Acknowledges through 0xb3401910 / physical 0x13401910.
- Same class split: FPM return for class <0x13, overlay context route or stream for class >=0x13.

## CP2 event body, pull, budget, and limit helpers

### fn_dqm_cp2_handle_status_bit_80c82bd8_candidate

Handles/pulls a CP2 event for one DQM status bit.

Important register:

- 0xb6045a00 / physical 0x16045a00 = DQM_CP2_EVENT_PULL_CTRL_16045a00_candidate.

Behavior:

- Accepts status bits in masks 0x00451024 and 0xafb00000.
- Builds selector from status bit.
- Writes pull control word to 0xb6045a00.
- Calls fn_dqm_cp2_poll_event_pull_status_80c82b54_candidate.
- If event available, reads CP2 d801/d802, updates queue budget usage, and calls fn_dqm_cp2_event_body_return_or_stream_80c825ac_candidate.

### fn_dqm_cp2_poll_event_pull_status_80c82b54_candidate

Polls 0xb6045a1c / physical 0x16045a1c.

Meaning:

- 0xffffffff = busy/pending.
- 0 = accepted/no error, return 1.
- nonzero = log error/status to 0xb6045e00 + idx*8, ack status bit through 0xb6045a80, return 0.
- Timeout returns 1 like clean status, so timeout is not strict failure in this helper.

### fn_dqm_cp2_event_body_return_or_stream_80c825ac_candidate

Main CP2 event body for token return, stream submission, and adaptive queue-limit update.

Context layout:

- +0x00 = cp2_selector.
- +0x01 = queue_id.
- +0x02 = event flag/path.
- +0x10 = cp2_token_word.
- +0x14 = cp2_aux_word.
- +0x20 = expected token low12.
- +0x22 = event count low12.

Direct-token path:

- If selector mode table says direct path and token valid, return token to 0xb2200200.
- If bit30 set, clear bit30 and mailbox {0x6c,0,token}.

Submit/stream path:

- Writes 0xb6045a0c = ctx+0x14.
- Writes 0xb6045a08 = ctx+0x10.
- Writes 0xb6045a04 = 1.
- Waits for trigger clear.
- Reads result token 0xb6045a10 and status 0xb6045a18.
- Valid result token returns to FPM endpoint.
- Otherwise sends stream/doorbell via 0xb38043a0 / physical 0x138043a0.

Adaptive limit state:

- Updates 0x800040c8 + q*2.
- Mirrors/uses 0xb6045500 + q*4.

### fn_dqm_cp2_patch_low12_delta_stub_80c811a4_candidate

Runtime patcher for low12 mismatch recovery.

Inputs:

- ctx expected low12 at +0x20.
- observed low12 passed as param_2.

Patches runtime words 0x8000423c..0x80004250 with MIPS instruction constants depending on delta size and direction.

Interpretation:

- Firmware dynamically patches a low12 mismatch adjustment stub to recover or adapt CP2/DQM token-count deltas.

### fn_dqm_cp2_check_low12_limit_or_redirect_80c81270_candidate

Queue low12 threshold guard.

Uses:

- 0x800050c4 + q*0x2c = queue flags.
- 0x800050c6 + q*0x2c = queue low12 limit.

Return values:

- 1 = accepted/no limit violation.
- 2 = violation and redirected to queue 0.
- 0 = violation/fallback stats recorded, no redirect.

### fn_dqm_cp2_reinject_or_return_by_queue_budget_80c82dd8_candidate

Budget-based CP2 reinject or fallback-token-return helper.

Uses:

- 0x800050b8 + q*0x2c = budget limit.
- 0x800050bc + q*0x2c = budget used.
- 0x800050c0 + q*0x2c = budget high-water.
- 0x80008014 + q*4 = reinject enable table.
- 0x80004ea8 + q*0x20 = fallback/budget stats.

Behavior:

- Adds low12 event count to queue budget accounting.
- If within budget and reinject enabled: writes CP2 registers and reinjects event.
- If over budget or not reinjected: valid token returns directly to FPM endpoint; invalid increments reject counter; stats are updated and budget usage is reduced.

Important:

- This helper does not clear bit30 and does not emit mailbox before returning token.

## Event07 path

### fn_dqm_event07_trace_rewrite_ctx_80c81118_candidate

Optional trace/context rewrite helper.

Gate:

- 0x80004042 == 0.
- queue bit enabled in 0x80004050.

Copies 10 words from event context, rewrites metadata fields, then calls fn_dqm_event07_trace_emit_or_return_token_80c832a4_candidate.

### fn_dqm_event07_trace_emit_or_return_token_80c832a4_candidate

If 0x80008074 == 0:

- Return valid ctx token to FPM endpoint.
- If bit30 set, emit mailbox {0x6c,4,token} first.
- Invalid token increments 0x800041fc.

If 0x80008074 != 0:

- Emits CP2 event through selector 0x18.
- Updates event07 trace CP2 emit stats at 0x80004298 / 0x8000429c + q*0x60.

### fn_dqm_event07_limit_adjust_return_or_forward_80c839d0_candidate

Adjusts event07 context low12/size field based on mode and special service mask.

Observed adjustment:

- base 0x0a / 0x0e / 0x0f plus mode-dependent +2/+3.

If token has bit30:

- Sends mailbox command 0x76.
- Clears bit30 on token A.
- Sets bit30 on token B/context word.

Then decides return-to-FPM, reject, rewrite, or forward.

### fn_dqm_event07_route_ctx_pull_or_budget_80c83178_candidate

Main event07 context router.

If queue bit not in 0x800040c4:

- Update primary stats and call trace_emit_or_return_token.

If queue bit is in 0x800040c4:

- Optional helper fn_dqm_event07_optional_cap_fastpath_80c82ff0_candidate may handle it.
- Otherwise performs CP2 pull through 0xb6045a00 and poll helper.
- If pull fails or route requires fallback, calls budget reinject/return helper.

### fn_dqm_event07_optional_cap_fastpath_80c82ff0_candidate

Optional cap fast path. Only used when 0x80004044 == 1.

Behavior:

- Computes overhead 0x0b or 0x0d.
- Compares low12 + overhead with cap at 0x800050b0 + q*0x2c.
- If under cap and fallthrough flag is zero: handles by stats update and trace_emit_or_return_token.
- If over cap: returns/rejects token and records fallback stats.
- Return 0 means helper declined and caller continues normal route.
- Return 1 means handled.

## Event16 / Event17 path

### fn_dqm_event16_17_fifo_token_mailbox_80c80494_candidate

Handles event types 0x16 and 0x17.

Behavior:

- Reads three extra FIFO words from 0xb6045740.
- Builds mailbox event header = (event_word & 0xffffff00) | event_type.
- Increments 0x800041f8.
- For event 0x16: returns second FIFO word directly to FPM endpoint.
- For event 0x17: if first FIFO word is valid/negative, returns it to FPM endpoint; if bit30 set, first emits {0x6c,4,cleaned_token}.
- Always sends final 4-word event record through mailbox.

## Event18 path

### fn_dqm_event18_fifo_snapshot_mailbox_dump_80c80568_candidate

Extended FIFO snapshot / diagnostic mailbox dump.

Behavior:

- Initializes local snapshot buffer with 0xdeadbee7.
- Stores first event word.
- Reads FIFO words from 0xb6045740 into snapshot.
- If snapshot[8] bit17 is clear, writes runtime 0x80004214 = 0x3c0c8001 and sends four mailbox records 0x18..0x1b.
- If bit17 is set, writes runtime 0x80004238 = 0xad0b0001.

Note:

- snapshot[10] and snapshot[11] remain 0xdeadbee7 in current decompile unless assembly proves additional FIFO reads.

## Unknown event fallback

### fn_dqm_unknown_event_fifo_drain_mailbox_80c8065c_candidate

Generic fallback for event types not 0x07, 0x0c, 0x16, 0x17, or 0x18.

Uses:

- 0xb604573c = event FIFO status.
- 0xb6045704 = IRQ/status mask.
- 0xb6045740 = event FIFO word.

Behavior:

- Starts with first event word.
- Drains more FIFO words while FIFO status indicates data and IRQ/status bit31 is set.
- Sends mailbox packets with header 0xf00000ff | encoded count bits.
- Initializes diagnostic snapshot with 0xdeadbee7.
- Writes runtime debug word 0x80004228 = 0x3c098001.

## Event0c command/completion path

### fn_dqm_event0c_queue_cmd_completion_80c83fc4_candidate

Mapped as damaged-but-understood event_type 0x0c queue command/completion handler.

Input:

- event0c_word.

Extracts:

- queue_id = (event0c_word >> 20) & 0x1f.

Main registers:

- 0xb6045a20 = DQM_QUEUE_CMD_WORD_16045a20_candidate.
- 0xb6045a24 = DQM_QUEUE_CMD_TRIGGER_16045a24_candidate.
- 0xb6045a28 = DQM_QUEUE_CMD_RESULT_TOKEN_16045a28_candidate.
- 0xb6045a2c = DQM_QUEUE_CMD_BUSY_MASK_LO_16045a2c_candidate.
- 0xb6045a30 = DQM_QUEUE_CMD_BUSY_MASK_HI_16045a30_candidate.

Core behavior:

- Chooses selector 0x1c or 0x1d through fn_dqm_queue_choose_selector_1c_1d_80c83ea0_candidate.
- Polls busy mask for selector/queue bit.
- Submits command word to 0xb6045a20 and triggers 0xb6045a24.
- Waits up to around 0x190 loops for trigger clear.
- Reads result token from 0xb6045a28.
- Valid result token is returned to FPM endpoint 0xb2200200.
- If result token bit30 set, emits mailbox {0x6c,0,cleaned_token} before return.
- Invalid result increments 0x800041f8 and contributes to event0c stats.
- Finalizes queue state, stats, and resize operations.

Important corrected stat stride:

- event0c per-queue command stats use stride 0x20, not 0x60.
- 0x80004280 + stats_idx*0x20 += rejected_token_count.
- 0x80004284 + stats_idx*0x20 += rejected_token_low12_sum.

Important false splits inside event0c fixed as labels:

- lab_dqm_event0c_poll_busy_mask_80c8409c_candidate.
- lab_dqm_event0c_selector_mode_compare_80c8407c_candidate.
- lab_dqm_event0c_submit_cmd_or_finalize_80c840dc_candidate.
- lab_dqm_event0c_result_token_bit30_mailbox_80c84160_candidate.
- lab_dqm_event0c_reject_counter_store_80c841a8_candidate.
- lab_dqm_event0c_result_token_stats_tail_80c841b0_candidate.
- lab_dqm_event0c_pool_class_debug_next_poll_80c841cc_candidate.
- lab_dqm_event0c_finalize_stats_resize_80c841e4_candidate.
- lab_dqm_event0c_resize_failed_80c842d8_candidate.
- lab_dqm_event0c_set_per_queue_ctrl_bit0_80c84414_candidate.

Additional cleanup after final pass:

- Deleted false function FUN_80c84420; replaced with lab_dqm_event0c_reactivate_queue_state_tail_80c84420_candidate.
- Deleted false function FUN_80c84494; replaced with lab_dqm_event0c_reply_header_merge_80c84494_candidate.

## Queue selector and resize helpers

### fn_dqm_queue_choose_selector_1c_1d_80c83ea0_candidate

Input:

- queue_idx.

Reads:

- 0xb6045000 + queue_idx*8 = DQM queue table A entry.
- high16(table word) indexes into 0xb6040000.

Decision:

- if low16(indexed_value) > 0x1ff: return 0x1c.
- else return 0x1d.

Known caller:

- fn_dqm_event0c_queue_cmd_completion_80c83fc4_candidate.

### fn_dqm_queue_resize_index_range_80c85120_candidate

Queue index range resize/refill/drain helper.

Parameters:

- queue_idx.
- requested_count.
- selector_id.

Behavior:

- Accepts queue range 0x00..0x43.
- Reads base index and count from DQM_QUEUE_TABLE_A.
- If requested_count > current_count: pulls entries from selector index port 0xb6001c00 + selector_id*0x10 into central index table 0xb6040000.
- If requested_count < current_count: writes excess entries back to selector index port.
- Calls fn_dqm_selector1c_toggle_pool_mode_80c80fe4_candidate(selector_id,1) before grow/pull and fn_dqm_selector1c_toggle_pool_mode_80c80fe4_candidate(selector_id,0) after shrink/release.
- Returns true if full resize satisfied, false if capped/limited.

### fn_dqm_selector1c_toggle_pool_mode_80c80fe4_candidate

Acts only for selector_id 0x1c.

When enabling/grow side:

- Clears bits 2:3 in 0xb6045a8c.
- Calls cfg pulse helper.
- Clears 0xb6054000..0xb605fffc.

When disabling/release side:

- If selector1c count is zero and cfg bits indicate ready, sets bits 2:3 and re-enables cfg bits 0x70.

## Control mailbox command dispatcher

### fn_dqm_ctrl_mailbox_command_dispatch_80c845b8_candidate

Mapped and cleaned as one real function.

Reads command words:

- 0xb6001de0 / physical 0x16001de0 = word0.
- 0xb6001de4 / physical 0x16001de4 = word1.
- 0xb6001de8 / physical 0x16001de8 = word2.
- 0xb6001dec / physical 0x16001dec = word3.

Command fields:

- opcode = word0 & 0xff.
- queue_id = (word0 >> 20) & 0x1f.

Reply:

- Most paths rewrite local 4-word command/reply words and call fn_dqm_queue_write_4word_mailbox_80c807ac_candidate.
- Shared reply tail label: lab_dqm_ctrl_write_reply_mailbox_80c850a4_candidate.
- This label is not a function. It calls mailbox writer using sp+0x08 and falls into the function epilogue.

Major opcode map:

- 0x64 = dynamic queue create/activate.
- 0x65 = transition active queue to class/state 5.
- 0x66 = transition active queue to class/state 6.
- 0x68 = queue service/reset helper.
- 0x6d = read/clear stream debug values.
- 0x6e = set per-queue aux value and ctrl bit4.
- 0x6f = dump and clear per-queue stats.
- 0x70 = runtime scratch/fill/stack diagnostic query.
- 0x71 = read event07 pull/mode/debug state.
- 0x74 = transition normal active queue to class/state 0x10 service state.
- 0x75 = write per-queue CP2/event07 policy table.
- 0x78 = reply/status value 0xb3014070.
- 0x79 = rebuild event07 CP2 pull queue mask and MMIO config.
- 0x7a = trace-disable / stream-control toggle.
- 0x7b = event07 mode flag update and table patch.
- 0x7c = accepted no-op/readback style command in this branch chain.
- 0x7d = set trace queue mask in this decompile branch order.
- 0x7e = accepted no-op/readback style command depending branch chain.
- 0x02 = accepted no-op / no invalid-command increment.
- default = increment 0x8000422c unknown command counter.

Note: Some 0x7c/0x7d/0x7e branch labels were affected by Ghidra decompile/register reuse in earlier passes. The final assembly view confirms the branch chain is cleaned, but exact naming of the readback/no-op branches should stay conservative unless another isolated decompile is taken.

### Command 0x64 dynamic queue create

Steps:

1. queue_id = (word0 >> 20) & 0x1f.
2. primary_count = ceil((word1 & 0xfff) / 8).
3. secondary_count = ceil((word2 & 0xfff) / 8).
4. If queue already active in 0x800040bc, reply status 1.
5. Clamp counts using fn_dqm_clamp_queue_primary_secondary_counts_80c850d4_candidate.
6. Compute requested_total_count = primary_count + secondary_count, plus secondary optional count if enabled.
7. Find optional secondary table-C slot through fn_dqm_queue_find_free_table_c_slot_80c85554_candidate.
8. Choose selector 0x1d or 0x1c through fn_dqm_choose_selector1d_or_1c_by_capacity_80c844e4_candidate.
9. If no selector capacity, reply status 2.
10. Set active masks.
11. Initialize DQM queue table entries and per-queue runtime table 0x800050a8..0x800050d0.
12. Resize index ranges through fn_dqm_queue_resize_index_range_80c85120_candidate.
13. Initialize per-queue MMIO 0xb6082000 + q*0x100.
14. Mark runtime class as 0x13.
15. Reply with final primary/secondary byte sizes.

### Command 0x75 policy table write

Copies staging config from:

- 0x80004070.
- 0x80004074.
- 0x80004078.
- 0x8000407c.
- 0x80004080.
- 0x8000408c.
- 0x8000408e.
- 0x80004094.

into per-queue CP2/event07 table:

- 0x800050a8 + q*0x2c.
- 0x800050ac + q*0x2c.
- 0x800050b0 + q*0x2c.
- 0x800050b4 + q*0x2c.
- 0x800050b8 + q*0x2c.
- 0x800050c4/c6 + q*0x2c.

May mirror config to hardware CP2 pull registers 0xb6045c00/5c04/5d00/5d04 and enable queue bit in 0x800040c4 / 0xb6045a84.

### Command 0x79 rebuild CP2 pull mask

If word1 == 0:

- Clears 0x800040c4.

Otherwise scans queues 0..15 and enables pull path for queues whose mode/config requires it:

- Writes per-queue pull config to 0xb6045c00 + q*0x10.
- Writes 0xb6045c04 + q*0x10.
- Writes period 0x2f90 to 0xb6045d00 + q*0x10.
- Writes 0xb6045d04 + q*0x10.
- Acks/statuses through 0xb6045a80 = queue_bit.
- ORs queue bit into 0xb6045a84.
- ORs queue bit into 0x800040c4.

### Command 0x7a trace/stream-control toggle

Updates:

- 0x80004042 trace-disable byte.
- 0x80004054 event07 mode flags bit0.
- 0xb609000c trace/stream control bit4.

### Command 0x7b event07 mode update

Updates event07 mode flags at 0x80004054.

Calls:

- fn_dqm_patch_extended_queue_table_field_80c83f6c_candidate for mask 0x3000 shift 12.
- fn_dqm_patch_extended_queue_table_field_80c83f6c_candidate for mask 0x0f00 shift 8.
- fn_dqm_adjust_extended_queue_overhead_80c83edc_candidate when mode transitions require +4/-4 adjustment.

### Command 0x68 stats/counter reset

Calls:

- fn_dqm_clear_queue_stats_and_hw_counters_80c85360_candidate.

### Command 0x70 diagnostic query

Calls:

- fn_dqm_runtime_scratch_fill_stack_probe_80c80420_candidate with scan_start_offset 0x1668.

Returns stack/scratch diagnostic values through reply words.

## Final small helpers mapped

### fn_dqm_cp2_pull_disable_clear_queue_80c84534_candidate

Clears selected queue CP2 pull runtime fields:

- 0x800050a8 + q*0x2c.
- 0x800050ac + q*0x2c.
- 0x800050b4 + q*0x2c.
- 0x800050b8 + q*0x2c.
- 0x800050bc + q*0x2c.
- 0x800050c0 + q*0x2c.

Clears hardware CP2 pull config:

- 0xb6045c00 + q*0x10.
- 0xb6045c04 + q*0x10.
- 0xb6045d00 + q*0x10.
- 0xb6045d04 + q*0x10.

Clears queue bit from:

- 0x800040c4 runtime event07 CP2 pull queue mask.
- 0xb6045a84 event enable mask.

Acks/statuses via:

- 0xb6045a80 = queue_bit.

Cleanup:

- Deleted false internal FUN_80c84568 and replaced with lab_dqm_cp2_pull_disable_clear_mmio_and_masks_80c84568_candidate.

### fn_dqm_choose_selector1d_or_1c_by_capacity_80c844e4_candidate

Chooses selector pool based on capacity.

Inputs:

- requested_entry_count.

Registers:

- 0xb6001f74 = selector 0x1d count, max 0x200.
- 0xb6001f70 = selector 0x1c count, max 0x600.

Return:

- 0x1d if requested count fits selector 0x1d.
- Else 0x1c if it fits selector 0x1c.
- Else 0.

### fn_dqm_clamp_queue_primary_secondary_counts_80c850d4_candidate

Clamps primary and secondary queue allocation counts.

Primary limits:

- queue 0 -> max 0x400.
- queues 1..2 -> max 0x200.
- queues 3..255 -> max 0x80.

Secondary limit:

- max 0x0c.

### fn_dqm_queue_find_free_table_c_slot_80c85554_candidate

Scans four table-C entries:

- slot0: 0xb6045204.
- slot1: 0xb604520c.
- slot2: 0xb6045214.
- slot3: 0xb604521c.

If +4 word is zero, slot is free.

Return:

- 0..3 = free secondary table-C slot.
- 0x7f = no free slot.

Used by command 0x64 when secondary selector is requested. Caller converts slot to selector by adding 0x40.

### fn_dqm_patch_extended_queue_table_field_80c83f6c_candidate

Walks 32 queues with stride 0x2c. For each queue with class >=0x13, patches one masked field in the target per-queue table word.

Known use:

- Patches 0x800050cc + q*0x2c with mask 0x3000 shift 12.
- Patches 0x800050cc + q*0x2c with mask 0x0f00 shift 8.

Important:

- field_value is not masked by helper; caller must pass a fitting value.

Cleanup:

- Deleted false internal FUN_80c83fb4 and replaced with lab_dqm_patch_extended_queue_table_loop_continue_80c83fb4_candidate.

### fn_dqm_adjust_extended_queue_overhead_80c83edc_candidate

Walks all 32 queues. For class >=0x13:

- if add_overhead == 0: 0x800050d0 + q*0x2c -= 4.
- else: 0x800050d0 + q*0x2c += 4.

This tightens interpretation of 0x800050d0 as per-queue event07/CP2 overhead.

Cleanup:

- Deleted false internal FUN_80c83f28 and replaced with lab_dqm_adjust_extended_queue_overhead_subtract_80c83f28_candidate.

### fn_dqm_clear_queue_stats_and_hw_counters_80c85360_candidate

Stats/hardware counter reset helper.

Clears:

- 0x800041e8..0x80004264 shared runtime DQM counters.
- 0x80004268 + q*0x60, length 0x60, per-queue CP2/event stats.
- 0x80004ea8 + q*0x20, length 0x20, per-queue budget/fallback stats.
- 0xb6045600..0xb6045618 hardware counter/status regs.
- 0xb6045f00 + q*8 and 0xb6045f80 + q*8 counter pairs.
- 0xb6002000/2080/2100 entries for indices 0x18..0x1f and selected queue.

### fn_dqm_runtime_scratch_fill_stack_probe_80c80420_candidate

Diagnostic helper for scratch fill and stack depth.

Sentinel region:

- 0x80007000..0x80007fff.

Counts consecutive 0xdeadbeef words starting at scan_start_offset and reports approximate current stack usage relative to 0x80008000.

Known command dispatcher use:

- command 0x70 calls it with scan_start_offset 0x1668.

## Service-side sweep and state machine

### fn_dqm_queue_sweep_service_mask_80c83e34_candidate

Walks fixed service mask 0x346300ff.

Enabled bit indices:

- 0,1,2,3,4,5,6,7.
- 16,17.
- 21,22.
- 26,28,29.

For each enabled bit, calls fn_dqm_queue_service_bit_state_machine_80c83cc8_candidate.

Cleanup:

- Deleted false internal FUN_80c83e7c and replaced with lab_dqm_service_mask_sweep_loop_continue_80c83e7c_candidate.

### fn_dqm_queue_service_bit_state_machine_80c83cc8_candidate

Per-bit/queue service state machine.

Input:

- service_bit_idx / queue_idx.

Uses:

- 0x800040e8 + q*4 = queue class/mode.
- 0x80004168 + q*4 = service timestamp/age.
- 0x80004068 = runtime service mask.
- 0xb3805940 = service status mask.
- 0xb3804394 = service pending mask.
- 0xb6082000 + q*0x100 = per-queue control.

Behavior:

- class 0x13 or <=4: remove current bit from service mask.
- class 0x10: wait until elapsed age >0xc350, then set class 7 via fn_dqm_queue_set_class_and_timestamp_80c8549c_candidate.
- class 5..7: wait until queue bit appears in 0xb3805940 or age >=0x191; then clear pending bit, set per-queue ctrl bit2, decrement class by 3.
- class >7 except 0x10: restore service mask behavior/leave for next sweep.

## Queue class/timestamp helper

### fn_dqm_queue_set_class_and_timestamp_80c8549c_candidate

Sets queue class and service timestamp.

Inputs:

- queue_idx.
- new_queue_class.

Behavior:

- Clears queue bit from 0xb3804390.
- Writes queue bit to 0xb3805940.
- Writes new class to 0x800040e8 + q*4.
- Writes current tick from 0xb60010b8 to 0x80004168 + q*4.
- Updates service mask 0x80004068.
- Clears 0x800040bc.
- For special mask bits 0x40048001, updates 0x800040b4.

### fn_dqm_tick_delta_since_80c807fc_candidate

Computes elapsed ticks from saved tick using 0xb60010b8 tick counter.

Wrap handling:

- If saved_tick < current_tick, add 0x1fffffff.

## Ghidra cleanup results

Final cleanup removed false functions and retained labels only. No bytes were deleted.

False splits cleaned:

- FUN_80c8199c -> label inside vector49 handler.
- FUN_80c81a84 / 80c81b4c / 80c81c48 / 80c81c74 / 80c81cc0 / 80c81d0c / 80c81e10 / 80c82050 / 80c82158 / 80c821bc / 80c821fc / 80c8226c / 80c82370 -> labels inside vector49 dispatcher.
- FUN_80c8409c / 80c8407c / 80c84160 / 80c841a8 / 80c841b0 / 80c841cc / 80c841e4 / 80c842d8 / 80c84414 -> labels inside event0c handler.
- FUN_80c8465c / 80c847ac / 80c847fc / 80c84828 / 80c84830 / 80c84884 / 80c849c8 / 80c849ec / 80c849f0 / 80c84a70 / 80c84b1c / 80c84c3c / 80c84c6c / 80c84e50 / 80c84e7c / 80c84ec8 / 80c84ee8 / 80c84f54 / 80c84fcc / 80c84fe4 / 80c84ff8 / 80c85074 / 80c850a4 -> labels inside control dispatcher.
- FUN_80c83e7c -> lab_dqm_service_mask_sweep_loop_continue_80c83e7c_candidate.
- FUN_80c83f28 -> lab_dqm_adjust_extended_queue_overhead_subtract_80c83f28_candidate.
- FUN_80c83fb4 -> lab_dqm_patch_extended_queue_table_loop_continue_80c83fb4_candidate.
- FUN_80c84420 -> lab_dqm_event0c_reactivate_queue_state_tail_80c84420_candidate.
- FUN_80c84494 -> lab_dqm_event0c_reply_header_merge_80c84494_candidate.
- FUN_80c84568 -> lab_dqm_cp2_pull_disable_clear_mmio_and_masks_80c84568_candidate.

Final state:

- No known fake functions remain in the mapped DQM/FPM/CP2 path.
- Branches now land on labels instead of wrong standalone functions.
- Shared reply tails and inline blocks are documented as labels.
- Parent functions own their real prologue/epilogue ranges.

## Result / working hypothesis

The OEM path is not a plain GENET TDMA-only flow. The relevant Ethernet-side packet movement path appears to involve:

- DQM queue subsystem.
- FPM token pools/endpoints.
- CP2 event pull/reinject/budget mechanisms.
- Per-queue runtime class/mode tables.
- Mailbox command/control path.
- Stream/trace port at 0xb609d000.
- FPM pool token endpoint at 0xb2200200.

This explains why OpenWrt direct GENET TDMA register work alone may not reproduce OEM packet movement. OEM firmware appears to coordinate packet buffers/tokens through DQM/FPM/CP2 hardware and runtime queue policy tables.

## Remaining uncertainty

The path is functionally mapped, but exact names of some hardware registers should remain candidate-level until correlated with runtime probes or Broadcom documentation:

- Exact semantics of several 0xb6045aXX DQM command/status registers.
- Exact bit meaning inside 0xb6082000 per-queue control word.
- Exact field meaning inside 0x800050cc and 0x800050d0.
- Exact behavior of runtime masks at 0x8000800c, 0x80008074, 0x800081c0.
- Whether 0x8000811c / 0x80008120 are runtime status words or decompiler artifacts in one dispatcher condition.

## Recommended next work

1. Preserve this cleaned Ghidra state.
2. Export a symbol/comment script or Ghidra archive snapshot before further experiments.
3. Use runtime probes to compare OEM expected values against OpenWrt around:
   - 0x12200200 / 0x12200208 / 0x12200210 / 0x12200218.
   - 0x12200044.
   - 0x16045a00..0x16045a30.
   - 0x16045c00..0x16045d04.
   - 0x16082000 + q*0x100.
   - 0x16045000 / 0x16045100 / 0x16045200.
   - 0x16001de0..0x16001dfc mailbox in/out.
4. For OpenWrt driver direction, stop treating GENET TDMA as fully standalone until DQM/FPM token setup is accounted for.
5. Investigate which OpenWrt driver layer should initialize the FPM/DQM queue tables or minimally emulate the OEM queue/token enable path.
