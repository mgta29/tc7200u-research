# Ghidra DQM mailbox region progress log - 2026-06-11

## Scope

This note records the current Ghidra reverse progress around the DQM mailbox dispatcher, mailbox context parser, slot selection and slot commit path, ctrl580 and ctrl880 submit helpers, slot quota rebalance logic, CP2 and FPM side service path, chunked hardware region submit path, and the earlier DQM queue profile installer chain.

This note is additive only. Old logs and notes are preserved. No git action is part of this command.

## Repository placement

Target path:
home/mgta29/tc7200u-research/records/notes/reverse

Reason:
- records is the main data bucket for notes and reverse work
- this is a reverse engineering progress log
- this note continues the existing dated log pattern

## High level outcome

This pass significantly tightened the DQM control path and removed several fake function splits created by decompiler flow recovery.

Main outcomes:
- the DQM mailbox dispatcher at 0x80c7a588 was mapped as a real command dispatcher
- the mailbox parser at 0x80c7a990 was mapped as the context builder for commands 0x64 and 0x65
- the ctrl580 status submit helper at 0x80c7ac40 was identified and tied into later slot paths
- the free-slot selection and programming path at 0x80c7aca0 was merged and cleaned
- the status2-only slot update and commit path at 0x80c7aea0 was corrected
- the slot commit, wait, validate, and optional rebalance path at 0x80c7af64 was mapped
- the ctrl880 submit helper at 0x80c7b324 was isolated as a real helper
- the ctrl880 plus CP2 and FPM service helper at 0x80c7b358 was mapped
- the recursive slot reference walk and service helper at 0x80c7b22c was mapped
- the active-slot quota rebalance function at 0x80c7aa68 was merged correctly and fake split 0x80c7ab2c was removed
- the earlier chunked hardware region submit helper at 0x80c7b700 was stabilized and fake tail splits were identified
- the DQM queue profile install chain around 0x80c801e4 and 0x80c802d8 remained consistent with the new mailbox driven paths

## Important renamed functions

Confirmed or improved names in this pass:
- fn_dqm_mailbox_command_dispatch_80c7a588_candidate
- fn_dqm_parse_mailbox_ctx_cmd64_cmd65_80c7a990_candidate
- fn_popcount_u32_80c7aa48_candidate
- fn_dqm_rebalance_active_slot_quota_and_program_80c7aa68_candidate
- fn_dqm_submit_ctrl580_and_read_status_80c7ac40_candidate
- fn_dqm_select_free_region_and_program_context_80c7aca0_candidate
- fn_dqm_update_slot_fields_on_status2_and_commit_80c7aea0_candidate
- fn_dqm_commit_slot_wait_validate_and_maybe_rebalance_80c7af64_candidate
- fn_dqm_walk_slot_ref_chain_and_service_80c7b22c_candidate
- fn_dqm_submit_ctrl880_wait_80c7b324_candidate
- fn_dqm_slot_ctrl880_wait_and_service_cp2_fpm_path_80c7b358_candidate
- fn_dqm_slot_service_finalize_and_bump_counter_80c7b534_candidate
- fn_dqm_submit_region20_with_status_mask_80c79950_candidate
- fn_dqm_hw_region_submit_wait_chunked_80c7b700_candidate
- fn_dqm_hw_region_runtime_state_and_scratch_init_80c7b81c_candidate
- fn_dqm_hw_region_submit_wait_sequence_80c7bdac_candidate
- fn_dqm_cp2_selector_and_hw_block_init_80c7bc04_candidate
- fn_dqm_queue_profile_install_direct_preserve_bitmaps_80c801e4_candidate
- fn_dqm_queue_profile_install_80c802d8_candidate
- fn_dqm_emit_queue_config_record_80c85590_candidate
- fn_dqm_queue_profile_batch_init_direct_80c7b95c_candidate

Important label only symbols retained as labels instead of fake functions:
- lab_dqm_rebalance_second_pass_per_slot_program_80c7ab2c_candidate
- lab_dqm_select_free_region_submit_and_program_80c7ace0_candidate
- lab_dqm_hw_region_submit_remainder_80c7b7c0_candidate
- lab_dqm_hw_region_submit_remainder_wait_result_80c7b7e4_candidate

## Mailbox command dispatcher 0x80c7a588

fn_dqm_mailbox_command_dispatch_80c7a588_candidate is now the top level mailbox command handler for the DQM control block.

Observed front-end behavior:
- first checks 0x8000800c bit 0x10000
- if the bit is clear it immediately returns 0
- copies four words from b6001d00..b6001d0c into stack locals
- interprets the low byte of cmd_word0 as the command ID
- writes command reply state to b6001d10 and b6001d14
- returns the command ID byte

Observed command IDs:
- 0x02 and 0x04 fall into a simple immediate reply path
- 0x03 walks active slots and calls FUN_80c7b0f4 on referenced low20 values
- 0x07 runs fn_dqm_runtime_scratch_fill_stack_probe_80c80420_candidate and returns a packed reply
- 0x64 parses context through FUN_80c7a990 and then calls fn_dqm_select_free_region_and_program_context_80c7aca0_candidate
- 0x65 parses context through FUN_80c7a990 and then calls fn_dqm_update_slot_fields_on_status2_and_commit_80c7aea0_candidate
- 0x66 calls FUN_80c7b0f4 directly on cmd_arg0 low20
- 0x6a returns 0x100 in the reply low word
- 0x6b updates uRam8000704c and uRam8000705c, then runs quota rebalance
- 0x6c reports a translated runtime scratch pointer derived from iRam80007050 plus 0x49ffc000
- 0x6d switches puRam80007054 between b6000000 and b3400000
- 0x6e conditionally pokes b4e00010 if uRam8000705c is zero
- 0x6f calls fn_dqm_walk_slot_ref_chain_and_service_80c7b22c_candidate
- 0x70 reads or clears an entry from the runtime table at 0x80007174

Current interpretation:
main DQM mailbox command dispatcher and command-response handler.

## Mailbox parser 0x80c7a990

fn_dqm_parse_mailbox_ctx_cmd64_cmd65_80c7a990_candidate is the parser for commands 0x64 and 0x65.

Observed behavior:
- initializes parsed_ctx[10] = 0x10
- initializes parsed_ctx[11] = 0
- extracts low20 of cmd_word1 into parsed_ctx[0]
- extracts bits 29:25 of cmd_word1 into parsed_ctx[1], then adds 1
- extracts bits 24:20 of cmd_word1 into parsed_ctx[2], then adds 1
- stores cmd_word2 into parsed_ctx[3]
- stores halfword at command offset 0x0e into parsed_ctx[4]
- stores bit30 of cmd_word1 into parsed_ctx[5]
- stores bit31 of cmd_word1 into parsed_ctx[6]
- stores low16 of cmd_word0 into parsed_ctx[7] low16
- validates parsed_ctx[1] < 0x20 after increment
- on success sets parsed_ctx[8] = 0x4000 and parsed_ctx[9] = 0x40
- on failure sets parsed_ctx[11] = 7 and returns 0

Current interpretation:
mailbox parser and normalizer for the context later consumed by the free-slot programming and status2 slot update helpers.

## Ctrl580 submit helper 0x80c7ac40

fn_dqm_submit_ctrl580_and_read_status_80c7ac40_candidate:
- writes b604008c = (selector << 12) | 0x580
- issues sync
- polls until b604008c bit 0x80 clears
- reads b6040090
- stores low 7 bits into the output pointer
- returns 0 on the default non-negative path
- returns 1 when the status word is negative and bit 0x80 is clear
- returns 2 when the status word is negative and bit 0x80 is set

This helper is the front-end gate for later slot selection and update flows.

## Free-slot selection and program path 0x80c7aca0

fn_dqm_select_free_region_and_program_context_80c7aca0_candidate is now a clean merged parent.

Observed flow:
- calls fn_dqm_submit_ctrl580_and_read_status_80c7ac40_candidate on region_ctx[0]
- if helper returns 0, writes region_ctx[11] = 0 and fails
- if helper returns 2, writes region_ctx[11] = 2 and fails
- otherwise scans the low 16 bits of b6040500 for the first clear slot bit
- if all 16 bits are set, also writes region_ctx[11] = 2 and fails
- submits several per-slot hardware regions:
  - b6040700 + slot*4 size 0x4
  - b6041000 + slot*0x20 size 0x20 through the masked helper
  - b6042000 + slot*0x40 size 0x40
  - b6046000 + slot*0x10 size 0x10
  - b6043000 + slot*0x40 size 0x40
- writes per-slot config fields through FUN_80c7990c
- builds final control word for b604008c
- calls FUN_80c7aa68
- stores the selected slot index into region_ctx[10]
- returns 1 on success

Status fields:
- region_ctx[10] = selected slot index on success
- region_ctx[11] = failure status

## Status2 slot update and commit path 0x80c7aea0

fn_dqm_update_slot_fields_on_status2_and_commit_80c7aea0_candidate was corrected to reflect the actual status gating.

Observed flow:
- calls fn_dqm_submit_ctrl580_and_read_status_80c7ac40_candidate
- if helper returns 0, writes ctx[11] = 0 and fails
- if helper returns 1, writes ctx[11] = 1 and fails
- if helper returns 2:
  - programs slot field 0x18 from ctx[3]
  - programs slot field 0x1c from ctx[9], ctx[2], and ctx[1]
  - calls fn_dqm_commit_slot_wait_validate_and_maybe_rebalance_80c7af64_candidate(slot, 1)
  - on success stores slot index in ctx[10]
  - returns 1

This path is not a generic update helper. It is specifically a status2 gated update-and-commit path.

## Commit, validate, and optional rebalance path 0x80c7af64

fn_dqm_commit_slot_wait_validate_and_maybe_rebalance_80c7af64_candidate:
- sets the slot bit in b6040198
- waits until the same slot bit appears in b60401a0
- writes b604008c = slot_index | 0x780
- waits for busy bit to clear
- if the slot bit is set in b6040510:
  - reads slot fields through FUN_80061020 slot 0, 8, and 0x0c
  - performs a size or range validation check
  - if the check fails and FUN_80c7b324 returns 0, emits cmd06 with argument 1 and fails
- clears the slot bit from b6040198
- if do_rebalance == 1, runs fn_dqm_rebalance_active_slot_quota_and_program_80c7aa68_candidate
- returns 1 on the normal path

This helper links the slot programming path to the later ctrl880 and CP2 or FPM service path.

## Recursive slot reference walker 0x80c7b22c

fn_dqm_walk_slot_ref_chain_and_service_80c7b22c_candidate:
- if root_slot_ref == 0:
  - scans slots 0..15
  - for each active slot with a nonzero low20 reference field, recursively walks that referenced slot
  - returns 0 on first failure, otherwise 1
- if root_slot_ref != 0:
  - calls fn_dqm_submit_ctrl580_and_read_status_80c7ac40_candidate
  - helper return 0 writes status_out = 0 and fails
  - helper return 1 writes status_out = 1 and fails
  - helper return 2:
    - calls fn_dqm_slot_ctrl880_wait_and_service_cp2_fpm_path_80c7b358_candidate
    - writes b6040120 = 0x13
    - sets the slot bit in 0x80007048
    - returns 1

Current interpretation:
recursive slot-reference walker and service helper. The low20 field of the slot state word appears to hold a referenced slot or control identifier.

## Ctrl880 submit helper 0x80c7b324

fn_dqm_submit_ctrl880_wait_80c7b324_candidate:
- writes b604008c = slot_index | 0x880
- executes sync
- polls 0x800080d4 until bit 0x80 clears
- returns 1

This is a small submit and wait helper. The exact hardware semantic of opcode 0x880 is still unresolved.

## Ctrl880 plus CP2 or FPM service path 0x80c7b358

fn_dqm_slot_ctrl880_wait_and_service_cp2_fpm_path_80c7b358_candidate:
- calls fn_dqm_submit_ctrl880_wait_80c7b324_candidate
- if that fails, emits cmd06 with argument 2 and returns 0
- checks 0x80008100 + slot*4 bit 0x10
- if that bit is clear, returns 1
- otherwise temporarily rewrites b60400c0, b60400c4, b60400e0, and b60400e4
- may mirror b6040144 into the FPM pool0 endpoint register at 0xb2200200 when 0x800080e8 bit 1 is set
- then enters a CP2 or FPM drain and service loop while 0x800080e8 bit 0 or the runtime event07 skip-pull mask bit 0x400 remains asserted
- inside the inner loop reads CP2 register f001 and stores the value to FPM_POOL0_ENDPOINT_12200200_candidate
- restores the saved control values and resets b60400c0 to 0x180
- returns 1 on the normal path

This is one of the more important hardware service helpers in the current cluster.

## Slot service finalize path 0x80c7b534

fn_dqm_slot_service_finalize_and_bump_counter_80c7b534_candidate:
- calls fn_dqm_slot_ctrl880_wait_and_service_cp2_fpm_path_80c7b358_candidate
- if that fails, emits cmd06 with argument 9 and returns 0
- writes b6040120 = 0x11
- sets the slot bit in runtime mask 0x80007048
- waits for 0x800080a0 bit 0x10 to clear
- writes b6040120 = 0x10
- increments the per-slot counter at b6042000 + slot*0x40 + 0x24
- waits again for 0x800080a0 bit 0x10 to clear
- returns 0x800080a4

## Slot quota rebalance path 0x80c7aa68

fn_dqm_rebalance_active_slot_quota_and_program_80c7aa68_candidate is now the clean merged parent with the fake split at 0x80c7ab2c removed.

Observed behavior:
- pass 1 scans slots 0..15 and sums a total active weight using popcount of FUN_80061020(slot, 4)
- if total active weight is zero, returns immediately
- computes base quota from uRam8000704c divided by total active weight
- computes remainder
- pass 2 revisits active slots:
  - computes per-slot quota
  - caps quota at 0x4000
  - writes quota into the runtime table under 0x80007068 + slot*0x10
  - writes slot fields 0x18 and 0x1c
  - calls FUN_80c7af64(slot, 0)
  - clears the per-slot runtime flag

Helper 0x80c7aa48 was renamed to fn_popcount_u32_80c7aa48_candidate and is confirmed as a popcount loop.

## Earlier DQM region submit and CP2 selector path retained

The earlier conclusions remain consistent with the newer mailbox path:
- fn_dqm_submit_region20_with_status_mask_80c79950_candidate submits a 0x20-byte region from b6041000 + index*0x20 while temporarily overriding b6040534 and b604053c
- fn_dqm_hw_region_submit_wait_chunked_80c7b700_candidate is the real parent for the chunked hardware-region submit and wait flow, with fake tails 0x80c7b7c0 and 0x80c7b7e4 kept as labels only
- fn_dqm_hw_region_runtime_state_and_scratch_init_80c7b81c_candidate is the real parent for the runtime state and scratch table setup, with 0x80c7b868 treated as part of the same parent flow
- fn_dqm_hw_region_submit_wait_sequence_80c7bdac_candidate is the multi-region submit and wait wrapper
- fn_dqm_cp2_selector_and_hw_block_init_80c7bc04_candidate remains the front-end CP2 selector and control-block initializer

## Earlier DQM queue profile work retained

The earlier queue-profile findings remain in place and now connect cleanly with the mailbox-driven control layer:
- fn_dqm_queue_profile_install_direct_preserve_bitmaps_80c801e4_candidate
- fn_dqm_queue_profile_install_80c802d8_candidate
- fn_dqm_emit_queue_config_record_80c85590_candidate
- fn_dqm_queue_profile_batch_init_direct_80c7b95c_candidate

These earlier findings were not invalidated by the new mailbox and slot-control work.

## Fake function cleanup summary

Confirmed fake splits that should remain labels only:
- 0x80c802a0 inside 0x80c801e4
- 0x80c802a8 inside 0x80c801e4
- 0x80c7ab2c inside 0x80c7aa68
- 0x80c7ace0 inside 0x80c7aca0
- 0x80c7b7c0 inside 0x80c7b700
- 0x80c7b7e4 inside 0x80c7b700
- 0x80c7b868 inside 0x80c7b81c

## Results

Current confidence is high for:
- mailbox command dispatch structure
- parser role of 0x80c7a990
- ctrl580 status submit semantics
- free-slot selection and slot programming path
- status2 gated update and commit path
- recursive slot walk and service logic
- ctrl880 submit helper role
- ctrl880 plus CP2 or FPM service path
- slot quota rebalance structure
- fake split cleanup in the major parents above

Remaining uncertainty:
- exact semantic name of the ctrl880 opcode beyond submit and wait
- precise meaning of some b60400c0 or c4 or e0 or e4 control values
- precise hardware meaning of 0x800080d4, 0x800080e4, 0x800080e8, and 0x800080a0 sideband status words
- full context type names for the parsed command buffer built by 0x80c7a990

## Recommended next reverse targets

1. Revisit 0x80c7b0f4 and its callers with the now-clean mailbox command context.
2. Continue outward from the mailbox dispatcher callers to identify the higher-level command submission source.
3. Resolve the sideband status registers around 0x800080d4, 0x800080e4, 0x800080e8, and 0x800080a0.
4. Define a real parsed_ctx struct once enough field meanings are confirmed across commands 0x64 and 0x65.
5. Keep preserving old notes and only add new dated logs.

## Preservation

This note is additive. No existing logs or notes were deleted. No git action is part of this command.
