# 2026-06-19 DMA/FPM allocator runtime init reverse-engineering log

## Scope

This note records the Ghidra reverse-engineering pass for the TC7200U / BCM3383 DMA/FPM allocator path, including the allocator singleton, allocator header initialization, FPM token allocation/conversion helpers, FPM hardware runtime initialization, board/platform FPM init constants, memory-block organization notes, datatype updates, function labels, signatures, comments, and remaining work.

Primary focus:

- Static DMA/FPM allocator object anchored at `0x81848740`.
- FPM hardware MMIO base `0xb2200000` / physical `0x12200000`.
- FPM token endpoint selection at `fpm_hw_base + 0x200 + pool_class * 8`.
- Vendor board init path proving runtime FPM configuration: buffer size `0x100`, FPM base `0xb2200000`.
- Packet allocator handoff immediately after FPM hardware init.

This log is a manual reverse-engineering record. It does not claim that every suggested Ghidra rename/signature was already applied unless explicitly listed as confirmed/applied in the working notes below.

---

## Repository and artifact placement

Recommended repo-relative path:

```text
records/reverse/2026-06-19-dma-fpm-allocator-runtime-init.md
```

Do not place new notes under `records/notes/`; that path is legacy/wrong for this project.

---

## High-level result

The DMA/FPM allocator model is now substantially closed:

```text
board/platform target init at 0x80143088
  -> fn_dma_fpm_driver_hw_init_wrapper_8009f6a8(0x100, 0xb2200000)
     -> fn_dma_fpm_allocator_get_or_init_8002a798()
     -> fn_dma_fpm_driver_hw_init_8009d0a0(
            allocator_state = 0x81848740,
            requested_fpm_buffer_size = 0x100,
            fpm_hw_base_kseg1 = 0xb2200000)
  -> fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate()
  -> fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate(packet_allocator_context)
```

Runtime constants proven by the caller at `0x801431d4`:

```text
requested_fpm_buffer_size = 0x100
fpm_hw_base_kseg1         = 0xb2200000
physical FPM base         = 0x12200000
```

The MIPS delay slot at `0x801431d8` loads `a1 = 0xb2200000` before the wrapper receives the call arguments.

---

## Memory blocks and map updates

### Confirmed / retained memory blocks

```text
RAM_DMA_ALLOCATOR_STATE_81848700
MMIO_FPM_GMAC0_KSEG1_B2200000_candidate
MMIO_FPM_GMAC0_PHYS_12200000_candidate
```

The DMA/FPM allocator object anchor is:

```text
0x81848740  g_dma_allocator_global_state_81848740_candidate
```

The allocator block currently seen as `0x81848700-0x818488ff` may be only a visible slice. The token high-bits table starts at object offset `+0x48` and is indexed by token index:

```text
allocator_state + 0x48 + token_index * 4
```

The likely logical size may extend far beyond the current small local block. Do not blindly expand the block without auditing overlaps with existing RAM labels/blocks.

### MMIO evidence

The FPM init and token helpers touch these KSEG1 addresses or ranges:

```text
0xb2200000 + 0x00       FPM control / enable bits
0xb2200000 + 0x10       FPM config/status programming
0xb2200000 + 0x40       FPM buffer-size code field
0xb2200000 + 0x44       bus-visible backing-base bits
0xb2200000 + 0xc0       FPM config/status programming
0xb2200000 + 0x200      common FPM free endpoint / class-0 endpoint
0xb2200000 + 0x208      class-1 endpoint
0xb2200000 + 0x210      class-2 endpoint
0xb2200000 + 0x218      class-3 endpoint
0xb2204000              token-field/status window
0xb220b400..0xb220b880  FPM register initialization loops
```

Keep the MMIO block conservative:

```text
MMIO_FPM_GMAC0_KSEG1_B2200000_candidate
```

Do not rename the entire region as fully vendor-confirmed FPM-only unless a broader source/register-map proof is found.

---

## Datatypes

### `dma_allocator_global_state_81848740_candidate`

Current best layout:

```text
+0x00  uint32_t   fpm_hw_base_kseg1_00
+0x04  uint32_t   fpm_buffer_size_hw_code_04
+0x08  uint32_t   configured_fpm_buffer_size_08
+0x0c  void *     fpm_backing_base_aligned_0c
+0x10  undefined  embedded_log_or_flags_object_10_candidate[0x18]
+0x28  uint8_t    pool_size_shift_bits_28
+0x29  undefined  pad_29[0x03]
+0x2c  uint8_t *  pool_class_lookup_table_ptr_2c
+0x30  uint32_t   max_alloc_size_30
+0x34  uint32_t   fpm_extra_base_offset_34_candidate
+0x38  uint32_t   pool_size_by_token_highbits_38[4]
+0x48  uint32_t   token_highbits_table_48_candidate
```

Fields confirmed strongly enough to remove `_candidate` suffix:

```text
fpm_hw_base_kseg1_00
fpm_buffer_size_hw_code_04
configured_fpm_buffer_size_08
fpm_backing_base_aligned_0c
pool_size_shift_bits_28
pool_class_lookup_table_ptr_2c
max_alloc_size_30
pool_size_by_token_highbits_38
```

Fields still provisional:

```text
embedded_log_or_flags_object_10_candidate
fpm_extra_base_offset_34_candidate
token_highbits_table_48_candidate
```

Keep the full structure name candidated for now:

```text
dma_allocator_global_state_81848740_candidate
```

Reason: the full logical object extent and token table bound are still not fully audited.

### Default pool-size/config table

At `0x8146ff54`:

```text
g_dma_fpm_default_pool_sizes_or_limits_8146ff54_candidate
```

Type:

```c
uint32_t[4]
```

Values:

```text
[0] = 0x800
[1] = 0x400
[2] = 0x200
[3] = 0x100
```

These values are copied into `allocator_state->pool_size_by_token_highbits_38[0..3]` by the allocator header initializer.

### Packet allocator datatypes

Do not create a fake empty packet allocator structure yet.

Temporary signatures should use `void *` until the body of `fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate` proves real fields:

```c
void *fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate(void);

int *fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate
        (void *packet_alloc_context);
```

---

## Function findings and labels

### `fn_dma_fpm_allocator_get_or_init_8002a798`

Final role:

- Singleton getter/initializer for the static DMA/FPM allocator control object.
- Returns object base `0x81848740`.
- Checks init byte at `0x81848738`.
- Calls allocator header init on first use.
- Registers cleanup callback.

Recommended signature:

```c
dma_allocator_global_state_81848740_candidate *
fn_dma_fpm_allocator_get_or_init_8002a798(void);
```

Confirmed global:

```text
0x81848738  g_dma_allocator_init_done_81848738_candidate  uint8_t
0x81848740  g_dma_allocator_global_state_81848740_candidate
```

Important correction from this pass:

- The returned pointer is the allocator/control object, not a DMA buffer address.
- `0x81848740` must be the primary object label.
- Labels such as `g_dma_allocator_default_pool_sizes_copy_81848780_candidate`, `g_dma_allocator_fpm_hw_base_or_constant_81848784_candidate`, and `g_dma_allocator_high_bits_table_81848788_candidate` must not be primary labels at `0x81848740`.

### `fn_register_shutdown_or_cleanup_callback_80e99004`

Ghidra rejected raw C function-pointer syntax in the function-signature dialog:

```c
void (*cleanup_callback)(void)
```

Correct procedure:

1. Create a Function Definition datatype:

```c
void stage1_shutdown_cleanup_cb(void)
```

2. Use this signature:

```c
bool fn_register_shutdown_or_cleanup_callback_80e99004
        (stage1_shutdown_cleanup_cb *cleanup_callback);
```

Fallback if `bool` is inconvenient:

```c
int fn_register_shutdown_or_cleanup_callback_80e99004
        (stage1_shutdown_cleanup_cb *cleanup_callback);
```

### `fn_dma_allocator_header_init_8009cf58`

Final role:

- Initializes allocator object header at `0x81848740`.
- Clears/setup fields.
- Copies default pool-size table into allocator object.
- Initializes embedded log/config object as `BcmBfcFpmDriver`.

Recommended signature:

```c
void fn_dma_allocator_header_init_8009cf58
        (dma_allocator_global_state_81848740_candidate *allocator_state);
```

Confirmed writes:

```text
+0x00 = 0
+0x04 = 6
+0x08 = 0x800
+0x0c = NULL
+0x10 = embedded object/log/config state init
+0x28 = 0
+0x2c = NULL
+0x30 = 0
+0x34 = 0
+0x38..+0x44 = copy of 0x8146ff54[4]
```

Important corrections:

- `+0x38..+0x44` is a four-word pool-size/config table copy, not padding.
- `+0x44` is not the FPM hardware base.
- `+0x00` is later proven to be the FPM HW KSEG1 base.

### `fn_dma_fpm_alloc_token_for_size_8002a7ec`

Final role:

- Allocates/reads an FPM token for a requested allocation size.
- Validates against `max_alloc_size_30`.
- Uses pool-size shift and pool-class table to select FPM endpoint.
- Reads token from FPM hardware.
- Saves token highbits into `token_highbits_table_48_candidate[token_index]`.

Recommended signature:

```c
uint32_t fn_dma_fpm_alloc_token_for_size_8002a7ec
        (dma_allocator_global_state_81848740_candidate *allocator_state,
         uint32_t requested_alloc_size);
```

Token format:

```text
bit31      valid token marker
bits29:28  high bits / pool selector
bits27:12  token index
bits11:0   requested allocation size low bits
```

Formula:

```text
pool_index = (requested_alloc_size - 1) >> pool_size_shift_bits_28
pool_class = pool_class_lookup_table_ptr_2c[pool_index]
token      = *(uint32_t *)(fpm_hw_base_kseg1_00 + 0x200 + pool_class * 8)
```

### `fn_dma_get_hw_alloc_free_addr_by_pool_size_8009de50`

Final role:

- Returns FPM hardware alloc/free endpoint address for a nonzero pool size.
- Does not return a normal DMA data buffer.

Recommended signature:

```c
uint32_t fn_dma_get_hw_alloc_free_addr_by_pool_size_8009de50
        (dma_allocator_global_state_81848740_candidate *allocator_state,
         uint16_t pool_size);
```

Formula:

```text
pool_index = (pool_size - 1) >> allocator_state->pool_size_shift_bits_28
pool_class = allocator_state->pool_class_lookup_table_ptr_2c[pool_index]
return allocator_state->fpm_hw_base_kseg1_00 + 0x200 + pool_class * 8
```

### `fn_dma_fpm_token_to_backing_buffer_addr_8009dfec`

Final role:

- Converts an FPM token to a backing buffer pointer.
- Requires configured backing base at `+0x0c`.
- Saves token highbits into the token table.

Recommended signature:

```c
void *fn_dma_fpm_token_to_backing_buffer_addr_8009dfec
        (dma_allocator_global_state_81848740_candidate *allocator_state,
         uint32_t token_word,
         uint32_t extra_base_offset);
```

Formula:

```text
token_index = (token_word >> 12) & 0xffff
backing_addr = extra_base_offset
             + allocator_state->fpm_backing_base_aligned_0c
             + token_index * 0x100

allocator_state->token_highbits_table_48_candidate[token_index] =
    (token_word >> 28) & 3
```

### `fn_dma_fpm_backing_buffer_addr_to_token_8009e0a4`

Final role:

- Reverse of token-to-buffer path.
- Converts backing/FPM data buffer pointer back into token.
- Uses low 29-bit physical/bus-address masking.

Recommended signature:

```c
uint32_t fn_dma_fpm_backing_buffer_addr_to_token_8009e0a4
        (dma_allocator_global_state_81848740_candidate *allocator_state,
         void *backing_buffer_ptr,
         uint32_t extra_base_offset);
```

Formula:

```text
token_index = (((backing_buffer_ptr & 0x1fffffff)
              - (fpm_backing_base_aligned_0c & 0x1fffffff)
              - extra_base_offset) >> 8)

return 0x80000000
     | (token_index << 12)
     | (token_highbits_table_48_candidate[token_index] << 28)
```

### `fn_dma_fpm_free_token_to_hw_8009e168`

Final role:

- Validates token bit31.
- Reconstructs backing address.
- Saves token highbits.
- Selects cache flush size from pool-size table.
- Flushes cache.
- Writes token to common FPM free endpoint.

Recommended signature:

```c
uint32_t fn_dma_fpm_free_token_to_hw_8009e168
        (dma_allocator_global_state_81848740_candidate *allocator_state,
         uint32_t token_word,
         uint32_t extra_base_offset);
```

Final write:

```text
*(uint32_t *)(allocator_state->fpm_hw_base_kseg1_00 + 0x200) = token_word
```

### `fn_fpm_read_7bit_token_field_8009dc4c`

Final role:

- Reads 7-bit FPM token field from hardware token-field window.
- First argument is unused.

Recommended signature:

```c
uint8_t fn_fpm_read_7bit_token_field_8009dc4c
        (dma_allocator_global_state_81848740_candidate *allocator_state_unused,
         uint32_t token_word);
```

Formula:

```text
token_index = (token_word >> 12) & 0x7fff
lane        = token_index & 7
regs        = 0xb2204000 + (token_index & 0x7ff8)
```

### `fn_fpm_set_token_multicast_count_8009dcc0`

Final role:

- Sets/updates a token multicast/count field.
- Requires token bit31 set.
- Count must be `1..0x7f`.

Recommended signature:

```c
uint32_t fn_fpm_set_token_multicast_count_8009dcc0
        (dma_allocator_global_state_81848740_candidate *allocator_state,
         uint32_t token_word,
         uint32_t multicast_count,
         int set_token_bit_0x800);
```

Write target:

```text
allocator_state->fpm_hw_base_kseg1_00 + 0x224
```

Reason: the function builds `fpm_hw_base + 0x200`, then writes at offset `9 * 4`.

### `fn_dma_token_to_pool_size_by_saved_highbits_8009de2c`

Final role:

- Converts token to a pool-size table value through saved token highbits.

Recommended signature:

```c
uint32_t fn_dma_token_to_pool_size_by_saved_highbits_8009de2c
        (dma_allocator_global_state_81848740_candidate *allocator_state,
         uint32_t token_word);
```

Formula:

```text
token_index = (token_word >> 12) & 0xffff
highbits    = token_highbits_table_48_candidate[token_index]
return pool_size_by_token_highbits_38[highbits]
```

### `fn_dma_fpm_alloc_buffer_ptr_for_size_8009e218`

Final role:

- Allocates an FPM token for an effective requested size.
- Converts token to backing buffer pointer.
- Fatal path if token allocation succeeded but token-to-buffer conversion returns NULL.

Recommended signature:

```c
void *fn_dma_fpm_alloc_buffer_ptr_for_size_8009e218
        (dma_allocator_global_state_81848740_candidate *allocator_state,
         uint32_t requested_size);
```

Important note:

```text
requested_effective_size = requested_size + fpm_extra_base_offset_34_candidate
```

Then `fpm_extra_base_offset_34_candidate` is also passed into token-to-buffer conversion.

### `fn_dma_fpm_driver_hw_init_8009d0a0`

Final role:

- Runtime hardware init for DMA/FPM allocator and FPM hardware block.
- Real function starts at `0x8009d0a0`.
- `0x8009d184` is not a real function boundary; it is a MIPS delay-slot instruction for the call at `0x8009d180`.

Recommended signature:

```c
uint32_t fn_dma_fpm_driver_hw_init_8009d0a0
        (dma_allocator_global_state_81848740_candidate *allocator_state,
         uint32_t requested_fpm_buffer_size,
         uint32_t fpm_hw_base_kseg1);
```

Do not force return type to `bool` yet. Some error/log paths still return helper values.

Confirmed writers:

```text
+0x00 = FPM HW KSEG1 base
+0x04 = FPM hardware buffer-size code
+0x08 = configured FPM buffer size
+0x0c = aligned FPM backing base
+0x28 = pool-size shift bits
+0x2c = pool-class lookup table
+0x30 = max allocation size
```

Important correction:

```text
This function does not write +0x34.
```

`+0x34` remains provisional and is used later as an extra base offset by token/buffer conversion.

Buffer-size code mapping:

```text
requested_fpm_buffer_size  fpm_buffer_size_hw_code_04
0x100                      7
0x200                      0
0x400                      2
0x800                      6
```

Runtime result for board path:

```text
requested_fpm_buffer_size = 0x100
fpm_buffer_size_hw_code_04 = 7
backing allocation size = 0x100 * 0x8000 + 0x100 = 0x800100
fpm_hw_base_kseg1_00 = 0xb2200000
```

### `fn_dma_fpm_driver_hw_init_wrapper_8009f6a8`

Final role:

- Thin wrapper for FPM runtime hardware init.
- Gets singleton allocator object.
- Calls the real hardware init.
- Returns callee status because `v0` is not overwritten before return.

Recommended signature:

```c
uint32_t fn_dma_fpm_driver_hw_init_wrapper_8009f6a8
        (uint32_t requested_fpm_buffer_size,
         uint32_t fpm_hw_base_kseg1);
```

Corrected behavior:

```text
Does not call fn_dma_addr_alloc_core.
Calls fn_dma_fpm_allocator_get_or_init_8002a798.
```

### `fn_platform_target_init_fpm_packet_alloc_and_boot_linux_80143088_candidate`

Suggested rename for the broad board/platform function formerly treated as only FPM init:

```text
fn_platform_target_init_fpm_packet_alloc_and_boot_linux_80143088_candidate
```

Reason:

- Resolves platform/nonvolatile config.
- Builds a local FPM/platform config object.
- Calls FPM runtime init with `0x100` and `0xb2200000`.
- Initializes the FPM packet allocator path.
- Logs `Booting Linux on TP1...`.
- Calls `fn_boot_linux_entry`.

Keep `_candidate` until the non-FPM boot/config helpers are mapped.

Confirmed FPM call site:

```asm
801431d0  li    a0,0x100
801431d4  jal   fn_dma_fpm_driver_hw_init_wrapper_8009f6a8
801431d8  _lui  a1,0xb220
```

---

## FPM endpoint mapping

With runtime `requested_fpm_buffer_size = 0x100`, the pool-size table is still:

```text
pool_size_by_token_highbits_38[0] = 0x800
pool_size_by_token_highbits_38[1] = 0x400
pool_size_by_token_highbits_38[2] = 0x200
pool_size_by_token_highbits_38[3] = 0x100
```

The setup computes:

```text
pool_size_shift_bits_28 = 8
max_alloc_size_30       = 0x800
lookup table length     = 0x800 >> 8 = 8 bytes
```

Pool-class lookup table generated by init:

```text
pool_index 0 -> class 3 -> 0x100 pool -> fpm_hw_base + 0x218
pool_index 1 -> class 2 -> 0x200 pool -> fpm_hw_base + 0x210
pool_index 2 -> class 1 -> 0x400 pool -> fpm_hw_base + 0x208
pool_index 3 -> class 1 -> 0x400 pool -> fpm_hw_base + 0x208
pool_index 4 -> class 0 -> 0x800 pool -> fpm_hw_base + 0x200
pool_index 5 -> class 0 -> 0x800 pool -> fpm_hw_base + 0x200
pool_index 6 -> class 0 -> 0x800 pool -> fpm_hw_base + 0x200
pool_index 7 -> class 0 -> 0x800 pool -> fpm_hw_base + 0x200
```

Exact request endpoints for base `0xb2200000`:

```text
request 0x100 -> class 3 -> 0xb2200218 -> physical 0x12200218
request 0x200 -> class 2 -> 0xb2200210 -> physical 0x12200210
request 0x400 -> class 1 -> 0xb2200208 -> physical 0x12200208
request 0x800 -> class 0 -> 0xb2200200 -> physical 0x12200200
```

This matches the expected values written/used by the GMAC MBDMA global init path for FPM endpoint registers:

```text
0x12c0004c = 0x12200218
0x12c00050 = 0x12200210
0x12c00054 = 0x12200208
0x12c00058 = 0x12200200
0x12c00008 = 0x12200200
```

---

## Ghidra repair notes

### Function boundary repair

Bad split:

```text
FUN_8009d184
```

Status:

```text
Not a real function boundary.
0x8009d184 is a delay-slot instruction inside fn_dma_fpm_driver_hw_init_8009d0a0.
```

Action:

- Remove only the bad function boundary if present.
- Keep real function start at `0x8009d0a0`.

### Flow override repair

Broken decompile/disassembly was caused by incorrect flow overrides around calls to `FUN_80f95470`, which converted real instructions into `??` data bytes.

Known affected areas:

```text
8009dde8 / 8009ddf0
8009e078 / 8009e080
```

Repair procedure:

- Set flow override back to default/none on the bad call instruction.
- Clear bad data at following instruction addresses.
- Disassemble again.
- Inspect `FUN_80f95470`; it should not be marked `No Return` if normal callers continue.

### Function-pointer signature repair

Ghidra does not accept raw function pointer syntax reliably in the signature dialog. Use a Function Definition datatype first.

Example:

```c
void stage1_shutdown_cleanup_cb(void);
```

Then use:

```c
stage1_shutdown_cleanup_cb *cleanup_callback
```

---

## Board/platform function notes

### `0x80143088` function scope

The function at `0x80143088` is broader than FPM setup. It performs platform target initialization, FPM setup, packet allocator initialization, local boot/config object setup, and Linux boot.

Recommended provisional name:

```text
fn_platform_target_init_fpm_packet_alloc_and_boot_linux_80143088_candidate
```

### Template constants

Potential labels from local config construction:

```text
0x80fc9c44  g_platform_fpm_local_entry_a_template_80fc9c44_candidate  uint32_t  value 0x00100030
0x80fc9c48  g_platform_fpm_local_entry_b_template_80fc9c48_candidate  uint32_t  value 0x01f401f4
```

### Non-FPM scratch/global labels

Earlier suggestions for `0x81840098` should be treated separately from packet allocator datatype work. If this address is not mapped, do not force it while working on packet allocator signatures. It belongs to the later platform boot scratch/config path, not the FPM allocator structure.

---

## Packet allocator handoff

Immediately after board FPM runtime init:

```asm
801431dc  jal   fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate
801431e0  _nop
801431e4  jal   fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate
801431e8  _move a0,v0
```

Temporary signatures until the body is inspected:

```c
void *fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate(void);

int *fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate
        (void *packet_alloc_context);
```

Do not create `fpm_packet_allocator_context_candidate` until fields are proven by the decompile/listing.

Next high-value target:

```text
fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate
```

---

## Relevance to current Ethernet / GENET blocker

The vendor FPM path proves that FPM hardware is initialized with:

```text
FPM HW KSEG1 base: 0xb2200000
FPM physical base: 0x12200000
FPM configured buffer size: 0x100
```

The endpoint mapping then resolves to physical FPM endpoint values matching the previously expected MBDMA/GENET FPM register setup:

```text
0x12200218
0x12200210
0x12200208
0x12200200
```

This matters for the OpenWrt GENET/TDMA blocker because the vendor path distinguishes:

```text
FPM hardware endpoints  -> MMIO alloc/free token addresses
FPM token values        -> bitfield identifiers for backing slots
FPM backing buffers     -> CPU pointer + low-29-bit physical/bus masking
GENET/MBDMA registers   -> likely receive physical endpoint/address values, not raw CPU pointers
```

Do not treat `0x81848740` as a DMA buffer. It is software allocator state.

---

## Remaining work

1. Inspect `fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate`.
2. Build a real `fpm_packet_allocator_context_candidate` only from proven fields.
3. Audit allocator object/token table extent beyond the visible `0x81848700-0x818488ff` block.
4. Confirm or reject overlap with any existing `RAM_STAGE1_RELATED_OBJECT_POOLS_8184FA00_candidate` interpretation.
5. Continue mapping packet header allocation and release callbacks:
   - `fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate`
   - `fn_dma_fpm_packet_alloc_header_buffer_init_800b6b2c_candidate`
   - `fn_dma_fpm_packet_free_callback_8002a4ac_candidate`
   - `fn_dma_fpm_alloc_buffer_ptr_for_size_8009e218`
   - `fn_dma_fpm_free_token_to_hw_8009e168`
6. Re-check GMAC/MBDMA global init writes against the now-proven FPM endpoint mapping.

---

## Suggested commit

Recommended commit message:

```text
reverse: document DMA/FPM allocator runtime init
```

Suggested WSL command from repo root:

```bash
cd ~/tc7200u-research; mkdir -p records/reverse; cp /mnt/data/records/reverse/2026-06-19-dma-fpm-allocator-runtime-init.md records/reverse/2026-06-19-dma-fpm-allocator-runtime-init.md; git status --short --branch; git add records/reverse/2026-06-19-dma-fpm-allocator-runtime-init.md; git commit -m "reverse: document DMA/FPM allocator runtime init"; git status --short --branch
```

