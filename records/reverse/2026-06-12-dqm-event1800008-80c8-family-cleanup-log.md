# 2026-06-12 DQM event1800008 0x80c8 dispatcher family cleanup log

## Scope

This log records the reverse-engineering cleanup performed on the alternate 0x80c8 DQM event/mask 0x01800008 runtime family. Work focused on confirming the event registration chain, correcting a bad handler-address interpretation caused by signed MIPS addiu behavior, and cleaning the pending-bit service helpers under the 0x80c8 dispatcher.

No Git action was performed. Existing logs are preserved.

## High-level result

The 0x80c8 event1800008 family is now structurally mapped and matches the earlier 0x80c7 family at the dispatcher level. The family is initialized by the alternate runtime init path, registered for event/mask 0x01800008, and services the same major pending bits:

- 0x00000008: direct request submit helper
- 0x00080000: selector-record dispatcher
- 0x00100000: route-mode output-lane router
- 0x00200000: direct mode2 lane router
- 0x40000000: control-mailbox dispatcher

The corrected registered handler address is 0x80c8a118, not 0x80c9a118.

## Important correction: signed addiu handler address

The parent init registers the handler with:

```asm
80c8a0e0  lui    a0,0x80c9
80c8a0e4  addiu  a0,a0,0xa118
```

The immediate 0xa118 is signed in addiu:

```text
0xa118 signed16 = -0x5ee8
0x80c90000 - 0x5ee8 = 0x80c8a118
```

Result:

- Wrong address rejected: 0x80c9a118
- Correct handler address: 0x80c8a118
- Bad label removed or ignored: fn_dqm_event1800008_service_ack_and_rearm_80c9a118_candidate
- Correct label kept: fn_dqm_event1800008_service_ack_and_rearm_80c8a118_candidate

At 0x80c9a118 the listing showed a delay-slot instruction inside an unrelated ipsecadm/ipsecmsg.c region. That address is not a DQM event handler start.

## Parent init chain status

Function kept:

```text
fn_dqm_alt_runtime_init_register_event1800008_genet500_510_80c89cb4_candidate
```

The final arm/register block was analyzed. It performs:

- Clears DQM_EVENT100000_ROUTE_MODE_80007120_candidate to 0
- Initializes event100000 mode1/mode2 lane gates:
  - b6001902 = 0x40
  - b6001906 = 0x40
  - b600190a = 0x40
  - b600190e = 0x40
- Writes b6001028 = 0xffffffff
- Programs queue-control pair:
  - b6001640 = 0x8000003f
  - b600163c = 0x14
- Arms queue pending/IRQ mask:
  - b6001818 = 0x40383c08
  - b6001810 |= 0x40383c08
- Arms global DQM IRQ bits:
  - b6001014 = 0x000c0000
  - b6001010 |= 0x000c0000
- Registers fn_dqm_event1800008_service_ack_and_rearm_80c8a118_candidate for event/mask 0x01800008
- Enables event/mask 0x01800008

Interpretation: this is the final activation step for the alternate DQM event1800008 runtime path after queue/profile setup, selector lookup context setup, pair-copy bootstrap load, and b604 CP2 table programming.

## Handler wrapper

Function confirmed:

```text
fn_dqm_event1800008_service_ack_and_rearm_80c8a118_candidate
```

Behavior:

```text
fn_dqm_event_mask_enable_disable_8005fa08_candidate(0x01800008, 0)
fn_dqm_event1800008_dispatch_pending_services_80c89a34_candidate()
b6001818 = 0x40383c08
b6001014 = 0x000c0000
fn_dqm_event_mask_enable_disable_8005fa08_candidate(0x01800008, 1)
```

Interpretation: service wrapper follows the known pattern:

```text
mask event -> run dispatcher -> queue/global ack or rearm write -> re-enable event
```

Important wording retained:

- b6001818 is queue-side pending/ack/rearm write candidate
- b6001014 is global IRQ ack/rearm write candidate
- exact ACK versus enable behavior remains candidate

## Main dispatcher

Function kept:

```text
fn_dqm_event1800008_dispatch_pending_services_80c89a34_candidate
```

This is the alternate 0x80c8 copy of the event1800008 pending-service dispatcher. It matches the structure of the earlier 0x80c7 dispatcher but calls the 0x80c8 helper family.

Dispatcher loop returns only when:

- No masked pending bits are set under mask 0x40383c08
- 0x80008160 bit0 is clear
- Emitted term `(0x80008160 & 0x10) != 1` is true
- 0x80008160 bit2 is set
- 0x80008160 bit6 is set

Important: `(state & 0x10) != 1` is preserved as emitted. It is an assembly-confirmed impossible-false compare, not rewritten into a normal bit4 test.

Pending service calls:

```text
0x00080000 -> fn_dqm_service_bit80000_dispatch_record_by_selector_80c8a9ac_candidate()
0x00100000 -> fn_dqm_route_record_by_mode_to_output_lanes_80c8a178_candidate()
0x00200000 -> fn_dqm_service_bit200000_route_mode2_record_80c8a380_candidate()
0x00000008 -> fn_dqm_service_bit8_submit_direct_request_80c8aeb0_candidate()
```

Selector dispatch gates:

```text
((1 << (selector & 0x1f)) & 0x80008000) == 0
(0x80008004 & 0x1f) > 0x0f
```

Selector A state at 0x80007110:

- Pending bit 0x800 selects selector 0x0b
- Pending bit 0x400 selects selector 0x0a
- If both pending, 0x0b wins

Selector B state at 0x80007114:

- Pending bit 0x2000 selects selector 0x0d
- Pending bit 0x1000 selects selector 0x0c
- If both pending, 0x0d wins

Both selector paths call:

```text
fn_dqm_dispatch_selector_index_port_80c8aaa8_candidate(selector)
```

Finalize waits:

- Waits for service-state bit2 through fn_dqm_finalize_request_result_publish_or_return_80c8a7fc_candidate()
- Waits for service-state bit6 through fn_dqm_finalize_selector_request_result_or_return_80c8a8e4_candidate()

Late control-mailbox dispatch:

- After finalize waits, pending bit 0x40000000 calls fn_dqm_ctrl_mailbox_command_dispatch_80c89414_candidate()

## Pending bit 0x00080000 selector-record dispatcher

Function kept:

```text
fn_dqm_service_bit80000_dispatch_record_by_selector_80c8a9ac_candidate
```

Behavior:

```text
source_index = b6001d30
record = 0x80000000 | ((source_index + 0x100) & 0xffff)
```

Record fields:

- record +0x1c = selector
- record +0x24 = record_word_a
- record +0x28 = record_word_b
- record +0x38 = selector10/11 nibble source

Selector routing:

- 0x0a..0x0d:
  - Try fn_dqm_try_issue_selector_record_fpm_request_80c8a478_candidate(source_index)
  - If return 0, fallback to fn_dqm_publish_selector_value_if_gate_enabled_80c8aad4_candidate(selector, record_word_b)
- 0x10..0x11:
  - Call fn_dqm_selector10_11_issue_fpm_request_80c8ac70_candidate(selector, record[0x38] & 0x0f, record_word_a, record_word_b)
- 0x18..0x19:
  - Call fn_dqm_publish_selector_value_if_gate_enabled_80c8ab20_candidate(selector, record_word_b)
- 0x16..0x17:
  - Call fn_dqm_selector16_17_publish_or_special_lane_80c8ab6c_candidate(selector, record_word_a, record_word_b)

Final write:

```text
b6001c00 = source_index
```

Current cautious label:

```text
DQM_EVENT80000_PROCESSED_SOURCE_INDEX_16001c00_candidate
```

Note: b6001c00 is context-dependent and also acts as the selector output base in other paths.

## Selector/FPM request gate for selectors 0x0a..0x0d

Function kept:

```text
fn_dqm_try_issue_selector_record_fpm_request_80c8a478_candidate
```

Helper kept:

```text
fn_dqm_record_field_to_lookup_index_80c8a454_candidate
```

Lookup helper behavior:

- Input 0x0d..0x1c maps to index 0..15
- Anything else maps to 0xff

Decompiler artifact noted:

```text
CONCAT22(extraout_var,uVar4)
```

This is not real logic. Treat result as a normal lookup index return value: 0..15 or 0xff.

Gate entry conditions:

- Exits with 0 if both are disabled:
  - DQM_SELECTOR_FPM_GATE_MODE_80007060_candidate == 0
  - DQM_SELECTOR_LOOKUP_ENABLE_80007128_candidate == 0
- Increments attempt counter at 0x8000712c when active

Record pointer:

```text
record = 0x80000000 | ((source_index + 0x100) & 0xffff)
```

Fields:

- record +0x00 = flags
- record +0x1c = selector
- record +0x28 = record_word_b / payload-size-and-page field

Forced mode:

- DQM_SELECTOR_FPM_GATE_MODE_80007060_candidate == 1
- Selectors 0x0a or 0x0c use context at 0x80007068
- Selectors 0x0b or 0x0d use context at 0x80007064

Lookup mode:

- Requires record flag bit0x10 clear
- Requires lookup enable == 1
- Requires record low flags bit0 and bit1 clear
- Maps record +0x10 through fn_dqm_record_field_to_lookup_index_80c8a454_candidate()
- Slot must have nonzero halfword at slot +0x00

FPM endpoint selection uses:

```text
payload_size = record_word_b & 0x0fff
```

Endpoint choice:

- payload_size + 4 < 0x101 -> 0x12200218
- payload_size + 4 < 0x201 -> 0x12200210
- payload_size + 4 < 0x401 -> 0x12200208
- otherwise -> 0x12200200

Successful request writes:

```text
b6001320 = record_word_b
b6001324 = fpm_token
b6001328 = selected_context
b600132c = (record_word_b & 0x0fff) | 0x16000
b2200224 = (record_word_b & 0xfffff000) | 0x801
b6001dbc = selector
```

Busy behavior:

- If service-state bit0x20 is set, increments 0x80007140 and waits
- While waiting, if service-state bit0x40 is clear, calls fn_dqm_finalize_selector_request_result_or_return_80c8a8e4_candidate()
- Wait loop is bounded by 0x2711 iterations
- If still busy, returns token to 0x12200200, increments 0x80007148, and returns 1

Return behavior:

- Returns 1 when request was issued or busy token-return path ran
- Returns 0 when no request was issued, allowing fallback publish
- Increments 0x80007138 on fallback/no-request path

## Fallback selector-value publish helper for selectors 0x0a..0x0d

Function kept:

```text
fn_dqm_publish_selector_value_if_gate_enabled_80c8aad4_candidate
```

Behavior:

```text
if (*(uint *)(0x80008014 + selector * 4) != 0) {
  b2200224 = (selector_value & 0xfffff000) | 0x801;
  *(uint *)(0xb6001c00 + selector * 0x10) = selector_value;
}
```

Selector output addresses:

- selector 0x0a -> b6001ca0
- selector 0x0b -> b6001cb0
- selector 0x0c -> b6001cc0
- selector 0x0d -> b6001cd0

Labels added or recommended:

- 0x80008014 -> DQM_SELECTOR_OUTPUT_GATE_TABLE_80008014_candidate
- b6001c00 -> DQM_SELECTOR_OUTPUT_PORT_BASE_16001c00_candidate or DQM_SELECTOR_OUTPUT_WORD0_BASE_16001c00_candidate

## Selector-value publish helper for selectors 0x18..0x19

Function kept:

```text
fn_dqm_publish_selector_value_if_gate_enabled_80c8ab20_candidate
```

This is logic-identical to the 0x80c8aad4 helper, but used for selectors 0x18..0x19.

Selector output addresses:

- selector 0x18 -> b6001d80
- selector 0x19 -> b6001d90

Behavior:

```text
if (*(uint *)(0x80008014 + selector * 4) != 0) {
  b2200224 = (selector_value & 0xfffff000) | 0x801;
  *(uint *)(0xb6001c00 + selector * 0x10) = selector_value;
}
```

Important: difference is caller/range, not behavior.

## Selector 0x16/0x17 publish or special-lane helper

Function kept:

```text
fn_dqm_selector16_17_publish_or_special_lane_80c8ab6c_candidate
```

Arguments:

- param_1 = selector, expected 0x16 or 0x17
- param_2 = record_word_a
- param_3 = record_word_b

Special-lane condition:

```text
DQM_SELECTOR16_17_SPECIAL_MODE_80007100_candidate == 1
((record_word_a >> 22) & 0x0f) == 1
```

Selector 0x17 special lane:

- Reads gate b6001916
- Gate permits only halfword values 0x0001..0x7fff via emitted signed-shift test
- Writes b2200224 = (record_word_b & 0xfffff000) | 0x801
- Writes b6001916 = 0xffff
- Writes b4201c80 = record_word_b

Selector 0x16 special lane:

- Reads gate b6001912
- Gate permits only halfword values 0x0001..0x7fff via emitted signed-shift test
- Writes b2200224 = (record_word_b & 0xfffff000) | 0x801
- Writes b6001912 = 0xffff
- Writes b4201c90 = record_word_b

Normal path:

```text
if (*(uint *)(0x80008014 + selector * 4) != 0) {
  b2200224 = (record_word_b & 0xfffff000) | 0x801;
  *(uint *)(0xb6001c00 + selector * 0x10) = record_word_a;
  *(uint *)(0xb6001c04 + selector * 0x10) = record_word_b;
}
```

Normal output addresses:

- selector 0x16 -> b6001d60 / b6001d64
- selector 0x17 -> b6001d70 / b6001d74

Labels:

- b6001912 -> DQM_SELECTOR16_SPECIAL_LANE_GATE_16001912_candidate
- b6001916 -> DQM_SELECTOR17_SPECIAL_LANE_GATE_16001916_candidate
- b4201c90 -> DQM_SELECTOR16_SPECIAL_WORD_B_14201c90_candidate
- b4201c80 -> DQM_SELECTOR17_SPECIAL_WORD_B_14201c80_candidate
- b6001c00 -> DQM_SELECTOR_OUTPUT_WORD0_BASE_16001c00_candidate
- b6001c04 -> DQM_SELECTOR_OUTPUT_WORD1_BASE_16001c04_candidate

MMIO alias note:

- Ghidra may not accept b420 or low29 1420 addresses unless an MMIO block exists.
- The write operands still prove the targets.
- Do not create functions in MMIO regions.

## Selector 0x10/0x11 FPM request helper

Function kept:

```text
fn_dqm_selector10_11_issue_fpm_request_80c8ac70_candidate
```

Arguments:

- param_1 = selector, expected 0x10 or 0x11
- param_2 = caller-provided record[0x38] & 0x0f, currently unused in body
- param_3 = record_word_a
- param_4 = record_word_b

Gate:

```text
*(uint *)(0x80008014 + selector * 4) != 0
```

FPM allocation size:

```text
payload_size = record_word_b & 0x0fff
endpoint decision uses payload_size + 0xc0
```

Endpoint choice:

- payload_size + 0xc0 < 0x101 -> 0x12200218
- payload_size + 0xc0 < 0x201 -> 0x12200210
- payload_size + 0xc0 < 0x401 -> 0x12200208
- otherwise -> 0x12200200

Page translation pair:

```text
b6001408 = record_word_b >> 12
translated_src = b600140c
b6001408 = fpm_token >> 12
translated_dst = b600140c
```

Labels:

- b6001408 -> DQM_PAGE_TRANSLATE_INPUT_PAGE_16001408_candidate
- b600140c -> DQM_PAGE_TRANSLATE_RESULT_VALUE_1600140c_candidate

Busy behavior:

- Calls fn_dqm_request_barrier_noop_80c890e4_candidate()
- If service-state bit0x2 is set, increments 0x8000713c and waits
- While waiting, if service-state bit0x4 is clear, calls fn_dqm_finalize_request_result_publish_or_return_80c8a7fc_candidate()
- Wait bounded by 0x2711 iterations
- If still busy, increments 0x80007144 and returns FPM token to 0x12200200

Successful writes:

```text
b6001300 = translated record_word_b page result
b6001304 = translated fpm_token page result + 0xc0
b6001308 = 0
b600130c = payload_size
b2200224 = (record_word_b & 0xfffff000) | 0x801
b6001da0 = record_word_b
b6001da4 = fpm_token
b6001da8 = (record_word_a & 0xfffff800) | 0xc0
b6001dac = selector
```

Interpretation: selector 0x10/0x11 request builder. It reserves a 0xc0-byte prefix/header in the FPM buffer and submits through the shared b6001300..b600130c and b6001da0..b6001dac request blocks.

## Pending bit 0x00100000 route-mode output-lane router

Function kept:

```text
fn_dqm_route_record_by_mode_to_output_lanes_80c8a178_candidate
```

Behavior:

```text
source_index = b6001d40
record = 0x80000000 | ((source_index + 0x100) & 0xffff)
record +0x1c = selector
record +0x24 = record_word_a
record +0x28 = record_word_b
```

Route mode source:

```text
DQM_EVENT100000_ROUTE_MODE_80007120_candidate
```

Route mode 1:

- selector 0x0d -> lane1:
  - gate b6001906
  - writes b6001906 = 0xffff
  - writes 0x13401cd0 = record_word_a
  - writes 0x13401cd4 = record_word_b
- all other selectors -> lane0:
  - gate b6001902
  - writes b6001902 = 0xffff
  - writes 0x13401ca0 = record_word_a
  - writes 0x13401ca4 = record_word_b

Route mode 2:

- selector 0x0d -> lane1:
  - gate b600190e
  - writes b600190e = 0xffff
  - writes 0x14201c10 = record_word_a
  - writes 0x14201c14 = record_word_b
- all other selectors -> lane0:
  - gate b600190a
  - writes b600190a = 0xffff
  - writes 0x14201c00 = record_word_a
  - writes 0x14201c04 = record_word_b

Default route mode:

- selector 0x0d -> default lane1:
  - requires nonzero word gate at 0x80008070
  - writes b6001d70 = record_word_a
  - writes b6001d74 = record_word_b
- all other selectors -> default lane0:
  - requires nonzero word gate at 0x8000806c
  - writes b6001d60 = record_word_a
  - writes b6001d64 = record_word_b

Common behavior:

- Writes b2200224 = (record_word_b & 0xfffff000) | 0x801 before output
- Writes b6001c00 = source_index at exit

Gate details:

- Mode1/mode2 gates permit only 0x0001..0x7fff
- Consumed mode1/mode2 gates are set to 0xffff
- Default mode gates are nonzero word gates and are not consumed here

Labels:

- b6001d40 -> DQM_EVENT100000_SOURCE_INDEX_16001d40_candidate
- 0x80007120 -> DQM_EVENT100000_ROUTE_MODE_80007120_candidate
- b6001902 -> DQM_EVENT100000_MODE1_LANE0_GATE_16001902_candidate
- b6001906 -> DQM_EVENT100000_MODE1_LANE1_GATE_16001906_candidate
- b600190a -> DQM_EVENT100000_MODE2_LANE0_GATE_1600190a_candidate
- b600190e -> DQM_EVENT100000_MODE2_LANE1_GATE_1600190e_candidate
- 0x8000806c -> DQM_EVENT100000_DEFAULT_LANE0_GATE_8000806c_candidate
- 0x80008070 -> DQM_EVENT100000_DEFAULT_LANE1_GATE_80008070_candidate
- 0x13401ca0 -> DQM_EVENT100000_MODE1_LANE0_WORD_A_13401ca0_candidate
- 0x13401ca4 -> DQM_EVENT100000_MODE1_LANE0_WORD_B_13401ca4_candidate
- 0x13401cd0 -> DQM_EVENT100000_MODE1_LANE1_WORD_A_13401cd0_candidate
- 0x13401cd4 -> DQM_EVENT100000_MODE1_LANE1_WORD_B_13401cd4_candidate
- 0x14201c00 -> DQM_MODE2_LANE0_WORD_A_14201c00_candidate
- 0x14201c04 -> DQM_MODE2_LANE0_WORD_B_14201c04_candidate
- 0x14201c10 -> DQM_MODE2_LANE1_WORD_A_14201c10_candidate
- 0x14201c14 -> DQM_MODE2_LANE1_WORD_B_14201c14_candidate
- b6001d60 -> DQM_EVENT100000_DEFAULT_LANE0_WORD_A_16001d60_candidate
- b6001d64 -> DQM_EVENT100000_DEFAULT_LANE0_WORD_B_16001d64_candidate
- b6001d70 -> DQM_EVENT100000_DEFAULT_LANE1_WORD_A_16001d70_candidate
- b6001d74 -> DQM_EVENT100000_DEFAULT_LANE1_WORD_B_16001d74_candidate

## Pending bit 0x00200000 direct mode2 lane router

Function kept:

```text
fn_dqm_service_bit200000_route_mode2_record_80c8a380_candidate
```

Behavior:

```text
source_index = b6001d50
record = 0x80000000 | ((source_index + 0x100) & 0xffff)
record +0x1c = lane selector
record +0x24 = record_word_a
record +0x28 = record_word_b
```

Lane selection:

- record[0x1c] == 1 -> mode2 lane1
- otherwise -> mode2 lane0

Lane1 path:

- Gate b600190e must contain positive one-shot value
- Writes b600190e = 0xffff
- Writes b2200224 = (record_word_b & 0xfffff000) | 0x801
- Writes 0x14201c10 = record_word_a
- Writes 0x14201c14 = record_word_b

Lane0 path:

- Gate b600190a must contain positive one-shot value
- Writes b600190a = 0xffff
- Writes b2200224 = (record_word_b & 0xfffff000) | 0x801
- Writes 0x14201c00 = record_word_a
- Writes 0x14201c04 = record_word_b

Final write:

```text
b6001c00 = source_index
```

Labels:

- b6001d50 -> DQM_EVENT200000_SOURCE_INDEX_16001d50_candidate
- Shared mode2 lane labels:
  - DQM_MODE2_LANE0_WORD_A_14201c00_candidate
  - DQM_MODE2_LANE0_WORD_B_14201c04_candidate
  - DQM_MODE2_LANE1_WORD_A_14201c10_candidate
  - DQM_MODE2_LANE1_WORD_B_14201c14_candidate

Important: the 0x14201c00 mode2 lane region is shared by both the 0x00100000 route-mode2 path and the 0x00200000 direct mode2 path.

## Pending bit 0x00000008 direct request submit helper

Function kept:

```text
fn_dqm_service_bit8_submit_direct_request_80c8aeb0_candidate
```

Behavior:

```text
request_word_a = b6001c30
request_word_b = b6001c34
```

If service-state bit0x2 at 0x80008160 is clear:

```text
b6001408 = request_word_b >> 12
translated = b600140c
fn_dqm_request_barrier_noop_80c890e4_candidate()
b6001300 = translated + (request_word_a & 0x7ff)
b6001304 = request_word_b
b6001308 = 0
b600130c = (request_word_b & 0x0fff) | 0x4000
b6001da0 = request_word_b
b6001da4 = request_word_b
b6001da8 = request_word_a & 0xfffff800
b6001dac = 2
```

If service-state bit0x2 is set:

```text
0x8000713c++
```

Important differences from selector/lane output paths:

- Does not write b2200224
- Does not allocate an FPM token from 0x12200200/208/210/218
- Does not wait or call a finalize helper when busy
- Uses the page translation pair b6001408/b600140c
- b6001dac is fixed to 2

Labels:

- b6001c30 -> DQM_DIRECT_REQUEST_WORD_A_16001c30_candidate
- b6001c34 -> DQM_DIRECT_REQUEST_WORD_B_16001c34_candidate
- b6001408 -> DQM_PAGE_TRANSLATE_INPUT_PAGE_16001408_candidate
- b600140c -> DQM_PAGE_TRANSLATE_RESULT_VALUE_1600140c_candidate

## Request barrier helper

The 0x80c8 family calls:

```text
fn_dqm_request_barrier_noop_80c890e4_candidate
```

This helper should be inspected or confirmed as a no-op barrier before final naming. It appears in the request submit paths immediately before request-block publication.

## MMIO alias block note

Ghidra initially showed no results for low29 and raw alias addresses such as:

- 0x14201c00
- 0x14201c04
- 0x14201c10
- 0x14201c14
- 0x14201c80
- 0x14201c90
- 0x13401ca0
- 0x13401ca4
- 0x13401cd0
- 0x13401cd4

Recommended Ghidra Memory Map additions:

```text
MMIO_1420_ALIAS_candidate
Start: 14200000
Length: 10000
Type: Uninitialized
Read: yes
Write: yes
Execute: no
Volatile: yes if available
Overlay: no
```

```text
MMIO_1340_ALIAS_candidate
Start: 13400000
Length: 10000
Type: Uninitialized
Read: yes
Write: yes
Execute: no
Volatile: yes if available
Overlay: no
```

Do not run auto-analysis on these blocks. They are MMIO/register windows, not code.

If Ghidra still rejects full block addresses, create a small test block:

```text
MMIO_14201C00_test
Start: 14201c00
Length: 100
Type: Uninitialized
Read: yes
Write: yes
Execute: no
```

## Labeling and cleanup decisions

Confirmed or recommended labels:

```text
DQM_SELECTOR_OUTPUT_GATE_TABLE_80008014_candidate
DQM_SELECTOR_OUTPUT_WORD0_BASE_16001c00_candidate
DQM_SELECTOR_OUTPUT_WORD1_BASE_16001c04_candidate
DQM_EVENT80000_SOURCE_INDEX_16001d30_candidate
DQM_EVENT100000_SOURCE_INDEX_16001d40_candidate
DQM_EVENT200000_SOURCE_INDEX_16001d50_candidate
DQM_DIRECT_REQUEST_WORD_A_16001c30_candidate
DQM_DIRECT_REQUEST_WORD_B_16001c34_candidate
DQM_PAGE_TRANSLATE_INPUT_PAGE_16001408_candidate
DQM_PAGE_TRANSLATE_RESULT_VALUE_1600140c_candidate
DQM_SELECTOR16_SPECIAL_LANE_GATE_16001912_candidate
DQM_SELECTOR17_SPECIAL_LANE_GATE_16001916_candidate
DQM_SELECTOR16_SPECIAL_WORD_B_14201c90_candidate
DQM_SELECTOR17_SPECIAL_WORD_B_14201c80_candidate
DQM_MODE2_LANE0_WORD_A_14201c00_candidate
DQM_MODE2_LANE0_WORD_B_14201c04_candidate
DQM_MODE2_LANE1_WORD_A_14201c10_candidate
DQM_MODE2_LANE1_WORD_B_14201c14_candidate
DQM_EVENT100000_MODE1_LANE0_WORD_A_13401ca0_candidate
DQM_EVENT100000_MODE1_LANE0_WORD_B_13401ca4_candidate
DQM_EVENT100000_MODE1_LANE1_WORD_A_13401cd0_candidate
DQM_EVENT100000_MODE1_LANE1_WORD_B_13401cd4_candidate
```

Avoided unsafe final naming:

- Do not final-name b6001c00 as only ACK. It is context-dependent.
- Do not final-name b6001014 or b6001818 as pure ACK without more runtime evidence.
- Do not final-name b2200224 beyond page-flag endpoint candidate.
- Do not create code/functions in MMIO alias ranges.

## Open questions

1. Why do both 0x80c7 and 0x80c8 helper families exist side-by-side?
2. Are the 0x80c8 helpers a copied runtime profile, alternate build path, or active GENET 0x500/0x510 path variant?
3. What is the exact hardware role of b2200224 beyond page-flag commit endpoint behavior?
4. What exact hardware operation is triggered by b6001300..b600130c and b6001da0..b6001dac?
5. What is the precise role of b6001408/b600140c page translation pair?
6. What are the exact semantics of b6001818 and b6001014: ACK, rearm, enable, or mixed write-one registers?
7. What are the real bus/MMIO mappings for 0x1340 and 0x1420 alias windows on this target?

## Current status

The main 0x80c8 event1800008 dispatcher set is cleaned enough for the next reverse pass. The registered handler address bug is fixed, the pending-bit services are mapped, selector/FPM behavior is matched against the 0x80c7 family, and the mode1/mode2/default output-lane routing is documented.

Next useful work:

- Confirm fn_dqm_request_barrier_noop_80c890e4_candidate body.
- Compare each cleaned 0x80c8 helper against its 0x80c7 counterpart for only meaningful address/register differences.
- Inspect xrefs to 0x80007120, 0x80007100, 0x80007128, and 0x80008014 to understand runtime command/control changes.
- Continue proving whether this 0x80c8 family is the active path tied to the OpenWrt GENET DMA/TX blocker.
