# TC7200 Ghidra interactive mapping findings (2026-06-07)

Scope:
- Capture the high-confidence labels and control-flow conclusions from the manual Ghidra session on the `d60242` image.
- Prefer string xrefs and direct call targets over unstable decompiler prototypes.
- Record known false starts so they are not reintroduced later.

Inputs:
- Raw image: `/home/mgta29/tc7200u-research/reverse/d60242_ghidra/image.raw`
- Base address: `0x80004000`
- Language: `MIPS:BE:32:default`
- Main anchor strings used during the session:
  - `0x810a8e80` `Linux Boot Args: %s`
  - `0x810a9d4c` `ReconfigureLeasePoolImpl`
  - `0x810746cc` `NandFlashRead: Failed to find replacement block!`
  - `0x81074738` `NandFlashRead: Detected out-of-order block...`
  - `0x810a074c` `<<<<< %s sent initial handshake >>>>>>`
  - `0x810a07a0` `Error: getHostDqmMessage(handshake) on %s`
  - `0x810a07cc` `Error: handshake rx unexpected message`
  - `0x810a07f4` `<<<<< %s sent reply handshake message >>>>>>`

## BootLinux path (`0x804c99d0`)

High-confidence labels:
- `0x804c99d0` `fn_boot_linux_entry`
- `0x804c9a58` `loc_boot_linux_allowed`
- `0x804c9b40` `loc_boot_linux_args_setup`
- `0x804c9b80` `xref_linux_boot_args_log`
- `0x804c9b9c` `loc_boot_linux_handoff_copy_loop`
- `0x804c9bd0` `loc_post_handoff_reconfigure_lease_pool`
- `0x804c9bd8` `loc_boot_linux_return_success`
- `0x804c9bdc` `loc_boot_linux_epilogue`

Observed flow:
- Logs `BootLinux`.
- Gates the path through `FUN_8059b180()`.
- Runs two table/list helpers before continuing:
  - `0x804ccf54` `fn_lookup_matching_entry`
  - `0x804ccdec` `fn_find_and_flag_matching_entry`
- Calls two shared helpers that currently decompile inside the broader `BootLinux` window:
  - `0x80481fc8` `fn_build_ssdp_discovery_response_core`
  - `0x80481f88` `fn_build_ssdp_discovery_response`
- Chooses between:
  - `root=/dev/mtdblock3 ...`
  - `console=%s,115200 ubi.mtd=linuxkfs ubi.mtd=linuxapps ...`
- Chooses `ttyS0` vs `ttyUSB0`.
- Formats the final boot args into the buffer at `0x81a8e820`.
- Sets `_DAT_b3e0108c |= 1`.
- Prepares a handoff context, then copies that prepared structure into the `0x87000000` region.
- Calls `FUN_80008d00()`.
- Immediately enters lease-pool reconfiguration via `fn_reconfigure_lease_pool_impl`.

Notes:
- `0x804c9b84` is the single xref site for `Linux Boot Args: %s`.
- If Ghidra creates a standalone function around `0x804c9b48`, treat it as a false split and keep only an internal location label there.

## Boot-adjacent helpers

High-confidence labels:
- `0x804cd9b8` `fn_prepare_linux_handoff_context`
- `0x80e9d958` `fn_snprintf`
- `0x80e9dd64` `fn_vfprintf_core`

Low-confidence / intentionally left generic:
- `0x804cd840` `FUN_804cd840`
- `0x80008d00` `FUN_80008d00`
- `0x803ea4f8` `FUN_803ea4f8`

Reason for leaving these generic:
- `FUN_804cd840` sits next to the boot-args logger, but current evidence is not strong enough to lock a semantic name.
- `FUN_803ea4f8` appears in the boot path decompile, but separate string evidence (`%f%n`, `Must be a floating point number`) conflicts with a simple boot-mode interpretation. Function boundary cleanup is needed before renaming it confidently.

## Lease-pool reconfiguration path

High-confidence labels:
- `0x804cdee0` `fn_reconfigure_lease_pool_impl`
- `0x804ce210` `fn_reconfigure_lease_pool_conflict_path`
- `0x804ccf54` `fn_lookup_matching_entry`
- `0x804ccdec` `fn_find_and_flag_matching_entry`
- `0x804df130` `fn_copy_entry_record`

Evidence:
- `ReconfigureLeasePoolImpl` has xrefs only inside the `0x804cdfc0..0x804ce408` window.
- The conflict helper references:
  - `since it's the server router add...`
  - `it's already associated with cli...`
- The implementation and conflict helper both walk/compare entry records and feed the same update/logging machinery.

Conclusion:
- This is not a kernel jump stub. It is a real post-copy lease-pool/configuration path that runs after the `0x87000000` handoff structure is written.

## NAND replacement path

High-confidence labels:
- `0x803f6d90` `fn_nandflashread_with_replacement`
- `0x803f6e14` `xref_log_nand_no_replacement`
- `0x803f6f3c` `loc_nand_out_of_order_compare`
- `0x803f6f40` `xref_log_nand_out_of_order`
- `0x803f6f64` `loc_nand_replacement_missing_branch`
- `0x803f6f70` `xref_log_nand_replacement_found`
- `0x803facac` `fn_find_replacement_block_candidate`

Observed flow:
- Detects tagged-offset mismatch / out-of-order NAND metadata.
- Logs the out-of-order condition.
- Calls `fn_find_replacement_block_candidate`.
- If the resolver returns `0`, logs `NandFlashRead: Failed to find replacement block!`, poisons cached NAND pointers with `0xffffffff`, and returns error.
- If the resolver succeeds, logs the replacement block and continues reading.

Important correction:
- The real replacement resolver target is `0x803facac`.
- Earlier guesses that placed this role on `0x803f6cac` were wrong and should not be reused.

## TP handshake path

High-confidence labels:
- `0x8049714c` `fn_tp_handshake_flow`
- `0x804971e8` `xref_tp_handshake_init`
- `0x8049720c` `loc_tp_handshake_post_first_rx`
- `0x80497220` `xref_tp_handshake_first_message_event`
- `0x80497230` `xref_tp_getmsg_handshake_err`
- `0x804972b0` `xref_tp_handshake_reply_log`
- `0x804972d0` `xref_tp_handshake_unexpected`
- `0x804972e0` `loc_tp_handshake_main_loop`

Observed flow:
- Creates an ITC RX endpoint/thread.
- Sends the initial handshake.
- Waits for the first receive event.
- If receive fails, logs `Error: getHostDqmMessage(handshake) on %s`.
- If the first received message is unexpected, logs `Error: handshake rx unexpected message`.
- Otherwise sends the reply handshake and falls into the main infinite RX/dispatch loop.

Important cleanup:
- If Ghidra creates standalone functions at `0x80497190`, `0x8049720c`, or `0x804972e0`, delete those false splits and keep them only as location labels inside `fn_tp_handshake_flow`.
- `loc_tp_handshake_main_loop` should exist only at `0x804972e0`.
- `0x8049720c` should remain `loc_tp_handshake_post_first_rx`, not another copy of the main-loop label.

Runtime relevance:
- This path is a strong candidate for the repeated message-loop / unhandled-message behavior seen after the NAND failure path at runtime.

## Ghidra hygiene notes from this session

- Prefer string xrefs over decompiler-inferred prototypes when naming blocks.
- Duplicate labels are easy to create at the same address; keep one primary label and remove extras.
- Internal labels should use `loc_` or `xref_`, not `fn_`.
- If a location label appears in the decompiler as a standalone function header, verify the boundary in `Listing` and delete the false function if necessary.
- For function-level notes, use Plate Comments rather than EOL comments.

## Current unresolved items worth revisiting later

- `FUN_804cd840`
- `FUN_80008d00`
- `FUN_803ea4f8`

These are still better left generic until the surrounding boundaries or xrefs are cleaner.
