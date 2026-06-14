# Ghidra DQM FPM CP2 progress log - 2026-06-11

## Scope

This note records the current Ghidra cleanup and reverse progress for the TC7200U OEM DQM, FPM, CP2, and queue profile path around 0x80c80174..0x80c85e10 and related callers.

This is a new dated note under records/notes/reverse/. No old logs or notes were deleted. No git action is part of this command.

## High level result

The current pass resolved the local queue profile install chain from allocator and word index helpers through both installer variants, batch profile recipe wrappers, profile record emitters, and the CP2 selector or hardware block initialization helpers.

Main result:
- runtime bump allocator helper identified and renamed
- backing address to DQM word index helper identified and renamed
- direct queue profile installer mapped and given a real 4 argument signature
- packed record queue profile installer mapped with better field meanings
- queue bitmap A, bitmap B, update trigger, and IRQ or ack register roles tightened
- fake function splits at 0x80c802a0 and 0x80c802a8 converted to labels only
- 0x80c85590 record emitter path cleaned and tied to installer 0x80c802d8
- bulk direct batch installer 0x80c7b95c mapped as a fixed queue layout recipe
- 0x80c7bc04 block mapped as CP2 selector and DQM hardware block initialization gate
- 0x80c7bdac identified as a multi region DQM hardware probe sequence
- 0x80c7bd4c and 0x80c7be8c identified as small DQM command or status helpers

## Important renamed functions

Confirmed or improved candidate names during this pass:
- fn_runtime_bump_alloc_aligned4_80c80174_candidate
- fn_dqm_backing_addr_to_word_index_80c801cc_candidate
- fn_dqm_queue_profile_install_direct_preserve_bitmaps_80c801e4_candidate
- fn_dqm_queue_profile_install_80c802d8_candidate
- fn_dqm_emit_queue_config_record_80c85590_candidate
- fn_dqm_emit_queue_config_record_group_a_80c856bc_candidate
- fn_dqm_emit_queue_config_record_group_b_80c8573c_candidate
- fn_dqm_copy_swapped_word_pairs_to_table_16052000_80c855d4_candidate
- fn_dqm_init_runtime_halfword_table_800070c0_80c85634_candidate
- fn_dqm_set_ctrl_bits_16040010_80c8579c_candidate
- fn_dqm_static_table_block_init_80c857c4_candidate
- fn_dqm_vector8_handler_80c85e10_candidate
- fn_dqm_queue_profile_batch_init_direct_80c7b95c_candidate
- fn_dqm_cp2_selector_and_hw_block_init_80c7bc04_candidate
- fn_dqm_hw_region_probe_sequence_80c7bdac_candidate
- fn_dqm_write_status_mode_and_value_80c7bd4c_candidate
- fn_dqm_emit_cmd06_with_return_pc_80c7be8c_candidate

## Important label cleanup

False function splits were removed or should remain labels only:
- lab_dqm_profile_install_write_step_and_bitmap_a_tail_80c802a0_candidate
- lab_dqm_profile_install_write_bitmap_b_trigger_irq_tail_80c802a8_candidate

These belong to the real parent function 0x80c801e4 and are not standalone functions.

## Helper findings

### 0x80c80174 runtime bump allocator

fn_runtime_bump_alloc_aligned4_80c80174_candidate is a real 4 byte aligned bump allocator over runtime scratch state.

Observed behavior:
- aligned_size = (requested_size + 3) & 0xfffffffc
- if aligned_size is nonzero and fits in remaining space:
  - return current cursor
  - advance cursor by aligned_size
  - subtract aligned_size from remaining count
- otherwise return 0

Interpreted state:
- 0x80007000 = runtime allocation cursor
- 0x80007004 = remaining free byte count

This invalidates the old stub patch interpretation.

### 0x80c801cc backing address to word index

fn_dqm_backing_addr_to_word_index_80c801cc_candidate converts a backing address into a 16 bit DQM word index.

Effective behavior:
- word_index = ((addr - 0x80004000) >> 2) & 0xffff

Practical effect:
- base 0x80004000 maps to index 0
- address is converted from byte offset to 32 bit word offset
- low 16 bits are stored into queue profile entries

## Installer variants

### 0x80c801e4 direct installer with bitmap preserve and restore

fn_dqm_queue_profile_install_direct_preserve_bitmaps_80c801e4_candidate is a real 4 argument installer.

Arguments:
- queue_id
- queue_type_count
- total_units
- step_low16_or_extra

Flow:
- allocates backing space of total_units shifted left by 2 bytes
- converts backing address to DQM word index
- snapshots current bitmap A and bitmap B state
- clears the queue bit from both bitmap paths
- writes short form profile entry to 0xb6001a00 + queue_id * 0x10
- restores bitmap A and bitmap B exactly as they were
- triggers queue update via 0xb600180c
- triggers IRQ or ack via 0xb6001818
- returns 1 on success and 0 on allocation failure

Entry format written:
- +0x00 = queue_type_count - 1
- +0x04 = concat total_units, backing_word_index
- +0x08 = ((total_units / queue_type_count) << 16) | step_low16_or_extra

Important note:
- the decompiler still shows high16 writes in a coarse way, but comments now capture the interpretation without forcing unsupported decompile rewrites

### 0x80c802d8 packed record installer

fn_dqm_queue_profile_install_80c802d8_candidate consumes a temporary profile record and installs one queue profile entry.

Inferred record fields:
- +0x00 = bitmap select or install mode flag
- +0x01 = immediate enable gate flag
- +0x02 = queue_id
- +0x03 = queue_type_count or divisor, valid range 1..4
- +0x04 = total_units
- +0x06 = low16 step or extra field
- +0x08 = queue limit or threshold
- +0x0a = backing word index output

Flow:
- allocates backing space of total_units shifted left by 2 bytes
- converts backing address to DQM word index
- writes 16 byte profile entry to 0xb6001a00 + queue_id * 0x10
- clears queue bit from bitmap A and bitmap B
- conditionally restores one bitmap path if record byte +0x01 equals 0
- record byte +0x00 selects bitmap A vs bitmap B restore path
- writes queue update trigger at 0xb600180c
- writes IRQ or ack trigger at 0xb6001818

Entry format written:
- +0x00 = queue_type_count - 1
- +0x04 = concat total_units, backing_word_index
- +0x08 = ((total_units / queue_type_count) << 16) | low16_step_or_extra_field
- +0x0c = queue_limit_or_threshold

Important interpretation tightened during this pass:
- record +0x01 gates whether the queue bit is restored after install
- record +0x00 selects bitmap A at 0xb6001804 vs bitmap B at 0xb6001810
- the inner zero check on queue_type_count is only the compiler divide guard and not a meaningful runtime branch

## Register cluster around 0xb6001804

Current candidate names and meanings:
- 0xb6001804 -> DQM_QUEUE_BITMAP_A_16001804_candidate
- 0xb600180c -> DQM_QUEUE_UPDATE_TRIGGER_1600180c_candidate
- 0xb6001810 -> DQM_QUEUE_BITMAP_B_OR_MASK_16001810_candidate
- 0xb6001818 -> DQM_QUEUE_IRQ_STATUS_OR_ACK_16001818_candidate

What is now supported:
- 0x1804 and 0x1810 are paired queue bitmaps used by both installer variants
- 0x180c is the per queue update or apply trigger
- 0x1818 is the IRQ, status, or ack path and is used by queue installs and vector handlers

## Record emitters and local config helpers

### 0x80c85590

fn_dqm_emit_queue_config_record_80c85590_candidate builds a 10 byte stack record and submits it through the packed record installer.

Observed layout:
- +0x00 = 0
- +0x01 = 1
- +0x02 = param_1
- +0x03 = low8 param_2
- +0x04 = param_2 * param_3
- +0x06 = 0
- +0x08 = param_4

This is a small record emitter wrapper, not direct hardware MMIO.

### 0x80c856bc group A

fn_dqm_emit_queue_config_record_group_a_80c856bc_candidate:
- emits one fixed record with selector 0x13
- then fills 0xb6001d30 with a sequence based on 0x16010000 plus stepped offsets

### 0x80c8573c group B

fn_dqm_emit_queue_config_record_group_b_80c8573c_candidate:
- emits one fixed record with selector 0x12
- then writes 0..7 to 0xb6001d20

### 0x80c855d4 swapped word pair copier

fn_dqm_copy_swapped_word_pairs_to_table_16052000_80c855d4_candidate copies source word pairs into 0xb6052000 with the pair order swapped.

### 0x80c85634 runtime halfword table init

fn_dqm_init_runtime_halfword_table_800070c0_80c85634_candidate writes 0x00df into 16 halfwords at 0x800070c0.

### 0x80c8579c packed control bits

fn_dqm_set_ctrl_bits_16040010_80c8579c_candidate packs 3 one bit inputs into bits 2:0 and writes 0xb6040010.

### 0x80c857c4 static table block init

fn_dqm_static_table_block_init_80c857c4_candidate initializes a large DQM static table block under 0xb6040400..0xb604060c and related registers.

Important point:
- it writes 0xb6040084 = 0x12200200, so this block also carries the shared FPM token endpoint into DQM side setup.

### 0x80c85e10 vector 8 handler

fn_dqm_vector8_handler_80c85e10_candidate:
- disables vector 8
- calls a deeper helper
- writes 0xb6001818 = 0x0f400000
- re enables vector 8

## Batch profile recipe wrapper

### 0x80c7b95c

fn_dqm_queue_profile_batch_init_direct_80c7b95c_candidate is a direct installer batch recipe wrapper.

Behavior:
- calls FUN_80c801a8
- calls FUN_80c801b0(0, 0x1000)
- repeatedly calls the direct installer at 0x80c801e4 with step_low16_or_extra = 0
- aborts on first failure and returns 0
- returns 1 only when the full recipe succeeds

Observed fixed direct installs:
- 0x11 -> (2, 0x10, 0)
- 0x12 -> (2, 0x10, 0)
- 0x10 -> (4, 0x20, 0)
- 0x13 -> (2, 0x80, 0)
- 0x14 -> (1, 0x40, 0)
- 0x1b -> (3, 0x0c, 0)
- 0x15 -> (3, 0x30, 0)
- 0x16 -> (3, 0xc0, 0)
- 0x17 -> (3, 0xc0, 0)
- 0x18 -> (3, 0x30, 0)
- 0x19 -> (1, 0x10, 0)
- loop 0x00..0x07 -> (2, 0x40, 0)
- loop 0x08..0x0f -> (2, 0xc8, 0) with profile limit +0x0c forced to 0x64
- 0x1a -> (2, 0x40, 0)

Additional post install writes observed:
- b6001b5c = 0x08
- b6001b6c = 0x38
- b6001b7c = 0x38
- b6001b9c = 0x08
- b6001bac = 0x20
- b6040194 = 0x19151617

This is a fixed queue layout recipe, not a generic one entry helper.

## CP2 selector and hardware block init cluster

### 0x80c7bc04

fn_dqm_cp2_selector_and_hw_block_init_80c7bc04_candidate:
- writes 0xb604001c = 0xe0000001
- clears 0xb6001200
- enables CP0 status bit 0x40000000
- programs CP2 registers 0x800..0x806 with selector values 0x14, 0x13, 0x15, 0x19, 0x16 and 0
- calls fn_dqm_hw_region_probe_sequence_80c7bdac_candidate as a gate
- if the probe sequence passes, initializes a larger 0xb60400xx hardware control block

Observed gated block setup after successful probe:
- clears 0xb6040030.. for 0x40 entries
- manipulates DQM_QUEUE_INDEX_VALUE_TABLE_16040000_candidate
- writes fixed control values into 0xb6040080, 0xb6040084, 0xb60400c0, 0xb60400c4, 0xb60400e0, 0xb60400e4, 0xb6040154, 0xb6040180
- returns 1 only on success, 0 on probe failure

### 0x80c7bdac region probe sequence

fn_dqm_hw_region_probe_sequence_80c7bdac_candidate calls FUN_80c7b700(base, size) over a fixed region list and returns false on the first failure.

Observed region list:
- 0xb6040700 size 0x40
- 0xb6041000 size 0x200
- 0xb6042000 size 0x400
- 0xb6050000 size 0x1000
- 0xb6043000 size 0x400
- 0xb6046000 size 0x100
- 0xb6044000 size 0x800
- 0xb6080000 size 0x10000
- 0xb60c0000 size 0x10000

This is a hardware region probe or preparation gate for the later CP2 or DQM block init.

### 0x80c7bd4c status mode and value helper

fn_dqm_write_status_mode_and_value_80c7bd4c_candidate:
- if input == 1, calls FUN_80c80414 and uses its result, mode = 1
- otherwise uses 0xdeaddead, mode = 2
- writes 0xb6001d10 = 1
- writes 0xb6001d14 = mode
- writes 0xb6001028 = selected value

### 0x80c7be8c command 0x06 emitter with return PC

fn_dqm_emit_cmd06_with_return_pc_80c7be8c_candidate builds command = ((arg & 0xff) << 8) | 0x06 and writes:
- 0xb6001d20 = command
- 0xb6001d24 = return PC
- 0xb6001028 = command

This looks like a small DQM command emission helper carrying caller return address context.

## Scratch or runtime table prep

### 0x80c7b868

fn_dqm_runtime_scratch_tables_init_80c7b868_candidate clears and initializes several runtime scratch tables around 0x80007050, 0x80007060, 0x80007160, and 0x80007174, and also allocates 0x58 bytes through the runtime bump allocator.

This is runtime table preparation, not a queue profile installer.

## Results and current confidence

Current confidence is high for:
- allocator and backing index helper meanings
- two queue profile installer variants
- queue bitmap A, bitmap B, update trigger, and IRQ or ack cluster behavior
- record emitter wrapper role at 0x80c85590
- bulk direct profile recipe wrapper at 0x80c7b95c
- CP2 selector and gated hardware block init role at 0x80c7bc04
- region probe sequence role at 0x80c7bdac

Remaining uncertainty is mainly exact hardware semantic naming for some 0xb60400xx control fields and the exact low policy meaning of a few queue profile flag fields.

## Recommended next Ghidra work

1. Reverse and rename FUN_80c7b700 to resolve what the region probe sequence actually verifies or initializes.
2. Continue from callers of fn_dqm_cp2_selector_and_hw_block_init_80c7bc04_candidate to place the CP2 selector block in the larger control flow.
3. Revisit additional callers of fn_dqm_queue_profile_install_direct_preserve_bitmaps_80c801e4_candidate to identify other direct profile recipes.
4. Keep preserving old logs and add only new dated notes.

## Preservation

This note is additive. No old logs or notes were deleted. No git action is part of this command.
