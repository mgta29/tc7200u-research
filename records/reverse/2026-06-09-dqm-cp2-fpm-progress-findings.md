# TC7200U reverse progress: DQM, CP2, FPM token path

Date: 2026-06-09
Scope: Ghidra reverse work around TC7200U BCM3383 DQM queue, CP2 token/event handling, FPM endpoint return path, and runtime overlay scratch area.

## Current high-level finding

The investigated chain is not the direct GENET 0x12c00000 TDMA register setup. It is the OEM DQM/FPM/CP2 event path that appears to sit beside or underneath the Ethernet datapath. Multiple independent handlers feed valid token-like words into FPM endpoint 0xb2200200, physical 0x12200200. This strengthens the theory that the OEM Ethernet path uses DQM/FPM token handling and not only the Linux-visible GENET TDMA path.

Important FPM endpoint already confirmed:

- 0xb2200200 / physical 0x12200200 = FPM pool0 endpoint / token return port candidate
- 0xb2200044 / physical 0x12200044 = FPM backing-base low bus-visible field, read by endpoint setup functions
- valid token convention observed: negative word, bit31 set
- bit30 means special mailbox command needed before returning token
- token low12 is repeatedly used for counts, sizes, or mismatch checks

## Address interpretation rules confirmed

- KSEG1 MMIO physical conversion: physical = kseg1 - 0xa0000000
- Example: 0xb6045740 -> 0x16045740
- Example: 0xb2200200 -> 0x12200200
- Example: 0xb609d000 -> 0x1609d000
- Example: 0xb38043a0 -> 0x138043a0

Ghidra scalar-search rule for this setup:

- Scalar searches are decimal input, not hex.
- Example: search 0xb220 high half as decimal 45600 when searching for 0xb220xxxx construction.

## Runtime overlay warning

Major correction: low addresses around 0x80004040..0x800056xx must be treated as DQM runtime overlay or scratch RAM in this path, even though Ghidra static listing still shows boot/vector code there.

Do not blindly create hard primary data labels on these addresses if that makes the static listing misleading. Prefer comments like runtime overlay table.

Confirmed runtime overlay uses:

- 0x80004068 = runtime DQM service mask / scratch word
- 0x800040b4 = runtime special service mask word
- 0x800040bc = runtime scratch / flag clear word
- 0x800040c8 + queue_id*2 = runtime dynamic limit RAM table
- 0x800040e8 + queue_id*4 = runtime queue class or mode table
- 0x80004168 + queue_id*4 = runtime queue service timestamp / age table
- 0x8000423c..0x80004250 = patchable low12 mismatch stub words
- 0x80005628 + queue_id*4 = runtime queue backoff counter table

Do not treat the original instruction bytes in this range as live immutable code after DQM init. DQM init and related service handlers reuse this area as runtime state.

## Important counter correction from assembly

At code address 0x80c8269c, the data target is 0x800041f8. The code address must not be used in the symbol name.

Assembly proved:

- 80c82698 loads from 0x800041f8
- 80c8269c increments
- 80c826a0 stores to 0x800041f8

Correct symbol:

- 0x800041f8 -> DQM_QUEUE_TOKEN_OR_CMD_REJECT_COUNT_800041f8_candidate

Do not use:

- DQM_QUEUE_EVENT_SIZE_STATS_80c8269c_candidate
- DQM_QUEUE_EVENT_SIZE_STATS_80004274_candidate for this standalone counter

Also corrected:

- 0x80004220 is incremented as a counter, not assigned a fixed debug constant in that assembly block
- better name: DQM_CP2_DIRECT_TOKEN_PATH_COUNT_80004220_candidate

## Core DQM init and setup functions

### fn_dqm_queue_subsystem_init_80c80c6c_candidate

Main wrapper for this DQM queue subsystem path. It zeroes and initializes runtime state, calls queue profile/table setup, FPM endpoint setup, and registers vector 0x49 handler.

Key behavior:

- zeroes low runtime/scratch area near 0x80004040 for a large span
- calls early control setup
- calls queue profile/table init helpers
- calls FPM endpoint setup helper
- sets DQM queue registers under 0xb600xxxx and 0xb604xxxx
- registers vector 0x49 handler through FUN_80c739f8(FUN_80c81960, 0x49)
- enables vector 0x49 through FUN_8005fa08(0x49, 1)

Current interpretation: DQM queue subsystem init wrapper, not GENET 0x12c00000 TDMA setup.

### fn_dqm_or_queue_fpm_endpoint_setup_80c809f0_candidate

Programs a DQM/FPM endpoint consumer register bank under 0xb609xxxx, physical 0x1609xxxx.

Important writes:

- 0xb6090038 = 0x12200200
- 0xb6090044 = *(0xb2200044) & 0x0fffffff
- 0xb6090128 = 0x12200208
- 0xb609012c = 0x12200210
- 0xb6090130 = 0x12200218
- 0xb6090068 = 0xc0001617

Same pattern also exists in fn_dqm_or_queue_fpm_endpoint_setup_80c73f74_candidate.

Interpretation: endpoint mapping from DQM queue side to FPM pool endpoints. It reads FPM backing-base low field and masks to low 28 bits.

### fn_dqm_queue_table_init_80c80884_candidate

Initializes DQM queue tables and clears queue table memory.

Important regions:

- 0xb6050000 -> 0x16050000 clear table region
- 0xb6045000 -> 0x16045000 queue table A
- 0xb6045100 -> 0x16045100 queue table B
- 0xb6045200 -> 0x16045200 queue table C

Decompile expressions like iVar + -0x49fb0000 are MMIO/global access to 0xb6050000 + offset, not stack.

### fn_dqm_queue_profile_init_80c80b1c_candidate

Builds queue profiles through fn_dqm_queue_write_profile_entry_80c80a70_candidate.

Fixed profile calls include:

- queue 0x1e, type/count 4, size 0x40
- queue 0x1f, type/count 4, size 0x80
- queue 0x1b, type/count 1, size 0x08
- queue 0x1a, type/count 4, size 0x100
- queue 0x19, type/count 4, size 0x100
- queue 0x18, type/count 3, size 0xc0

Looped queues:

- 0x00..0x0f type/count 2 size 0x80
- 0x20..0x2f type/count 3 size 0xc0

### fn_dqm_queue_write_profile_entry_80c80a70_candidate

Writes a per-queue profile entry into low or high profile tables depending on queue id.

Parameters:

- queue_id
- queue_type_or_group_count
- queue_size
- queue_offset_accum

Important behavior:

- writes count/type minus one
- writes size and current accumulated offset
- writes step = queue_size / count shifted left 16
- advances offset accumulator by queue_size

## Mailbox writer

### fn_dqm_queue_write_4word_mailbox_80c807ac_candidate

Small helper that writes a 4-word structure to DQM mailbox registers:

- 0xb6001df0 / 0x16001df0 = word0
- 0xb6001df4 / 0x16001df4 = word1
- 0xb6001df8 / 0x16001df8 = word2
- 0xb6001dfc / 0x16001dfc = word3

Known payloads:

- CP2 token handlers use word0 = 0x6c, word1 = 4, word2 = token with bit30 cleared
- CP2 event body direct-token path uses word0 = 0x6c, word1 = 0, word2 = token with bit30 cleared
- event18 snapshot helper uses record ids 0x18..0x1b as word0 values

Interpretation: DQM mailbox / command writer.

## Vector 0x49 event handling

### fn_dqm_queue_vector49_handler_80c81960_candidate

Top-level vector 0x49 handler.

Behavior:

- disables vector 0x49 with FUN_8005fa08(0x49, 0)
- calls fn_dqm_queue_vector49_event_dispatch_80c819cc_candidate
- clears or acknowledges DQM queue state:
  - 0xb6001818 = 0
  - 0xb6045704 = 0x8000
  - 0xb600103c |= 0x80000000
- re-enables vector 0x49 with FUN_8005fa08(0x49, 1)

### fn_dqm_queue_vector49_event_dispatch_80c819cc_candidate

Main DQM event dispatcher and drain loop. Decompiler has many unreachable-block warnings, so keep final interpretation conservative and verify with assembly when needed.

Main sources:

- 0xb6045740 / physical 0x16045740 = DQM event FIFO
- 0xb6045a80 / physical 0x16045a80 = DQM event/status register

Main status handling:

- calls fn_dqm_cp2_token_event_handler_80c8138c_candidate
- calls fn_dqm_cp2_sel1a_token_event_handler_80c81654_candidate
- if 0xb6045a80 & 0x3c1a80ea is nonzero, calls fn_dqm_queue_handle_status_bits_80c82d34_candidate
- repeatedly calls fn_dqm_queue_sweep_service_mask_80c83e34_candidate around the event loop

Event dispatch:

- event_type = event_word >> 26
- event_type 0x07 = token/FPM-like path
- event_type 0x0c = command/count/doorbell-like path using 0xb6045a20 and 0xb6045a24
- event_type 0x16 or 0x17 -> FUN_80c80494(event_word)
- event_type 0x18 -> fn_dqm_event18_fifo_snapshot_mailbox_dump_80c80568_candidate(event_word)
- other event types -> FUN_80c8065c(event_word)

Event type 0x07 behavior:

- reads additional FIFO/token words from 0xb6045740
- queue_id = event word bits around 20, masked to 0x1f
- updates per-queue event stats around 0x80004270 and 0x80004274
- if token is valid negative and bit30 is set, clears bit30 and writes mailbox command word0 0x6c, word1 4, word2 token
- writes valid token-like words to FPM_POOL0_ENDPOINT_12200200_candidate at 0xb2200200

Important correction:

- 0x80004274 is an indexed per-queue event size/low12 stat when used as 0x80004274 + queue_id*0x60
- standalone increments should not use 0x80004274 unless assembly proves that exact data address

## CP2 token/event handlers

### fn_dqm_cp2_token_event_handler_80c8138c_candidate

CP2 selector 0x19 token/event handler.

Behavior:

- checks possible status/global guard at FUN_80007ffc & 1, likely mislabeled global/status word, not trusted as function pointer
- setCopReg(2, 0x800, 0x19)
- reads:
  - getCopReg(2, 0xd802) -> cp2_event_meta
  - getCopReg(2, 0xd801) -> cp2_token_word
  - getCopReg(2, 0xd803) -> cp2_aux_word
- queue_id = (cp2_event_meta >> 20) & 0x1f
- increments per-queue CP2 event stats at 0x80004290 + queue_id*0x60
- writes ack to 0xb3401910 / physical 0x13401910

Queue class decision:

- uses runtime overlay table 0x800040e8 + queue_id*4
- do not confuse with queue metadata table 0x800050c8/0x800050cc

Token path:

- if queue class/mode < 0x13 and token is valid negative:
  - if bit30 set, clear bit30 and write mailbox command word0 0x6c, word1 4, word2 token
  - write token to 0xb2200200 / 0x12200200
- invalid token increments DQM_QUEUE_TOKEN_WORD_NOT_VALID_COUNT_800041fc_candidate

Alternate stream path:

- if queue class/mode >= 0x13:
  - updates stats at 0x80004268 and 0x8000426c indexed by queue
  - writes 5-word sequence to 0xb609d000 / physical 0x1609d000

### fn_dqm_cp2_sel1a_token_event_handler_80c81654_candidate

Paired CP2 selector 0x1a token/event handler.

Behavior:

- setCopReg(2, 0x800, 0x1a)
- reads:
  - getCopReg(2, 0xd800) -> cp2_event_meta
  - getCopReg(2, 0xd801) -> cp2_token_word
  - getCopReg(2, 0xd802) -> cp2_aux_word
  - getCopReg(2, 0xd803) -> cp2_flags_word
- queue_id = (cp2_event_meta >> 20) & 0x1f
- increments 0x80004294 + queue_id*0x60

Special flag:

- if cp2_flags_word bit25 is set:
  - setCopReg(2, 0x800, 0x1b)
  - setCopReg(2, 0xd800, cp2_token_word)
  - increments 0x800042c4 + queue_id*0x60

Then same basic decision:

- queue class >= 0x13 -> stream sequence to 0xb609d000
- queue class < 0x13 and valid token -> possible mailbox then return token to 0xb2200200
- invalid token -> token not valid counter

## Live status bit handling

### fn_dqm_queue_handle_status_bits_80c82d34_candidate

Handles selected live status bits from:

- 0xb6045a80 / physical 0x16045a80

Mask:

- 0x3c1a80ea

Behavior:

- scans masked bits
- for each set bit, writes 1 << bit_idx back to 0xb6045a80 to ack
- calls fn_dqm_cp2_handle_status_bit_80c82bd8_candidate(bit_idx) until it returns 0

Note: decompiler loop bound appears to stop at bit_idx < 0x10 despite high bits in mask. Verify with assembly before finalizing.

### fn_dqm_cp2_handle_status_bit_80c82bd8_candidate

Per-status-bit CP2/DQM event extractor.

Accepted bit masks:

- 0x00451024
- 0xafb00000

Selector rule:

- if status bit is in 0x00451024, cp2_selector = status_bit_idx | 0x20
- else cp2_selector = status_bit_idx

Behavior:

- setCopReg(2, 0x800, cp2_selector)
- reads getCopReg(2, 0xd800)
- writes DQM_CP2_EVENT_PULL_CTRL_16045a00_candidate at 0xb6045a00 = low12 | selector << 20
- calls fn_dqm_cp2_poll_event_pull_status_80c82b54_candidate
- if accepted, reads token and optional aux words, updates runtime table 0x800050bc + idx*0x2c, then calls fn_dqm_cp2_event_body_return_or_stream_80c825ac_candidate

### fn_dqm_cp2_poll_event_pull_status_80c82b54_candidate

Polls DQM CP2 event pull status:

- 0xb6045a1c / physical 0x16045a1c

Status behavior:

- 0xffffffff = busy, keep polling up to about 400 loops
- 0 = accepted, return 1
- nonzero other = log pull_status | 0xa0000000 to 0xb6045e00 + idx*8, ack bit in 0xb6045a80, return 0

Return interpretation:

- return 1 = continue decode/body
- return 0 = logged nonzero status and acked bit

## Main CP2 event body

### fn_dqm_cp2_event_body_return_or_stream_80c825ac_candidate

Main CP2/DQM event body helper. Called after per-status-bit pull succeeds.

Input context layout:

- +0x00 = cp2 selector
- +0x01 = queue id
- +0x02 = event/path flag
- +0x10 = CP2 token word
- +0x14 = CP2 aux word
- +0x20 = expected token low12
- +0x22 = event/count low12

Direct token path:

- if DQM_CP2_SELECTOR_MODE_TABLE_16045b00_candidate[selector] < 2:
  - if token valid negative:
    - if bit30 set, clear bit30 and write mailbox command word0 0x6c, word1 0, word2 token
    - write token to FPM_POOL0_ENDPOINT_12200200_candidate at 0xb2200200
  - else increment 0x800041f8 reject counter
  - increment 0x80004220 direct-token path count
  - return

Submit/stream path:

- writes aux/token to:
  - 0xb6045a0c = aux
  - 0xb6045a08 = token
  - 0xb6045a04 = 1 trigger
- waits for 0xb6045a04 to clear
- timeout increments DQM_CP2_SUBMIT_TIMEOUT_COUNT_80004210_candidate
- reads result token from 0xb6045a10
- reads status from 0xb6045a18

If result token valid negative:

- if low12 mismatch against expected_low12, calls fn_dqm_cp2_patch_low12_delta_stub_80c811a4_candidate
- increments result token stats
- writes result token to 0xb2200200

If result token not valid:

- writes stream/doorbell through 0xb38043a0 / physical 0x138043a0
- updates stream stats
- adjusts dynamic queue limit state

Dynamic limit state:

- runtime RAM table near 0x800040c8 + queue_id*2
- MMIO table 0xb6045500 + queue_id*4
- queue backoff count table near runtime overlay 0x80005628 + queue_id*4

## Low12 mismatch patcher

### fn_dqm_cp2_patch_low12_delta_stub_80c811a4_candidate

Called when returned token low12 does not match expected low12.

Inputs:

- cp2_event_ctx + 0x20 = expected_low12
- observed_low12 = actual/result token low12

It patches runtime words at:

- 0x8000423c
- 0x80004240
- 0x80004244
- 0x80004248
- 0x8000424c
- 0x80004250

These words decode as MIPS instructions in the static view, and the function writes instruction words such as:

- 0x21080004 or 0x21080005 = addi t0,t0,4 or 5
- 0x21290004 or 0x21290005 = addi t1,t1,4 or 5
- 0x1540fffb or 0x1540fffc = bne pattern
- 0x214afffc or 0x214afffd = addi t2,t2,-4 or -3
- 0x1000fff3 or 0x1000fff4 = branch back pattern
- 0x00000000 = nop

Delta policy:

- observed >= expected:
  - delta < 7 -> small forward drift patch
  - delta < 0x100 -> medium forward drift patch
  - delta >= 0x100 -> set word5 to 1
- observed < expected:
  - delta < 7 -> patch word0
  - delta < 0x100 -> patch word1
  - delta >= 0x100 -> patch word2

Interpretation: CP2/DQM token low12 mismatch recovery or adjustment stub patcher.

## Service sweep and queue state machine

### fn_dqm_queue_sweep_service_mask_80c83e34_candidate

Walks fixed service mask:

- 0x346300ff

Enabled bits:

- 0,1,2,3,4,5,6,7,16,17,21,22,26,28,29

For each set bit, calls:

- fn_dqm_queue_service_bit_state_machine_80c83cc8_candidate(bit_idx)

### fn_dqm_queue_service_bit_state_machine_80c83cc8_candidate

Per-bit service state machine.

Uses runtime overlay:

- 0x800040e8 + queue_idx*4 = queue class/mode
- 0x80004168 + queue_idx*4 = service timestamp/age base
- 0x80004068 = runtime service mask

Uses MMIO/global masks:

- 0xb3805940 / 0x13805940 = DQM_QUEUE_SERVICE_STATUS_MASK_13805940_candidate
- 0xb3804394 / 0x13804394 = DQM_QUEUE_SERVICE_PENDING_MASK_13804394_candidate
- 0xb6082000 + queue_idx*0x100 / 0x16082000 + offset = per-queue control

Queue class behavior:

- class == 0x13 or class <= 4: remove this bit from runtime service mask
- class == 0x10: wait until age >= 0xc351, then call fn_dqm_queue_set_class_and_timestamp_80c8549c_candidate(queue_idx, 7)
- class 5..7: wait until queue bit is present in 0xb3805940 or age >= 0x191, then clear bit in 0xb3804394, set bit2 in 0xb6082000 + queue_idx*0x100, and decrement class by 3
- class > 7 except 0x10: restore runtime service mask to 0x346300ff

### fn_dqm_tick_delta_since_80c807fc_candidate

Reads current tick:

- 0xb60010b8 / physical 0x160010b8 = DQM_TICK_COUNTER_160010b8_candidate

Returns:

- saved_tick - current_tick
- if saved_tick < current_tick, adds 0x1fffffff for wrap correction

Used by service state machine for age thresholds:

- 0xc351
- 0x191

### fn_dqm_queue_set_class_and_timestamp_80c8549c_candidate

Queue class/timestamp transition helper.

Inputs:

- queue_idx
- new_queue_class

Behavior:

- computes queue bit mask
- clears queue bit from 0xb3804390 active/pending mask
- writes queue bit to 0xb3805940 service status mask
- writes new class to runtime overlay 0x800040e8 + queue_idx*4
- stores current DQM tick from 0xb60010b8 to runtime overlay 0x80004168 + queue_idx*4
- clears runtime scratch word 0x800040bc
- updates special service mask 0x800040b4 for bits in 0x40048001

## Event type 0x18 helper

### fn_dqm_event18_fifo_snapshot_mailbox_dump_80c80568_candidate

Called when dispatcher sees event_type == 0x18.

Behavior:

- initializes a stack snapshot buffer with 0xdeadbee7
- stores first event word from dispatcher as snapshot[0]
- reads additional words from 0xb6045740 event FIFO into snapshot[1..9]
- if snapshot[8] bit17 is clear, sends four mailbox records through fn_dqm_queue_write_4word_mailbox_80c807ac_candidate
- if snapshot[8] bit17 is set, writes a runtime patch/debug word at 0x80004238

Mailbox records:

- record 0: word0 0x18, word1 snapshot[0], word2 snapshot[1], word3 snapshot[2]
- record 1: word0 0x19, word1 snapshot[3], word2 snapshot[4], word3 snapshot[5]
- record 2: word0 0x1a, word1 snapshot[6], word2 snapshot[7], word3 snapshot[8]
- record 3: word0 0x1b, word1 snapshot[9], word2 snapshot[10], word3 snapshot[11]

snapshot[10] and snapshot[11] remain 0xdeadbee7 in the current decompile. Do not fix unless assembly proves two more FIFO reads.

Interpretation: extended DQM event 0x18 diagnostic or forwarding helper.

## Functions already renamed or candidate names

- FUN_80c807ac -> fn_dqm_queue_write_4word_mailbox_80c807ac_candidate
- FUN_80c807fc -> fn_dqm_tick_delta_since_80c807fc_candidate
- FUN_80c80830 -> fn_dqm_queue_preload_index_ports_80c80830_candidate
- FUN_80c80884 -> fn_dqm_queue_table_init_80c80884_candidate
- FUN_80c809c8 -> fn_dqm_queue_set_global_field0c_80c809c8_candidate
- FUN_80c809f0 -> fn_dqm_or_queue_fpm_endpoint_setup_80c809f0_candidate
- FUN_80c80a70 -> fn_dqm_queue_write_profile_entry_80c80a70_candidate
- FUN_80c80b1c -> fn_dqm_queue_profile_init_80c80b1c_candidate
- FUN_80c80c3c -> fn_dqm_queue_set_small_cfg_80c80c3c_candidate
- FUN_80c80c6c -> fn_dqm_queue_subsystem_init_80c80c6c_candidate
- FUN_80c80e50 -> fn_dqm_queue_early_ctrl_init_80c80e50_candidate
- FUN_80c80e7c -> fn_dqm_queue_clear_status30_set_bit1_delay_80c80e7c_candidate
- FUN_80c80ec8 -> fn_dqm_queue_enable_cfg_bits70_80c80ec8_candidate
- FUN_80c80f54 -> fn_dqm_queue_status_check_set_mode0c_80c80f54_candidate
- FUN_80c811a4 -> fn_dqm_cp2_patch_low12_delta_stub_80c811a4_candidate
- FUN_80c8138c -> fn_dqm_cp2_token_event_handler_80c8138c_candidate
- FUN_80c81654 -> fn_dqm_cp2_sel1a_token_event_handler_80c81654_candidate
- FUN_80c81960 -> fn_dqm_queue_vector49_handler_80c81960_candidate
- FUN_80c819cc -> fn_dqm_queue_vector49_event_dispatch_80c819cc_candidate
- FUN_80c82b54 -> fn_dqm_cp2_poll_event_pull_status_80c82b54_candidate
- FUN_80c82bd8 -> fn_dqm_cp2_handle_status_bit_80c82bd8_candidate
- FUN_80c82d34 -> fn_dqm_queue_handle_status_bits_80c82d34_candidate
- FUN_80c825ac -> fn_dqm_cp2_event_body_return_or_stream_80c825ac_candidate
- FUN_80c83cc8 -> fn_dqm_queue_service_bit_state_machine_80c83cc8_candidate
- FUN_80c83e34 -> fn_dqm_queue_sweep_service_mask_80c83e34_candidate
- FUN_80c8549c -> fn_dqm_queue_set_class_and_timestamp_80c8549c_candidate
- FUN_80c80568 -> fn_dqm_event18_fifo_snapshot_mailbox_dump_80c80568_candidate

## Remaining near-term reverse targets

Next recommended functions:

1. FUN_80c80494
   - handles dispatcher event_type 0x16 and 0x17
   - likely paired event body beside event18

2. FUN_80c8065c
   - handles all other event types from the dispatcher
   - likely generic unknown-event or error path

3. FUN_80c83fc4
   - called by event_type 0x0c command/count path when event_word bit0 is set
   - likely command tail or callback helper

4. Repair or verify suspicious symbols:
   - FUN_8000811c in dispatcher loop may be mislabeled global/status word
   - FUN_80007ffc in CP2 handlers may be mislabeled global/status word
   - keep decompiler warnings in mind around 80c819cc and split fragments like 80c81b4c

## Working conclusion

This work found a coherent OEM DQM/FPM/CP2 token-management subsystem:

- DQM queue init builds queue profiles and runtime state
- FPM endpoints are programmed into DQM-facing registers
- vector 0x49 drains DQM event FIFO and CP2 token events
- valid token words are repeatedly returned to FPM endpoint 0x12200200
- special tokens with bit30 use a DQM 4-word mailbox before token return
- CP2 event body can either return tokens to FPM or submit/stream through 0xb6045a08/0c/04 and 0xb38043a0
- low runtime area 0x80004040..0x800056xx is heavily reused as scratch, stats, runtime tables, and patchable code words

This does not directly solve GENET TDMA not consuming descriptors, but it provides the clearest OEM-side evidence so far that Ethernet token and queue operation depends on DQM/FPM and CP2 event machinery rather than only the obvious GENET 0x12c00000 TDMA registers.
