# FPM allocator caller chain and derived GMAC MBDMA values

## Scope

This note records additive reverse-engineering findings for the TC7200.U / BCM3383 DMA/FPM allocator path and its relationship to GMAC MBDMA global initialization. Preserve old logs and notes. Do not delete or overwrite prior evidence.

## Confirmed direct caller chain

The direct JAL search for `fn_dma_fpm_driver_hw_init_8009d0a0_candidate` used byte pattern:

```text
0C 02 74 28
```

Search result:

```text
8009f6cc -> jal fn_dma_fpm_driver_hw_init_8009d0a0_candidate
```

The function containing this call was repaired from a bad Ghidra `CALL_TERMINATOR` split after `fn_dma_addr_alloc_core`. The missing bytes at `8009f6c4` decode as:

```text
8009f6c4  move  a0,v0
8009f6c8  move  a1,s0
8009f6cc  jal   fn_dma_fpm_driver_hw_init_8009d0a0_candidate
8009f6d0  move  a2,s1
8009f6d4  lw    ra,0x8(sp)
8009f6d8  lw    s1,0x4(sp)
8009f6dc  lw    s0,0x0(sp)
8009f6e0  jr    ra
8009f6e4  addiu sp,sp,0x10
```

Confirmed wrapper:

```text
fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate
```

Wrapper behavior:

```text
allocator_object = fn_dma_addr_alloc_core(param_1, param_2, param_3, param_4)
fn_dma_fpm_driver_hw_init_8009d0a0_candidate(allocator_object, param_1, param_2, param_4)
```

## Confirmed higher-level caller

`fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate` has an XREF from:

```text
FUN_80143088:801431d4
```

The repaired decompile shows:

```text
fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate(0x100, 0xb2200000, puVar5, param_4)
```

Therefore the exact FPM init arguments are now known:

```text
requested_fpm_buffer_size = 0x100
fpm_hw_regs_base          = 0xb2200000
fpm_hw_phys_base          = 0x12200000
allocator_object          = 0x81848740
```

Suggested caller label:

```text
FUN_80143088 -> fn_platform_or_board_fpm_driver_init_80143088_candidate
```

## Confirmed FPM driver HW init function

Function:

```text
fn_dma_fpm_driver_hw_init_8009d0a0_candidate
```

Correct signature after Ghidra fix:

```text
undefined4 fn_dma_fpm_driver_hw_init_8009d0a0_candidate(int allocator_object, uint requested_fpm_buffer_size, undefined4 fpm_hw_regs_base, undefined *arg3)
```

Role:

```text
FPM hardware allocator init + DDR backing allocation + pool lookup-table builder
```

It sets the allocator object fields later consumed by GMAC MBDMA global init:

```text
allocator +0x00 = fpm_hw_regs_base
allocator +0x04 = encoded FPM buffer-size class
allocator +0x08 = requested_fpm_buffer_size
allocator +0x0c = 256-byte-aligned FPM DDR backing base
allocator +0x28 = computed size shift bits
allocator +0x2c = allocated pool lookup table
allocator +0x30 = largest/default pool size
```

## Confirmed buffer-size class mapping

The function maps `requested_fpm_buffer_size` as:

```text
0x100 -> class 7
0x200 -> class 0
0x400 -> class 2
0x800 -> class 6
other -> invalid buffer size and return 0
```

For this board path:

```text
requested_fpm_buffer_size = 0x100
allocator +0x04 = 7
```

The class is written into FPM hardware register field:

```text
fpm_hw_regs_base + 0x40 bits 26:24
```

## Confirmed FPM DDR backing memory allocation

The function allocates FPM backing memory with:

```text
allocation_length = requested_fpm_buffer_size * 0x8000 + 0x100
```

For this board path:

```text
allocation_length = 0x100 * 0x8000 + 0x100 = 0x00800100
```

If allocation succeeds:

```text
allocator +0x0c = (allocated_ptr + 0xff) & 0xffffff00
fpm_hw_regs_base +0x44 = (allocated_ptr + 0xff) & 0x1fffff00
```

So:

```text
allocator +0x0c = aligned FPM DDR backing base
0xb2200044 = aligned backing base masked for HW
```

This field later feeds GMAC MBDMA:

```text
GENET_MBDMA_GLOBAL_12c00010 = allocator[+0x0c] & 0x1fffffff
```

Therefore `0x12c00010` is the aligned FPM DDR backing base, not the allocator object pointer and not a normal descriptor-ring pointer.

## Confirmed default pool-size table

Address:

```text
0x8146ff54
```

Label:

```text
g_dma_fpm_default_pool_sizes_or_limits_8146ff54_candidate
```

Confirmed DWORD values:

```text
0x8146ff54 = 0x00000800
0x8146ff58 = 0x00000400
0x8146ff5c = 0x00000200
0x8146ff60 = 0x00000100
```

These four values are copied into allocator object fields:

```text
allocator +0x38 = 0x800
allocator +0x3c = 0x400
allocator +0x40 = 0x200
allocator +0x44 = 0x100
```

## Derived size shift and lookup map

With pool sizes:

```text
0x800, 0x400, 0x200, 0x100
```

the computed shift is:

```text
size_shift_bits = 8
```

Largest pool size:

```text
allocator +0x30 = 0x800
```

Lookup length:

```text
lookup_len = 0x800 >> 8 = 8
```

Pool class map:

```text
class(0x100) = 3
class(0x200) = 2
class(0x400) = 1
class(0x800) = 0
```

This lookup table is used by:

```text
fn_dma_get_hw_alloc_free_addr_by_pool_size_8009de50_candidate
```

Formula:

```text
hw_alloc_free_addr = allocator[+0x00] + 0x200 + class(pool_size) * 8
```

With `allocator[+0x00] = 0xb2200000`, the KSEG1 values are:

```text
size 0x100 -> 0xb2200218
size 0x200 -> 0xb2200210
size 0x400 -> 0xb2200208
size 0x800 -> 0xb2200200
```

After GMAC MBDMA masking with `0x1fffffff`, the physical/register-view values are:

```text
size 0x100 -> 0x12200218
size 0x200 -> 0x12200210
size 0x400 -> 0x12200208
size 0x800 -> 0x12200200
```

## Final high-confidence GMAC MBDMA derived values

In `fn_enet_gmac_mbdma_global_init`, the sized wrapper calls now resolve to high-confidence constants:

```text
GENET_MBDMA_GLOBAL_12c0004c = 0x12200218
GENET_MBDMA_GLOBAL_12c00050 = 0x12200210
GENET_MBDMA_GLOBAL_12c00054 = 0x12200208
GENET_MBDMA_GLOBAL_12c00058 = 0x12200200
GENET_MBDMA_GLOBAL_12c00008 = 0x12200200
```

The remaining runtime-dependent value is:

```text
GENET_MBDMA_GLOBAL_12c00010 = aligned_fpm_ddr_backing_base & 0x1fffffff
```

## Other important GMAC MBDMA register writes

Previously confirmed in `fn_enet_gmac_mbdma_global_init`:

```text
0x12c00004 = (old & 0xffffe000) | 0x9010
0x12c0000c = (old_or_unaff_s3_derived & 0xff7ff000) | 0x0c41
0x12c00044 = 0x02020202
0x12c00048 = 0x0000000f
```

Per-core channel setup remains:

```text
core0 TX-like control: 0x12c00100, final low bits | 5
core0 TX-like base/size: 0x12c00104 = 0x13601c10
core0 RX-like control: 0x12c00140, sets 0x200, final low bits | 5
core0 RX-like base/size: 0x12c00144 = 0x13601c10
core1 TX-like control: 0x12c00120, final low bits | 5
core1 TX-like base/size: 0x12c00124 = 0x13601c10
core1 RX-like control: 0x12c00180, sets 0x200, final low bits | 5
core1 RX-like base/size: 0x12c00184 = 0x13601c10
```

Keep TX/RX direction as `_candidate` until confirmed by register documentation or runtime behavior.

## OpenWrt implication

The vendor path requires FPM allocator hardware init before or alongside GMAC MBDMA init:

```text
FPM HW base = 0xb2200000 / 0x12200000
FPM backing memory length = 0x00800100
FPM backing base written to allocator +0x0c and HW +0x44
Pool lookup table built from 0x800, 0x400, 0x200, 0x100
GMAC MBDMA receives FPM HW alloc/free addresses at 0x12c0004c/50/54/58/08
```

If OpenWrt only initializes GENET DMA rings and does not reproduce the FPM HW allocator setup, descriptor/token consumption can fail even when link and GMAC probe appear functional.

## Highest-value OpenWrt devmem compare list

```text
0x12200040 FPM buffer-size class field
0x12200044 FPM aligned DDR backing base masked with 0x1fffff00
0x12200200 FPM HW alloc/free address for class 0
0x12200208 FPM HW alloc/free address for class 1
0x12200210 FPM HW alloc/free address for class 2
0x12200218 FPM HW alloc/free address for class 3
0x12c00008 expected 0x12200200
0x12c00010 expected aligned_fpm_ddr_backing_base & 0x1fffffff
0x12c0004c expected 0x12200218
0x12c00050 expected 0x12200210
0x12c00054 expected 0x12200208
0x12c00058 expected 0x12200200
0x12c00004 token control expected (old & 0xffffe000) | 0x9010
0x12c00044 expected 0x02020202
0x12c00048 expected 0x0000000f
```

## Ghidra repair notes

Bad flow splits were caused by callees incorrectly marked or treated as no-return / call terminator. Known repair cases:

```text
fn_dma_addr_alloc_core must return
FUN_804ec310 must return
FUN_8002a034 must return
fn_obj_get_flagged_value_or_fallback must return
```

When a tail after a call appears as `??`, do not create a new function. Clear the bad no-return or flow override, then disassemble the tail bytes with `D`.

## Next reverse target

Inspect:

```text
FUN_8002a4f8
```

It is called immediately after FPM driver init with the same key values:

```text
FUN_8002a4f8(0x100, 0xb2200000, puVar5, param_4)
```

Likely role: next FPM token/allocator setup stage after FPM hardware base and backing memory are initialized.
