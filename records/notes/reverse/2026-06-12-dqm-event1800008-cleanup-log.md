# 2026-06-12 DQM event1800008 cleanup log

## Scope

This note records the completed cleanup pass for the TC7200U DQM event/mask `0x01800008` reverse-engineering path in Ghidra.

The work focused on the event1800008 pending-service dispatcher and its related DQM / CP2 / FPM helpers:

- dispatcher loop and pending-bit service routing
- selector record gate/intercept path
- selector publish/fallback paths
- selector and direct request submit paths
- request-result finalize paths
- mode1/mode2 output lane routing helpers
- final naming, label, and comment audit

No git operation is performed by this log command.

## Current overall status

```text
DQM event 0x01800008 path:        ~94-96%
DQM / CP2 / FPM subsystem:        ~78-80%
OpenWrt-useful hardware mapping:  ~60%
Primary event1800008 helpers:     cleaned
Remaining work type:              assembly checks / hardware-table proof only
Final cleanup result

The primary event1800008 helper chain is now considered locally cleaned.

Primary functions left: 0
Cleanup state: final audit pass done
Next work: documentation, assembly verification, or xref-driven hardware proof

The cleanup loop should stop here. Remaining unresolved items are not ordinary naming/comment cleanup blockers.

Main event dispatcher
Function
fn_dqm_event1800008_dispatch_pending_services_80c7cbf0_candidate
Role

Central dispatcher for the DQM event/mask 0x01800008 path.

Confirmed behavior
loops until masked pending state and required service-state flags reach idle/ready state
checks pending bits in the event/status word against mask 0x40383c08
dispatches direct pending services:
0x00080000 -> fn_dqm_service_bit80000_dispatch_record_by_selector_80c7db4c_candidate
0x00100000 -> fn_dqm_service_bit100000_route_record_80c7d318_candidate
0x00200000 -> fn_dqm_service_bit200000_route_mode2_record_80c7d520_candidate
0x00000008 -> fn_dqm_service_bit8_submit_direct_request_80c7e050_candidate
dispatches selector service requests:
pending bit 0x00000400 -> selector 0x0a
pending bit 0x00000800 -> selector 0x0b
pending bit 0x00001000 -> selector 0x0c
pending bit 0x00002000 -> selector 0x0d
waits for service-state bit2 by calling:
fn_dqm_finalize_request_result_publish_or_return_80c7d99c_candidate
waits for service-state bit6 by calling:
fn_dqm_finalize_selector_request_result_or_return_80c7da84_candidate
calls fn_runtime_stub_patch_dispatcher when pending bit 0x40000000 is set
Important unresolved point

The decompiler emits:

(uRam80008160 & 0x10) != 1

This is suspicious because bit 0x10 cannot equal 1. It was intentionally left unchanged. Assembly check is still required before rewriting this condition.

Selector FPM gate/intercept helper
Function
fn_dqm_try_issue_selector_record_fpm_request_80c7d618_candidate
Role

Gate/check helper for selector records 0x0a..0x0d in the event80000 path.

Confirmed behavior
runs only when forced selector/FPM mode or selector lookup is enabled
increments attempt counter at 0x8000712c
builds runtime record pointer:
0x80000000 | ((source_index_or_token + 0x100) & 0xffff)
reads record fields:
+0x00 = flags
+0x1c = record selector
+0x28 = record word B
forced mode:
selectors 0x0a and 0x0c use default context value at 0x80007068
selectors 0x0b and 0x0d use default context value at 0x80007064
lookup mode:
uses fn_dqm_record_field_to_lookup_index_80c7d5f4
maps record field values 0x0d..0x1c to lookup indexes 0..15
checks per-index gate/control field
selects FPM endpoint by record_word_b & 0x0fff plus 4:
< 0x101 -> FPM_ENDPOINT_100_12200218
< 0x201 -> FPM_ENDPOINT_200_12200210
< 0x401 -> FPM_ENDPOINT_400_12200208
otherwise -> FPM_POOL0_ENDPOINT_12200200_candidate
negative/high-bit token values are treated as usable FPM tokens
waits for service-state bit 0x20 to clear
may call selector finalize helper while waiting for bit 0x40
on success writes selector request block:
0xb6001320 = record word B
0xb6001324 = FPM token/value
0xb6001328 = selected request context
0xb600132c = payload size flags
0xb2200224 = page bits from record word B plus 0x801
0xb6001dbc = record selector
Important unresolved point

In forced gate mode, lookup_index_or_invalid may remain 0xff, while the decompiler still emits a per-index counter update.

This was intentionally preserved. Assembly/register lifetime check is required before changing the logic.

Shared request-result finalize helper
Function
fn_dqm_finalize_request_result_publish_or_return_80c7d99c_candidate
Role

Finalize helper for the shared DQM request block path.

Confirmed behavior
reads request metadata:
0xb6001da0 = request meta word0
0xb6001da4 = request meta token/page word1
0xb6001da8 = request meta word2
0xb6001dac = service selector
reads result low bits from:
0xb600131c
builds completed value:
(request_meta_word1 & 0xfffff000) | (result_low_bits & 0x0fff)
returns request meta word0 to FPM pool0 if it differs from completed value
reads selector gate expression:
0x80008014 + service_selector * 4
if selector gate value is zero:
returns completed value to FPM pool0
if selector gate value is nonzero:
publishes request meta word2 to selector table word0
publishes completed value to selector table word1
Important wording decision

The expression 0x80008014 + service_selector * 4 must not be described as a confirmed enable/context table.

Correct wording used:

selector gate expression
selector gate value
cautious runtime-state/table reference

Rejected wording:

confirmed selector enable/context table
Selector request-result finalize helper
Function
fn_dqm_finalize_selector_request_result_or_return_80c7da84_candidate
Role

Finalize helper for selector-request result path using 0xb6001330..0xb600133c and selector field 0xb6001dbc.

Confirmed behavior
reads selector request metadata/result words:
0xb6001330 = request meta word0
0xb6001334 = saved token/page word
0xb6001dbc = service selector
0xb600133c = result/status low bits
builds completed value:
(0xb6001334 & 0xfffff000) | (0xb600133c & 0x0fff)
calls request barrier helper twice
returns request meta word0 to FPM pool0
reads selector gate expression:
0x80008014 + service_selector * 4
if selector gate value is zero:
returns completed value to FPM pool0
if selector gate value is nonzero:
publishes completed value to:
0xb6001c00 + service_selector * 0x10
Event80000 selector dispatcher
Function
fn_dqm_service_bit80000_dispatch_record_by_selector_80c7db4c_candidate
Role

Direct service helper for pending bit 0x00080000.

Confirmed behavior
reads source index/token from 0xb6001d30
builds runtime record pointer:
0x80000000 | ((source_index_or_token + 0x100) & 0xffff)
reads:
+0x1c = record selector
+0x24 = record word A / argument
+0x28 = record word B
+0x38 = subselector/port field for selector 0x10/0x11
dispatches:
0x0a..0x0d -> selector FPM gate helper, then fallback publish if not intercepted
0x10..0x11 -> selector10/11 FPM request helper
0x18..0x19 -> selector18/19 publish helper
0x16..0x17 -> selector16/17 special/generic publish helper
writes source index/token back to DQM_QUEUE_SELECTOR_INDEX_PORT_16001c00_candidate
Fallback selector publish helper
Function
fn_dqm_fallback_publish_selector_value_80c7dc74_candidate
Role

Fallback publish path for selector records 0x0a..0x0d when FPM gate helper does not intercept.

Confirmed behavior
reads selector gate expression:
0x80008014 + service_selector * 4
if selector gate value is nonzero:
writes FPM_OR_B220_ENDPOINT_12200224_candidate = (selector_value & 0xfffff000) | 0x801
writes selector value to:
0xb6001c00 + service_selector * 0x10
returns without publishing if selector gate value is zero
Selector 0x18/0x19 publish helper
Function
fn_dqm_selector18_19_publish_value_80c7dcc0_candidate
Role

Publish helper for event80000 record selectors 0x18 and 0x19.

Confirmed behavior
same generic selector-gate publish pattern as fallback helper
reads selector gate expression:
0x80008014 + service_selector * 4
if gate is nonzero:
programs FPM_OR_B220_ENDPOINT_12200224_candidate from selector value page bits plus 0x801
publishes selector value to selector table/window word0
if gate is zero:
returns without publishing
Selector 0x16/0x17 publish or mode2-lane helper
Function
fn_dqm_selector16_17_publish_or_mode2_lane_80c7dd0c_candidate
Role

Selector helper for event80000 record selectors 0x16 and 0x17.

Confirmed behavior

Special path:

active when:
special mode at 0x80007100 equals 1
(record_word_a >> 0x16) & 0xf equals 1
selector 0x17:
uses gate at 0xb6001916
writes output word B to b4201c80
selector 0x16:
uses gate at 0xb6001912
writes output word B to b4201c90
each special path:
requires signed-positive halfword gate value
programs FPM_OR_B220_ENDPOINT_12200224_candidate
writes lane gate to 0xffff
publishes record word B to special output lane

Generic path:

reads selector gate expression:
0x80008014 + service_selector * 4
if gate is nonzero:
programs FPM_OR_B220_ENDPOINT_12200224_candidate
writes record word A to selector table word0
writes record word B to selector table word1
if gate is zero:
returns without publishing
Gate interpretation

The special lane gate check is not a simple nonzero check.

0x0001..0x7fff = pass
0x0000          = fail
0x8000..0xffff = fail

The function writes 0xffff after publishing, likely marking the lane consumed, busy, or closed.

Selector 0x10/0x11 FPM request helper
Function
fn_dqm_selector10_11_issue_fpm_request_80c7de10_candidate
Role

Specialized selector helper for event80000 record selectors 0x10 and 0x11.

Confirmed behavior
reads selector gate expression:
0x80008014 + service_selector * 4
only issues request if selector gate value is nonzero
computes:
payload_size = record_word_b & 0x0fff
adjusted_size = payload_size + 0xc0
selects FPM endpoint by adjusted size:
< 0x101 -> FPM_ENDPOINT_100_12200218
< 0x201 -> FPM_ENDPOINT_200_12200210
< 0x401 -> FPM_ENDPOINT_400_12200208
otherwise -> FPM_POOL0_ENDPOINT_12200200_candidate
reads token/value from selected FPM endpoint
usable token is negative/high-bit set
translates source page and token page through:
0xb6001408
0xb600140c
waits for service-state bit1 to clear
may call shared finalize helper while waiting for bit2
on success writes command engine block:
0xb6001300 = source page translate
0xb6001304 = token page translate plus 0xc0
0xb6001308 = 0
0xb600130c = payload size
programs FPM_OR_B220_ENDPOINT_12200224_candidate
writes request metadata:
0xb6001da0 = record word B
0xb6001da4 = FPM token/value
0xb6001da8 = (record_word_a & 0xfffff800) | 0xc0
0xb6001dac = service selector
if busy wait fails:
increments busy-return counter
returns token/value to FPM pool0
Event100000 route helper
Function
fn_dqm_service_bit100000_route_record_80c7d318_candidate
Role

Direct service helper for pending bit 0x00100000.

Confirmed behavior
reads source index/token from 0xb6001d40
builds runtime record pointer:
0x80000000 | ((source_index_or_token + 0x100) & 0xffff)
reads:
+0x1c = record selector
+0x24 = record word A
+0x28 = record word B
route mode at 0x80007120 selects output family:
mode 1 -> b340 output pairs
mode 2 -> b420 output pairs
other -> b600 default output pairs
record selector 0x0d selects lane1
all other selectors select lane0
enabled route writes:
FPM_OR_B220_ENDPOINT_12200224_candidate = (record_word_b & 0xfffff000) | 0x801
output word A = record word A
output word B = record word B
writes source index/token back to selector/index port
Gate interpretation

Mode1/mode2 lane gates require signed-positive halfword gate value.

0x0001..0x7fff = pass
0x0000          = fail
0x8000..0xffff = fail

The function writes 0xffff after publishing, likely marking the lane consumed, busy, or closed.

Event200000 mode2 route helper
Function
fn_dqm_service_bit200000_route_mode2_record_80c7d520_candidate
Role

Direct service helper for pending bit 0x00200000.

Confirmed behavior
reads source index/token from 0xb6001d50
builds runtime record pointer:
0x80000000 | ((source_index_or_token + 0x100) & 0xffff)
reads:
+0x1c = selector/type
+0x24 = record word A
+0x28 = record word B
selector/type value 1 uses mode2 lane1:
b4201c10/b4201c14
all other selector/type values use mode2 lane0:
b4201c00/b4201c04
enabled route writes:
FPM_OR_B220_ENDPOINT_12200224_candidate = (record_word_b & 0xfffff000) | 0x801
output word A = record word A
output word B = record word B
writes source index/token back to selector/index port
Gate interpretation

Same signed-positive gate rule:

0x0001..0x7fff = pass
0x0000          = fail
0x8000..0xffff = fail

The function writes 0xffff after publishing, likely marking the lane consumed, busy, or closed.

Direct request submit helper
Function
fn_dqm_service_bit8_submit_direct_request_80c7e050_candidate
Role

Direct service helper for pending bit 0x00000008.

Confirmed behavior
reads direct request word A from:
0xb6001c30
checks service-state bit1
if bit1 is clear:
reads direct request word B from:
0xb6001c34
translates request word B page index through:
0xb6001408
0xb600140c
calls request barrier helper
writes command engine block:
0xb6001300 = translated page/result + (request_word_a & 0x7ff)
0xb6001304 = request word B
0xb6001308 = 0
0xb600130c = (request_word_b & 0x0fff) | 0x4000
writes request metadata:
0xb6001da0 = request word B
0xb6001da4 = request word B
0xb6001da8 = request_word_a & 0xfffff800
0xb6001dac = 2
if bit1 is set:
increments busy counter shared with selector 0x10/0x11 busy path
Cleanup result

Stale FUN_80c7c2a0 reference was replaced with:

fn_dqm_request_barrier_noop_80c7c2a0_candidate

Duplicate metadata selector comment was removed.

Naming and label changes
Functions promoted out of _candidate

The following simple/mechanical helpers were judged safe to remove _candidate from earlier in this cleanup series:

fn_dqm_record_field_to_lookup_index_80c7d5f4
fn_dqm_queue1c_preload_8_entries_80c7c008
fn_dqm_queue1d_preload_50_entries_80c7bf70
fn_dqm_b6040010_set_three_enable_bits_80c7c068
Functions intentionally kept with _candidate

The following retain _candidate because they still encode hardware-role interpretation:

fn_dqm_event1800008_dispatch_pending_services_80c7cbf0_candidate
fn_dqm_try_issue_selector_record_fpm_request_80c7d618_candidate
fn_dqm_finalize_request_result_publish_or_return_80c7d99c_candidate
fn_dqm_finalize_selector_request_result_or_return_80c7da84_candidate
fn_dqm_service_bit80000_dispatch_record_by_selector_80c7db4c_candidate
fn_dqm_fallback_publish_selector_value_80c7dc74_candidate
fn_dqm_selector18_19_publish_value_80c7dcc0_candidate
fn_dqm_selector16_17_publish_or_mode2_lane_80c7dd0c_candidate
fn_dqm_selector10_11_issue_fpm_request_80c7de10_candidate
fn_dqm_service_bit100000_route_record_80c7d318_candidate
fn_dqm_service_bit200000_route_mode2_record_80c7d520_candidate
fn_dqm_service_bit8_submit_direct_request_80c7e050_candidate
Important labels used or confirmed
Event/source state
DQM_EVENT_PENDING_STATUS_8000800c_candidate
DQM_SERVICE_STATE_FLAGS_80008160_candidate
DQM_SELECTOR_ACTIVE_BITMAP_80008000_candidate
DQM_SELECTOR_STATE_WORD_80008004_candidate
DQM_EVENT80000_SOURCE_INDEX_16001d30_candidate
DQM_EVENT100000_SOURCE_INDEX_16001d40_candidate
DQM_EVENT200000_SOURCE_INDEX_16001d50_candidate
Selector/CP2 globals
DQM_CP2_SELECTOR_A_80007110_candidate
DQM_CP2_SELECTOR_B_80007114_candidate
DQM_CP2_GENET_TARGET_A_80007118_candidate
DQM_CP2_GENET_TARGET_B_8000711c_candidate
Selector gate/FPM counters
DQM_SELECTOR_FPM_GATE_MODE_80007060_candidate
DQM_SELECTOR_CONTEXT_DEFAULT_A_80007064_candidate
DQM_SELECTOR_CONTEXT_DEFAULT_B_80007068_candidate
DQM_SELECTOR_LOOKUP_ENABLE_80007128_candidate
DQM_SELECTOR_FPM_GATE_ATTEMPT_COUNT_8000712c_candidate
DQM_SELECTOR_FLAG10_SKIP_COUNT_80007130_candidate
DQM_SELECTOR_FPM_REQUEST_ISSUED_COUNT_80007134_candidate
DQM_SELECTOR_FPM_GATE_FALLBACK_COUNT_80007138_candidate
DQM_SELECTOR10_WAIT_BUSY_COUNT_8000713c_candidate
DQM_SELECTOR_FPM_WAIT_BUSY_COUNT_80007140_candidate
DQM_SELECTOR10_BUSY_RETURN_COUNT_80007144_candidate
DQM_SELECTOR_FPM_BUSY_RETURN_COUNT_80007148_candidate
Request engine and page translation
DQM_PAGE_TRANSLATE_INDEX_16001408_candidate
DQM_PAGE_TRANSLATE_RESULT_1600140c_candidate
DQM_CMD_ENGINE_WORD0_16001300_candidate
DQM_CMD_ENGINE_WORD1_16001304_candidate
DQM_CMD_ENGINE_WORD2_16001308_candidate
DQM_CMD_ENGINE_WORD3_1600130c_candidate
DQM_CMD_ENGINE_RESULT_1600131c_candidate
Selector request block
DQM_SELECTOR_REQUEST_WORD_B_16001320_candidate
DQM_SELECTOR_REQUEST_FPM_TOKEN_16001324_candidate
DQM_SELECTOR_REQUEST_CONTEXT_16001328_candidate
DQM_SELECTOR_REQUEST_SIZE_FLAGS_1600132c_candidate
DQM_SELECTOR_REQUEST_META_WORD0_16001330_candidate
DQM_SELECTOR_REQUEST_META_WORD1_16001334_candidate
DQM_SELECTOR_REQUEST_RESULT_1600133c_candidate
DQM_SELECTOR_REQUEST_SELECTOR_16001dbc_candidate
Shared request metadata
DQM_REQUEST_META_WORD0_16001da0_candidate
DQM_REQUEST_META_WORD1_16001da4_candidate
DQM_REQUEST_META_WORD2_16001da8_candidate
DQM_REQUEST_META_SELECTOR_16001dac_candidate
Selector table/window
DQM_QUEUE_SELECTOR_INDEX_PORT_16001c00_candidate
DQM_QUEUE_SELECTOR_WORD1_16001c04_candidate
DQM_DIRECT_REQUEST_WORD_A_16001c30_candidate
DQM_DIRECT_REQUEST_WORD_B_16001c34_candidate
FPM / B220 endpoints
FPM_POOL0_ENDPOINT_12200200_candidate
FPM_ENDPOINT_400_12200208
FPM_ENDPOINT_200_12200210
FPM_ENDPOINT_100_12200218
FPM_OR_B220_ENDPOINT_12200224_candidate
Event100000 mode/default lane state
DQM_EVENT100000_ROUTE_MODE_80007120_candidate
DQM_EVENT100000_DEFAULT_LANE0_ENABLE_8000806c_candidate
DQM_EVENT100000_DEFAULT_LANE1_ENABLE_80008070_candidate
DQM_EVENT100000_DEFAULT_LANE0_WORD_A_16001d60_candidate
DQM_EVENT100000_DEFAULT_LANE0_WORD_B_16001d64_candidate
DQM_EVENT100000_DEFAULT_LANE1_WORD_A_16001d70_candidate
DQM_EVENT100000_DEFAULT_LANE1_WORD_B_16001d74_candidate
Mode1/mode2 output lane labels
DQM_EVENT100000_MODE1_LANE0_GATE_16001902_candidate
DQM_EVENT100000_MODE1_LANE1_GATE_16001906_candidate
DQM_EVENT100000_MODE2_LANE0_GATE_1600190a_candidate
DQM_EVENT100000_MODE2_LANE1_GATE_1600190e_candidate
DQM_EVENT100000_MODE1_LANE0_WORD_A_13401ca0_candidate
DQM_EVENT100000_MODE1_LANE0_WORD_B_13401ca4_candidate
DQM_EVENT100000_MODE1_LANE1_WORD_A_13401cd0_candidate
DQM_EVENT100000_MODE1_LANE1_WORD_B_13401cd4_candidate
DQM_MODE2_LANE0_WORD_A_14201c00_candidate
DQM_MODE2_LANE0_WORD_B_14201c04_candidate
DQM_MODE2_LANE1_WORD_A_14201c10_candidate
DQM_MODE2_LANE1_WORD_B_14201c14_candidate
Final audit performed

The final audit checked for:

Ramb
uRam
iRam
cRam
enable/context table
FUN_80c7c2a0
selector_value page bits
duplicated Metadata selector value 2 wording
stale _candidate references to helpers promoted to final names

The cleanup target is to leave raw names only where intentionally unresolved or outside the current cleaned scope.

Remaining unresolved items

These are not normal cleanup errors.

0x80008014 + service_selector * 4

Current status:

unresolved / cautious selector gate reference

Reason:

decompiler uses it as a selector gate expression
current Ghidra image shows 0x80008014 overlapping code-looking bytes
do not force a data array or struct there yet

Allowed wording:

selector gate expression
selector gate value
cautious runtime-state/table reference
0xb2200224

Current label:

FPM_OR_B220_ENDPOINT_12200224_candidate

Reason:

endpoint-like write target
programmed repeatedly from page bits plus flag 0x801
likely related to FPM/B220 return/mailbox behavior
exact hardware block identity still not fully proven
b6040400..b60406c4

Current status:

raw table/register writes retained

Reason:

the b604 table is real and important
per-column and per-row field meanings are not fully proven
do not mass-label until xrefs/runtime evidence prove layout
Forced gate lookup index

Current issue:

In forced selector/FPM gate mode, lookup_index_or_invalid may remain 0xff while
the decompiler still emits a per-index counter update.

Action:

leave unchanged until assembly/register lifetime is checked
Dispatcher bit4 condition

Current issue:

Decompiler emits (0x80008160 & 0x10) != 1

Action:

leave unchanged until assembly confirms intended branch logic
Practical next steps

Do not continue the same cleanup loop.

Next useful work should be one of:

1. assembly-check the suspicious dispatcher bit4 comparison
2. assembly-check forced gate mode lookup_index_or_invalid behavior
3. xref/trace 0xb2200224 writes and reads
4. xref/trace b6040400..06c4 table layout
5. write a handoff JSON or higher-level reverse summary
Result

The event1800008 helper chain is now clean enough for logging and handoff.

Key result:

The DQM event1800008 path is now readable as a dispatcher-driven service chain
that routes pending bits into selector dispatch, FPM request issue, page translation,
request engine submit, publish/finalize, and mode-specific sideband output lanes.

