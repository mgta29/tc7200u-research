# TC7200U Ghidra reverse log: FPM packet/token allocation, release, callback, and RX-token reconstruction

## Rule compliance

- New dated reverse note created under records/notes/reverse/.
- No old logs were edited, deleted, moved, or overwritten.
- This is a reverse-engineering/Ghidra finding log, not source-research output.

## Summary

This pass confirms the OEM FPM-backed packet lifecycle used around the secondary packet allocator object. The same FPM token index links packet-header slots and FPM backing/data buffers. The alloc path builds packet headers from newly allocated FPM tokens. The release path reconstructs FPM tokens from packet data addresses and returns them to FPM hardware. A separate RX path reconstructs packet headers from already received RX tokens.

## Key static objects and constants

- Secondary FPM packet allocator object: 0x8187bc70.
- Main DMA/FPM allocator object: 0x81848740.
- Packet header slot size: 0xe0 / decimal 224.
- FPM data-buffer stride: 0x100 / decimal 256.
- Token valid bit: 0x80000000.
- Token high bits / pool selector: bits 29:28.
- Token index: bits 27:12.
- Token index mask after shift: 0xffff.
- Token low size field: bits 11:0, mask 0x00000fff.
- Common FPM free endpoint: KSEG1 0xb2200200, physical 0x12200200, decimal 304087552.

## Packet header structure findings

Current useful packet header model:

```c
struct tc7200_fpm_packet_header {
    void *free_callback;                           // +0x00
    tc7200_fpm_packet_inner_header *inner_header;  // +0x04
    void *list_or_inner_ptr_a;                     // +0x08
    uint32_t active_or_refcount;                   // +0x0c
    uint8_t unknown_10[0x02];                      // +0x10..+0x11
    uint16_t rx_context_or_type_12;                // +0x12 candidate, values seen 0x64 and 0x78
    uint8_t unknown_14[0x0c];                      // +0x14..+0x1f
    tc7200_fpm_packet_inner_header embedded_inner; // +0x20..+0x4f
    uint8_t unknown_50[0x90];                      // +0x50..+0xdf
};
```

Current useful inner header model:

```c
struct tc7200_fpm_packet_inner_header {
    uint32_t data_addr;                    // +0x00
    uint32_t requested_payload_len;        // +0x04
    uint8_t unknown_08[0x10];              // +0x08..+0x17
    void *ptr_or_list_18;                  // +0x18, points to outer +0x64
    uint8_t unknown_1c[0x04];              // +0x1c..+0x1f
    uint16_t flags_20;                     // +0x20
    uint8_t unknown_22[0x0a];              // +0x22..+0x2b
    uint32_t fpm_extra_base_offset_saved;  // +0x2c
};
```

Offset validation: packet_header +0x04 and +0x08 both point to packet_header +0x20, the embedded inner header. inner_header +0x18 is set to packet_header +0x64, which appears in typed output as packet_header->unknown_50 + 0x14. This matches the raw assignment packet_header[0xe] = packet_header + 0x19.

## Allocation path: fn_dma_fpm_packet_alloc_from_size_8002a54c_candidate

Confirmed behavior:

- Gets an FPM token through fn_dma_fpm_alloc_token_for_size_8002a7ec_candidate.
- Effective request size is requested_payload_len_or_size + main_fpm_allocator[0x34] + 0x20.
- token_index = (fpm_token_word >> 12) & 0xffff.
- packet_header = packet_header_arena_aligned + token_index * packet_header_slot_size.
- Clears the whole packet header slot using packet_header_slot_size >> 2 words.
- Sets packet_header->list_or_inner_ptr_a = &packet_header->embedded_inner.
- Sets packet_header->inner_header = &packet_header->embedded_inner.
- Sets packet_header->embedded_inner.ptr_or_list_18 = packet_header + 0x64.
- Saves main_fpm_allocator +0x34 into inner_header->fpm_extra_base_offset_saved.
- Sets packet_header->active_or_refcount = 1.
- Stores fn_dma_fpm_packet_free_callback_8002a4ac_candidate at packet_header->free_callback.
- Sets inner_header->flags_20 bit0.
- Stores requested_payload_len_or_size at inner_header->requested_payload_len.
- Calls fn_dma_fpm_token_to_backing_buffer_addr_8009dfec_candidate.
- Stores returned backing/data address at inner_header->data_addr.

Important cleanup: the decompiler expression packet_header->unknown_10 + work_offset_or_dma_addr + -0x10 is just packet_header_base + clear_offset. It clears the packet header from offset +0x00, not only unknown_10.

## Release path: fn_dma_fpm_packet_release_to_fpm_8002a658_candidate

Confirmed behavior:

- Accepts packet_alloc and tc7200_fpm_packet_header *packet_header.
- If release_fpm_buffer_flag == 1, reads packet_alloc->main_fpm_allocator_ptr.
- Reads packet_header->inner_header->data_addr.
- Reads packet_header->inner_header->fpm_extra_base_offset_saved.
- Calls fn_dma_fpm_backing_buffer_addr_to_token_8009e0a4_candidate to reconstruct token.
- Calls fn_dma_fpm_free_token_to_hw_8009e168_candidate to return token to FPM hardware.
- On failure, logs through PacketFree / Failure to free FPM buffer path.

Release model:

```text
packet_header -> inner_header -> data_addr -> reconstruct token -> free token to FPM endpoint
```

## Packet free callback: fn_dma_fpm_packet_free_callback_8002a4ac_candidate

Confirmed behavior:

- This function is stored at packet_header->free_callback by the allocation path.
- It gets the secondary packet allocator object through fn_dma_fpm_packet_alloc_get_or_init_8002a4f8_candidate.
- It calls fn_dma_fpm_packet_release_to_fpm_8002a658_candidate(packet_alloc, packet_header, 1).
- It returns 1 when release succeeds.
- Fatal error path logs BcmBfcApi PacketFree: Failure if release fails.

Correct interpretation: packet_header is the first argument. It is not a raw token. The callback is a small wrapper around the release helper.

## ENET wrapper: fn_enet_release_fpm_packet_header_803a8d38_candidate

Confirmed behavior:

- ENET-adjacent wrapper gets the secondary FPM packet allocator object.
- Releases the passed tc7200_fpm_packet_header through fn_dma_fpm_packet_release_to_fpm_8002a658_candidate with release_fpm_buffer_flag = 1.
- Sets DAT_81479f58 = 1 afterward.

Recommended name: fn_enet_release_fpm_packet_header_803a8d38_candidate or fn_enet_fpm_packet_release_wrapper_803a8d38_candidate. Avoid token in the name because param_1 is a packet header pointer and the token is reconstructed internally.

## Token-to-buffer helper: fn_dma_fpm_token_to_backing_buffer_addr_8009dfec_candidate

Confirmed formula:

```text
token_index = (token_word >> 12) & 0xffff
data_addr = extra_base_offset + allocator->fpm_backing_base_aligned + token_index * 0x100
```

Also stores high bits:

```text
allocator->token_highbits_table[token_index] = (token_word >> 28) & 3
```

## Buffer-to-token helper: fn_dma_fpm_backing_buffer_addr_to_token_8009e0a4_candidate

Confirmed formula:

```text
token_index = ((backing_buffer_ptr & 0x1fffffff) - (allocator->fpm_backing_base_aligned & 0x1fffffff) - extra_base_offset) >> 8
token = 0x80000000 | (allocator->token_highbits_table[token_index] << 28) | (token_index << 12)
```

Important: bits 11:0 are not restored here. The reconstructed token uses valid bit, saved high bits, and token index.

## Token free helper: fn_dma_fpm_free_token_to_hw_8009e168_candidate

Confirmed behavior:

- Requires token bit31 set.
- Extracts token_index = (token_word >> 12) & 0xffff.
- Reconstructs backing_addr = extra_base_offset + allocator->fpm_backing_base_aligned + token_index * 0x100.
- Saves high bits into token_highbits_table[token_index].
- Selects cache operation size from allocator->pool_size_table[(token_word >> 28) & 3].
- Performs cache op through fn_mips_dcache_range_op_8002a034_candidate.
- Writes token to allocator->fpm_hw_base_kseg1 + 0x200.

Common free endpoint: 0xb2200200 / physical 0x12200200 / decimal 304087552.

## False function correction: 8002a634

Ghidra created or displayed FUN_8002a634, but this is not a real function. Address 8002a634 is the delay slot of the jal at 8002a630:

```asm
8002a630  jal   fn_dma_fpm_token_to_backing_buffer_addr_8009dfec_candidate
8002a634  _lw   a2,0x2c(s0)
8002a638  sw    v0,0x0(s0)
```

Meaning:

```c
data_addr = fn_dma_fpm_token_to_backing_buffer_addr_8009dfec_candidate(main_fpm_allocator, fpm_token_word, packet_inner_header->fpm_extra_base_offset_saved);
packet_inner_header->data_addr = data_addr;
```

If Ghidra splits this again, delete the false function only. Do not clear bytes.

## RX-token reconstruction path: 80846620 / 80846ab0 candidate workers

A high-value RX-side path was found around NatpNoMatchRxIst / got BAD rxToken strings. This path is different from the normal requested-size allocation path.

RX path model:

```text
existing RX token -> token_index -> packet_header slot -> embedded inner header -> data pointer/payload length setup -> process packet -> cleanup release if not consumed
```

Observed behavior:

- Receives or dequeues an RX token.
- If token is not valid, logs got BAD rxToken.
- token_index = (rxToken >> 12) & 0xffff.
- packet_header = packet_alloc->packet_header_arena_aligned + token_index * packet_header_slot_size.
- Clears packet header slot.
- Initializes packet_header +0x04 and +0x08 to packet_header +0x20.
- Sets inner_header +0x18 to packet_header +0x64.
- Saves allocator +0x34 to inner_header +0x2c during generic setup, then RX-specific path can overwrite +0x2c to zero.
- Sets callback at packet_header +0x00 to fn_dma_fpm_packet_free_callback_8002a4ac_candidate.
- In RX-specific setup, payload length comes from rxToken & 0xfff.
- In RX-specific setup, data_addr is set from the RX token data/buffer conversion result, and fpm_extra_base_offset_saved is set to 0.
- Packet header +0x12 is set with halfword values 0x64 in one worker and 0x78 in the alternate worker.
- If packet is not consumed, function calls fn_dma_fpm_packet_release_to_fpm_8002a658_candidate(packet_alloc, packet_header, 1).

Candidate names:

- fn_natp_nomatch_rx_token_worker_80846620_candidate.
- fn_natp_nomatch_rx_token_worker_alt_80846ab0_candidate.

Do not over-finalize the Natp naming yet; the string strongly suggests it, but broader caller context should still be checked.

## OpenWrt implication

The OEM RX path appears token-backed. Hardware or a lower RX stage provides an FPM token, not only a normal DMA buffer address. OEM code reconstructs packet headers by token index and links packet header slots to backing buffers through FPM token math.

Critical implications for OpenWrt GENET/GMAC bring-up:

- GENET/MBDMA cannot be treated as plain descriptor-ring setup only.
- FPM hardware at 0x12200000 participates in buffer lifecycle.
- Packet headers are indexed by token_index * 0xe0.
- Backing buffers are indexed by token_index * 0x100.
- Free path writes tokens to 0x12200200.
- RX path likely needs token-aware handling or compatible FPM initialization.

## Next reverse targets

Priority functions to inspect next:

- FUN_8002aa3c: likely converts RX token to data pointer or token-backed buffer pointer.
- FUN_8002b974: likely receives/dequeues RX token.
- FUN_8002bc50: likely enqueues packet header into packet/list path.
- More 803a/803b ENET/GMAC callers of packet release if present.

## Current conclusion

The FPM packet lifecycle is now proven end-to-end:

```text
ALLOC path: requested payload length -> FPM token -> token-indexed packet header -> token-indexed data buffer
RELEASE path: packet header -> data_addr -> reconstructed token -> FPM free endpoint
RX path: existing RX token -> token-indexed packet header reconstruction -> packet processing -> optional release
```

No old logs were edited or deleted.
