# 2026-06-24 — Ghidra Flash Region Placement, Partition Map, Region Tables Log

Project: `tc7200u-research`  
Target: Technicolor TC7200U / BCM3383 Stage1 image  
Program: `image.raw`  
Architecture context: `MIPS:BE:32:default`, Stage1 base `0x80004000`  
Main scope: flash-region placement after SPI flash/device-base/vtable work  
Primary functions: `803e5854`, `803e53d4`, `803e8d40`  
Primary RAM state: `818ca920..818caa9f`  
Primary static table: `8147a49c..8147a53b`

---

## 1. Session result summary

This pass completed the main cleanup for the flash-region placement layer following the prior SPI flash device/base/vtable analysis. The result is a clearer split between:

1. the **generic detected-device placement path** at `803e5854`, used for the memory-window style path;
2. the **SPI/NAND partition-map placement path** at `803e53d4`, used when SPI or NAND detection flags are set;
3. the **region work-entry builder** at `803e8d40`;
4. the compact final output table at `818ca920`;
5. the expanded working region table at `818ca998`;
6. the builtin fallback partition map at `8147a49c`.

The major correction from this session is that `818ca920` was initially not reachable in Ghidra because the RAM block did not exist. A new uninitialized RAM block was created for the flash-region state, after which the output and work tables were applied and the decompiler cleaned up substantially.

The second major correction is that the fallback map at `8147a49c` should be modeled as **8 real partition entries**, not 9. The would-be ninth slot at `8147a53c` is adjacent pointer/config data. The `803e53d4` loop may probe the would-be slot 8, but its size field is zero, so it is skipped.

The third major correction is that `803e57e0`, `803e5734`, and similar Ghidra-created inner functions in the `803e53d4`/`803e5854` range are not real functions. They are code chunks inside the parent function, caused by Ghidra function-boundary splitting. They must be deleted as function objects and kept only as labels or comments.

---

## 2. Export/source baseline used during this pass

Current loaded Ghidra export snapshots in the conversation:

```text
labels.json
  program:     image.raw
  exported_at: 20260624-010405

memoryblock.json
  generated_at: 2026-06-24T01:03:59
  block_count:   62
  language:      MIPS:BE:32:default
  image_base:    80004000

datatype.json
  exported_at: 2026-06-24T01:04:01.9831604
```

Important: these exports predate some live Ghidra changes made in this pass. The session findings below are based primarily on the current pasted Ghidra listings/decompiles after manual table/type changes.

---

## 3. Repository status check

The upstream GitHub repository was checked before giving repo-sensitive instructions.

Repository:

```text
https://github.com/mgta29/tc7200u-research
```

GitHub currently exposes the project as public, on branch `main`, with top-level folders including `records/`, `docs/`, `patches/`, `reverse/`, and `scripts/`. The README states that the repo preserves TC7200.U OpenWrt bring-up notes, logs, captures, snapshots, binary images, reverse output, and patch copies. It also explicitly says not to delete old logs or historical notes.

Practical effect for this log:

```text
- keep the new markdown under records/reverse/
- do not overwrite or delete older reverse logs
- use a dated filename
- commit and push only the new record file unless the user intentionally stages other changes
```

---

## 4. Memory block changes

### 4.1 New block created

A new uninitialized RAM block was created in Ghidra because `Go To -> 818ca920` initially failed with “No results”.

Memory Map entry:

```text
Name:        RAM_FLASH_REGION_STATE_818CA920
Start:       818ca920
End:         818caa9f
Length:      0x180
Permissions: read/write, not executable
Volatile:    no
Initialized: no / uninitialized
```

Purpose:

```text
818ca920..818ca997  final compact flash-region output table
818ca998..818caa87  expanded flash-region work table
818caa88..818caa9f  adjacent/extra flash runtime state area
```

### 4.2 Labels and datatypes in this block

```text
818ca920  g_flash_region_output_table_818CA920_candidate
          stage1_flash_region_output_entry_0c_candidate[10]

818ca998  g_flash_region_work_table_818CA998_candidate
          stage1_flash_region_work_entry_18_candidate[10]

818caa88  g_flash_extra_runtime_state_818CAA88_candidate
          undefined1 / raw for now
```

Do not extend either table past its confirmed end:

```text
Output table end: 818ca997
Work table end:   818caa87
```

---

## 5. Flash-region output table

### 5.1 Address and range

```text
Base:   818ca920
Type:   stage1_flash_region_output_entry_0c_candidate[10]
Size:   10 * 0x0c = 0x78
Range:  818ca920..818ca997
```

### 5.2 Datatype

Category suggestion:

```text
/tc7200u/common/flash
```

Structure:

```c
struct stage1_flash_region_output_entry_0c_candidate {
    uint32_t total_size_00;
    uint32_t usable_size_or_runtime_override_04_candidate;
    uint32_t block_count_08;
};
```

Reasoning:

```text
+0x00 receives work[i].total_size_00
+0x04 receives either work[i].usable_size_excluding_flagged_blocks_04_candidate
      or a nonzero runtime override for index 5 / 7
+0x08 receives work[i].block_count_08
```

### 5.3 Special output behavior

Output entries `[5]` and `[7]` are special:

```text
output[5].usable_size_or_runtime_override_04_candidate
  = fn_flash_permanent_nonvol_size_override_get_8014f078_candidate()
    if nonzero
  else work[5].usable_size_excluding_flagged_blocks_04_candidate

output[7].usable_size_or_runtime_override_04_candidate
  = fn_flash_dynamic_nonvol_size_override_get_8014f0c0_candidate()
    if nonzero
  else work[7].usable_size_excluding_flagged_blocks_04_candidate
```

This behavior appears in both region-placement paths:

```text
803e5854  memory-window detected-device placement path
803e53d4  SPI/NAND partition-map placement path
```

---

## 6. Flash-region work table

### 6.1 Address and range

```text
Base:   818ca998
Type:   stage1_flash_region_work_entry_18_candidate[10]
Size:   10 * 0x18 = 0xf0
Range:  818ca998..818caa87
```

### 6.2 Datatype

Category suggestion:

```text
/tc7200u/common/flash
```

Structure:

```c
struct stage1_flash_region_work_entry_18_candidate {
    uint32_t total_size_00;
    uint32_t usable_size_excluding_flagged_blocks_04_candidate;
    uint32_t block_count_08;
    stage1_flash_block_map_entry_10_candidate *first_block_entry_0c;
    stage1_flash_device_object_68_candidate *flash_device_10;
    char *region_name_14;
};
```

If `stage1_flash_device_object_68_candidate *` is unavailable in Ghidra, use:

```c
void *flash_device_10;
```

### 6.3 Field proof from `803e8d40`

`fn_flash_region_work_entry_build_803e8d40` proves the layout:

```text
+0x08 = block_count
+0x0c = first_block
+0x14 = region_name
+0x10 = first_block->flash_device_0c
+0x00 = sum of selected block_size_04 values
+0x04 = sum of block_size_04 values only for blocks where flash_device->vtable[+0x20] returns 0
```

Important correction:

```text
+0x10 is flash_device_10.
It is not last_or_limit_block_entry_10_candidate.
```

---

## 7. Region index map

Current confirmed work/output indexes:

```text
[0] Bootloader
[1] Image1
[2] Image2
[3] linux / partition-map path only, when populated
[4] linuxapps / partition-map path only, when populated
[5] Permanent NonVol / permnv
[6] dhtml / partition-map path only, when populated
[7] Dynamic NonVol / dynnv
[8] skipped in builtin fallback map because size == 0
[9] Global Flash, built separately outside the partition-map loop
```

For the `803e5854` memory-window path, the confirmed built records are:

```text
[0] Bootloader
[1] Image1
[2] Image2
[5] Permanent NonVol
[7] Dynamic NonVol
[9] Global Flash
```

For the `803e53d4` SPI/NAND partition-map path, entries `[0]..[8]` may be scanned, but only entries with nonzero size are built. In the builtin fallback map, `[0]..[7]` are real populated partition entries and `[8]` is skipped because the would-be size field is zero.

---

## 8. Builtin fallback partition map

### 8.1 Address and range

Final modeling:

```text
8147a49c  g_flash_builtin_partition_map_8147A49C_candidate
          stage1_flash_partition_map_entry_14_candidate[8]

Range:    8147a49c..8147a53b
```

Do not model `8147a53c` as entry `[8]`.

### 8.2 Datatype

Category suggestion:

```text
/tc7200u/common/flash
```

Structure:

```c
struct stage1_flash_partition_map_entry_14_candidate {
    char region_name_00[12];
    uint32_t region_size_0c;
    uint32_t region_start_offset_10;
};
```

### 8.3 Confirmed builtin entries

| Index | Address | Name | Size | Start offset | Notes |
|---:|---:|---|---:|---:|---|
| 0 | `8147a49c` | `bootloade` | `0x00010000` | `0x00000000` | builtin name is truncated to 9 chars plus NULs |
| 1 | `8147a4b0` | `image1` | `0x003e0000` | `0x00020000` | primary image region |
| 2 | `8147a4c4` | `image2` | `0x003f0000` | `0x00400000` | secondary image region |
| 3 | `8147a4d8` | `linux` | `0x00800000` | `0x00800000` | only used when loop sees nonzero size and offset fits |
| 4 | `8147a4ec` | `linuxapps` | `0x00800000` | `0x01000000` | may fall onto flash device 1 depending size/device layout |
| 5 | `8147a500` | `permnv` | `0x00010000` | `0x00010000` | output index 5 has override getter fallback behavior |
| 6 | `8147a514` | `dhtml` | `0x00800000` | `0x01800000` | partition-map path only |
| 7 | `8147a528` | `dynnv` | `0x00010000` | `0x007f0000` | output index 7 has override getter fallback behavior |

### 8.4 Adjacent data after builtin map

At:

```text
8147a53c  g_flash_partition_or_config_extra_8147A53C_candidate
          undefined4[5]
```

Observed words:

```text
8147a53c  0x8106f9d4
8147a540  0x8106fa0c
8147a544  0x00000000
8147a548  0x00000000
8147a54c  0x81071b0c
```

Reason not to model it as partition-map entry `[8]`:

```text
- first 8 bytes are pointer-looking words, not a 12-byte inline partition name
- the would-be region_size_0c at 8147a548 is zero
- 803e53d4 skips zero-sized entries
- many XREFs point into this area independently
```

Recommended table comment:

```text
8147a49c = builtin fallback partition map, real entries [0]..[7].
8147a53c = adjacent flash/config data. The partition loop can probe the
would-be slot 8 size at 8147a548, but it is zero, so slot 8 is skipped.
Do not model 8147a53c as a normal inline-name partition entry.
```

---

## 9. Global labels and config values

Apply or keep these labels:

```text
8147a450  g_flash_device0_8147A450_candidate
          stage1_flash_device_object_68_candidate * / void *

8147a454  g_flash_device1_8147A454_candidate
          stage1_flash_device_object_68_candidate * / void *

8147a45c  g_flash_rotated_block_map_8147A45C_candidate
          stage1_flash_block_map_entry_10_candidate *

8147a470  g_flash_bootloader_min_region_size_8147A470_candidate
          uint32_t

8147a474  g_flash_image1_min_region_size_8147A474_candidate
          uint32_t

8147a478  g_flash_image2_min_region_size_8147A478_candidate
          uint32_t

8147a484  g_flash_permanent_nonvol_min_region_size_8147A484_candidate
          uint32_t

8147a48c  g_flash_dynamic_nonvol_min_region_size_8147A48C_candidate
          uint32_t

8147a498  g_flash_spi_device0_detected_8147A498_candidate
          uint8_t

8147a499  g_flash_nand_detected_8147A499_candidate
          uint8_t

8147a49c  g_flash_builtin_partition_map_8147A49C_candidate
          stage1_flash_partition_map_entry_14_candidate[8]

8147a53c  g_flash_partition_or_config_extra_8147A53C_candidate
          undefined4[5]
```

Keep `_candidate` on globals and structs because exact vendor names are still not proven.

---

## 10. Function findings and final labels

### 10.1 `803e5854`

Final label:

```text
803e5854  fn_flash_region_place_detected_devices_803e5854
```

Signature:

```c
uint32_t fn_flash_region_place_detected_devices_803e5854(uint32_t boot_address)
```

Candidate suffix removed because:

```text
- function role is clear
- main table ownership is clear
- major side effects are known
- caller/callee relationship is known
- remaining uncertainty is mostly exact vendor naming and some config names
```

Behavior:

```text
- if SPI or NAND detection flag is set, delegates to 803e53d4
- for the memory-window path:
    - rejects flash sizes greater than 16 MiB
    - finds block-map entry matching boot_address
    - gathers enough contiguous blocks for Bootloader
    - handles 16 MiB rotated block-map case
    - computes Image1, Image2, Permanent NonVol, Dynamic NonVol, and Global Flash work records
    - emits compact final output table
    - returns 1 on success, 0 on failure
```

Important side effects:

```text
818ca998  work table populated
818ca920  compact output table emitted
8147a45c  optional rotated block map allocated and filled
```

Recommended plate comment:

```text
Plate comment @803e5854:
Flash region placement helper.

Called by {@symbol fn_flash_subsystem_detect_devices_and_place_regions_803e3230_candidate}
after flash device detection and validation.

Behavior:
  - if SPI or NAND detection flags are set, delegates to {@symbol fn_flash_region_place_spi_or_nand_devices_803e53d4}
  - for the memory-window flash path:
      - rejects flash sizes greater than 16 MiB
      - finds the flash block-map entry matching boot_address
      - gathers enough contiguous blocks for the Bootloader region
      - handles the 16 MiB alternate/rotated block-map case
      - builds working flash-region records at {@address 818ca998}
      - emits 10 compact output region descriptors to {@address 818ca920}
      - returns 1 on successful placement, 0 on failure

Tables:
  {@address 818ca920} = final compact output table:
    stage1_flash_region_output_entry_0c_candidate[10]

  {@address 818ca998} = working table:
    stage1_flash_region_work_entry_18_candidate[10]

Region index map:
  [0] Bootloader
  [1] Image1
  [2] Image2
  [3] reserved/unused in this path
  [4] reserved/unused in this path
  [5] Permanent NonVol
  [6] reserved/unused in this path
  [7] Dynamic NonVol
  [8] reserved/unused in this path
  [9] Global Flash

Special output behavior:
  - output[5].usable_size_or_runtime_override_04 uses
    {@symbol fn_flash_permanent_nonvol_size_override_get_8014f078_candidate}
    when nonzero, otherwise work[5].usable_size_excluding_flagged_blocks_04_candidate
  - output[7].usable_size_or_runtime_override_04 uses
    {@symbol fn_flash_dynamic_nonvol_size_override_get_8014f0c0_candidate}
    when nonzero, otherwise work[7].usable_size_excluding_flagged_blocks_04_candidate

Important:
  The memory-window path is clear enough to remove _candidate from this
  function name. Keep _candidate on region structs and config globals until
  SPI/NAND and table-management helpers are fully decoded.
```

### 10.2 `803e53d4`

Final label:

```text
803e53d4  fn_flash_region_place_spi_or_nand_devices_803e53d4
```

Signature:

```c
uint32_t fn_flash_region_place_spi_or_nand_devices_803e53d4(uint32_t boot_address)
```

Candidate suffix can be removed. The behavior is now clear enough: it is the partition-map-driven region placement path used by SPI/NAND detection.

Behavior:

```text
- queries/locates a partition map through 8014efb0
- if not found, checks an in-memory flash-map signature near computed high memory
- if the signature is invalid, falls back to builtin map at 8147a49c
- loops over candidate partition indexes 0..8
- skips index 9; Global Flash is built separately
- skips zero-sized entries
- maps region_start_offset_10 onto flash device 0 or flash device 1
- converts region_size_0c to block count through 803e53a8
- builds work table entries through 803e8d40
- emits final output table with the same special index 5 and 7 override logic
- returns 1 on success
```

Recommended plate comment:

```text
Plate comment @803e53d4:
SPI/NAND flash partition-map region placement.

Called by {@symbol fn_flash_region_place_detected_devices_803e5854}
when SPI or NAND flash detection flags are set.

Behavior:
  - resolves a partition map through {@symbol fn_flash_partition_map_lookup_8014efb0_candidate}
  - if no external/valid map is returned, checks an in-memory flash-map signature
  - if that signature is not valid, falls back to {@address 8147a49c}
  - scans partition-map candidate indexes 0..8
  - skips entries where region_size_0c is zero
  - maps each partition start offset to flash device 0 or flash device 1
  - converts partition size to block count through {@symbol fn_flash_count_blocks_for_region_size_803e53a8_candidate}
  - builds work-region records at {@address 818ca998}
  - builds Global Flash at work/output index 9
  - emits the compact output table at {@address 818ca920}
  - returns 1

Tables:
  {@address 8147a49c} = builtin fallback partition map:
    stage1_flash_partition_map_entry_14_candidate[8]

  {@address 8147a53c} = adjacent flash/config data.
    The partition loop can probe the would-be slot 8 size at {@address 8147a548},
    but it is zero, so slot 8 is skipped. Do not model {@address 8147a53c}
    as a normal inline-name partition entry.

  {@address 818ca998} = working region table:
    stage1_flash_region_work_entry_18_candidate[10]

  {@address 818ca920} = compact output region table:
    stage1_flash_region_output_entry_0c_candidate[10]

Special output behavior:
  output[5] uses {@symbol fn_flash_permanent_nonvol_size_override_get_8014f078_candidate}
  output[7] uses {@symbol fn_flash_dynamic_nonvol_size_override_get_8014f0c0_candidate}
  If override value is zero, the work-table usable-size value is used.
```

### 10.3 `803e8d40`

Final label:

```text
803e8d40  fn_flash_region_work_entry_build_803e8d40
```

Signature:

```c
void fn_flash_region_work_entry_build_803e8d40(
    stage1_flash_region_work_entry_18_candidate *out_region,
    stage1_flash_block_map_entry_10_candidate *first_block,
    uint32_t block_count,
    char *region_name)
```

Candidate suffix removed because behavior is fully understood.

Behavior:

```text
- writes block_count, first_block, region_name
- writes flash_device_10 from first_block->flash_device_0c
- computes total_size_00 as sum of block_size_04 over all selected blocks
- computes usable_size_excluding_flagged_blocks_04_candidate by calling flash_device vtable +0x20 per block
- if the predicate returns 0, that block contributes to usable size
```

Recommended plate comment:

```text
Plate comment @803e8d40:
Builds one flash-region working record.

Arguments:
  out_region  = destination work-entry record
  first_block = first flash block-map entry in the region
  block_count = number of contiguous block-map entries in this region
  region_name = diagnostic/name string for this region

Behavior:
  - stores block_count, first_block, region_name
  - stores flash_device_10 from first_block->flash_device_0c
  - sums every selected block's block_size_04 into total_size_00
  - calls flash-device vtable +0x20 with:
      flash_device, block_offset_08
    for each block
  - if that predicate returns 0, adds the block size to
    usable_size_excluding_flagged_blocks_04_candidate

Current interpretation:
  total_size_00 is the raw region size.
  usable_size_excluding_flagged_blocks_04_candidate excludes blocks reported by
  the flash-device predicate at vtable +0x20.

Called by:
  {@symbol fn_flash_region_place_detected_devices_803e5854}
  {@symbol fn_flash_region_place_spi_or_nand_devices_803e53d4}
```

Optional pre-comment at the indirect call inside `803e8d40`:

```text
Pre comment @803e8dc0:
Calls flash_device->vtable[+0x20](flash_device, block_offset_08).

Return low byte:
  0       = block contributes to usable_size_excluding_flagged_blocks_04_candidate
  nonzero = block is skipped/excluded from usable size

Exact predicate name is still provisional.
```

### 10.4 `803e53a8`

Next target label:

```text
803e53a8  fn_flash_count_blocks_for_region_size_803e53a8_candidate
```

Expected signature:

```c
uint32_t fn_flash_count_blocks_for_region_size_803e53a8_candidate(
    uint32_t region_size,
    stage1_flash_block_map_entry_10_candidate *first_block)
```

This helper is used by `803e53d4` to convert partition-map `region_size_0c` into a contiguous block count from the starting block.

Do not remove `_candidate` until the full helper is decompiled and verified.

### 10.5 `8014efb0`

Suggested label:

```text
8014efb0  fn_flash_partition_map_lookup_8014efb0_candidate
```

Initial signature:

```c
stage1_flash_partition_map_entry_14_candidate * fn_flash_partition_map_lookup_8014efb0_candidate(uint32_t boot_address)
```

Do not finalize until callers and return cases are checked.

### 10.6 Override getter helpers

Labels and signatures:

```text
8014f078  fn_flash_permanent_nonvol_size_override_get_8014f078_candidate
```

```c
uint32_t fn_flash_permanent_nonvol_size_override_get_8014f078_candidate(void)
```

```text
8014f0c0  fn_flash_dynamic_nonvol_size_override_get_8014f0c0_candidate
```

```c
uint32_t fn_flash_dynamic_nonvol_size_override_get_8014f0c0_candidate(void)
```

Keep `_candidate`; exact vendor-level meaning is still not fully proven.

---

## 11. Fake Ghidra inner functions to delete

The following apparent functions are not real standalone routines. They are chunks inside the parent flash placement functions and should be deleted as Ghidra function objects if present:

```text
Inside / around 803e5854:
  FUN_803e5cd0
  FUN_803e5d30
  FUN_803e5ddc
  FUN_803e60f4
  FUN_803e61a0
  FUN_803e61b4
  FUN_803e61c8
  FUN_803e61f0
  FUN_803e623c
  FUN_803e62e8

Inside / around 803e53d4:
  FUN_803e55bc
  FUN_803e5668
  FUN_803e5734
  FUN_803e57e0
```

Reason:

```text
- they use parent saved registers such as s0/s1/s2/s3/s4/s5
- they restore the parent stack frame
- they are not normal callable functions
- they appear because Ghidra split code chunks at jump targets
```

Action in Ghidra:

```text
Right-click fake function header -> Function -> Delete Function
```

This deletes only the function object, not the bytes.

Useful labels for code chunks, if wanted:

```text
803e5734  LAB_flash_spi_nand_emit_output_table_loop_803e5734
803e57e0  LAB_flash_spi_nand_copy_normal_usable_size_803e57e0
```

Do not create signatures for these labels.

---

## 12. Datatype summary

### 12.1 New or updated datatypes

```c
struct stage1_flash_region_output_entry_0c_candidate {
    uint32_t total_size_00;
    uint32_t usable_size_or_runtime_override_04_candidate;
    uint32_t block_count_08;
};
```

```c
struct stage1_flash_region_work_entry_18_candidate {
    uint32_t total_size_00;
    uint32_t usable_size_excluding_flagged_blocks_04_candidate;
    uint32_t block_count_08;
    stage1_flash_block_map_entry_10_candidate *first_block_entry_0c;
    stage1_flash_device_object_68_candidate *flash_device_10;
    char *region_name_14;
};
```

```c
struct stage1_flash_partition_map_entry_14_candidate {
    char region_name_00[12];
    uint32_t region_size_0c;
    uint32_t region_start_offset_10;
};
```

Optional, only if editing the flash-device vtable:

```c
uint32_t flash_device_block_exclude_predicate_fn_candidate(
    stage1_flash_device_object_68_candidate *flash_device,
    uint32_t block_offset)
```

Suggested vtable field:

```text
+0x20  flash_device_block_exclude_predicate_fn_candidate *  block_exclude_predicate_20_candidate
```

### 12.2 Datatype placement

Recommended category:

```text
/tc7200u/common/flash
```

If that category does not exist:

```text
Data Type Manager -> /tc7200u/common -> New Category -> flash
```

Use `stdint.h` exact-width types for all integer fields:

```text
uint8_t
uint16_t
uint32_t
```

Use volatile MMIO types only for hardware registers, not these RAM/static tables.

---

## 13. Current corrected model

### 13.1 Memory-window path model

```text
fn_flash_region_place_detected_devices_803e5854(boot_address)

if SPI/NAND detected:
    return fn_flash_region_place_spi_or_nand_devices_803e53d4(boot_address)

else:
    verify flash size <= 16 MiB
    find boot block by boot_address
    build work[0] Bootloader
    optionally rotate block map for 16 MiB nonzero boot offset case
    compute available regions
    build work[1] Image1
    build work[5] Permanent NonVol
    build work[2] Image2
    build work[7] Dynamic NonVol
    build work[9] Global Flash
    emit output[0..9]
    return 1 on success
```

### 13.2 SPI/NAND path model

```text
fn_flash_region_place_spi_or_nand_devices_803e53d4(boot_address)

partition_map = fn_flash_partition_map_lookup_8014efb0_candidate(boot_address)

if partition_map == NULL:
    if flash-map signature at computed high-memory table is valid:
        partition_map = computed_table + 4
    else:
        partition_map = g_flash_builtin_partition_map_8147A49C_candidate

for index in 0..8:
    if index == 9:
        skipped by code
    if partition_map[index].region_size_0c == 0:
        skip
    select flash device by region_start_offset_10 versus flash_device0->total_size_4c
    first_block = block at start offset / block size
    block_count = fn_flash_count_blocks_for_region_size_803e53a8_candidate(region_size, first_block)
    fn_flash_region_work_entry_build_803e8d40(&work[index], first_block, block_count, partition_map[index].region_name_00)

build work[9] Global Flash from device0 full block map
emit output[0..9]
return 1
```

---

## 14. Open questions / next targets

### Immediate next target

```text
803e53a8  fn_flash_count_blocks_for_region_size_803e53a8_candidate
```

Goal:

```text
Confirm how partition size is converted to block count.
Check whether it counts until >= size, exact-fit only, or includes partial final block.
```

### Follow-up target

```text
8014efb0  fn_flash_partition_map_lookup_8014efb0_candidate
```

Goal:

```text
Resolve external/valid partition-map lookup.
Determine whether boot_address is truly the only argument.
Find table source and signature validation flow.
```

### Table-management XREF cluster

Many XREFs point into `8147a53c` and nearby config data:

```text
803e6934
803e7230
803e7d74
803e7f20
803e7fa8
803e80f8
803e8a4c
803e9414
803e9504
803e9680
803e9d64
803eb33c
```

Goal:

```text
Decode adjacent config/pointer data after builtin partition map.
Do not merge it into the partition-map array yet.
```

---

## 15. Current Ghidra cleanup checklist

Already done in this pass:

```text
[x] Created RAM_FLASH_REGION_STATE_818CA920 block
[x] Applied g_flash_region_output_table_818CA920_candidate
[x] Applied g_flash_region_work_table_818CA998_candidate
[x] Corrected work-entry +0x10 to flash_device_10
[x] Created partition-map datatype
[x] Applied builtin fallback map at 8147a49c
[x] Corrected builtin map from [9] to [8]
[x] Identified 8147a53c as adjacent config, not normal map entry
[x] Dropped _candidate from 803e5854, 803e53d4, 803e8d40 where role is clear
[x] Identified bad inner Ghidra function splits
```

Still to do:

```text
[ ] Delete all fake inner function objects that still exist
[ ] Re-decompile 803e53d4 and 803e5854 after fake function deletion
[ ] Decode 803e53a8 block-count helper
[ ] Decode 8014efb0 partition-map lookup helper
[ ] Re-export labels.json, datatype.json, and memoryblock.json after current Ghidra state is stable
[ ] Commit the new reverse log to records/reverse/
```

---

## 16. Suggested git action

Filename for this record:

```text
2026-06-24-ghidra-flash-region-placement-log.md
```

Target repository path:

```text
records/reverse/2026-06-24-ghidra-flash-region-placement-log.md
```

Suggested commit message:

```text
reverse: document flash region placement analysis
```

Use this after placing the file in the repo:

```sh
cd ~/tc7200u-research; git status --short --branch; git add records/reverse/2026-06-24-ghidra-flash-region-placement-log.md; git diff --cached --name-status; git commit -m "reverse: document flash region placement analysis"; git push
```

Do not run broad `git add .` here because the working tree may contain unrelated generated artifacts, logs, or binary changes.

---

## 17. Resume point

Next Ghidra target:

```text
803e53a8
```

Expected label:

```text
fn_flash_count_blocks_for_region_size_803e53a8_candidate
```

Expected first-pass signature:

```c
uint32_t fn_flash_count_blocks_for_region_size_803e53a8_candidate(
    uint32_t region_size,
    stage1_flash_block_map_entry_10_candidate *first_block)
```

Paste the full decompile after applying the label/signature.
