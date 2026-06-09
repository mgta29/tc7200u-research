# TC7200U Ghidra ENET/GENET consolidated summary addendum - 2026-06-08

## Scope

This is an additive update to:

- `2026-06-08-ghidra-enet-genet-consolidated-summary.md`

The older consolidated note is preserved unchanged. This addendum records later same-day findings that refine or supersede specific parts of that summary.

New source notes folded into this addendum:

- `2026-06-08-gmac-ghidra-findings.md`
- `2026-06-08-enet-gmac-step1-mdio-profile-findings.md`
- `2026-06-08-ghidra-dma-fpm-allocator-field-search.md`
- `2026-06-08-140718-ghidra-fpm-dma-allocator-findings.md`
- `2026-06-08-ghidra-mbdma-static-dma-findings.md`

## Step2 correction

The older consolidated summary should no longer be treated as authoritative for the exact bit behavior of `fn_enet_gmac_init_step2`.

Preferred current interpretation:

- `fn_enet_gmac_init_step2(param_1)`
  - if `param_1 == 0`, sets bits `0x1` and `0x2` in `GENET_REG_12c00070`
  - always sets bits `0x1000` and `0x2000` in `GENET_REG_12c00070`

Related inverse helper:

- `fn_enet_gmac_disable_step2(param_1)`
  - if `param_1 == 0`, clears bits `0x2` and `0x1`
  - always clears bits `0x2000` and `0x1000`

Operational reading:

- `step2` is now best understood as a small enable/disable bit sequencer for `GENET_REG_12c00070`
- the earlier `0x00030000` interpretation in the preserved consolidated note is stale and should be treated as superseded by this addendum

## Step1 correction

`fn_enet_gmac_init_step1` is not the full GMAC core init body.

Best current interpretation:

- `fn_enet_gmac_init_step1`
  - wrapper only
  - calls `fn_enet_gmac_profile_select_once_14e0_candidate`
  - does not directly touch `0x12c0xxxx` GENET MMIO in the inspected body

Best current interpretation of the one-time helper:

- `fn_enet_gmac_profile_select_once_14e0_candidate`
  - checks one-time latch `DAT_81479f50`
  - updates ENET/profile-control field in the `0x14e0xxxx` region
  - applies `value = value & 0xfffff3ff | 0x400`
  - then calls no-return `FUN_808ff3f8(2)` on first-run path

Implication:

- step1 is a board/profile gate
- it is pre-GENET setup, not the main `0x12c00000` bring-up body

## Static DMA/FPM allocator update

This is the main missing piece that the older consolidated note did not capture.

Confirmed current interpretation:

- `fn_dma_addr_alloc_core @ 0x8002a798`
  - lazy one-time initializer
  - returns fixed cached KSEG0 static DMA buffer base `0x81848740`
  - does not behave like a normal bump allocator in the inspected path

Ready flag:

- `DAT_81848738`
  - best current meaning: `g_dma_static_buf_ready`

GMAC/MBDMA caller behavior:

- callers mask the returned KSEG0 address with `0x1fffffff`
- this yields DMA-visible physical address `0x01848740`
- this masked address is the one relevant to GENET/MBDMA register programming

Practical conclusion:

- the OEM GMAC/MBDMA path is using a fixed static DMA area
- the important address for hardware-side reasoning is `0x01848740`, not the cached KSEG0 alias `0x81848740`

## Allocator object layout and unresolved field

Confirmed allocator object base:

- `0x81848740`

High-value fields confirmed so far:

- `+0x00` hardware/FPM base or token-path pointer field
- `+0x08` initialized size/count field, seen as `0x800`
- `+0x0c` backing/base address field
- `+0x10` embedded control/object used by flag/value helpers
- `+0x34` allocator offset/limit-related field
- `+0x48` high-address-bit table base

Critical unresolved item:

- `0x8184874c` / allocator `+0x0c`
  - many consumers confirmed
  - nonzero writer still not found

Confirmed initializer boundary:

- `FUN_8009cf58`
  - initializes allocator header
  - sets allocator `+0x0c = 0`
  - is only a zero-init for that field, not the missing backing-base writer

Current implication:

- token-to-buffer and buffer-to-token translation logic is understood well enough to know what `+0x0c` means
- the actual runtime source of its nonzero value remains unresolved

## GMAC/MBDMA interpretation refinement

The older consolidated summary was correct that `fn_enet_gmac_mbdma_global_init` is a real GENET/MBDMA setup path. The new allocator notes refine that conclusion:

- DMA address programming in this path is tied to the fixed static DMA object returned by `fn_dma_addr_alloc_core`
- the masked physical result `0x01848740` is the hardware-facing base that matters for GENET/MBDMA register analysis

Still unresolved:

- source of the hidden control/template value flowing into `GENET_MBDMA_GLOBAL_CTRL_12c0000c`
- writer for allocator `+0x0c`

## Updated reverse conclusion

Preserved from the older summary and still high-confidence:

- GENET main MMIO window is `0x12c00000`
- dual MDIO windows are `0x12c00600` and `0x12c02600`
- `fn_enet_probe_mac_phy_id` remains the correct top-level probe/selection path
- `fn_enet_gmac_mbdma_global_init` remains the correct GMAC/MBDMA global register setup path

Updated by this addendum:

- `fn_enet_gmac_init_step1` is only a one-time profile-select wrapper
- `fn_enet_gmac_init_step2` is an enable/disable bit sequencer for `GENET_REG_12c00070`
- the GMAC/MBDMA path uses a fixed static DMA area rooted at `0x81848740`, masked to physical `0x01848740`
- allocator backing/base field `0x8184874c` is still a live unresolved reverse target

## Best current next targets

Highest-value next targets after this addendum:

- nonzero writer for allocator `+0x0c` / `0x8184874c`
- callers of `fn_dma_addr_alloc_wrapper_a`
- callers of `fn_dma_addr_alloc_wrapper_sized`
- source of the preserved-register control value that reaches `GENET_MBDMA_GLOBAL_CTRL_12c0000c`
- full body around the real post-profile GMAC/UNIMAC/MBDMA bring-up path after step1/step2

## Preservation

Created as a new dated reverse note. The older consolidated summary was not edited or deleted.

## 2026-06-08 refresh after full reverse reread

This section was added after rereading the full reverse-note set under:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\notes\reverse`

Additional source notes folded into this refresh:

- `2026-06-08-192902-dma-fpm-mbdma-allocator-findings.md`
- `2026-06-08-enet-gmac-mbdma-global-init-register-labeling.md`
- `2026-06-08-enet-wrapper-flow-repair-803ad8a4.md`
- `2026-06-08-ghidra-dma-fpm-allocator-field-search.md`

### MBDMA wrapper correction

Earlier shorthand around the MBDMA path was too loose. The current best interpretation is:

- `fn_dma_addr_alloc_core`
  - returns allocator object base `0x81848740`
- `fn_dma_addr_alloc_wrapper_a`
  - does not return the allocator object address unchanged
  - calls `fn_dma_translate_or_get_flag2_value(core_base, original_param_1, original_param_2)`
- therefore `0x12c00010` is not simply the static object base masked to physical
- when allocator field `+0x0c` is configured, `0x12c00010` is best read as:
  - translated backing-base-derived address
  - effectively `allocator_backing_base & 0x1fffffff` for the `(0,0)` call shape seen in the GMAC/MBDMA init path

### Sized-wrapper correction

The sized MBDMA writes are now better understood:

- `0x12c0004c`
- `0x12c00050`
- `0x12c00054`
- `0x12c00058`
- `0x12c00008`

These are not best described as generic data-buffer allocations. Current interpretation:

- they are pool-class HW alloc/free control addresses derived from allocator object state
- derivation uses allocator fields at least equivalent to:
  - `+0x00`
  - `+0x28`
  - `+0x2c`
- helper string evidence includes:
  - `GetFpmHwAllocDeallocAddress`
  - `fpmPoolSize:`
  - `FPM_HW_Alloc/Free_Address:`

Operational implication:

- `0x12c00058` and `0x12c00008` should normally match because both are sourced from size `0x800`, unless allocator state advances between calls

### Additional high-value MBDMA control values

Later notes added concrete values that should be preserved in the current truth set:

- `0x12c00004 = (old & 0xffffe000) | 0x9010`
- `0x12c00044 = 0x02020202`
- `0x12c00048 = 0x0000000f`
- `0x12c0000c` final low field includes `0x0c41` after an earlier `| 0x800000`
- `0x12c00104 = 0x13601c10`
- `0x12c00124 = 0x13601c10`
- `0x12c00144 = 0x13601c10`
- `0x12c00184 = 0x13601c10`

Core/interface control clusters remain direction-labeled only as candidates:

- core/interface 0:
  - `0x12c00100`
  - `0x12c00140`
- core/interface nonzero:
  - `0x12c00120`
  - `0x12c00180`

### ENET wrapper flow repair

Another repaired caller-side wrapper now matters for the higher-level init picture:

- around `0x803ad8a4`

Current interpreted flow after Ghidra repair:

- zero/init helper likely called with `(0x81a8dc00, 0, 0xb8)`
- one-time latch checked near `DAT_81479f81`
- log `Enet Starting GMAC Init..!`
- save/clear CP0 status bits
- call precheck/status helper
- call GMAC `step1`
- call GMAC `step2`
- optional helper call near `0x803a8774`
- delay/yield with `a0 = 3`

Implication:

- there is a real higher-level ENET init wrapper above the step1/step2 helpers
- it is a useful runtime tracing point for OpenWrt comparison, even though the full preserved-register context is still unresolved

### Still unresolved after full reread

The main unresolved items did not change:

- nonzero writer for allocator `+0x0c` / `0x8184874c`
- exact source of preserved-register control template that reaches `0x12c0000c`
- final semantic meaning of the `0x14e0xxxx` profile/control block
- confirmed TX/RX direction and field meaning for `0x12c00100/120/140/180`

## 2026-06-08 control pass: caller-chain and derived-value closure

This section was added after a second full reread. It folds in the newer allocator/caller-chain notes:

- `2026-06-08-192902-dma-fpm-mbdma-allocator-findings.md`
- `2026-06-08-201531-fpm-mbdma-caller-chain-and-derived-values.md`

### FPM caller-chain closure

The allocator path is now materially better understood.

Confirmed wrapper:

- `fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate`

Confirmed direct call shape:

- `allocator_object = fn_dma_addr_alloc_core(...)`
- `fn_dma_fpm_driver_hw_init_8009d0a0_candidate(allocator_object, param_1, param_2, param_4)`

Confirmed higher-level caller:

- `FUN_80143088:801431d4`

Observed board path:

- `fn_dma_fpm_driver_hw_init_wrapper_8009f6a8_candidate(0x100, 0xb2200000, puVar5, param_4)`

Therefore the board-specific FPM init inputs are now high confidence:

- requested FPM buffer size: `0x100`
- FPM HW base KSEG1: `0xb2200000`
- FPM HW physical/register view: `0x12200000`
- allocator object base: `0x81848740`

### Allocator field meaning is now stronger

The earlier summary treated allocator `+0x0c` as unresolved in origin. That is no longer true at the conceptual level.

Current best interpretation:

- `allocator +0x00 = 0xb2200000`
- `allocator +0x04 = encoded FPM buffer-size class`
- `allocator +0x08 = requested_fpm_buffer_size`
- `allocator +0x0c = 256-byte-aligned FPM DDR backing base`
- `allocator +0x28 = computed size shift bits`
- `allocator +0x2c = allocated pool lookup table`
- `allocator +0x30 = largest/default pool size`
- `allocator +0x38 = 0x800`
- `allocator +0x3c = 0x400`
- `allocator +0x40 = 0x200`
- `allocator +0x44 = 0x100`

Important refinement:

- the nonzero runtime writer for allocator `+0x0c` is no longer a conceptual mystery
- it is assigned by `fn_dma_fpm_driver_hw_init_8009d0a0_candidate`
- what remains unresolved is the exact runtime allocated pointer value, not the role of the field

### FPM buffer-size class mapping

Confirmed buffer-size-to-class mapping inside the FPM driver init:

- `0x100 -> class 7`
- `0x200 -> class 0`
- `0x400 -> class 2`
- `0x800 -> class 6`

For the current board path:

- requested size is `0x100`
- allocator `+0x04 = 7`

The class is written into:

- `fpm_hw_regs_base + 0x40`, bits `26:24`

### FPM DDR backing allocation

Confirmed allocation formula:

- `allocation_length = requested_fpm_buffer_size * 0x8000 + 0x100`

For the board path:

- `0x100 * 0x8000 + 0x100 = 0x00800100`

If allocation succeeds:

- `allocator +0x0c = (allocated_ptr + 0xff) & 0xffffff00`
- `0xb2200044 = (allocated_ptr + 0xff) & 0x1fffff00`

This closes the meaning of the GMAC/MBDMA value at `0x12c00010`:

- `GENET_MBDMA_GLOBAL_12c00010 = allocator[+0x0c] & 0x1fffffff`
- therefore `0x12c00010` is the aligned FPM DDR backing base in physical/bus form
- it is not the allocator object pointer
- it is not a simple ring pointer

### Default pool-size table and derived HW alloc/free addresses

Confirmed default pool-size table:

- `0x8146ff54 = 0x800`
- `0x8146ff58 = 0x400`
- `0x8146ff5c = 0x200`
- `0x8146ff60 = 0x100`

Derived values:

- size shift bits: `8`
- allocator `+0x30 = 0x800`
- lookup length: `0x800 >> 8 = 8`

Derived pool-class map used by the sized wrapper path:

- `class(0x100) = 3`
- `class(0x200) = 2`
- `class(0x400) = 1`
- `class(0x800) = 0`

With `allocator +0x00 = 0xb2200000`, the sized wrapper targets resolve to:

- size `0x100 -> 0xb2200218 -> 0x12200218`
- size `0x200 -> 0xb2200210 -> 0x12200210`
- size `0x400 -> 0xb2200208 -> 0x12200208`
- size `0x800 -> 0xb2200200 -> 0x12200200`

This upgrades the earlier “pool-class control address” interpretation to concrete expected values for the GMAC/MBDMA registers:

- `0x12c0004c = 0x12200218`
- `0x12c00050 = 0x12200210`
- `0x12c00054 = 0x12200208`
- `0x12c00058 = 0x12200200`
- `0x12c00008 = 0x12200200`

### Updated current truth

High-confidence current interpretation of the key MBDMA inputs:

- `0x12c00010 = aligned_fpm_ddr_backing_base & 0x1fffffff`
- `0x12c0004c = 0x12200218`
- `0x12c00050 = 0x12200210`
- `0x12c00054 = 0x12200208`
- `0x12c00058 = 0x12200200`
- `0x12c00008 = 0x12200200`

Operational implication:

- the OEM path depends on FPM hardware allocator setup at `0x12200000` before or alongside GMAC/MBDMA init
- reproducing only GENET-side ring programming in OpenWrt is likely insufficient if the FPM side is absent

## 2026-06-08 final control pass

This section was added after another full reread of the reverse-note set. The purpose is to freeze the current truth set and explicitly separate high-confidence facts from still-provisional items.

### No new contradictions found

The final reread did not introduce contradictions against the earlier control-pass sections. The newer caller-chain notes strengthen the allocator/FPM interpretation; they do not weaken the GENET/MDIO conclusions.

### Frozen high-confidence facts

These are the current best facts to treat as stable:

- stage1 must be decoded as `MIPS:BE:32:default`
- GENET main window is `0x12c00000`
- MDIO windows are:
  - `0x12c00600`
  - `0x12c02600`
- MDIO offsets are:
  - `+0x2c`
  - `+0x2e`
  - `+0x30`
  - `+0x32`
- MDIO busy bit is `bit0`
- `fn_enet_probe_mac_phy_id @ 0x803af53c` is the top-level probe/selection path
- `fn_enet_gmac_init_step1` is only the one-time profile/control gate wrapper
- `fn_enet_gmac_init_step2` controls `0x12c00070`
- `fn_enet_gmac_mbdma_global_init @ 0x803a8790` is the key GENET/MBDMA global setup path
- board-path FPM HW base is `0x12200000` (`0xb2200000` KSEG1)
- board-path requested FPM buffer size is `0x100`
- board-path FPM backing allocation length is `0x00800100`
- `0x12c00010 = aligned_fpm_ddr_backing_base & 0x1fffffff`
- sized-wrapper derived constants are:
  - `0x12c0004c = 0x12200218`
  - `0x12c00050 = 0x12200210`
  - `0x12c00054 = 0x12200208`
  - `0x12c00058 = 0x12200200`
  - `0x12c00008 = 0x12200200`
- additional GENET/MBDMA control values are:
  - `0x12c00004 = (old & 0xffffe000) | 0x9010`
  - `0x12c00044 = 0x02020202`
  - `0x12c00048 = 0x0000000f`
  - `0x12c0000c` final low field includes `0x0c41`
- base/size-like per-core words remain:
  - `0x12c00104 = 0x13601c10`
  - `0x12c00124 = 0x13601c10`
  - `0x12c00144 = 0x13601c10`
  - `0x12c00184 = 0x13601c10`

### Still provisional

These items are still not frozen as final semantics:

- exact meaning of preserved-register control template feeding `0x12c0000c`
- confirmed TX/RX direction and field semantics for:
  - `0x12c00100`
  - `0x12c00120`
  - `0x12c00140`
  - `0x12c00180`
- final semantic meaning of the `0x14e0xxxx` board/profile block
- actual runtime allocated DDR pointer value behind allocator `+0x0c`

### Final reverse control conclusion

The current reverse picture is now strong enough to support targeted OpenWrt instrumentation:

- GENET-side bring-up must be compared together with FPM-side allocator setup
- the OEM path is not only a GENET/TDMA sequence
- the FPM hardware block at `0x12200000` is part of the dependency chain for the values later written into the `0x12c00000` MBDMA window

## 2026-06-09 control pass: packet-token allocator closure

This section was added after a fresh full reread on `2026-06-09`. It folds in the new reverse note:

- `2026-06-09-024849-fpm-dma-packet-token-findings.md`

### Control result

The June 9 reread did not contradict the June 8 frozen GENET/MBDMA constants. It strengthens the existing interpretation that the OEM Ethernet DMA path is FPM-backed and token-driven, not only a normal ring-base programming sequence.

### New high-confidence allocator facts

Confirmed secondary packet allocator object:

- init latch: `0x8187bc68`
- object base: `0x8187bc70`
- object `+0x18 = 0xe0`
- object `+0x1c = 16-byte-aligned packet-header arena base`
- object `+0x20 = 0x81848740` main DMA/FPM allocator pointer

Derived packet-header arena allocation:

- `0xe0 << 0xf = 0x700000`
- allocation request includes alignment slack, producing `0x700010`

This is operationally important because the vendor path uses a software packet-header arena tied to hardware FPM tokens rather than only plain descriptor-owned linear buffers.

### New high-confidence token facts

Token format now has a stronger working model:

- `bit31 = valid token marker`
- `bits29:28 = stored high bits / pool selector from allocator high-bits table`
- `bits27:12 = token index`
- per-token data stride: `0x100`

Translation model:

- token/data-address translation uses `allocator_backing_base + extra_offset + token_index * 0x100`
- reverse translation reconstructs the token from buffer address, backing base, stored high bits, and token index

This materially strengthens the earlier conclusion that the OEM datapath is using FPM-token semantics behind the GENET/MBDMA values.

### New high-confidence FPM register roles

The June 9 note also strengthens the FPM register map:

- `0x12200010` = interrupt/control enable-mask candidate
- `0x12200014` = interrupt pending/status + ack/clear candidate
- `0x12200044` = bus-visible backing-base low bits
- `0x12200200` = token free/deallocation endpoint
- `0x12200200 + pool_class * 8` = sized alloc/free endpoints used by the MBDMA global init path

This is consistent with the already-frozen derived values:

- `0x12c0004c = 0x12200218`
- `0x12c00050 = 0x12200210`
- `0x12c00054 = 0x12200208`
- `0x12c00058 = 0x12200200`
- `0x12c00008 = 0x12200200`

### Updated reverse conclusion

The strongest current model is now:

- the main allocator at `0x81848740` owns FPM HW base, backing base, pool lookup state, and token high bits
- the secondary packet allocator at `0x8187bc70` builds packet-header metadata around FPM-backed data buffers
- GMAC/MBDMA global init is fed with FPM-derived endpoint values, not ordinary descriptor-ring bases for the sized registers

For OpenWrt work, this means the comparison target is no longer just “GENET register sequence versus OEM.” It is “GENET register sequence plus the FPM token/backing-base model that feeds those registers.”

## 2026-06-09 control pass: step2 mask correction and status-register closure

This section was added after another full reread of the reverse-note set in `reverse`. It folds in these later notes:

- `2026-06-08-215910-fpm-packet-allocator-heap-chain.md`
- `2026-06-08-233251-enet-mii-static-log-stream-followup.md`
- `2026-06-09-030109-fpm-token-alloc-free-path.md`
- `2026-06-09-030657-gmac-mbdma-fpm-endpoint-reinterpretation.md`
- `2026-06-09-ghidra-fpm-mbdma-labeling-next-steps.md`
- `2026-06-09-ghidra-fpm-mbdma-packet-allocator-control-log.md`

### Control result

The reread did not weaken the FPM-endpoint interpretation of the MBDMA path. It did close one real ambiguity: the maintained June 8 step2 interpretation is now superseded.

### Corrected `0x12c00070` interpretation

Earlier June 8 notes treated the nonzero-core path as if `0x12c00070` always gained `0x00003000`. That is no longer the best reading.

Current best interpretation:

- selected core/interface `0` path sets `0x00000003`
- selected nonzero core/interface path sets `0x00030000`
- the paired disable path clears the corresponding core-pair
- the wrapper enables the selected core-pair and clears the opposite one

Operational consequence:

- retire `0x00003000` as the preferred comparison value for this register
- use selected-core masks `0x00000003` and `0x00030000` instead

### Additional MBDMA/FPM control values now worth freezing

New high-value control/status facts from the later notes:

- `0x12c00040` receives candidate status/ack/mask value `status | 0xdea9`
- FPM dump/snapshot helpers read:
  - `0x12200050` overflow/underflow count
  - `0x12200054` FIFO/token status
  - `0x12200058` invalid token free count
  - `0x1220005c` invalid token multifree count

These do not change the endpoint model. They add better observability around it.

### Packet allocator storage/lifetime closure

The packet allocator picture is now stronger:

- `0x8187bc60` is active packet-allocator static state
- `0x8187bc68` is the packet-allocator init latch
- `0x8187bc70` is fixed/static-looking packet-allocator object storage
- `0x8187bc70 + 0x1c` stores a 16-byte-aligned packet-header arena from raw allocation `0x700010`
- `0x8187bc70 + 0x20` links to main allocator `0x81848740`

Important consequence:

- `0x8187bc60..0x8187bc6f` is not clean heap-header space for a normal heap payload at `0x8187bc70`
- treat the generic heap-free cleanup path as suspicious or context-dependent, not as proof that `0x8187bc70` is a normal heap allocation

### Token-format closure

The token format is now stronger than the earlier packet-token note alone:

- `bit31` = valid token marker
- `bits29:28` = saved high bits / selector
- `bits27:12` = token index
- `bits11:0` = requested allocation-size low bits on allocation path
- stride remains `token_index * 0x100`

### Updated reverse conclusion

The strongest current reverse model is now:

- GENET/MBDMA global init is an FPM bridge, not a plain descriptor-only setup
- `0x12c00010` carries masked FPM backing-base state
- `0x12c0004c/50/54/58/08` carry FPM endpoint addresses
- `0x12c00040` and FPM `0x12200050/54/58/5c` are the next high-value status/control reads for OEM-vs-OpenWrt comparison
- `0x12c00070` must be compared with selected-core masks `0x00000003` and `0x00030000`, not `0x00003000`
