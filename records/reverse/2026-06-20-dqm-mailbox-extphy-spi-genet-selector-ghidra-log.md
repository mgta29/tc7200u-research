# 2026-06-20 — DQM mailbox, external-PHY SPI, and GENET selector Ghidra log

## Scope

This log records the Ghidra reverse-engineering pass focused on:

- ENET external PHY serial-management / SPI-offset helpers around `0x803c5ac8..0x803c6144`.
- DQM mailbox runtime-stub/board-option patch dispatcher around `0x80c7c5d0..0x80c7cb84`.
- DQM/CP2 selector programming toward GENET KSEG1 targets `0xb2c00500` and `0xb2c00510`.
- Memory-block, datatype, structure, global-label, and function-label changes identified during the pass.

This record belongs under:

```text
records/reverse/
```

It should not be placed under `records/notes/`, because that path is a legacy path and should not receive new files.

---

## Inputs reviewed

### Ghidra function/decompile pastes

Reviewed function ranges and pasted Ghidra listings:

- `803c5ac8` — external PHY serial-management init/config sequence.
- `803c5cf8` — checked external PHY SPI read wrapper.
- `803c5d34` — write gate based on serial-management detection flag.
- `803c5d7c` — external PHY SPI read-offset helper.
- `803c5ed4` — external PHY SPI page/device selector.
- `803c5f28` — external PHY SPI write-offset helper.
- `803c6040` — external PHY SPI write-transfer helper.
- `803c60e0` — external PHY serial-management detect helper.
- `80c7c580..80c7c760` — start of DQM mailbox runtime-stub patch dispatcher.
- `80c7c760..80c7cb60` — dispatcher midsection, selector cases, GENET target routing, and B604/B605 programming.
- `80c7cb60..80c7cbd0` — dispatcher common response path and start of response-record store helper.

### Export snapshots reviewed

Reviewed the uploaded Ghidra JSON exports:

- `datatype.json`
- `labels.json`
- `memoryblock.json`

Relevant export findings from the latest reviewed state:

- Datatype manager had `/tc7200u/mmio` populated with MMIO/helper datatypes, including `dqm_cp2_b604_selector_programming_candidate`, `chiphal_pinmux_entry_candidate`, `vuint16_t`, `vuint32_t`, and the external PHY SPI transfer function definition.
- `tc7200u_like_outside_target_categories` was empty in the reviewed export state, meaning TC7200U-like custom datatypes had been moved into target category paths.
- Memory map had broad DQM/IOP KSEG1 coverage through `MMIO_IOP_DQM_KSEG1_B6000000`, covering `b6000000-b609ffff`.
- `MMIO_FPM_KSEG1_B2200000`, `MMIO_GENET_KSEG1_B2C00000`, and split `B4E` peripheral-control/interrupt blocks were present.
- Additional RAM state blocks existed for ENET globals, DMA/FPM allocator state, FPM token manager state, Stage1 state, and the external PHY SPI driver table area when added.

---

## High-level conclusions

### 1. External PHY serial-management chain is recovered

The helper cluster at `0x803c5ac8..0x803c6144` is an external PHY serial-management/SPI access path. It is not direct GENET TDMA ring programming.

Key recovered behavior:

- The path detects external PHY serial-management devices by reading 4 bytes from page/device `0x02`, offset `0x30`, length `0x04`.
- Accepted device IDs are:
  - `0x00053115`
  - `0x00053125`
- The write path is gated by `g_enet_extphy_serial_mode_detected_8147a044_candidate`.
- Read and write helpers serialize data through an external transfer callback at `81a8e9ac`.
- The transfer callback uses normal arguments in `a0..a3`, but also uses hidden `t0..t3` register inputs in observed call paths.
- Payload bytes are reversed in the transfer-buffer serialization logic. This matters for interpreting 1-, 2-, and 4-byte external PHY/register values.

### 2. DQM mailbox dispatcher is recovered far enough to name

The parent at `80c7c5d0` copies four DQM mailbox words from `b6001de0..b6001dec` into the stack and dispatches on command byte `sp+0x03`.

This is a DQM control-mailbox runtime-stub/board-option patch dispatcher.

Recommended parent name:

```text
fn_dqm_mailbox_runtime_stub_patch_dispatcher_80c7c5d0_candidate
```

Recommended signature:

```c
void fn_dqm_mailbox_runtime_stub_patch_dispatcher_80c7c5d0_candidate(void);
```

The final tail confirms there is no meaningful return value: the parent writes or forwards a 4-word response record through a store helper, restores registers, and returns.

### 3. DQM/CP2 case `0x11` routes selector output toward GENET

The previous uncertain `80c7c8a0`/`80c7c8d4` area is part of the parent dispatcher, not standalone functions.

Recovered command/case behavior:

```text
case 0x11:
  if sp+0x04 == 0:
    update selector/target A
  else:
    update selector/target B

  if sp+0x08 == 0:
    selector = 0x0c
    target   = 0xb2c00500
  else:
    selector = 0x0e
    target   = 0xb2c00510

  then program B604 selector command/target registers
```

This block programs DQM/CP2 selector routing toward GENET KSEG1 target candidates:

- `0xb2c00500`
- `0xb2c00510`

It is not the GENET TDMA ring consumer itself, but it is a high-value vendor path connecting DQM/CP2 routing with GENET-side targets.

### 4. DQM/CP2 case `0x12` performs B604/B605 window programming

Case `0x12` clears bit `0x100` on a run of B604 entry control/flags words, waits for B604 idle/status bits, calls the B6052000 word-pair copy helper, and restores bit `0x100` afterward.

This is a separate B604/B605 programming flow after the selector-target routing block.

### 5. B604 does not need its own memory block

The existing broad block is correct:

```text
MMIO_IOP_DQM_KSEG1_B6000000
b6000000-b609ffff
rw volatile
```

It covers:

- `b6040000-b6040fff`
- `b6052000`
- `b6001de0..b6001dfc`

Do not split out `MMIO_DQM_CP2_B6040000` as a separate memory block. Use labels and datatypes inside the existing broad DQM/IOP window.

---

## Function findings and recommended Ghidra naming

## External PHY serial-management / SPI chain

### `803c5ac8`

Recommended name:

```text
fn_enet_extphy_serial_management_init_sequence_803c5ac8_candidate
```

Recommended signature:

```c
void fn_enet_extphy_serial_management_init_sequence_803c5ac8_candidate(
    uint phy_or_unit_id_candidate,
    uint serial_mode_arg_candidate,
    uint option_or_flags_candidate);
```

Behavior summary:

- Masks caller argument 0 and argument 2 to low 8 bits.
- Writes `0x8000` through the external PHY serial write wrapper to targets `0x11..0x14` at offset `0x00`.
- Calls `fn_platform_restart_or_handoff_808ff3f8_candidate(0x14)`.
- Calls `FUN_803ab940(index, 1)` for indexes `1..4`.
- Computes a mode byte from caller arguments, with default base `0x20`, special handling for serial-mode argument `0x64`, and optional low bit from argument 2.
- Writes serial-management sequences through `fn_enet_extphy_serial_write_if_detected_803c5d34_candidate`.
- Writes target `0x30`, offset `0x62`, value `{0x00,0x40}`.
- Writes target `0x30`, offset `0x80`, value `{0x03}`.

Status:

- Keep `_candidate`; exact board/device semantics of the external target IDs are not fully proven.

---

### `803c5cf8`

Recommended name:

```text
fn_enet_extphy_spi_read_offset_checked_803c5cf8_candidate
```

Recommended signature:

```c
uint fn_enet_extphy_spi_read_offset_checked_803c5cf8_candidate(
    byte page_or_device,
    uint offset,
    void *out_buf,
    uint length);
```

Behavior summary:

- Masks page/device, offset, and length to low 8 bits.
- If offset is `0xf3`, returns `0` without a read.
- Otherwise calls `fn_enet_extphy_spi_read_offset_803c5d7c_candidate`.

---

### `803c5d34`

Recommended name:

```text
fn_enet_extphy_serial_write_if_detected_803c5d34_candidate
```

Recommended signature:

```c
uint fn_enet_extphy_serial_write_if_detected_803c5d34_candidate(
    byte page_or_device,
    uint offset,
    void *src_buf,
    uint length);
```

Behavior summary:

- Checks `g_enet_extphy_serial_mode_detected_8147a044_candidate`.
- If detected flag is `1`, calls `fn_enet_extphy_spi_write_offset_803c5f28_candidate`.
- Otherwise returns `0xc0000001`.

---

### `803c5d7c`

Recommended name:

```text
fn_enet_extphy_spi_read_offset_803c5d7c_candidate
```

Recommended signature:

```c
uint fn_enet_extphy_spi_read_offset_803c5d7c_candidate(
    byte page_or_device,
    uint offset,
    void *out_buf,
    uint length);
```

Behavior summary:

- Masks page/device, offset, and length to low 8 bits.
- If `g_enet_extphy_serial_sem_8147a040_candidate` is non-null, waits on it.
- Selects the page/device through `fn_enet_extphy_spi_select_page_or_device_803c5ed4_candidate`.
- Sends an initial command buffer using opcode `0x60` and requested offset.
- Loops over the requested output length.
- Uses the external transfer callback at `81a8e9ac` with hidden `t2 = sp+0x08` and `t3 = 1` in the receive path.
- Copies received bytes to `out_buf` in reverse order:

```text
out_buf[length - loop_index - 1] = received_byte
```

- Posts the semaphore if one exists.
- Returns `0` on success or `0xc0000001` on semaphore/logged failure path.

Important note:

- Do not simplify this as a forward `memcpy`. The byte order is intentionally reversed relative to the read loop.

---

### `803c5ed4`

Recommended name:

```text
fn_enet_extphy_spi_select_page_or_device_803c5ed4_candidate
```

Recommended signature:

```c
void fn_enet_extphy_spi_select_page_or_device_803c5ed4_candidate(byte page_or_device);
```

Behavior summary:

Builds a 3-byte command buffer:

```text
byte0 = 0x61
byte1 = 0xff
byte2 = page_or_device
```

Then calls the external transfer callback with normal arguments:

```text
a0 = 2
a1 = 2
a2 = command buffer
a3 = 3
```

Hidden register inputs `t0..t3` are zero in this path.

---

### `803c5f28`

Recommended name:

```text
fn_enet_extphy_spi_write_offset_803c5f28_candidate
```

Recommended signature:

```c
uint fn_enet_extphy_spi_write_offset_803c5f28_candidate(
    byte page_or_device,
    uint offset,
    void *src_buf,
    uint length);
```

Behavior summary:

- Masks page/device, offset, and length to low 8 bits.
- Rejects `length >= 9` and returns `0xc0000001`.
- Waits on `g_enet_extphy_serial_sem_8147a040_candidate` if present.
- Selects page/device through `fn_enet_extphy_spi_select_page_or_device_803c5ed4_candidate`.
- Calls `fn_enet_extphy_spi_write_transfer_803c6040_candidate`.
- Posts the semaphore afterward if present.
- Logs failure strings on semaphore wait/post failure and internal write failure paths.
- Returns `0` on success.

---

### `803c6040`

Recommended name:

```text
fn_enet_extphy_spi_write_transfer_803c6040_candidate
```

Recommended signature:

```c
uint fn_enet_extphy_spi_write_transfer_803c6040_candidate(
    uint offset,
    uint length,
    void *src_buf);
```

Behavior summary:

Builds a command buffer:

```text
byte0 = 0x61
byte1 = offset low8
```

Payload serialization:

- If `length == 1`, writes `src_buf[0]` to command byte 2.
- If `length > 1`, writes payload bytes in reverse order:

```text
src_buf[length - 1], src_buf[length - 2], ...
```

Calls the external transfer callback with:

```text
a0 = 2
a1 = 2
a2 = command buffer
a3 = length + 2
```

Hidden `t0..t3` are zero in this write path.

---

### `803c60e0`

Recommended name:

```text
fn_enet_extphy_serial_management_detect_803c60e0_candidate
```

Recommended signature:

```c
uint fn_enet_extphy_serial_management_detect_803c60e0_candidate(void);
```

Behavior summary:

- Calls `FUN_80610694`.
- Reads 4 bytes through `fn_enet_extphy_spi_read_offset_803c5d7c_candidate` from:

```text
page/device = 0x02
offset      = 0x30
length      = 0x04
```

- Accepts ID values:

```text
0x00053115
0x00053125
```

- Logs the external PHY serial-management string and returns `1` when accepted.
- Returns `0` otherwise.

---

## External PHY SPI globals and datatype work

### RAM block

Add or keep:

```text
RAM_ENET_EXTPHY_SPI_DRIVER_TABLE_81A8E9A8_candidate
81a8e9a8-81a8e9af
rw, non-volatile
```

This is RAM/global state, not MMIO. Do not mark volatile.

### Labels

Add or keep:

```text
81a8e9a8  g_enet_extphy_spi_driver_table_81a8e9a8_candidate
81a8e9ac  g_enet_extphy_spi_transfer_fn_81a8e9ac_candidate
```

### Function-definition datatype

Create under `/tc7200u/mmio`:

```c
typedef uint enet_extphy_spi_transfer_fn_candidate(
    uint bus_or_channel,
    uint command_class,
    void *transfer_buf,
    uint transfer_len);
```

Apply at:

```text
81a8e9ac  enet_extphy_spi_transfer_fn_candidate *
```

Comment semantics:

```text
Normal arguments:
  a0 = bus_or_channel
  a1 = command_class
  a2 = transfer buffer
  a3 = transfer length

Hidden register inputs observed:
  t0 = 0 in shown paths
  t1 = 0 in shown paths
  t2 = optional receive buffer, sp+0x08 in read path
  t3 = read/receive flag, 1 in read path and 0 in write/select paths
```

Do not force `t0..t3` into the normal C signature unless a custom calling convention is created.

---

# DQM mailbox dispatcher analysis

## Parent function at `80c7c5d0`

Recommended name:

```text
fn_dqm_mailbox_runtime_stub_patch_dispatcher_80c7c5d0_candidate
```

Recommended signature after tail review:

```c
void fn_dqm_mailbox_runtime_stub_patch_dispatcher_80c7c5d0_candidate(void);
```

Input behavior:

- Copies four DQM control-mailbox words from:

```text
b6001de0
b6001de4
b6001de8
b6001dec
```

into local stack storage.

- Dispatches by command byte at `sp+0x03`.

Recommended input labels:

```text
b6001de0  DQM_CTRL_MAILBOX_WORD0_16001DE0_candidate
b6001de4  DQM_CTRL_MAILBOX_WORD1_16001DE4_candidate
b6001de8  DQM_CTRL_MAILBOX_WORD2_16001DE8_candidate
b6001dec  DQM_CTRL_MAILBOX_WORD3_16001DEC_candidate
```

Optional input datatype:

```c
typedef struct dqm_ctrl_mailbox_words_candidate {
    vuint32_t word0_command_1de0;
    vuint32_t word1_arg0_1de4;
    vuint32_t word2_arg1_1de8;
    vuint32_t word3_arg2_1dec;
} dqm_ctrl_mailbox_words_candidate;
```

Apply at:

```text
b6001de0
```

---

## Dispatcher command cases

### Case `0x02`

Default/pass-through response path.

### Case `0x0d`

Controls `DQM_SELECTOR_FPM_GATE_MODE_80007060_candidate` and updates default selector context A/B bytes through:

```text
80007064  DQM_SELECTOR_CONTEXT_DEFAULT_A_80007064_candidate
80007068  DQM_SELECTOR_CONTEXT_DEFAULT_B_80007068_candidate
```

Observed field writes:

```text
context +0x06
context +0x07
```

A nearby helper also writes:

```text
context +0x04
context +0x05
```

Recommended selector context datatype:

```c
typedef struct dqm_selector_context_candidate {
    undefined field_00[4];
    uint8_t selector_byte_04_candidate;
    uint8_t selector_byte_05_candidate;
    uint8_t lane_or_mode_byte_06_candidate;
    uint8_t enable_or_flags_byte_07_candidate;
} dqm_selector_context_candidate;
```

Apply pointer types at:

```text
80007064  dqm_selector_context_candidate *
80007068  dqm_selector_context_candidate *
```

### Case `0x0e`

Controls:

```text
800070fc  DQM_RUNTIME_GATE_800070FC_candidate
```

### Case `0x0f`

Controls:

```text
8000706c  DQM_RUNTIME_GATE_8000706C_candidate
```

When mailbox word1 is nonzero:

- Sets gate to `1`.
- Calls `FUN_80c7f830`.

Recommended helper label:

```text
80c7f830  fn_dqm_runtime_gate_apply_or_rebuild_80c7f830_candidate
```

### Case `0x10`

Controls:

```text
80007104  DQM_RUNTIME_GATE_80007104_candidate
```

### Case `0x11`

Routes DQM/CP2 selector A/B toward GENET targets and programs B604 selector command/target registers.

Runtime selector/target globals:

```text
80007110  DQM_RUNTIME_SELECTOR_A_80007110_candidate
80007114  DQM_RUNTIME_SELECTOR_B_80007114_candidate
80007118  DQM_CP2_GENET_TARGET_A_80007118_candidate
8000711c  DQM_CP2_GENET_TARGET_B_8000711c_candidate
```

GENET KSEG1 target candidates:

```text
b2c00500  GENET_DQM_TARGET_OR_IF0_CTRL_B2C00500_candidate
b2c00510  GENET_DQM_TARGET_OR_IF0_CTRL_B2C00510_candidate
```

B604 register labels:

```text
b6040400  DQM_CP2_B604_SELECTOR_PROGRAM_BASE_16040400_candidate
b6040564  DQM_CP2_B604_SELECTOR_A_CMD_WORD_16040564_candidate
b6040568  DQM_CP2_B604_SELECTOR_B_CMD_WORD_16040568_candidate
b60405c0  DQM_CP2_B604_SELECTOR_A_TARGET_L_160405C0_candidate
b60405c4  DQM_CP2_B604_SELECTOR_B_TARGET_L_160405C4_candidate
```

Recommended block label, not function:

```text
LAB_dqm_cp2_program_genet_selector_targets_80c7c928
```

Important correction:

- `80c7c928` is not a standalone function.
- It is the common B604 programming block for case `0x11`.
- Any false function split at `80c7c928` should be cleared.

### Case `0x12`

B604/B605 copy-window programming path.

Behavior:

- Clears bit `0x100` on several B604 entry control/flags words.
- Waits for B604 status/busy conditions to clear.
- Calls the word-pair copy helper into the B6052000 window.
- Restores bit `0x100` afterward.

Recommended labels:

```text
b6040480  DQM_B604_ENTRY_0480_CTRL_FLAGS_16040480_candidate
b6040484  DQM_B604_ENTRY_0484_CTRL_FLAGS_16040484_candidate
b6040488  DQM_B604_ENTRY_0488_CTRL_FLAGS_16040488_candidate
b6040490  DQM_B604_ENTRY_0490_CTRL_FLAGS_16040490_candidate
b6040494  DQM_B604_ENTRY_0494_CTRL_FLAGS_16040494_candidate
b6040498  DQM_B604_ENTRY_0498_CTRL_FLAGS_16040498_candidate
b604049c  DQM_B604_ENTRY_049C_CTRL_FLAGS_1604049C_candidate
b60404a0  DQM_B604_ENTRY_04A0_CTRL_FLAGS_160404A0_candidate
b60404a4  DQM_B604_ENTRY_04A4_CTRL_FLAGS_160404A4_candidate
b604002c  DQM_B604_STATUS_BUSY_002C_1604002C_candidate
b6040058  DQM_B604_STATUS_OR_GATE_0058_16040058_candidate
b6052000  DQM_B605_WORD_PAIR_COPY_WINDOW_16052000_candidate
```

Recommended helper label:

```text
80c7bf00  fn_dqm_copy_word_pairs_to_b6052000_window_80c7bf00_candidate
```

Recommended provisional signature:

```c
void fn_dqm_copy_word_pairs_to_b6052000_window_80c7bf00_candidate(
    uint word_a,
    uint word_b,
    uint pair_count_or_len_candidate);
```

### Case `0x13`

Controls:

```text
80007108  DQM_RUNTIME_GATE_80007108_candidate
```

### Case `0x14`

Controls:

```text
8000710c  DQM_RUNTIME_GATE_8000710C_candidate
```

### Case `0x15`

Stores mailbox word1 to:

```text
80007120  DQM_EVENT100000_ROUTE_MODE_80007120_candidate
```

### Case `0x16`

Controls selector16/17 special mode and writes B424 selector target/map words.

Recommended labels:

```text
80007100  DQM_SELECTOR16_17_SPECIAL_MODE_80007100_candidate
b42404e0  DQM_SELECTOR17_SPECIAL_TARGET_OR_MAP_B42404E0_candidate
b42404e4  DQM_SELECTOR16_SPECIAL_TARGET_OR_MAP_B42404E4_candidate
```

Keep the B424 labels candidate. The code writes constants `0x13601914` and `0x13601910`, but exact hardware semantics are not proven.

### Case `0x17`

Builds a small stack command record and calls helper:

```text
80c7c3f8  fn_dqm_selector_context_update_case_0x17_80c7c3f8_candidate
```

Recommended provisional signature:

```c
uint fn_dqm_selector_context_update_case_0x17_80c7c3f8_candidate(
    uint arg0,
    uint arg1,
    void *out_record);
```

### Case `0x18`

Builds a small stack command record and calls helper:

```text
80c7c500  fn_dqm_selector_context_reset_or_apply_case_0x18_80c7c500_candidate
```

Recommended provisional signature:

```c
uint fn_dqm_selector_context_reset_or_apply_case_0x18_80c7c500_candidate(
    uint arg0,
    void *out_record);
```

### Case `0x19`

Builds a response-like record using constant:

```text
0xb3617124
```

and the current value of:

```text
80007060  DQM_SELECTOR_FPM_GATE_MODE_80007060_candidate
```

Do not create a memory block or MMIO label for `0xb3617124` yet. In the reviewed paste, it is stored as a record value and is not dereferenced.

### Case `0x1a`

Controls:

```text
80007128  DQM_SELECTOR_LOOKUP_ENABLE_80007128_candidate
```

The branch at `80c7c704` is not a standalone function.

Recommended label after clearing false function split:

```text
LAB_dqm_mailbox_case_0x1a_enable_lookup_80c7c704
```

---

## Dispatcher response/writeback path

The final dispatcher tail confirms that most handled cases build a 4-word local response record and call the store helper.

Recommended store-helper rename:

```text
fn_dqm_mailbox_store_response_record_80c7cb84_candidate
```

Recommended signature:

```c
void fn_dqm_mailbox_store_response_record_80c7cb84_candidate(uint *record4_words);
```

Behavior confirmed so far:

- Polls a RAM gate/status word at `80008090` until nonzero or loop limit.
- If the wait passes, copies four 32-bit words from the supplied record pointer into mailbox response/output window beginning at `b6001df0`.
- The pasted tail ended mid-copy; final instructions after `80c7cbd0` still need to be checked for acknowledge/clear behavior.

Recommended labels:

```text
80008090  DQM_MAILBOX_RESPONSE_READY_OR_GATE_80008090_candidate
b6001df0  DQM_CTRL_MAILBOX_RESPONSE_WORD0_16001DF0_candidate
b6001df4  DQM_CTRL_MAILBOX_RESPONSE_WORD1_16001DF4_candidate
b6001df8  DQM_CTRL_MAILBOX_RESPONSE_WORD2_16001DF8_candidate
b6001dfc  DQM_CTRL_MAILBOX_RESPONSE_WORD3_16001DFC_candidate
```

Optional response datatype:

```c
typedef struct dqm_ctrl_mailbox_response_words_candidate {
    vuint32_t response_word0_1df0;
    vuint32_t response_word1_1df4;
    vuint32_t response_word2_1df8;
    vuint32_t response_word3_1dfc;
} dqm_ctrl_mailbox_response_words_candidate;
```

Apply at:

```text
b6001df0
```

---

# Datatype and structure updates

## Existing important datatype categories

The project datatype tree should keep the established categories:

```text
/tc7200u/common
/tc7200u/dqm_host_fap
/tc7200u/fpm_dma
/tc7200u/mmio
/tc7200u/stage1/context
/tc7200u/stage1/lifecycle
/tc7200u/stage1/netif
/tc7200u/stage1/post
/tc7200u/stage1/scheduler
/tc7200u/stage1/signal
/tc7200u/stage1/socket
/tc7200u/stage1/thread
/tc7200u/stage1/timeout
/tc7200u/stage1/wait_sync
```

## MMIO datatypes from this pass

Create or keep under `/tc7200u/mmio`:

```c
typedef volatile uint16_t vuint16_t;
typedef volatile uint32_t vuint32_t;
```

```c
typedef struct dqm_cp2_b604_selector_programming_candidate {
    undefined field_0000[0x164];
    vuint32_t selector_a_cmd_word_0164;
    vuint32_t selector_b_cmd_word_0168;
    undefined field_016c[0x54];
    vuint32_t selector_a_target_low_01c0;
    vuint32_t selector_b_target_low_01c4;
} dqm_cp2_b604_selector_programming_candidate;
```

Apply at:

```text
b6040400  dqm_cp2_b604_selector_programming_candidate
```

```c
typedef struct dqm_ctrl_mailbox_words_candidate {
    vuint32_t word0_command_1de0;
    vuint32_t word1_arg0_1de4;
    vuint32_t word2_arg1_1de8;
    vuint32_t word3_arg2_1dec;
} dqm_ctrl_mailbox_words_candidate;
```

Apply at:

```text
b6001de0
```

```c
typedef struct dqm_ctrl_mailbox_response_words_candidate {
    vuint32_t response_word0_1df0;
    vuint32_t response_word1_1df4;
    vuint32_t response_word2_1df8;
    vuint32_t response_word3_1dfc;
} dqm_ctrl_mailbox_response_words_candidate;
```

Apply at:

```text
b6001df0
```

```c
typedef struct dqm_selector_context_candidate {
    undefined field_00[4];
    uint8_t selector_byte_04_candidate;
    uint8_t selector_byte_05_candidate;
    uint8_t lane_or_mode_byte_06_candidate;
    uint8_t enable_or_flags_byte_07_candidate;
} dqm_selector_context_candidate;
```

Apply pointer types at:

```text
80007064  dqm_selector_context_candidate *
80007068  dqm_selector_context_candidate *
```

```c
typedef uint enet_extphy_spi_transfer_fn_candidate(
    uint bus_or_channel,
    uint command_class,
    void *transfer_buf,
    uint transfer_len);
```

Apply at:

```text
81a8e9ac  enet_extphy_spi_transfer_fn_candidate *
```

---

# Memory-block status

## Keep these blocks

```text
MMIO_IOP_DQM_KSEG1_B6000000
b6000000-b609ffff
rw volatile
```

Reason: covers DQM/IOP, including B604/B605 windows and control mailbox windows.

```text
MMIO_GENET_KSEG1_B2C00000
b2c00000-b2c03fff
rw volatile
```

Reason: covers GENET KSEG1 window and target candidates `b2c00500/b2c00510`.

```text
MMIO_FPM_KSEG1_B2200000
b2200000-b2200fff
rw volatile
```

Reason: covers FPM KSEG1 hardware window.

```text
MMIO_DQM_OR_IOP_KSEG1_B4240000_candidate
b4240000-b4240fff
rw volatile
```

Reason: needed for B424 selector special target/map words.

```text
RAM_ENET_EXTPHY_SPI_DRIVER_TABLE_81A8E9A8_candidate
81a8e9a8-81a8e9af
rw non-volatile
```

Reason: global RAM function-pointer table, not MMIO.

## Do not create these blocks

Do not create a separate `MMIO_DQM_CP2_B6040000` block when the broad B600 block already exists.

Do not create a block for `0xb3617124` yet. It was observed as a constant stored into a response record, not dereferenced.

---

# Project impact

This pass strengthens the vendor-path theory:

- The OpenWrt-side blocker remains GENET TDMA descriptor consumption.
- The vendor firmware path routes through DQM/FPM/IOP-style control paths, not only direct upstream `bcmgenet` TDMA ring setup.
- Case `0x11` specifically connects DQM/CP2 selector routing with GENET target candidates `b2c00500` and `b2c00510`.
- Case `0x12` programs B604/B605 windows after controlling B604 entry bit `0x100`.
- External PHY serial-management helpers are separate from direct GENET TDMA but explain board/vendor PHY setup sequences and ID detection.

This does not solve the TDMA consumer-index problem by itself, but it gives better Ghidra anchors for the vendor DQM/IOP routing layer around GENET.

---

# Remaining Ghidra work

## Immediate next paste/check

Paste the final tail of the store helper:

```text
80c7cbd0-80c7cc10
```

Purpose:

- Confirm all four response words are written.
- Confirm whether `80008090` is cleared, acknowledged, or only polled.
- Confirm whether any B600 mailbox status/ack register is written after response copy.

## Next helper functions to inspect

```text
80c7bf00  fn_dqm_copy_word_pairs_to_b6052000_window_80c7bf00_candidate
80c7c3f8  fn_dqm_selector_context_update_case_0x17_80c7c3f8_candidate
80c7c500  fn_dqm_selector_context_reset_or_apply_case_0x18_80c7c500_candidate
80c7f830  fn_dqm_runtime_gate_apply_or_rebuild_80c7f830_candidate
```

## Cleanup still worth doing

- Clear false function at `80c7c704` if still present.
- Clear false function at `80c7c928` if still present.
- Rename `fn_stub_patch_store_cmd_record` to `fn_dqm_mailbox_store_response_record_80c7cb84_candidate` after the final tail is reviewed.
- Rename parent `fn_runtime_stub_patch_dispatcher` to `fn_dqm_mailbox_runtime_stub_patch_dispatcher_80c7c5d0_candidate` after store-tail confirmation.
- Normalize DQM response labels at `b6001df0..b6001dfc` from generic mailbox names to response-word names if final tail confirms direction.

---

# Suggested repo placement and commit

Target path:

```text
records/reverse/2026-06-20-dqm-mailbox-extphy-spi-genet-selector-ghidra-log.md
```

Suggested commit message:

```text
reverse: document DQM mailbox and external PHY SPI findings
```

Recommended WSL command after downloading the file to `C:\Users\mgta29\Downloads\`:

```sh
cd ~/tc7200u-research; install -D -m 0644 /mnt/c/Users/mgta29/Downloads/2026-06-20-dqm-mailbox-extphy-spi-genet-selector-ghidra-log.md records/reverse/2026-06-20-dqm-mailbox-extphy-spi-genet-selector-ghidra-log.md; git add records/reverse/2026-06-20-dqm-mailbox-extphy-spi-genet-selector-ghidra-log.md; git diff --cached --name-status; git commit -m "reverse: document DQM mailbox and external PHY SPI findings"
```

