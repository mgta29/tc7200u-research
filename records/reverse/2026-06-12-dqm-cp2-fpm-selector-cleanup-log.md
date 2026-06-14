# 2026-06-12 DQM / CP2 / FPM selector cleanup log

## Scope

This note records the current Ghidra cleanup progress for the TC7200U DQM / CP2 / FPM selector path, focused on the `0x01800008` DQM event service chain and the related queue/profile, selector lookup, CP2 `b604`, and FPM endpoint helpers.

The work covered local function cleanup, candidate-suffix review, confirmed renames, remaining hardware uncertainty, and the current state of the event/service path.

No git operations were performed by this note.

## Current focus area

```text
Subsystem: DQM event 0x01800008 / CP2 / FPM selector path
Main reverse target: TC7200U OEM firmware runtime DQM path
Current Ghidra state: multiple small helpers cleaned, several names promoted out of _candidate
Primary uncertainty: b604 table layout and exact 0xb2200224 endpoint role
Overall status estimate
DQM event 0x01800008 path:        ~85–90%
DQM / CP2 / FPM subsystem:        ~68–72%
OpenWrt-useful hardware mapping:  ~55%
Current cleanup chain:            strong / mostly stable

The control flow is now largely readable. Remaining uncertainty is mostly hardware-table semantics, not basic decompiler cleanup.

Candidate suffix policy established

A local cleanup score of 100% does not automatically mean _candidate must be removed.

The working rule is:

Remove _candidate only when both are true:
  1. The behavior is fully proven.
  2. The name is descriptive, mechanical, non-speculative, and unlikely to change later.

Keep _candidate when the name still depends on wider hardware interpretation.

Practical rule:

100% clean + simple/mechanical helper = remove _candidate
100% clean + hardware role still interpreted = keep _candidate
<95% clean = keep _candidate

This prevents unstable names from becoming final too early.

Functions promoted out of _candidate

The following functions were considered safe to rename because their behavior is simple, local, and mechanically proven.

fn_dqm_record_field_to_lookup_index_80c7d5f4

Previous name:

fn_dqm_record_field_to_lookup_index_80c7d5f4_candidate

Final name:

fn_dqm_record_field_to_lookup_index_80c7d5f4

Status:

100% clean

Confirmed behavior:

- accepts a halfword field value, currently passed from record +0x10
- treats it as unsigned 16-bit
- subtracts 0x0d
- maps valid values 0x0d..0x1c to lookup indexes 0..15
- returns 0xff for invalid/out-of-range values

Reason _candidate was removed:

The function is a pure range-normalization helper.
There is no unresolved hardware role in the name.
The output behavior is fully proven by the decompiled logic.
fn_dqm_queue1c_preload_8_entries_80c7c008

Previous name:

fn_dqm_queue1c_preload_8_entries_80c7c008_candidate

Final name:

fn_dqm_queue1c_preload_8_entries_80c7c008

Status:

100% clean

Confirmed behavior:

- builds a queue/profile descriptor for queue/profile 0x1c
- descriptor values:
    byte0 = 0
    byte1 = 1
    byte2 = 0x1c
    byte3 = 1
    halfword4 = 8
    halfword6 = 0
    halfword8 = 8
- installs it through fn_dqm_queue_profile_install_80c802d8_candidate()
- preloads values 0..7 into DQM_QUEUE_PRELOAD_PORT_B_16001dc0_candidate

Reason _candidate was removed:

The function is a fixed small preload helper.
The queue/profile number and preload count are directly visible.
No ambiguous hardware-table interpretation is required for the name.
fn_dqm_b6040010_set_three_enable_bits_80c7c068

Previous name:

fn_dqm_b6040010_set_three_enable_bits_80c7c068_candidate

Final name:

fn_dqm_b6040010_set_three_enable_bits_80c7c068

Status:

100% clean

Confirmed behavior:

- accepts three bit-source arguments
- masks each argument to bit0
- writes the packed result to b6040010:
    bit2 = enable_bit2 & 1
    bit1 = enable_bit1 & 1
    bit0 = enable_bit0 & 1

Recommended final global label:

Ramb6040010 -> DQM_CP2_REGION_ENABLE_BITS_16040010_candidate

Reason _candidate was removed from the function:

The helper does exactly one register/config write.
The behavior is fully visible and non-branching.
The function name describes the exact operation without over-interpreting the whole hardware block.
fn_dqm_queue1d_preload_50_entries_80c7bf70

Previous name:

fn_dqm_queue1d_preload_50_entries_80c7bf70_candidate

Final name:

fn_dqm_queue1d_preload_50_entries_80c7bf70

Status:

95–100% clean

Confirmed behavior:

- builds a queue/profile descriptor for queue/profile 0x1d
- descriptor values:
    byte0 = 0
    byte1 = 1
    byte2 = 0x1d
    byte3 = 1
    halfword4 = 0x50
    halfword6 = 0
    halfword8 = 0x50
- installs it through fn_dqm_queue_profile_install_80c802d8_candidate()
- preloads 0x50 backing addresses into DQM_QUEUE_PRELOAD_PORT_A_16001dd0_candidate
- each entry value is:
    0x16010000 + entry_index * 0x140
- stores the next free backing address in the selector context allocation cursor

Recommended final global label:

iRam80007124 -> DQM_SELECTOR_CONTEXT_ALLOC_CURSOR_80007124_candidate

Reason _candidate was removed from the function:

The queue/profile number, count, and address formula are directly visible.
The name describes the mechanical preload action.
The remaining uncertainty is not in the function behavior.
Functions intentionally still carrying _candidate

The following names should keep _candidate for now because their names include hardware-role interpretation that may still change after the whole DQM/CP2/FPM path is locked.

fn_dqm_cp2_b604_table_init_80c7c090_candidate

Status:

80–85% clean

Confirmed behavior:

- clears and programs a fixed table in the 0xb6040400..0xb60406c4 region
- programs grouped control words, flags, target addresses, and size-like constants
- installs target addresses:
    0x13401900
    0x13401904
    0x14201908
    0x1420190c
- installs selector-derived CP2 command entries:
    b6040564 = (selector A & 0x1f) << 8 | 0x50002000
    b60405c0 = GENET target A & 0x1fffffff
    b6040640 = 0x04208000
    b6040568 = (selector B & 0x1f) << 8 | 0x50002001
    b60405c4 = GENET target B & 0x1fffffff
    b6040644 = 0x04208000
- writes global/control words:
    b604007c = 0x11001cef
    b6040080 = 1
    b6040084 = 0x12200200

Required/accepted labels:

uRam80007110 -> DQM_CP2_SELECTOR_A_80007110_candidate
uRam80007114 -> DQM_CP2_SELECTOR_B_80007114_candidate
uRam80007118 -> DQM_CP2_GENET_TARGET_A_80007118_candidate
uRam8000711c -> DQM_CP2_GENET_TARGET_B_8000711c_candidate

Ramb604007c -> DQM_CP2_B604_GLOBAL_CTRL_1604007c_candidate
Ramb6040080 -> DQM_CP2_B604_GLOBAL_ENABLE_16040080_candidate
Ramb6040084 -> DQM_CP2_B604_FPM_POOL0_ENDPOINT_16040084_candidate

Do not mass-label yet:

Ramb6040400..Ramb60406c4

Reason _candidate stays:

The table is definitely real and important, but the per-column and per-row field semantics are not fully decoded.
A final non-candidate name would imply stronger certainty than currently exists.
fn_dqm_selector_push_genet_stub_event_or_fpm_return_80c7e158_candidate

Status:

95–100% clean

Confirmed behavior:

- accepts service_selector and selector_value
- selector 0x0a / 0x0b uses DQM_CP2_GENET_TARGET_A_80007118_candidate
- selector 0x0c / 0x0d uses DQM_CP2_GENET_TARGET_B_8000711c_candidate
- other selector IDs write selector_value to FPM_POOL0_ENDPOINT_12200200_candidate
- valid selector path pushes three words to CP2 register f801:
    0x04208000
    selector_value
    target_reg_addr & 0x1fffffff
- returns a combined 64-bit value built from command word and low29 target address

Recommended type fix:

selector_value: undefined4 -> uint

Reason _candidate stays:

The behavior is mostly known, but the name includes GENET, CP2, FPM, stub-event, and return semantics.
Those are broader hardware-role interpretations, not just local arithmetic behavior.
fn_dqm_event1800008_dispatch_pending_services_80c7cbf0_candidate

Status:

High-value dispatcher, not final

Known role:

- central dispatcher for DQM event/mask 0x01800008
- checks pending/service bits
- calls service handlers
- coordinates selector dispatch/finalize paths

Reason _candidate stays:

The function connects several service bits and side effects.
Some pending-mask and service-state semantics are still being proven.
fn_dqm_try_issue_selector_record_fpm_request_80c7d618_candidate

Status:

Important bridge function, mostly understood, not final

Known role:

- reads selector record fields
- maps a record field to lookup index through fn_dqm_record_field_to_lookup_index_80c7d5f4
- checks selector/FPM gate state
- may issue an FPM request
- may fall back to selector publish path

Reason _candidate stays:

The function is central to the selector/FPM request path.
Some gate-mode and request-engine semantics are still not final.
FPM_OR_B220_ENDPOINT_12200224_candidate

Status:

Cautious global label retained

Known behavior:

- appears in fallback/publish/finalize paths
- acts endpoint-like
- likely related to FPM/B220 mailbox or return path

Reason _candidate stays:

The exact block identity of 0xb2200224 is not proven.
The cautious label prevents locking in a wrong hardware name.
Confirmed DQM setup chain

The runtime setup path now has a readable structure.

Main setup function:

fn_dqm_runtime_queue_profile_window_and_irq_init_80c7ce70_candidate

Confirmed helper chain:

fn_dqm_queue1d_preload_50_entries_80c7bf70
fn_dqm_queue1c_preload_8_entries_80c7c008
fn_dqm_selector_lookup_context_table_init_80c7c2a8_candidate
fn_dqm_b6040010_set_three_enable_bits_80c7c068
fn_dqm_cp2_b604_table_init_80c7c090_candidate
fn_dqm_event_handler_register_80c739f8_candidate
fn_dqm_event_mask_enable_disable_8005fa08_candidate

Setup behavior summary:

- initializes DQM queue/profile support
- preloads queue/profile 0x1d with 0x50 backing addresses
- preloads queue/profile 0x1c with values 0..7
- builds selector lookup/context table
- configures b604 CP2/DQM table
- enables b6040010 three-bit region/config value
- registers the event handler
- enables DQM event mask 0x01800008
Selector lookup/context table status

Function:

fn_dqm_selector_lookup_context_table_init_80c7c2a8_candidate

Status:

95% clean

Confirmed behavior:

- disables selector lookup flag at 0x80007128
- initializes 16 entries at 0x8000714c
- each entry has stride 0x18
- allocates two 0x0c-byte context records from the cursor at 0x80007124
- stores mapped pointers using low16 | 0x80000000
- stores backing addresses
- clears both records
- seeds common record fields:
    byte0 = 1
    byte2 = 0x0c
    byte3 = 4
- context A gets byte6 = 0x60
- context B gets byte6 = 0
- clears per-entry counter and global selector/FPM request counters

Recommended table layout note:

Table entry layout, base 0x8000714c, stride 0x18:
  +0x00 halfword control/enable field
  +0x02 halfword control/flag field
  +0x04 mapped context A pointer
  +0x08 mapped context B pointer
  +0x0c per-entry counter
  +0x10 context A backing address
  +0x14 context B backing address

Required/accepted labels:

uRam80007128 -> DQM_SELECTOR_LOOKUP_ENABLE_80007128_candidate
uRam80007124 -> DQM_SELECTOR_CONTEXT_ALLOC_CURSOR_80007124_candidate

uRam8000712c -> DQM_SELECTOR_FPM_GATE_ATTEMPT_COUNT_8000712c_candidate
uRam80007130 -> DQM_SELECTOR_FLAG10_SKIP_COUNT_80007130_candidate
uRam80007134 -> DQM_SELECTOR_FPM_REQUEST_ISSUED_COUNT_80007134_candidate
uRam80007138 -> DQM_SELECTOR_FPM_GATE_FALLBACK_COUNT_80007138_candidate
uRam8000713c -> DQM_SELECTOR10_WAIT_BUSY_COUNT_8000713c_candidate
uRam80007140 -> DQM_SELECTOR_FPM_WAIT_BUSY_COUNT_80007140_candidate
uRam80007144 -> DQM_SELECTOR10_BUSY_RETURN_COUNT_80007144_candidate
uRam80007148 -> DQM_SELECTOR_FPM_BUSY_RETURN_COUNT_80007148_candidate

Recommended local rename:

context_a_ptr -> context_a_mapped_ptr
Confirmed selector dispatch behavior

Wrapper:

fn_dqm_dispatch_selector_index_port_80c7dc48_candidate

Status:

95–100% clean

Behavior:

- reads selector/index/port value from DQM_QUEUE_SELECTOR_INDEX_PORT_16001c00_candidate + service_selector * 0x10
- forwards service_selector and selector value into the CP2/FPM selector helper
- returns the forwarded 64-bit result

No forced local extraction is required. The expression may remain inline because the available Ghidra menu did not expose a useful extract-variable option.

Confirmed CP2 command behavior

The selector helper and the b604 table both contain the same fixed command word:

0x04208000

This appears in:

- CP2 f801 push path
- b604 selector-derived table entries

The same low29 address mask appears repeatedly:

0x1fffffff

Current interpretation:

The mask converts mapped register pointers into low 29-bit physical/bus-visible address form.

This is important for OpenWrt bring-up because it helps distinguish CPU virtual/mapped pointers from hardware-visible addresses.

Current high-confidence labels
FPM / endpoints
FPM_POOL0_ENDPOINT_12200200_candidate
FPM_ENDPOINT_400_12200208
FPM_ENDPOINT_200_12200210
FPM_ENDPOINT_100_12200218
FPM_OR_B220_ENDPOINT_12200224_candidate
Selector queue/window
DQM_QUEUE_SELECTOR_INDEX_PORT_16001c00_candidate
DQM_QUEUE_SELECTOR_WORD1_16001c04_candidate
DQM_QUEUE_PRELOAD_PORT_A_16001dd0_candidate
DQM_QUEUE_PRELOAD_PORT_B_16001dc0_candidate
Selector CP2/GENET values
DQM_CP2_SELECTOR_A_80007110_candidate
DQM_CP2_SELECTOR_B_80007114_candidate
DQM_CP2_GENET_TARGET_A_80007118_candidate
DQM_CP2_GENET_TARGET_B_8000711c_candidate
Selector context/counters
DQM_SELECTOR_CONTEXT_ALLOC_CURSOR_80007124_candidate
DQM_SELECTOR_LOOKUP_ENABLE_80007128_candidate
DQM_SELECTOR_FPM_GATE_ATTEMPT_COUNT_8000712c_candidate
DQM_SELECTOR_FLAG10_SKIP_COUNT_80007130_candidate
DQM_SELECTOR_FPM_REQUEST_ISSUED_COUNT_80007134_candidate
DQM_SELECTOR_FPM_GATE_FALLBACK_COUNT_80007138_candidate
DQM_SELECTOR10_WAIT_BUSY_COUNT_8000713c_candidate
DQM_SELECTOR_FPM_WAIT_BUSY_COUNT_80007140_candidate
DQM_SELECTOR10_BUSY_RETURN_COUNT_80007144_candidate
DQM_SELECTOR_FPM_BUSY_RETURN_COUNT_80007148_candidate
CP2 / b604 globals
DQM_CP2_REGION_ENABLE_BITS_16040010_candidate
DQM_CP2_B604_GLOBAL_CTRL_1604007c_candidate
DQM_CP2_B604_GLOBAL_ENABLE_16040080_candidate
DQM_CP2_B604_FPM_POOL0_ENDPOINT_16040084_candidate
Important unresolved items
1. b604 table layout

Region:

0xb6040400..0xb60406c4

Known:

- fixed hardware table
- initialized during DQM/CP2 runtime setup
- includes selector-derived entries
- includes GENET-related low29 target addresses
- includes fixed command word 0x04208000

Unknown:

- exact row meanings
- exact column meanings
- whether the rows are command descriptors, queue entries, endpoints, or mixed records

Current action:

Do not mass-label Ramb6040400..Ramb60406c4.
Keep raw writes until the table layout is proven by xrefs, hardware behavior, or matching OEM/source references.
2. 0xb2200224 endpoint role

Known:

- appears in fallback/publish/finalize paths
- endpoint-like behavior
- likely related to FPM or B220 mailbox/return path

Unknown:

- exact hardware block identity
- whether it is pure FPM, B220 mailbox, CP2 return port, or another queue endpoint

Current action:

Keep cautious label:
FPM_OR_B220_ENDPOINT_12200224_candidate
3. Selector context table field names

Known:

- base around 0x8000714c
- 16 entries
- stride 0x18
- context A/B pointers and backing addresses are visible

Unknown:

- exact meaning of +0x00 and +0x02 halfword fields
- exact semantic meaning of context byte6 = 0x60 for context A
- exact semantic meaning of context byte6 = 0 for context B

Current action:

Do not force a struct yet.
Use table-layout comments only.
Result of this cleanup pass
- Several small helpers were promoted from candidate to final names.
- The selector record-field normalization helper is now final.
- Queue/profile preload helpers for 0x1c and 0x1d are now final.
- The b6040010 three-bit enable helper is now final.
- Larger hardware-role functions keep _candidate.
- The DQM event1800008 setup chain is substantially clearer.
- CP2 f801 command push behavior is tied to the b604 table command entries.
- GENET target A/B globals are now clearly part of selector-derived CP2 command setup.
- FPM pool0 endpoint 0x12200200 is confirmed in both fallback and b604 global setup.
- b604 table body remains intentionally raw because field layout is not fully proven.
Recommended next reverse targets

Primary next target:

fn_dqm_event1800008_dispatch_pending_services_80c7cbf0_candidate

Reason:

This ties the cleaned setup and selector helpers back into the real event pending-mask dispatcher.

Secondary next target:

fn_dqm_try_issue_selector_record_fpm_request_80c7d618_candidate

Reason:

This is the main bridge between record fields, lookup context table, selector gate state, and FPM request issue path.
Working rules to preserve
- Do not delete old logs.
- Do not overwrite existing evidence.
- Create dated records under records/notes/reverse.
- Do not create fake functions.
- Do not mass-label uncertain hardware tables.
- Do not remove _candidate from hardware-role names until the wider path is locked.
- Keep cautious labels when exact block identity is unresolved.
- Preserve existing naming conventions unless a rename is explicitly called out.

