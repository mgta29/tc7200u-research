# 2026-06-24 — Ghidra SPI Flash, Flash Device Base, Vtable, Block Map Log

Project: `tc7200u-research`  
Target: Technicolor TC7200U / BCM3383 Stage1 image  
Program: `image.raw`  
Architecture context: MIPS:BE:32, Stage1 base `0x80004000`  
Scope: SPI flash detection path, flash subsystem initializer, flash-device base object, vtable, block-map helpers, datatypes, memory blocks, tables, and remaining cleanup before continuing to `FUN_803e5854`.

---

## 1. Session result summary

This pass moved the current Ghidra work from the ENET/HSSPI transport layer into the Stage1 flash subsystem. The SPI flash path is now tied into the top-level flash initializer and the common flash-device base object is partially decoded.

Main result:

```text
803e3230  fn_flash_subsystem_detect_devices_and_place_regions_803e3230_candidate
```

Current interpretation:

```text
Top-level flash subsystem initializer:
  1. checks global init latch
  2. clears flash-region runtime state
  3. creates flash subsystem mutex/semaphore
  4. attempts SPI flash device detection/construction
  5. falls back to NAND flash detection/construction
  6. falls back to memory-window flash detection/construction
  7. validates detected device sizes/windows
  8. places flash regions
  9. computes clamped runtime limit
  10. sets init latch and returns success/failure
```

The SPI flash detection chain now has named opcode helpers for JEDEC ID, WREN, WRDI, status-register read, and extended CFI-style probing. The common flash-device base destructor, vtable destructor slots, block-map entry helpers, and indexed block-map accessor are also decoded.

---

## 2. Export/source state used for this log

The current attached/exported files showed this baseline:

```text
labels.json      exported_at: 20260623-235406
  labels:        1657
  datatypes:     158

datatype.json    exported_at: 2026-06-23T23:54:02.9737029
  total exported datatypes in /custom and /tc7200u: 301
  missing_category_paths: 0

memoryblock.json generated_at: 2026-06-23T21:39:47
  block_count:   59
```

Important export status:

```text
Already present in labels export:
  803e3230  fn_flash_subsystem_detect_devices_and_place_regions_803e3230_candidate
  806109d8  fn_spi_flash_device_factory_init_806109d8_candidate
  80610a84  fn_spi_flash_detect_jedec_build_device_80610a84_candidate
  806107b0  fn_spi_flash_read_jedec_id_806107b0_candidate
  80610720  fn_spi_flash_write_enable_80610720_candidate
  80610768  fn_spi_flash_write_disable_80610768_candidate
  806106d4  fn_spi_flash_read_status05_byte_806106d4_candidate
  80610830  fn_spi_flash_probe_cfi_from_jedec_buffer_80610830_candidate

Still pending in exported labels/datatypes, because these were decoded after that export:
  80610a28  fn_spi_flash_device_factory_cleanup_80610a28_candidate
  803e2390  fn_flash_device_base_destroy_block_map_803e2390_candidate
  803e2420  fn_flash_device_base_vtable_destroy_803e2420_candidate
  803e24b0  fn_flash_device_base_vtable_destroy_and_free_803e24b0_candidate
  803e21b4  fn_flash_block_map_entry_clear_803e21b4
  803e21c8  fn_flash_block_map_entry_copy_803e21c8
  803e21f0  fn_flash_block_map_entry_equal_803e21f0
  803e2548  fn_flash_device_get_block_map_entry_by_index_803e2548
```

---

## 3. Top-level flash subsystem initializer

### Function

```c
uint32_t fn_flash_subsystem_detect_devices_and_place_regions_803e3230_candidate(void)
```

Address:

```text
803e3230
```

Return meaning:

```text
1 = flash subsystem initialized / already initialized
0 = detection, validation, mutex setup, or region-placement failed
```

### Confirmed behavior

```text
- checks g_flash_subsystem_init_done_8147A44C_candidate
- clears flash region/runtime state at 818ca920, length 0x78
- creates flash subsystem mutex/semaphore and stores it at 8147a46c
- attempts flash device 0 in this order:
    1. SPI flash path
    2. NAND flash path
    3. memory-window flash fallback path
- validates device size against the detected memory window
- optionally detects a second flash device
- validates dual-device consistency
- calls flash region-placement helper
- on failure, destroys allocated flash objects and clears pointers
- on success:
    - computes g_flash_runtime_clamped_limit_8147A490_candidate
    - clamps lower bound to 0x10000
    - clamps upper bound to 0x40000
    - sets g_flash_subsystem_init_done_8147A44C_candidate
```

### Updated plate-comment references to use symbol names

The SPI section should reference the final names:

```text
SPI flash:
  {@symbol fn_spi_flash_device_factory_init_806109d8_candidate}
  {@symbol fn_spi_flash_detect_jedec_build_device_80610a84_candidate}
  cleanup through {@symbol fn_spi_flash_device_factory_cleanup_80610a28_candidate}
```

The region-placement reference should remain provisional until decoded:

```text
places detected flash regions through {@symbol FUN_803e5854}
```

Expected next major target:

```text
FUN_803e5854
```

---

## 4. Flash subsystem globals

Keep these as separate globals for now. Do **not** collapse into one large struct yet, because Ghidra already has stable labels/datatype items inside this range.

| Address | Label | Datatype | Meaning |
|---:|---|---|---|
| `8147a44c` | `g_flash_subsystem_init_done_8147A44C_candidate` | `uint8_t` | Flash subsystem init latch |
| `8147a450` | `g_flash_device0_8147A450_candidate` | `void *` | Primary flash device pointer |
| `8147a454` | `g_flash_device1_8147A454_candidate` | `void *` | Secondary flash device pointer |
| `8147a458` | `g_flash_primary_or_active_device_8147A458_candidate` | `void *` | Active/primary selected flash device pointer |
| `8147a46c` | `g_flash_subsystem_mutex_sem_8147A46C_candidate` | `stage1_bcm_sem_candidate *` | Flash subsystem mutex/semaphore |
| `8147a490` | `g_flash_runtime_clamped_limit_8147A490_candidate` | `uint32_t` | Runtime size/limit clamped to `0x10000..0x40000` |
| `8147a498` | `g_flash_spi_device0_detected_8147A498_candidate` | `uint8_t` | SPI flash path detected flag candidate |
| `8147a499` | `g_flash_nand_detected_8147A499_candidate` | `uint8_t` | NAND detected flag candidate |

Rejected action:

```text
Do not apply stage1_flash_runtime_state_candidate at 8147a44c yet.
Reason: it overwrites already-defined separate globals at 8147a44c..8147a499.
```

---

## 5. SPI flash factory path

### 5.1 Factory init

```c
void fn_spi_flash_device_factory_init_806109d8_candidate(void *factory_obj)
```

Address:

```text
806109d8
```

Behavior:

```text
- initializes base object with name "SPI Flash Device Factory"
- stores SPI factory vtable/object table pointer at factory_obj +0x00
- sets object name at factory_obj +0x04 to "BcmSpiFlashDevice"
```

Vtable/object pointer:

```text
8180f948  g_spi_flash_device_factory_vtable_8180F948_candidate
```

Keep datatype for `8180f948` as `void *` until the full SPI flash factory vtable is decoded.

### 5.2 Factory cleanup wrapper

```c
void fn_spi_flash_device_factory_cleanup_80610a28_candidate(void *factory_ctx)
```

Address:

```text
80610a28
```

Behavior:

```text
- restores vtable/object table pointer 8180f948 at factory_ctx +0x00
- calls common flash-device base cleanup:
    {@symbol fn_flash_device_base_destroy_block_map_803e2390_candidate}
```

Important correction:

```text
The decompiler shows inherited in_a1/in_a2/in_a3 values passed into 803e2390.
Those are register artifacts, not intentional parameters of 80610a28.
Keep the wrapper signature one-argument only.
```

### 5.3 SPI flash JEDEC/CFI detect and device construction

```c
stage1_flash_device_object_68_candidate * fn_spi_flash_detect_jedec_build_device_80610a84_candidate(spi_flash_detect_context_candidate *detect_ctx)
```

Fallback signature until object type is fully applied:

```c
void * fn_spi_flash_detect_jedec_build_device_80610a84_candidate(spi_flash_detect_context_candidate *detect_ctx)
```

Address:

```text
80610a84
```

Confirmed behavior:

```text
- initializes detect_ctx fields:
    +0x28 = 0
    +0x29 = 0
    +0x2c = 1
- calls shared HSSPI/SPI driver table return1 callback
- reads primary JEDEC ID with select 0
- reads secondary JEDEC ID with select 1
- scans SPI flash JEDEC parameter table at 814c3eec
- supports exact JEDEC table matches
- supports wildcard/mask-style entries where the middle JEDEC byte is 0xff
- when primary and secondary JEDEC IDs match:
    - sends WREN opcode 0x06
    - reads status opcode 0x05
    - if status bit 1 is clear, ORs flag 0x4 into matched table flags
    - sends WRDI opcode 0x04
    - calls HSSPI pre-transfer noop/hook
- probes extended JEDEC/CFI-style data with 0x9f and 0x80-byte receive buffer
- compares CFI result against matched table values
- logs/replaces block/page geometry when CFI values are more specific
- allocates flash-device object of size 0x68
- initializes geometry and block-map data
- returns flash object pointer or NULL
```

---

## 6. SPI flash opcode helpers

| Address | Function | Opcode | Role |
|---:|---|---:|---|
| `806107b0` | `fn_spi_flash_read_jedec_id_806107b0_candidate` | `0x9f` | Read 24-bit JEDEC ID |
| `80610830` | `fn_spi_flash_probe_cfi_from_jedec_buffer_80610830_candidate` | `0x9f` | Extended 128-byte JEDEC/CFI-style probe |
| `80610720` | `fn_spi_flash_write_enable_80610720_candidate` | `0x06` | WREN / Write Enable |
| `80610768` | `fn_spi_flash_write_disable_80610768_candidate` | `0x04` | WRDI / Write Disable |
| `806106d4` | `fn_spi_flash_read_status05_byte_806106d4_candidate` | `0x05` | Read status register byte |

### 6.1 JEDEC ID read helper

```c
uint32_t fn_spi_flash_read_jedec_id_806107b0_candidate(uint32_t read_select)
```

Transfer ABI:

```text
command[0] = 0x9f
call transfer_fn:
  a0 = 3
  a1 = read_select
  a2 = stack command buffer
  a3 = 1
  hidden t0 = 0
  hidden t1 = 0
  hidden t2 = stack +0x08 receive buffer
  hidden t3 = 3
```

Return:

```text
0 if transfer failed
0 if received JEDEC ID is 0x00ffffff
otherwise 24-bit JEDEC ID: rx[0] << 16 | rx[1] << 8 | rx[2]
```

### 6.2 Extended JEDEC/CFI-style probe helper

```c
uint32_t fn_spi_flash_probe_cfi_from_jedec_buffer_80610830_candidate(uint32_t select_value)
```

Transfer ABI:

```text
command[0] = 0x9f
call transfer_fn:
  a0 = 3
  a1 = select_value
  a2 = stack command buffer
  a3 = 1
  hidden t0 = 0
  hidden t1 = 0
  hidden t2 = stack +0x08 receive buffer
  hidden t3 = 0x80
```

Confirmed parsing:

```text
- bytes 0..2 become JEDEC ID
- invalid IDs 0 and 0x00ffffff return 0
- stores JEDEC ID into g_spi_flash_cfi_probe_result_818E7170_candidate +0x00
- checks QRY signature in returned buffer
- if QRY exists:
    +0x04 total_size = 1 << buffer[0x2f]
    +0x08 erase/block size = maximum erase-region size derived from CFI descriptors
    +0x0c page/write-buffer size from buffer[0x54]
```

Page/write-buffer code mapping:

| Code | Result |
|---:|---:|
| `0` | `1` |
| `1` | `4` |
| `2` | `8` |
| `3` | `0x100` |
| `4` | `0x200` |
| other | `1` |

### 6.3 WREN helper

```c
void fn_spi_flash_write_enable_80610720_candidate(uint32_t select_value)
```

```text
command[0] = 0x06
transfer mode a0 = 2
known caller: 80610a84, select_value = 1
```

### 6.4 WRDI helper

```c
void fn_spi_flash_write_disable_80610768_candidate(uint32_t select_value)
```

```text
command[0] = 0x04
transfer mode a0 = 2
known caller: 80610a84, select_value = 1
```

### 6.5 Status-register read helper

```c
uint8_t fn_spi_flash_read_status05_byte_806106d4_candidate(uint32_t select_value)
```

```text
command[0] = 0x05
transfer mode a0 = 3
hidden receive byte at stack +0x08
returns received status byte
```

Required comment cleanup:

```text
The old comment still says external PHY/SPI status helper.
Replace it with SPI flash status-register read helper wording.
```

---

## 7. SPI flash data structures

### 7.1 SPI flash detection context

Category:

```text
/tc7200u/stage1/spi_flash
```

```c
struct spi_flash_detect_context_candidate {
    undefined field_00[0x04];
    undefined log_or_config_object_04[0x24];
    uint8_t mode_byte_28;
    uint8_t option_byte_29;
    undefined field_2a[2];
    uint32_t detect_state_2c;
    uint32_t page_or_write_buffer_size_30;
    uint8_t field_34;
    undefined field_35[3];
    void *block_map_38;
    uint32_t erase_block_count_3c;
    undefined field_40[0x0c];
    uint32_t total_size_4c;
};
```

Length:

```text
0x50
```

### 7.2 SPI flash JEDEC table entry

Currently still exported from:

```text
/custom
```

Move to:

```text
/tc7200u/stage1/spi_flash
```

```c
struct spi_flash_jedec_table_entry_14_candidate {
    uint32_t jedec_id_or_mask_00;
    uint32_t total_size_04;
    uint32_t erase_block_size_08;
    uint32_t page_or_write_buffer_size_0c;
    uint32_t flags_10;
};
```

Length:

```text
0x14
```

Apply at:

```text
814c3eec  g_spi_flash_jedec_table_814C3EEC_candidate
```

Current export still shows this as `/undefined4`; this is a pending cleanup.

Pre-comment to keep:

```text
Pre comment @814c3eec:
SPI flash JEDEC parameter table candidate.

Entry size:
  0x14 bytes

Observed fields:
  +0x00 JEDEC ID or wildcard/mask-style ID
  +0x04 total device size
  +0x08 erase/block size
  +0x0c page/write-buffer size
  +0x10 flags

Observed use:
  {@symbol fn_spi_flash_detect_jedec_build_device_80610a84_candidate}
  scans this table, matches detected JEDEC IDs, applies wildcard entries, and
  uses the matched entry to construct the flash device geometry.

Keep _candidate:
  Table count and exact flag meanings are not fully proven yet.
```

### 7.3 SPI flash CFI/probe result

Currently still exported from:

```text
/custom
```

Move to:

```text
/tc7200u/stage1/spi_flash
```

```c
struct spi_flash_cfi_probe_result_10_candidate {
    uint32_t jedec_id_00;
    uint32_t total_size_04;
    uint32_t erase_block_size_08;
    uint32_t page_or_write_buffer_size_0c;
};
```

Length:

```text
0x10
```

Apply at:

```text
818e7170  g_spi_flash_cfi_probe_result_818E7170_candidate
```

Current export still shows this as `/undefined`; this is a pending cleanup.

---

## 8. Shared HSSPI/SPI transport table

The SPI flash path uses the existing shared HSSPI/SPI driver table also used by external PHY operations.

Base table:

```text
81a8e9a8  g_enet_extphy_spi_driver_table_81A8E9A8_candidate
```

Transfer slot:

```text
81a8e9ac  g_enet_extphy_spi_transfer_fn_81a8e9ac_candidate
```

Structure:

```c
uint32_t enet_extphy_hsspi_set_profile_clock_fn(uint32_t profile_index, uint32_t clock_index);
uint32_t enet_extphy_spi_transfer_fn_candidate(uint32_t transfer_mode, uint32_t profile_index, void *tx_buf, uint32_t tx_len);

struct enet_extphy_spi_driver_table_candidate {
    enet_extphy_hsspi_set_profile_clock_fn *set_profile_clock_fn_00;
    enet_extphy_spi_transfer_fn_candidate *transfer_fn_04;
    void *return1_callback_08;
};
```

Important ABI note:

```text
Do not add hidden t0/t1/t2/t3 to the function-definition typedef.
Document hidden t-register usage in comments only.
```

Known SPI flash calls through this slot:

| Caller | Command | transfer_mode | tx_len | hidden receive length |
|---|---:|---:|---:|---:|
| `fn_spi_flash_read_jedec_id_806107b0_candidate` | `0x9f` | `3` | `1` | `3` |
| `fn_spi_flash_probe_cfi_from_jedec_buffer_80610830_candidate` | `0x9f` | `3` | `1` | `0x80` |
| `fn_spi_flash_write_enable_80610720_candidate` | `0x06` | `2` | `1` | `0` |
| `fn_spi_flash_write_disable_80610768_candidate` | `0x04` | `2` | `1` | `0` |
| `fn_spi_flash_read_status05_byte_806106d4_candidate` | `0x05` | `3` | `1` | `1` |

---

## 9. Flash-device base object and block map

### 9.1 Block-map entry

Category:

```text
/tc7200u/stage1/flash
```

```c
struct stage1_flash_block_map_entry_10_candidate {
    uint32_t block_index_00;
    uint32_t block_size_04;
    uint32_t block_offset_08;
    void *flash_device_0c;
};
```

Length:

```text
0x10
```

Confirmed by:

```text
803e21b4  clears +0x00, +0x04, +0x08, +0x0c
803e21c8  copies +0x00, +0x04, +0x08, +0x0c
803e21f0  compares +0x00, +0x04, +0x08, +0x0c
803e2548  indexes entries using block_index * 0x10
```

### 9.2 Flash-device object

Category:

```text
/tc7200u/stage1/flash
```

```c
struct stage1_flash_device_object_68_candidate {
    stage1_flash_device_base_vtable_candidate *vtable_00;
    undefined object_or_config_04[0x34];
    stage1_flash_block_map_entry_10_candidate *block_map_entries_38;
    uint32_t block_map_entry_count_3c;
    undefined field_40[0x10];
    uint32_t field_50_zeroed_on_destroy;
    undefined field_54[0x14];
};
```

Length:

```text
0x68
```

Confirmed by:

```text
80610a84  allocates 0x68-byte flash object
803e2390  reads block_map_entries_38 and clears field_50
803e2420  reads block_map_entries_38 and clears field_50
803e24b0  reads block_map_entries_38, clears field_50, then frees object
803e2548  reads block_map_entry_count_3c and indexes block_map_entries_38
```

Field `+0x3c` is now confirmed as count:

```text
block_map_entry_count_3c
```

---

## 10. Flash-device base destructor and vtable work

### 10.1 Common base cleanup wrapper

```c
void fn_flash_device_base_destroy_block_map_803e2390_candidate(void *flash_obj)
```

Address:

```text
803e2390
```

Behavior:

```text
- restores base flash-device vtable at flash_obj +0x00
- reads block_map_entries_38
- if entries exist:
    - reads entry_count from *(entries - 4)
    - walks entries backward, 0x10 bytes each
    - calls fn_flash_block_map_entry_clear_803e21b4 for each entry
    - frees allocation at entries - 4 through FUN_80f08cdc
    - clears block_map_entries_38
- clears field_50_zeroed_on_destroy
- destroys/finalizes embedded object/config area at flash_obj +0x04 through:
    - FUN_804ed1ac
    - FUN_804ec3d4
```

### 10.2 Vtable destroy slot

```c
void fn_flash_device_base_vtable_destroy_803e2420_candidate(stage1_flash_device_object_68_candidate *flash_obj)
```

Address:

```text
803e2420
```

Behavior:

```text
Same base cleanup as 803e2390, without freeing flash_obj itself.
```

Vtable slot:

```text
8180adc8 +0x00
```

### 10.3 Vtable destroy-and-free slot

Correct function boundary:

```text
803e24b0
```

False split rejected:

```text
803e24c4 is not a real function start.
It is body code inside the 803e24b0 function after s1 has been initialized.
```

Signature:

```c
void fn_flash_device_base_vtable_destroy_and_free_803e24b0_candidate(stage1_flash_device_object_68_candidate *flash_obj)
```

Behavior:

```text
- performs same base cleanup as 803e2420
- then frees flash_obj itself through fn_heap_free_if_nonnull_80f08cbc_candidate
```

Vtable slot:

```text
8180adc8 +0x04
```

### 10.4 Flash-device base vtable

Address:

```text
8180adc8  g_flash_device_base_vtable_8180ADC8_candidate
```

Bytes shown by Ghidra:

```text
8180adc8  80 3e 24 20  -> 803e2420
8180adcc  80 3e 24 b0  -> 803e24b0
```

Structure:

```c
typedef void stage1_flash_device_destroy_fn_candidate(stage1_flash_device_object_68_candidate *flash_obj);

struct stage1_flash_device_base_vtable_candidate {
    stage1_flash_device_destroy_fn_candidate *destroy_00;
    stage1_flash_device_destroy_fn_candidate *destroy_and_free_04;
};
```

Applied at:

```text
8180adc8
```

Result:

```text
8180adc8  stage1_flash_device_base_vtable_candidate g_flash_device_base_vtable_8180ADC8_candidate
  +0x00 destroy_00          -> fn_flash_device_base_vtable_destroy_803e2420_candidate
  +0x04 destroy_and_free_04 -> fn_flash_device_base_vtable_destroy_and_free_803e24b0_candidate
```

Clean-up note:

```text
Separate top-level label at 8180adcc is not required once the full vtable struct is applied.
The field name destroy_and_free_04 is enough.
```

---

## 11. Flash block-map helpers

### 11.1 Clear helper

```c
void fn_flash_block_map_entry_clear_803e21b4(stage1_flash_block_map_entry_10_candidate *block_entry)
```

Address:

```text
803e21b4
```

Behavior:

```text
Clears:
  +0x00 block_index_00
  +0x04 block_size_04
  +0x08 block_offset_08
  +0x0c flash_device_0c
```

No `_candidate` needed; behavior is direct.

### 11.2 Copy helper

```c
stage1_flash_block_map_entry_10_candidate * fn_flash_block_map_entry_copy_803e21c8(stage1_flash_block_map_entry_10_candidate *dst_entry, stage1_flash_block_map_entry_10_candidate *src_entry)
```

Address:

```text
803e21c8
```

Behavior:

```text
Copies all four 32-bit fields from src_entry to dst_entry.
Returns dst_entry.
```

No `_candidate` needed; behavior is direct.

### 11.3 Equality helper

```c
uint32_t fn_flash_block_map_entry_equal_803e21f0(stage1_flash_block_map_entry_10_candidate *entry_a, stage1_flash_block_map_entry_10_candidate *entry_b)
```

Address:

```text
803e21f0
```

Return:

```text
1 = all fields match
0 = any field differs
```

Fields compared:

```text
+0x00 block_index_00
+0x04 block_size_04
+0x08 block_offset_08
+0x0c flash_device_0c
```

No `_candidate` needed; behavior is direct.

### 11.4 Bounds-checked block-map accessor

```c
stage1_flash_block_map_entry_10_candidate * fn_flash_device_get_block_map_entry_by_index_803e2548(stage1_flash_device_object_68_candidate *flash_obj, uint32_t block_index)
```

Address:

```text
803e2548
```

Behavior:

```text
if (block_index >= flash_obj->block_map_entry_count_3c)
    return NULL;

return flash_obj->block_map_entries_38 + block_index * 0x10;
```

This confirms:

```text
flash_obj +0x38 = block_map_entries_38
flash_obj +0x3c = block_map_entry_count_3c
entry size       = 0x10
```

No `_candidate` needed; behavior is direct.

---

## 12. Memory block status

No new memory block was required for the final `803e21b4..803e2548` helper pass. The current relevant memory/data regions are:

### 12.1 Flash-device base vtable

```text
Address: 8180adc8..8180adcf
Label:   g_flash_device_base_vtable_8180ADC8_candidate
Type:    stage1_flash_device_base_vtable_candidate
```

This lives in an existing image/RAM data area. Do not include byte `8180adc7`; it is the byte immediately before the vtable.

### 12.2 SPI flash JEDEC table

```text
Address: 814c3eec
Label:   g_spi_flash_jedec_table_814C3EEC_candidate
Type:    spi_flash_jedec_table_entry_14_candidate
Status:  pending apply; current export still shows /undefined4
```

If Ghidra cannot navigate or define it cleanly, create/confirm a small data block covering the table area, but do not force a huge array until table count/terminator is proven.

### 12.3 SPI flash CFI/probe result state

```text
Address: 818e7170
Label:   g_spi_flash_cfi_probe_result_818E7170_candidate
Type:    spi_flash_cfi_probe_result_10_candidate
Status:  pending apply; current export still shows /undefined
```

If needed, create:

```text
Name:    RAM_SPI_FLASH_CFI_STATE_818E7168_candidate
Start:   818E7168
Length:  0x20
End:     818E7187
Type:    Uninitialized
Read:    yes
Write:   yes
Execute: no
Volatile:no
```

Optional label at `818e7168`:

```text
g_spi_flash_cfi_static_state_818E7168_candidate
```

### 12.4 Flash region runtime state

Used by `803e3230`:

```text
Address: 818ca920
Length:  0x78
Label:   g_flash_region_state_818CA920_candidate
```

If missing/unmapped, create:

```text
Name:    RAM_FLASH_REGION_STATE_818CA920_candidate
Start:   818CA920
Length:  0x78
End:     818CA997
Type:    Uninitialized
Read:    yes
Write:   yes
Execute: no
Volatile:no
```

Minimal structure candidate:

```c
struct stage1_flash_region_state_78_candidate {
    undefined field_00[0x40];
    uint32_t region0_limit_or_size_40;
    undefined field_44[0x14];
    uint32_t region1_limit_or_size_58;
    undefined field_5c[0x1c];
};
```

### 12.5 HSSPI/SPI driver table

```text
Address: 81a8e9a8..81a8e9b3
Label:   g_enet_extphy_spi_driver_table_81A8E9A8_candidate
Type:    enet_extphy_spi_driver_table_candidate
Length:  0x0c
```

Slot `+0x04` at `81a8e9ac` is the real transfer function pointer slot used by SPI flash helpers.

### 12.6 HSSPI MMIO block

Previously organized memory block:

```text
Name:    PERIPH_HSSPI_OR_SPI_B4E01000_candidate
Start:   B4E01000
Length:  0x800
End:     B4E017FF
Read:    yes
Write:   yes
Execute: no
Volatile: yes if possible
```

Important register labels remain:

```text
b4e01000  HSSPI_OR_SPI_BASE_B4E01000_candidate
b4e01008  HSSPI_OR_SPI_STATUS_ACK_B4E01008_candidate
b4e01010  HSSPI_OR_SPI_CONTROL_CLEAR_B4E01010_candidate
b4e01080  HSSPI_OR_SPI_CHANNEL_COMMAND_BASE_B4E01080_candidate
b4e01084  HSSPI_OR_SPI_CHANNEL_STATUS_BASE_B4E01084_candidate
b4e01088  HSSPI_OR_SPI_CHANNEL_MSG_TAIL_BASE_B4E01088_candidate
b4e01100  HSSPI_OR_SPI_PROFILE_BASE_B4E01100_candidate
b4e01102  HSSPI_OR_SPI_PROFILE_CLOCK_DIV_BASE_B4E01102_candidate
b4e01104  HSSPI_OR_SPI_PROFILE_CONFIG_WORD_BASE_B4E01104_candidate
b4e01108  HSSPI_OR_SPI_PROFILE_CTRL_BASE_B4E01108_candidate
b4e01200  HSSPI_OR_SPI_MESSAGE_RAM_B4E01200_candidate
```

Do not define offcut standalone bytes at `b4e0100b` or `b4e01107` when their containing word fields are already defined.

---

## 13. Datatype category cleanup required

Current export still shows the two SPI flash structs under `/custom`:

```text
/custom/spi_flash_cfi_probe_result_10_candidate
/custom/spi_flash_jedec_table_entry_14_candidate
```

Move both to:

```text
/tc7200u/stage1/spi_flash
```

Add new flash object datatypes under:

```text
/tc7200u/stage1/flash
```

Recommended new datatype set:

```text
/tc7200u/stage1/flash/stage1_flash_block_map_entry_10_candidate
/tc7200u/stage1/flash/stage1_flash_device_object_68_candidate
/tc7200u/stage1/flash/stage1_flash_device_destroy_fn_candidate
/tc7200u/stage1/flash/stage1_flash_device_base_vtable_candidate
```

Use fixed-width stdint types for normal fields:

```text
uint8_t
uint16_t
uint32_t
```

Use volatile integer typedefs only for MMIO-visible register fields:

```text
vuint8_t
vuint16_t
vuint32_t
```

---

## 14. Ghidra corrections made / recommended

### 14.1 Bad function split at `803e24c4`

Correction:

```text
Delete function only at 803e24c4.
Do not delete bytes.
Real function start is 803e24b0.
```

Reason:

```text
803e24b0 contains the prologue and saved register setup.
803e24c4 relies on s1 already being initialized at 803e24c0.
```

### 14.2 Vtable apply at `8180adc8`

Correction:

```text
Apply stage1_flash_device_base_vtable_candidate at 8180adc8.
If Ghidra asks to clear conflicting data inside 8180adc8..8180adcf, click Yes.
```

Reason:

```text
Both vtable words are proven:
  8180adc8 -> 803e2420
  8180adcc -> 803e24b0
```

### 14.3 Do not clear globals at `8147a44c`

Correction:

```text
Do not apply a combined flash runtime struct at 8147a44c yet.
Click No/Cancel if Ghidra asks to clear existing separate global labels.
```

Reason:

```text
The separate globals are already useful and proven enough.
Collapsing them now would remove individual labels and reduce readability.
```

### 14.4 Function pointer type note

Do not use unavailable `code *`. Use either:

```text
void *
```

or a function-definition pointer such as:

```text
stage1_flash_device_destroy_fn_candidate *
```

---

## 15. Current function naming table

| Address | Name | Candidate? | Status |
|---:|---|---:|---|
| `803e3230` | `fn_flash_subsystem_detect_devices_and_place_regions_803e3230_candidate` | yes | Top-level flash subsystem init |
| `806109d8` | `fn_spi_flash_device_factory_init_806109d8_candidate` | yes | SPI flash factory init |
| `80610a28` | `fn_spi_flash_device_factory_cleanup_80610a28_candidate` | yes | SPI factory cleanup wrapper |
| `80610a84` | `fn_spi_flash_detect_jedec_build_device_80610a84_candidate` | yes | JEDEC/CFI detect and flash object construction |
| `806107b0` | `fn_spi_flash_read_jedec_id_806107b0_candidate` | yes | opcode `0x9f` JEDEC ID read |
| `80610830` | `fn_spi_flash_probe_cfi_from_jedec_buffer_80610830_candidate` | yes | opcode `0x9f`, 0x80-byte extended probe |
| `80610720` | `fn_spi_flash_write_enable_80610720_candidate` | yes | opcode `0x06` WREN |
| `80610768` | `fn_spi_flash_write_disable_80610768_candidate` | yes | opcode `0x04` WRDI |
| `806106d4` | `fn_spi_flash_read_status05_byte_806106d4_candidate` | yes | opcode `0x05` status read |
| `803e2390` | `fn_flash_device_base_destroy_block_map_803e2390_candidate` | yes | Common base cleanup wrapper |
| `803e2420` | `fn_flash_device_base_vtable_destroy_803e2420_candidate` | yes | Vtable destroy slot |
| `803e24b0` | `fn_flash_device_base_vtable_destroy_and_free_803e24b0_candidate` | yes | Vtable destroy-and-free slot |
| `803e21b4` | `fn_flash_block_map_entry_clear_803e21b4` | no | Direct block-map entry clear |
| `803e21c8` | `fn_flash_block_map_entry_copy_803e21c8` | no | Direct block-map entry copy |
| `803e21f0` | `fn_flash_block_map_entry_equal_803e21f0` | no | Direct block-map entry equality check |
| `803e2548` | `fn_flash_device_get_block_map_entry_by_index_803e2548` | no | Direct bounds-checked block-map accessor |

---

## 16. Pending action list before next reverse step

Do these before continuing to `FUN_803e5854`:

```text
1. Re-export labels.json/datatype.json after applying latest names and datatypes.
2. Move SPI flash structs from /custom to /tc7200u/stage1/spi_flash:
     spi_flash_cfi_probe_result_10_candidate
     spi_flash_jedec_table_entry_14_candidate
3. Apply spi_flash_jedec_table_entry_14_candidate at 814c3eec.
4. Apply spi_flash_cfi_probe_result_10_candidate at 818e7170.
5. Replace old 806106d4 plate comment with SPI flash status-register wording.
6. Ensure 803e24c4 false function is deleted.
7. Ensure 803e24b0 is the real function start.
8. Ensure 8180adc8 has stage1_flash_device_base_vtable_candidate applied.
9. Ensure 803e3230 plate comment references final SPI symbols, not raw addresses.
10. Keep 8147a44c..8147a499 as separate globals for now.
```

---

## 17. Next target

Next function for detailed reverse pass:

```text
FUN_803e5854
```

Reason:

```text
- It is referenced by the top-level flash subsystem initializer.
- It likely performs flash-region placement/mapping.
- It has several calls to fn_flash_device_get_block_map_entry_by_index_803e2548.
- It should clarify the meaning of region state at 818ca920 and the block-map fields.
```

Provisional interpretation:

```text
Flash region placement / flash map construction helper candidate.
```

Do not rename until the full listing and decompiler output are pasted.

---

## 18. Repository placement and commit commands

Target repository path:

```text
~/tc7200u-research/records/reverse/
```

Windows download path requested:

```text
C:\Users\mgta29\Downloads\
```

WSL-visible download path:

```text
/mnt/c/Users/mgta29/Downloads/
```

Recommended commit message:

```text
reverse: document SPI flash device base vtable analysis
```

Commands are provided separately in the ChatGPT response so they can be copied directly.
