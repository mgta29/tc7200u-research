# 2026-06-09 - Ghidra FPM allocator and packet data types

## Scope

This note records the current Ghidra Structure Editor layout for the TC7200U / BCM3383 FPM allocator and packet related data types seen in `image.raw`. These names are reverse-engineering working names, not vendor-confirmed headers.

Captured data types:

- `tc7200_fpm_allocator`
- `tc7200_fpm_packet_allocator`
- `tc7200_fpm_packet_header`
- `tc7200_fpm_packet_inner_header`

## Ghidra context

- Program: `image.raw`
- Structure category: `image.raw/`
- Intended architecture context: MIPS big-endian 32-bit firmware image
- Pointer size: 32-bit
- Structure alignment shown by editor: `0x1`
- These structures should be applied carefully and rechecked after decompile refresh.

## Relationship summary

```text
tc7200_fpm_packet_allocator
+0x20 main_fpm_allocator_ptr -> tc7200_fpm_allocator

tc7200_fpm_packet_header
+0x04 inner_header -> tc7200_fpm_packet_inner_header
+0x20 embedded_inner -> inline tc7200_fpm_packet_inner_header
```

Important point: the packet header contains both an inner-header pointer and an embedded inner-header object. Do not assume they are always the same object until xrefs confirm it.

## Structure: tc7200_fpm_allocator

Observed size: `0x20048` bytes.

This appears to be the main FPM allocator object. It contains allocator configuration, an embedded flag or log object, pool sizing metadata, a pool class lookup pointer, and a large token high-bits table.

| Offset | Size | Type | Field | Current meaning |
|---:|---:|---|---|---|
| `0x00` | `0x04` | `uint32_t` | `fpm_hw_base_kseg1` | FPM hardware or MMIO base, likely KSEG1 style address |
| `0x04` | `0x04` | `uint32_t` | `board_or_buffer_class` | Board, buffer class, or allocator class selector |
| `0x08` | `0x04` | `uint32_t` | `largest_default_pool_size` | Largest/default pool size value used during allocator setup |
| `0x0c` | `0x04` | `uint32_t` | `fpm_backing_base_aligned` | Aligned backing memory or arena base |
| `0x10` | `0x18` | `uint8_t[24]` | `embedded_flag_log_object` | Inline 24 byte flag/log style helper object |
| `0x28` | `0x01` | `uint8_t` | `pool_size_shift_bits` | Shift or count field used for pool size classification |
| `0x29` | `0x03` | `uint8_t[3]` | `pad_29` | Padding to next 32-bit field |
| `0x2c` | `0x04` | `uint32_t` | `pool_class_lookup_table_ptr` | Pointer/address to pool class lookup table |
| `0x30` | `0x04` | `uint32_t` | `max_largest_request_state` | State or threshold for largest request handling |
| `0x34` | `0x04` | `uint32_t` | `fpm_extra_base_offset_or_headroom_candidate` | Extra base or headroom offset used by packet paths |
| `0x38` | `0x10` | `uint32_t[4]` | `pool_size_table` | Four entry pool size table |
| `0x48` | `0x20000` | `uint32_t[32768]` | `token_highbits_table` | Large token indexed table, likely address high bits or token metadata |

Notes:

- `token_highbits_table` is not padding. Its size exactly accounts for the large tail of the allocator object.
- `fpm_extra_base_offset_or_headroom_candidate` should stay marked as candidate until stores and loads confirm the exact meaning.
- `embedded_flag_log_object` appears again in the packet allocator, so it is probably a reusable 24 byte helper subobject.

C style reconstruction:

```c
typedef struct tc7200_fpm_allocator {
    uint32_t fpm_hw_base_kseg1;                         /* +0x00 */
    uint32_t board_or_buffer_class;                     /* +0x04 */
    uint32_t largest_default_pool_size;                 /* +0x08 */
    uint32_t fpm_backing_base_aligned;                  /* +0x0c */
    uint8_t  embedded_flag_log_object[0x18];            /* +0x10 */
    uint8_t  pool_size_shift_bits;                      /* +0x28 */
    uint8_t  pad_29[3];                                 /* +0x29 */
    uint32_t pool_class_lookup_table_ptr;               /* +0x2c */
    uint32_t max_largest_request_state;                 /* +0x30 */
    uint32_t fpm_extra_base_offset_or_headroom_candidate;/* +0x34 */
    uint32_t pool_size_table[4];                        /* +0x38 */
    uint32_t token_highbits_table[32768];               /* +0x48 */
} tc7200_fpm_allocator;                                 /* size 0x20048 */
```

## Structure: tc7200_fpm_packet_allocator

Observed size: `0x24` bytes.

This appears to be a secondary packet allocator wrapper. It stores packet header arena parameters and points back to the main FPM allocator object.

| Offset | Size | Type | Field | Current meaning |
|---:|---:|---|---|---|
| `0x00` | `0x18` | `uint8_t[24]` | `embedded_flag_log_object` | Same 24 byte flag/log helper pattern as main allocator |
| `0x18` | `0x04` | `uint32_t` | `packet_header_slot_size` | Size or stride of packet header slots |
| `0x1c` | `0x04` | `uint32_t` | `packet_header_arena_aligned` | Aligned packet header arena base |
| `0x20` | `0x04` | `uint32_t` | `main_fpm_allocator_ptr` | Pointer/address of `tc7200_fpm_allocator` |

C style reconstruction:

```c
typedef struct tc7200_fpm_packet_allocator {
    uint8_t  embedded_flag_log_object[0x18]; /* +0x00 */
    uint32_t packet_header_slot_size;        /* +0x18 */
    uint32_t packet_header_arena_aligned;    /* +0x1c */
    uint32_t main_fpm_allocator_ptr;         /* +0x20 */
} tc7200_fpm_packet_allocator;               /* size 0x24 */
```

## Structure: tc7200_fpm_packet_header

Observed size: `0xe0` bytes.

This appears to be the outer packet header or packet control object. It stores the free callback at offset zero, an inner header pointer, list or ownership state, an embedded inner header at `+0x20`, and an unmapped tail region.

| Offset | Size | Type | Field | Current meaning |
|---:|---:|---|---|---|
| `0x00` | `0x04` | `void *` | `free_callback` | Callback stored at packet header start and used by packet free/release path |
| `0x04` | `0x04` | `tc7200_fpm_packet_inner_header *` | `inner_header` | Pointer to active inner packet descriptor |
| `0x08` | `0x04` | `void *` | `list_or_inner_ptr_a` | List link or alternate inner pointer |
| `0x0c` | `0x04` | `uint32_t` | `active_or_refcount` | Active marker, reference count, or ownership count |
| `0x10` | `0x10` | `uint8_t[16]` | `unknown_10` | Unmapped middle region |
| `0x20` | `0x30` | `tc7200_fpm_packet_inner_header` | `embedded_inner` | Inline inner packet descriptor |
| `0x50` | `0x90` | `uint8_t[144]` | `unknown_50` | Unmapped tail region |

Notes:

- Earlier packet allocation work indicates the free callback is written at `packet_header + 0x00`.
- The `inner_header` pointer may point to `embedded_inner`, but this should be confirmed per path.
- Keep `unknown_50` as a byte array until xrefs identify more subfields.

C style reconstruction:

```c
typedef struct tc7200_fpm_packet_header {
    void *free_callback;                                   /* +0x00 */
    struct tc7200_fpm_packet_inner_header *inner_header;    /* +0x04 */
    void *list_or_inner_ptr_a;                             /* +0x08 */
    uint32_t active_or_refcount;                           /* +0x0c */
    uint8_t unknown_10[0x10];                              /* +0x10 */
    struct tc7200_fpm_packet_inner_header embedded_inner;   /* +0x20 */
    uint8_t unknown_50[0x90];                              /* +0x50 */
} tc7200_fpm_packet_header;                                /* size 0xe0 */
```

## Structure: tc7200_fpm_packet_inner_header

Observed size: `0x30` bytes.

This appears to be the inner packet descriptor. It stores the payload/data address, requested payload length, a pointer or list field, flags, and a saved FPM extra-base or headroom offset.

| Offset | Size | Type | Field | Current meaning |
|---:|---:|---|---|---|
| `0x00` | `0x04` | `uint32_t` | `data_addr` | Data or payload address. Kept as integer because it may be bus/token derived |
| `0x04` | `0x04` | `uint32_t` | `requested_payload_len` | Requested payload length or allocation size |
| `0x08` | `0x10` | `uint8_t[16]` | `unknown_08` | Unmapped 16 byte region |
| `0x18` | `0x04` | `void *` | `ptr_or_list_18` | Pointer or list linkage |
| `0x1c` | `0x04` | `uint8_t[4]` | `unknown_1c` | Unmapped 4 byte region |
| `0x20` | `0x02` | `uint16_t` | `flags_20` | 16-bit flags field |
| `0x22` | `0x0a` | `uint8_t[10]` | `unknown_22` | Unmapped 10 byte region |
| `0x2c` | `0x04` | `uint32_t` | `fpm_extra_base_offset_saved` | Saved extra base/headroom offset copied from allocator state |

Notes:

- `data_addr` should remain `uint32_t` for now, not `void *`, because FPM values may be physical, bus visible, token derived, or masked addresses.
- `requested_payload_len` should be compared with size arguments in allocation functions.
- `flags_20` is probably a bitfield, but individual bit meanings are not yet confirmed.
- `fpm_extra_base_offset_saved` matches the allocator-side extra base/headroom concept and should be watched in alloc/free paths.

C style reconstruction:

```c
typedef struct tc7200_fpm_packet_inner_header {
    uint32_t data_addr;                       /* +0x00 */
    uint32_t requested_payload_len;           /* +0x04 */
    uint8_t  unknown_08[0x10];                /* +0x08 */
    void    *ptr_or_list_18;                  /* +0x18 */
    uint8_t  unknown_1c[4];                   /* +0x1c */
    uint16_t flags_20;                        /* +0x20 */
    uint8_t  unknown_22[0x0a];                /* +0x22 */
    uint32_t fpm_extra_base_offset_saved;     /* +0x2c */
} tc7200_fpm_packet_inner_header;             /* size 0x30 */
```

## Suggested Ghidra use

1. Apply `tc7200_fpm_packet_allocator *` to the secondary packet allocator object returned by the packet allocator get/init helper.
2. Cast `main_fpm_allocator_ptr` as `tc7200_fpm_allocator *`.
3. Apply `tc7200_fpm_packet_header *` to packet header objects returned by packet allocation functions.
4. Cast `packet_header->inner_header` as `tc7200_fpm_packet_inner_header *`.
5. Treat `packet_header->embedded_inner` as an inline `tc7200_fpm_packet_inner_header`.
6. Refresh the decompiler after applying each structure so raw offsets become field names.
7. Do not rename candidate fields until load/store xrefs confirm the exact role.

## High-priority checks next

- Xrefs to `main_fpm_allocator_ptr + 0x34` and `inner_header + 0x2c`.
- Stores to `packet_header + 0x00` to confirm all free callback writers.
- Writes to `flags_20` and tests against constants.
- Use of `token_highbits_table[index]` to determine whether entries are address high bits, token metadata, or both.
- Whether `inner_header` normally points to `embedded_inner` or to a separate header arena object.

## Current conclusion

The Ghidra data types are now coherent enough to use as working structures for the FPM allocator, packet allocator, packet header, and inner packet descriptor paths. The most important confirmed modeling decision is to preserve the large `token_highbits_table` and the dual inner-header representation in `tc7200_fpm_packet_header`.
