# 2026-06-11 DQM event1800008 reverse progress log

## Scope
This log records the reverse-engineering progress for the TC7200U OEM DQM/CP2/FPM service path around event mask 0x01800008. Work was done in Ghidra only. No git action is included or required.

## High-level result
The event 0x01800008 path is now structurally mapped from runtime initialization to event handler, dispatcher, selector routing, FPM token request logic, and several direct pending-bit helpers. Current estimate: event1800008 path about 72 percent mapped, whole DQM/CP2/FPM subsystem about 58 to 62 percent, OpenWrt-useful hardware map about 45 percent.

## Main chain now mapped
- fn_dqm_runtime_queue_profile_window_and_irq_init_80c7ce70_candidate installs and enables the event path.
- fn_dqm_event1800008_service_ack_and_rearm_80c7d2b8_candidate masks event 0x01800008, services pending work, acknowledges queue/global bits, then re-arms the event.
- fn_dqm_event1800008_dispatch_pending_services_80c7cbf0_candidate is the central pending-bit dispatcher.
- fn_dqm_dispatch_selector_index_port_80c7dc48_candidate forwards selector-based service requests into the real selector helper.
- fn_dqm_selector_push_genet_stub_event_or_fpm_return_80c7e158_candidate pushes CP2 f801 command triples for GENET stub targets or returns unexpected selector data to FPM pool0.

## Runtime init function cleaned
Function renamed: fn_dqm_runtime_queue_profile_window_and_irq_init_80c7ce70_candidate.

Findings:
- The old name fn_stub_patch_install_genet_500_510 was too narrow.
- The function does more than GENET 0x12c00500 and 0x12c00510 setup.
- It enables CP0 Status bit 0x40000000.
- It initializes runtime helper state through FUN_80c801a8() and FUN_80c801b0(0, 0x1000).
- It stores helper selector values under 0x80007110..0x8000711c.
- It stores GENET target pointers: 0x80007118 = 0x12c00510 and 0x8000711c = 0x12c00500.
- It allocates two 0x0c-byte runtime records through the bump allocator.
- It clears and seeds the two runtime records with fixed bytes.
- It installs many fixed DQM queue profiles through fn_dqm_emit_queue_profile_record_scaled_80c7bebc_candidate().
- It calls table/window setup helpers FUN_80c7bf70(), FUN_80c7c008(), and FUN_80c7c2a8().
- It copies a 0x4000-byte table from 0x817e7ffc into the b6052000 DQM pair-copy window.
- It calls additional setup helpers FUN_80c7c068(0,1,1) and FUN_80c7c090().
- It programs queue/event halfword values at 0xb6001902, 0xb6001906, 0xb600190a, and 0xb600190e to 0x40.
- It clears DQM command/status mirror 0xb6001028 with 0xffffffff.
- It acknowledges/enables queue mask 0x40383c08 through 0xb6001818 and 0xb6001810.
- It enables global event mask 0x000c0000 through 0xb6001014 and 0xb6001010.
- It installs FUN_80c7d2b8 as handler for event/mask 0x01800008 and enables it through FUN_8005fa08(0x01800008, 1).

Change summary:
- Function plate comment updated to describe DQM runtime queue-profile, b605 window, and IRQ/event initialization.
- Local uVar1 renamed to reg_value.
- Fake split around 0x80c7d0a4 was recognized as part of the parent flow rather than a real standalone function.

## Event handler cleaned
Function renamed: fn_dqm_event1800008_service_ack_and_rearm_80c7d2b8_candidate.

Behavior:
- Disables event/mask 0x01800008 with FUN_8005fa08(0x01800008, 0).
- Calls fn_dqm_event1800008_dispatch_pending_services_80c7cbf0_candidate().
- Acknowledges DQM queue/event mask 0x40383c08 by writing 0xb6001818.
- Writes global DQM acknowledge or enable value 0x000c0000 to 0xb6001014.
- Re-enables event/mask 0x01800008 through FUN_8005fa08(0x01800008, 1).

Result:
- Handler is simple and essentially done.
- DAT_b6001014 labeled as DQM_GLOBAL_IRQ_ACK_OR_ENABLE_16001014_candidate.

## Main dispatcher cleaned
Function renamed: fn_dqm_event1800008_dispatch_pending_services_80c7cbf0_candidate.

Behavior:
- Loops until masked event bits clear and service-state bits show idle or ready.
- Checks pending bits in 0x8000800c against mask 0x40383c08.
- Dispatches 0x00080000 to fn_dqm_service_bit80000_dispatch_record_by_selector_80c7db4c_candidate().
- Dispatches 0x00100000 to fn_dqm_service_bit100000_route_record_80c7d318_candidate().
- Dispatches 0x00200000 to fn_dqm_service_bit200000_route_mode2_record_80c7d520_candidate().
- Dispatches 0x00000008 to FUN_80c7e050(), not yet cleaned.
- Uses selector gates at 0x80007110 and 0x80007114 to call fn_dqm_dispatch_selector_index_port_80c7dc48_candidate() for selectors 0x0a, 0x0b, 0x0c, and 0x0d.
- Waits for 0x80008160 bit2 through FUN_80c7d99c().
- Waits for 0x80008160 bit6 through FUN_80c7da84().
- Calls fn_runtime_stub_patch_dispatcher() when 0x8000800c bit 0x40000000 is set.

Change summary:
- Local iVar1 renamed to service_selector.
- Dispatcher plate comment added.
- Direct pending-bit helper names updated in the comment as they were resolved.
- Note kept that comparison (0x80008160 & 0x10) != 1 is suspicious because bit 0x10 cannot equal 1. Assembly should be checked before changing logic.

## Selector wrapper cleaned
Function renamed: fn_dqm_dispatch_selector_index_port_80c7dc48_candidate.

Behavior:
- Takes service_selector, usually 0x0a, 0x0b, 0x0c, or 0x0d.
- Reads selector index/port word from 0xb6001c00 + service_selector * 0x10.
- Calls fn_dqm_selector_push_genet_stub_event_or_fpm_return_80c7e158_candidate(service_selector, selector_value).
- Returns forwarded undefined8 result.

Result:
- Wrapper is simple and done.

## Selector CP2/FPM helper cleaned
Function renamed: fn_dqm_selector_push_genet_stub_event_or_fpm_return_80c7e158_candidate.

Behavior:
- service_selector 0x0a or 0x0b routes to target from 0x80007118, initialized to GENET_REG_12c00510.
- service_selector 0x0c or 0x0d routes to target from 0x8000711c, initialized to GENET_REG_12c00500.
- Other selectors write selector_value to FPM_POOL0_ENDPOINT_12200200_candidate and return combined 0x04208000:b2200200 value.
- Valid selectors push three words to CP2 register 0xf801: 0x04208000, selector_value, and target_reg_addr & 0x1fffffff.

Important interpretation:
- 0x1fffffff masking converts mapped register pointer to low 29-bit physical or bus address.
- 0x04208000 is a fixed CP2 command/event word for this path.
- FPM pool0 is only used here for unexpected selector IDs.

## Direct pending bit 0x00100000 helper cleaned
Function renamed: fn_dqm_service_bit100000_route_record_80c7d318_candidate.

Behavior:
- Reads source_index_or_token from 0xb6001d40.
- Builds runtime record pointer: 0x80000000 | ((source_index_or_token + 0x100) & 0xffff).
- Reads record +0x1c selector, +0x24 word A, and +0x28 word B.
- Routes by runtime mode 0x80007120.
- Mode 1 uses b3401ca0/b3401cd0 output pairs.
- Mode 2 uses b4201c00/b4201c10 output pairs.
- Default mode uses b6001d60/b6001d70 output pairs.
- record_selector 0x0d selects alternate lane; other selectors select lane0.
- Enabled routes program 0xb2200224 = (record_word_b & 0xfffff000) | 0x801.
- Then they publish record_word_a and record_word_b to the selected output pair.
- Finally writes source_index_or_token back to 0xb6001c00.

Change summary:
- Function renamed and plate comment added.
- Locals renamed: record_base, output_word_b_ptr, record_selector, record_word_b, record_word_a, gate_value, source_index_or_token.
- Cautious labels introduced for mode gates and default output words.

## Direct pending bit 0x00200000 helper cleaned
Function renamed: fn_dqm_service_bit200000_route_mode2_record_80c7d520_candidate.

Behavior:
- Reads source_index_or_token from 0xb6001d50.
- Builds runtime record pointer in the same 0x80000000 | ((token + 0x100) & 0xffff) form.
- Reads record +0x28 as record_word_b and record +0x24 as record word A.
- If record +0x1c equals 1, uses mode2 lane1 gate 0xb600190e and output pair b4201c10/b4201c14.
- Otherwise uses mode2 lane0 gate 0xb600190a and output pair b4201c00/b4201c04.
- Each enabled route programs 0xb2200224 = (record_word_b & 0xfffff000) | 0x801.
- Writes source_index_or_token back to 0xb6001c00.

Change summary:
- Function renamed and plate comment added.
- Locals renamed: record_base, output_word_b_ptr, record_word_b, gate_value, source_index_or_token.
- Mode2 output word labels added for b420 lane0/lane1 pairs.

## Direct pending bit 0x00080000 dispatcher cleaned
Function renamed: fn_dqm_service_bit80000_dispatch_record_by_selector_80c7db4c_candidate.

Behavior:
- Reads source_index_or_token from 0xb6001d30.
- Builds runtime record pointer.
- Reads record selector from +0x1c and record_word_b from +0x28.
- Selector range 0x0a..0x0d calls fn_dqm_try_issue_selector_record_fpm_request_80c7d618_candidate(source_index_or_token). If that returns 0, it falls back to FUN_80c7dc74(record_selector, record_word_b).
- Selector range 0x10..0x11 calls FUN_80c7de10(record_selector, record[0x38] & 0x0f, record[0x24], record_word_b).
- Selector range 0x18..0x19 calls FUN_80c7dcc0(record_selector, record_word_b).
- Selector range 0x16..0x17 calls FUN_80c7dd0c(record_selector, record[0x24], record_word_b).
- Writes source_index_or_token back to 0xb6001c00.

Change summary:
- Function renamed and plate comment added.
- Locals renamed: source_index_or_token, record_base, gate_result, record_selector, record_word_b.
- This function is now understood as a selector dispatcher, not an output publisher.

## Selector FPM-request gate mostly cleaned
Function renamed: fn_dqm_try_issue_selector_record_fpm_request_80c7d618_candidate.

Return meaning:
- 1 means this helper consumed or issued an FPM-backed request.
- 0 means no request was issued and caller may continue fallback selector dispatch.

Behavior:
- Runs only when 0x80007060 or 0x80007128 is enabled.
- Increments attempt counter 0x8000712c.
- Builds runtime record pointer from source_index_or_token.
- Reads record flags, selector, and record_word_b.
- Chooses a context pointer from global runtime records or per-index lookup table.
- Calls FUN_80c7c2a0().
- If context selected, chooses an FPM endpoint by payload size:
  - size + 4 < 0x101 uses 0x12200218.
  - size + 4 < 0x201 uses 0x12200210.
  - size + 4 < 0x401 uses 0x12200208.
  - otherwise uses 0x12200200.
- Reads token/value from selected FPM endpoint.
- If token/value is negative or high-bit set, it may wait for 0x80008160 bit0x20 to clear.
- If bit0x20 clears, writes request block: 0xb6001320 = record_word_b, 0xb6001324 = token, 0xb6001328 = context, 0xb600132c = payload_size | 0x16000.
- Programs 0xb2200224 = (record_word_b & 0xfffff000) | 0x801.
- Writes selector to 0xb6001dbc.
- Returns 1 when request issued.
- If busy condition does not clear before loop exit, returns token/value to FPM_POOL0_ENDPOINT_12200200_candidate and returns 1.
- If no request issued, increments fallback count 0x80007138 and returns 0.

Change summary:
- Return type changed to uint.
- Parameter renamed source_index_or_token.
- Locals renamed: record_ptr, selected_fpm_endpoint, lookup_index_or_token, fpm_token_or_value, payload_size, record_word_b, record_selector, selected_context_ptr, keep_waiting.
- CONCAT22 artifact was resolved by fixing/checking FUN_80c7d5f4 return behavior; the call now returns directly into lookup_index_or_token.
- payload_size split succeeded from lookup_index_or_token.
- Some remaining wait-loop counter reuse may still need cleanup, but it is acceptable for now.

## FPM and DQM endpoint labels added or confirmed
- FPM_POOL0_ENDPOINT_12200200_candidate is confirmed as frequent token/data return endpoint.
- FPM_ENDPOINT_400_12200208, FPM_ENDPOINT_200_12200210, and FPM_ENDPOINT_100_12200218 are size-selected FPM endpoints used by selector FPM request gate.
- FPM_OR_B220_ENDPOINT_12200224_candidate is programmed as (record_word_b & 0xfffff000) | 0x801 in several record-routing paths. Exact semantics remain unresolved; name intentionally stays cautious.
- DQM_SELECTOR_FPM_BUSY_RETURN_COUNT_80007148_candidate was added for the busy-return counter.
- DQM_SELECTOR_REQUEST_WORD_B_16001320_candidate, DQM_SELECTOR_REQUEST_FPM_TOKEN_16001324_candidate, DQM_SELECTOR_REQUEST_CONTEXT_16001328_candidate, DQM_SELECTOR_REQUEST_SIZE_FLAGS_1600132c_candidate, and DQM_SELECTOR_REQUEST_SELECTOR_16001dbc_candidate identify the request block used by the selector FPM gate.

## Important hardware/register conclusions
- 0xb6001818 is queue/event ack for the DQM path.
- 0xb6001810 is queue/event mask or bitmap side for the same mask cluster.
- 0xb6001014 and 0xb6001010 are global DQM event ack/mask side registers.
- 0xb6001c00 acts as selector index/port publish or ack base.
- 0xb6001d30, 0xb6001d40, and 0xb6001d50 are event source-index slots for three direct pending-bit helpers.
- 0xb6001320..0xb600132c is a DQM selector request/submit block.
- 0xb2200224 is an unresolved FPM/b220-family endpoint programmed from record_word_b page bits plus flag 0x801.
- 0xb6052000/b6052004 is a pair-copy table/window used by runtime init.
- CP2 f801 is used to push GENET stub command triples.
- CP2 f800/e004/e005/e006 are part of the larger CP2 event movement path mapped earlier.

## Changed function names in this session
- fn_dqm_runtime_queue_profile_window_and_irq_init_80c7ce70_candidate
- fn_dqm_event1800008_service_ack_and_rearm_80c7d2b8_candidate
- fn_dqm_event1800008_dispatch_pending_services_80c7cbf0_candidate
- fn_dqm_dispatch_selector_index_port_80c7dc48_candidate
- fn_dqm_selector_push_genet_stub_event_or_fpm_return_80c7e158_candidate
- fn_dqm_service_bit100000_route_record_80c7d318_candidate
- fn_dqm_service_bit200000_route_mode2_record_80c7d520_candidate
- fn_dqm_service_bit80000_dispatch_record_by_selector_80c7db4c_candidate
- fn_dqm_try_issue_selector_record_fpm_request_80c7d618_candidate
- fn_dqm_copy_word_pairs_to_b6052000_window_80c7bf00_candidate
- fn_dqm_emit_queue_profile_record_scaled_80c7bebc_candidate

## Current progress estimates
- DQM event 0x01800008 path: about 72 percent.
- Whole DQM/CP2/FPM subsystem: about 58 to 62 percent.
- OpenWrt-useful hardware map: about 45 percent.

## Remaining unresolved functions on this path
Highest priority next:
- FUN_80c7d5f4, lookup helper used by fn_dqm_try_issue_selector_record_fpm_request_80c7d618_candidate.
- FUN_80c7dc74, fallback helper for selectors 0x0a..0x0d.
- FUN_80c7de10, selector 0x10..0x11 helper.
- FUN_80c7dcc0, selector 0x18..0x19 helper.
- FUN_80c7dd0c, selector 0x16..0x17 helper.
- FUN_80c7e050, direct pending bit 0x00000008 helper.
- FUN_80c7d99c and FUN_80c7da84, service-state wait helpers.
- FUN_80c7bf70, FUN_80c7c008, FUN_80c7c2a8, FUN_80c7c068, FUN_80c7c090, table/window setup helpers from parent init.

## Current interpretation for OpenWrt work
The OEM path is not only GENET DMA register setup. It includes DQM queue profiles, b605 table/window loading, DQM event masks, CP2 f800/f801 sideband movement, FPM token endpoints, b220 endpoint programming, selector request blocks, and live event-service loops. Any OpenWrt bring-up that only configures GENET rings may still fail if the DQM/FPM token service path is not replicated or safely bypassed.

## Notes
No old logs were deleted. This command only creates a new dated reverse-note file. No git command is run.
