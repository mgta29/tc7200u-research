# 2026-06-15-stage1-timeout-select-wait-reverse-log

## Scope

Detailed reverse-engineering log for the Stage1 timeout conversion, generic 64-bit unsigned division helpers, signal-object select/wait bitset path, and the thin public wrapper around the select/wait helper.

Target image context:

- TC7200U / BCM3383 Stage1 reverse-engineering work.
- Ghidra MIPS big-endian program.
- Main area covered:
  - `80ef6a54`
  - `80023e9c`
  - `80023eb8`
  - `80024518`
  - `8002453c`
  - `80ef6ccc`
  - `80ef71c8`

Repository destination requested:

```text
~/tc7200u-research/records/reverse/
```

Suggested filename:

```text
2026-06-15-stage1-timeout-select-wait-reverse-log.md
```

---

## High-level result

This pass cleaned and connected three related parts of Stage1:

1. Timeout conversion:
   - `stage1_timeval32_candidate` input is converted into a 64-bit scheduler tick value.
   - Timeout scale tables were corrected to `81a6ba70` and `81a6ba90`.
   - The previous accidental overlap with `81a7b908` scratch/global area was fixed conceptually.
   - Ghidra's final `CONCAT44` return was accepted as normal MIPS 64-bit return-pair output, but the final carry expression was documented as decompiler-damaged.

2. Generic 64-bit math:
   - `80023e9c` was identified as an unsigned 64-bit quotient wrapper.
   - `80023eb8` was identified as an unsigned 64-bit divide/modulo core with optional remainder output through nonstandard register input `t0`.
   - `80024518` was identified as an unsigned 64-bit remainder wrapper.
   - `8002453c` was identified as a clone/parallel unsigned 64-bit divide/modulo core with optional remainder output through nonstandard register input `t0`.

3. Select/wait path:
   - `80ef6ccc` was repaired after Ghidra split inner basic blocks as fake functions.
   - The function was modeled as a three-class bitset select/wait helper.
   - The stack layout was clarified as three 8-word ready/result bitsets, requested pointer tables, result pointer tables, and class mode/op words.
   - `80ef71c8` was identified as a thin public wrapper that clears `t1` and calls the main select/wait helper.

---

## Repository and workflow notes

- Keep records under the canonical reverse directory:

```text
~/tc7200u-research/records/reverse/
```

- Do not place new records under legacy `records/notes/`.
- Preserve old logs and old records.
- Create a new dated record instead of overwriting older reverse notes.
- Git commit requested after record creation.
- Push was not requested.

---

## Ghidra repair notes

### Fake functions deleted / should be deleted

Inside `80ef6ccc`, Ghidra created basic-block auto-functions. These are not real functions and should not remain as independent function entries.

Delete function only, not bytes/code:

```text
80ef6db8 -> Delete Function
80ef6e38 -> Delete Function
80ef6ed0 -> Delete Function, if Ghidra created it
```

Reason:

- They are inside the `80ef6ccc` stack frame.
- They use the same `sp+...` locals.
- They branch into the outer flow.
- Keeping them damages the decompile and creates misleading standalone signatures.

### Nonstandard register input wording

Use this wording instead of "hidden ABI" in comments:

```text
Nonstandard register input
```

Meaning:

- The value is passed in a CPU register that Ghidra does not expose as a normal C parameter.
- Normal MIPS argument registers are `a0`..`a3`.
- In these functions, extra values are carried in `t0` or `t1`.

Known cases:

```text
80023eb8 / 8002453c:
  t0 = optional uint64_t *remainder_out

80ef6ccc:
  t0 = optional stage1_timeval32_candidate *relative_timeout_arg
  t1 = wait/cancel helper argument

80ef71c8:
  clears t1 before calling 80ef6ccc
  leaves t0 unchanged
```

---

## Datatypes added or updated

### `stage1_timeval32_candidate`

```c
typedef struct stage1_timeval32_candidate {
    int tv_sec_00;
    int tv_usec_04;
} stage1_timeval32_candidate; /* size 0x08 */
```

Usage:

- Input type for `fn_stage1_signal_timeout_arg_to_ticks64_80ef6a54_candidate`.
- Passed through nonstandard register `t0` into select/wait timeout paths.

---

### `stage1_timeout_scale_table_candidate`

```c
typedef struct stage1_timeout_scale_table_candidate {
    uint word_00;
    uint word_04;
    uint word_08;
    uint word_0c;
    uint word_10;
    uint word_14;
    uint word_18;
    uint word_1c;
} stage1_timeout_scale_table_candidate; /* size 0x20 */
```

Status:

- Field semantics are not fully finalized.
- It is used by the timeout tick conversion logic.
- It interacts with the generic unsigned 64-bit division helper.

Do not rename fields beyond `word_xx` until `80e94b50` and the table layout are fully resolved.

---

### `stage1_signal_object_test_callback_10_cb`

Function definition to add:

```c
int stage1_signal_object_test_callback_10_cb
        (stage1_signal_object_candidate *signal_object,
         uint class_mode_or_op);
```

Evidence:

- `80ef6ccc` calls:

```c
signal_object->ops_or_class_0c->test_callback_10(signal_object, class_mode_or_op)
```

- The second argument is loaded from the three-word class mode table at `813a7f80`.

Update `stage1_signal_ops_or_class_candidate` field at `+0x10`:

```text
0x10  stage1_signal_object_test_callback_10_cb *  test_callback_10
```

---

## Memory labels and datatypes

### Timeout globals

```text
81803ae0 -> g_stage1_timeout_scale_tables_initialized_81803ae0
type: uint
```

```text
81802ab4 -> g_stage1_timeout_tick_scale_base_81802ab4_candidate
type: uint
```

```text
81a6ba70 -> g_stage1_timeout_usec_to_ticks_scale_table_81a6ba70_candidate
type: stage1_timeout_scale_table_candidate
```

```text
81a6ba90 -> g_stage1_timeout_sec_to_ticks_scale_table_81a6ba90_candidate
type: stage1_timeout_scale_table_candidate
```

Important correction:

```text
MIPS addiu sign-extends 0xba70/0xba90:
  0x81a70000 + 0xffffba70 = 81a6ba70
  0x81a70000 + 0xffffba90 = 81a6ba90
```

Therefore:

- The tables are not inside `g_stage1_global_scratch_area_81a7b908_candidate`.
- They are not at `81a7ba70` / `81a7ba90`.
- Do not create labels at the wrong `81a7...` addresses for these tables.

---

### Select/wait synchronization globals

```text
81a6ba50 -> g_stage1_select_wait_global_mutex_81a6ba50_candidate
type: stage1_owned_wait_object_candidate
```

```text
81a6ba68 -> g_stage1_select_wait_global_condition_81a6ba68_candidate
type: undefined1[8]
```

Important:

- Do not apply `stage1_owned_wait_object_candidate` at `81a6ba68`.
- It would overlap the timeout table at `81a6ba70`.
- `81a6ba68` is the select/wait condition object candidate area immediately before the timeout table.

```text
81803adc -> g_stage1_select_wait_generation_81803adc_candidate
type: uint
```

```text
813a7f80 -> g_stage1_signal_wait_class_modes_813a7f80_candidate
type: uint[3]
```

Observed first words:

```text
813a7f80 = 1
813a7f84 = 2
813a7f88 = third class mode/op value, verify before assuming 4
```

---

### Generic division helper table

```text
813a87d0 -> g_u8_div_normalize_shift_table_813a87d0_candidate
type: uchar[256]
```

Role:

- Used by unsigned 64-bit division normalization.
- Keep `_candidate`; the exact table generation/meaning is not fully documented.

---

## Function findings

### `80ef6a54`

Final name:

```c
ulonglong fn_stage1_signal_timeout_arg_to_ticks64_80ef6a54_candidate
        (stage1_timeval32_candidate *timeout_arg,
         undefined4 scale_init_arg_candidate);
```

Status:

- Keep `_candidate`.
- Function role is clear, but helper/table details are still partly provisional.

Behavior:

- Lazy-initializes timeout conversion tables once.
- Initializes usec scale table at `81a6ba70` with scale `1000`.
- Initializes sec scale table at `81a6ba90` with scale `1000000000`.
- Converts:
  - `timeout_arg->tv_sec_00`
  - `timeout_arg->tv_usec_04`
- Returns a 64-bit scheduler tick value.
- Returns zero if both `tv_sec_00` and `tv_usec_04` are zero.

Known decompiler issue:

- The final C expression near `CONCAT44` is misleading.
- The final carry must be read from assembly, not from Ghidra's reused temporaries.

Correct final semantic operation:

```c
ticks_lo = (uint)sec_ticks64 + (uint)usec_ticks64;
carry_from_low_add = ticks_lo < (uint)usec_ticks64;
ticks_hi = (uint)(sec_ticks64 >> 32) + (uint)(usec_ticks64 >> 32) + carry_from_low_add;
return CONCAT44(ticks_hi, ticks_lo);
```

Final assembly note to keep in the Ghidra comment:

```c
/* Decompiler warning:
   The final C expression near CONCAT44 is misleading.

   Real final assembly:
     {@address 80ef6c98}: ticks_lo = sec_ticks_lo + usec_ticks_lo
     {@address 80ef6c9c}: carry = ticks_lo < usec_ticks_lo
     {@address 80ef6ca0}: ticks_hi = sec_ticks_hi + usec_ticks_hi
     {@address 80ef6ca4}: ticks_hi += carry
     {@address 80ef6ca8}: v0 = ticks_hi
     {@address 80ef6cac}: v1 = ticks_lo

   Correct semantic return:
     return ((uint64_t)ticks_hi << 32) | ticks_lo.
 */
```

Notes:

- `CONCAT44` itself is not wrong.
- It is Ghidra's way of showing a 64-bit MIPS return-pair.
- The wrong part is the temporary expression feeding it.

---

### `80023e9c`

Final name:

```c
ulonglong fn_u64_udiv64_quotient_80023e9c
        (uint dividend_hi,
         uint dividend_lo,
         uint divisor_hi,
         uint divisor_lo);
```

Status:

- Suffix removed. Function role is clear.

Behavior:

- Thin wrapper.
- Saves `ra`.
- Clears `t0`.
- Calls `fn_u64_udivmod64_core_t0_rem_80023eb8`.
- Returns quotient only.
- Does not request remainder output.

Comment:

```c
/* Unsigned 64-bit quotient wrapper.

   Calls {@symbol fn_u64_udivmod64_core_t0_rem_80023eb8}
   with nonstandard register input t0 = NULL.

   Returns quotient only.
 */
```

---

### `80023eb8`

Final name:

```c
ulonglong fn_u64_udivmod64_core_t0_rem_80023eb8
        (uint dividend_hi,
         uint dividend_lo,
         uint divisor_hi,
         uint divisor_lo);
```

Status:

- Suffix removed. Generic math helper role is clear.

Nonstandard register input:

```text
t0 = optional uint64_t *remainder_out
```

Behavior:

- Performs unsigned 64-bit divide/modulo.
- Returns quotient as 64-bit MIPS return pair.
- If `t0 != NULL`, stores:
  - remainder high word at `t0+0`
  - remainder low word at `t0+4`

Comment:

```c
/* Unsigned 64-bit divide/modulo core.

   Normal arguments:
     a0 = dividend_hi
     a1 = dividend_lo
     a2 = divisor_hi
     a3 = divisor_lo

   Nonstandard register input:
     t0 = optional uint64_t *remainder_out

   Behavior:
     - returns quotient as 64-bit v0/v1 pair
     - if t0 != NULL:
         stores remainder high word at t0+0
         stores remainder low word at t0+4

   Generic math helper, not Stage1-specific.
 */
```

Important Ghidra cleanup:

- Delete fake auto-function at `8002403c`.
- It is the shared epilogue inside `80023eb8`, not a standalone function.

---

### `80024518`

Final name:

```c
ulonglong fn_u64_umod64_remainder_80024518
        (uint dividend_hi,
         uint dividend_lo,
         uint divisor_hi,
         uint divisor_lo);
```

Status:

- Suffix removed. Function role is clear.

Behavior:

- Allocates stack space.
- Sets nonstandard register input `t0 = sp`.
- Calls `fn_u64_udivmod64_core_t0_rem_8002453c`.
- Ignores the quotient return from the core.
- Reads the two stored words from stack.
- Returns remainder as 64-bit MIPS return pair.

Comment:

```c
/* Unsigned 64-bit remainder wrapper.

   Sets nonstandard register input t0 = sp before calling
   {@symbol fn_u64_udivmod64_core_t0_rem_8002453c}.

   The core stores the remainder at sp+0/sp+4.
   This wrapper returns that stored remainder.
 */
```

---

### `8002453c`

Final name:

```c
ulonglong fn_u64_udivmod64_core_t0_rem_8002453c
        (uint dividend_hi,
         uint dividend_lo,
         uint divisor_hi,
         uint divisor_lo);
```

Status:

- Suffix removed. Generic math helper role is clear.
- It appears to be a clone/parallel instance of the unsigned divide/modulo core.

Nonstandard register input:

```text
t0 = optional uint64_t *remainder_out
```

Behavior:

- Performs unsigned 64-bit divide/modulo.
- Returns quotient as 64-bit MIPS return pair.
- If `t0 != NULL`, stores:
  - remainder high word at `t0+0`
  - remainder low word at `t0+4`

Comment:

```c
/* Unsigned 64-bit divide/modulo core.

   Normal arguments:
     a0 = dividend_hi
     a1 = dividend_lo
     a2 = divisor_hi
     a3 = divisor_lo

   Nonstandard register input:
     t0 = optional uint64_t *remainder_out

   Behavior:
     - returns quotient as 64-bit v0/v1 pair
     - if t0 != NULL:
         stores remainder high word at t0+0
         stores remainder low word at t0+4

   Generic math helper, not Stage1-specific.
 */
```

---

### `80ef6ccc`

Final current name:

```c
int fn_stage1_global_three_class_bitset_select_wait_80ef6ccc_candidate
        (uint signal_index_limit_or_count_arg,
         uint *class0_bitset_inout_arg,
         uint *class1_bitset_inout_arg,
         uint *class2_bitset_inout_arg);
```

Status:

- Keep `_candidate`.
- Main behavior is understood, but exact public return semantics and timeout/cancel details are still provisional.

Normal arguments:

```text
signal_index_limit_or_count_arg = maximum signal index/count to scan
class0_bitset_inout_arg         = class 0 request bitset on input, ready bitset on success
class1_bitset_inout_arg         = class 1 request bitset on input, ready bitset on success
class2_bitset_inout_arg         = class 2 request bitset on input, ready bitset on success
```

Nonstandard register inputs:

```text
t0 = optional stage1_timeval32_candidate *relative_timeout_arg
t1 = wait/cancel helper argument passed later into the wait path
```

Saved argument locals:

```text
signal_index_limit_or_count_saved
class0_bitset_inout_saved
class1_bitset_inout_saved
class2_bitset_inout_saved
relative_timeout_arg_t0_saved
wait_cancel_arg_t1_saved
```

Important type correction:

```text
signal_index_limit_or_count_saved type = uint
```

Not:

```text
stage1_timeval32_candidate *
```

Core behavior:

- Enters critical section.
- Copies class modes from `g_stage1_signal_wait_class_modes_813a7f80_candidate`.
- Clears three local 8-word ready/result bitsets.
- Builds pointer tables on the stack:
  - requested/inout bitset pointers
  - ready/result bitset pointers
- Converts optional relative timeout from `t0` into ticks using `80ef6a54`.
- Acquires `g_stage1_select_wait_global_mutex_81a6ba50_candidate`.
- Loops over three classes and signal indexes up to `signal_index_limit_or_count_saved`.
- For each requested bit:
  - refs signal object by index
  - calls `signal_object->ops_or_class_0c->test_callback_10(signal_object, class_mode_or_op)`
  - sets corresponding bit in the local ready/result bitset if ready
  - unrefs signal object
- On ready result:
  - copies local result bitsets back into caller buffers
  - releases global mutex
  - dispatches signals with optional blocked-mask override
  - leaves critical section
  - returns ready count
- On no ready result:
  - enters wait path
  - snapshots `g_stage1_select_wait_generation_81803adc_candidate`
  - handles signal mask swap and pending signal check
  - waits indefinitely or with timed deadline depending on `relative_timeout_arg_t0_saved`
  - recomputes remaining timeout after timed wait
- Status candidates:
  - `4` = interrupted/cancel/failure candidate
  - `9` = target lookup/ref failure candidate
  - `0xb` = timeout/no-time-left candidate
- Return behavior:
  - positive ready count on success
  - `0` on timeout path
  - `-1` with errno/status slot set for non-timeout error paths

Stack layout note:

```c
/* Stack-frame note:
   Ghidra may merge the stack work area into arrays with misleading names.

   Real layout:
     sp+0x00 = class0 ready/result bitset, 8 uint words
     sp+0x20 = class1 ready/result bitset, 8 uint words
     sp+0x40 = class2 ready/result bitset, 8 uint words
     sp+0x60 = requested bitset pointer table, 3 pointers
     sp+0x70 = ready/result bitset pointer table, 3 pointers
     sp+0x80 = class operation/mode table, 3 uint words

   The public class bitset args are in/out buffers:
     input  = requested signal bits
     output = ready signal bits copied back on success.
 */
```

Recommended function comment:

```c
/* Stage1 global three-class bitset select/wait helper.

   Normal arguments:
     signal_index_limit_or_count_arg = maximum signal index/count to scan
     class0_bitset_inout_arg         = class 0 request bitset on input, ready bitset on success
     class1_bitset_inout_arg         = class 1 request bitset on input, ready bitset on success
     class2_bitset_inout_arg         = class 2 request bitset on input, ready bitset on success

   Nonstandard register inputs:
     t0 = optional stage1_timeval32_candidate *relative_timeout_arg
     t1 = wait/cancel helper argument passed later into the wait path

   Stack layout:
     local_f0 = class0 ready/result bitset, 8 words
     local_d0 = class1 ready/result bitset, 8 words
     local_b0 = class2 ready/result bitset, 8 words

   Synchronization:
     uses {@symbol g_stage1_select_wait_global_mutex_81a6ba50_candidate}
     uses {@symbol g_stage1_select_wait_global_condition_81a6ba68_candidate}

   Timeout:
     if relative_timeout_arg_t0 is non-NULL, calls
     {@symbol fn_stage1_signal_timeout_arg_to_ticks64_80ef6a54_candidate}.

   Ghidra warning:
     Do not keep inner auto-functions at {@address 80ef6db8} or
     {@address 80ef6e38}; they are basic blocks inside this function.
 */
```

---

### `80ef71c8`

Final current name:

```c
int fn_stage1_select_wait_t0_timeout_no_cancel_80ef71c8_candidate
        (uint signal_index_limit_or_count_arg,
         uint *class0_bitset_inout_arg,
         uint *class1_bitset_inout_arg,
         uint *class2_bitset_inout_arg);
```

Status:

- Keep `_candidate` until callers confirm public API naming.
- Thin wrapper behavior is clear.

Behavior:

- Saves `ra`.
- Calls `fn_stage1_global_three_class_bitset_select_wait_80ef6ccc_candidate`.
- Clears `t1` in the branch delay slot before the call.
- Leaves `t0` unchanged.
- Therefore:
  - `t0` still passes optional timeout pointer.
  - `t1` is forced to NULL / no wait-cancel helper argument.

Comment:

```c
/* Stage1 select/wait public wrapper.

   Normal arguments:
     signal_index_limit_or_count_arg = maximum signal index/count to scan
     class0_bitset_inout_arg         = class 0 request bitset on input, ready bitset on success
     class1_bitset_inout_arg         = class 1 request bitset on input, ready bitset on success
     class2_bitset_inout_arg         = class 2 request bitset on input, ready bitset on success

   Nonstandard register passthrough:
     t0 = optional stage1_timeval32_candidate *relative_timeout_arg

   Wrapper behavior:
     - clears t1 before calling
       {@symbol fn_stage1_global_three_class_bitset_select_wait_80ef6ccc_candidate}
     - therefore wait/cancel helper argument is NULL
     - leaves t0 unchanged, so timeout still passes through t0

   Real scan/wait behavior is in
   {@symbol fn_stage1_global_three_class_bitset_select_wait_80ef6ccc_candidate}.
 */
```

Do not add a visible fifth `timeout` argument. Timeout is not received in `a0..a3` or loaded from stack in this wrapper.

---

## Local naming notes

### `80ef6a54`

Use:

```text
ticks_hi
ticks_lo
tmp_hi_or_word
tmp_lo
tv_usec
sec_ticks64
usec_ticks64
relative timeout / scale variables as available
```

Do not try to fully repair final C carry expression by renaming alone. The decompiler reuses temps badly.

### `80ef6ccc`

Good stable names:

```text
status
ready_count
signal_index
class_ptr_table_offset
class_index_or_loop_index
is_ready
class_mode_or_op_3
saved_signal_mask_or_state
wait_generation_snapshot
remaining_or_deadline_ticks_lo
remaining_or_deadline_ticks_hi
relative_timeout_ticks64
```

If Ghidra refuses or reuses variables, keep the saved locals correct and use comments.

---

## Ghidra warnings and known decompiler artifacts

### `CONCAT44`

`CONCAT44(ticks_hi,ticks_lo)` is acceptable for 64-bit MIPS return values.

Meaning:

```c
return ((ulonglong)ticks_hi << 32) | ticks_lo;
```

Do not waste time trying to remove it.

### Register names cannot always be renamed

Registers like `s1`, `s2`, `t1`, `t2` often do not appear as normal Decompiler variables. Do not fight Ghidra.

Use comments on Listing instructions instead.

### Stack arrays may be merged

Ghidra may merge several independent stack ranges into one fake array. Use comments and saved local names instead of forcing a fake structure unless the split is clean.

---

## Current open questions

1. Exact semantics of `stage1_timeout_scale_table_candidate` fields.
2. Exact behavior and signature of `fn_stage1_timeout_scale_table_init_hidden_t0_80e94b50_candidate`.
3. Whether `fn_stage1_global_three_class_bitset_select_wait_80ef6ccc_candidate` public name should eventually drop `_candidate`.
4. Exact enum names for select/wait status values `4`, `9`, and `0xb`.
5. Exact meaning of third class mode value at `813a7f88`.
6. Exact type of `g_stage1_select_wait_global_condition_81a6ba68_candidate`.
7. Additional callers of `fn_stage1_select_wait_t0_timeout_no_cancel_80ef71c8_candidate`, especially those that set `t0`.

---

## Next recommended Ghidra work

Open one caller of:

```text
fn_stage1_select_wait_t0_timeout_no_cancel_80ef71c8_candidate
```

Suggested caller:

```text
80ef8700
```

Goal:

- Confirm how `t0` is prepared before the wrapper call.
- Confirm public API naming.
- Confirm timeout argument shape.
- Confirm whether `_candidate` can be removed from wrapper or main select/wait helper.

Also inspect:

```text
fn_stage1_timeout_scale_table_init_hidden_t0_80e94b50_candidate
```

Goal:

- Confirm the scale table layout.
- Rename fields in `stage1_timeout_scale_table_candidate` only after `80e94b50` proves their roles.

---

## WSL commands to write this record into the repo and commit

These commands preserve old records and create a new dated log under the canonical reverse directory.

### 1. Prepare path and write file

```sh
cd ~/tc7200u-research; mkdir -p records/reverse; cat > records/reverse/2026-06-15-stage1-timeout-select-wait-reverse-log.md <<'EOF'
# 2026-06-15-stage1-timeout-select-wait-reverse-log

Paste the downloaded markdown file contents here if not copying the file from /mnt/data.
EOF
```

Preferred copy from Windows/browser download into WSL repo:

```sh
cd ~/tc7200u-research; mkdir -p records/reverse; cp /mnt/c/Users/mgta29/Downloads/2026-06-15-stage1-timeout-select-wait-reverse-log.md records/reverse/2026-06-15-stage1-timeout-select-wait-reverse-log.md
```

Alternative if copied from this chat sandbox manually:

```sh
cd ~/tc7200u-research; mkdir -p records/reverse; cp ~/Downloads/2026-06-15-stage1-timeout-select-wait-reverse-log.md records/reverse/2026-06-15-stage1-timeout-select-wait-reverse-log.md
```

### 2. Verify and inspect git state

```sh
cd ~/tc7200u-research; test -s records/reverse/2026-06-15-stage1-timeout-select-wait-reverse-log.md && wc -l records/reverse/2026-06-15-stage1-timeout-select-wait-reverse-log.md && git status --short --branch
```

### 3. Commit

```sh
cd ~/tc7200u-research; git add records/reverse/2026-06-15-stage1-timeout-select-wait-reverse-log.md; git commit -m "Add stage1 timeout select wait reverse log"
```

No push command included because push was not requested.

---

## Short commit summary

```text
Add reverse log for Stage1 timeout/select-wait cleanup.

Documents:
- timeout timeval-to-ticks64 converter at 80ef6a54
- corrected timeout scale table addresses 81a6ba70/81a6ba90
- generic u64 unsigned division/remainder helpers
- three-class signal-object bitset select/wait helper at 80ef6ccc
- public wrapper at 80ef71c8
- datatypes, memory labels, fake function cleanup, and Ghidra artifacts
```
