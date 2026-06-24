# 2026-06-23 — Ghidra ENET / FPM packet-port table and MDIO findings

## Scope

This record captures the Ghidra reverse-engineering work around the TC7200U stage1 ENET/FPM packet submit path, packet-port submit table, GMAC/PHY link-control callback, and GENET MDIO register access layout.

Primary focus areas:

- FPM/DMA packet token preparation and submit bridge at `8002b410`
- Packet-port submit table at `81a8d7c0`
- Packet-port register/status-dispatch helper at `803ac1a4`
- GMAC/PHY link-control callback at `803ac42c`
- GENET MDIO0/MDIO1 MMIO register layout around `b2c00600` and `b2c02600`
- Ghidra memory-block corrections for the `81a8d7b0..81a8dc00` ENET area
- False Ghidra function boundary cleanup around fall-through/internal blocks

## High-level result

The packet/FPM submit side is now substantially clearer:

- `8002b410` is a DMA/FPM packet token-to-submit-descriptor bridge.
- The table at `81a8d7c0` is a `0x44`-byte-entry packet-port table.
- The table is not 5 entries; `803ac1a4` proves a 16-entry register/init path.
- The table occupies `81a8d7c0..81a8dbff` exactly, ending immediately before the ENET/GMAC state block at `81a8dc00`.
- The ENET core command argument copy area is `81a8d7b0..81a8d7bb`.
- `803ac1a4` is the real parent function for previously split blocks at `803ac268`, `803ac26c`, and `803ac318`.
- `803ac42c` is a GMAC/PHY link-control callback candidate, handling speed, duplex, autoneg/manual-link mode, and a special `0x400a0011` request.
- GENET MDIO register access is through MDIO0/MDIO1 bases `b2c00600` and `b2c02600` with command/write/status fields at `+0x2c/+0x30/+0x32`.
- No standalone symbols should be created at `b2c0062e` or `b2c0262e`; those are offcut read-data halfwords inside the `+0x2c` 32-bit command/read-data word.

## Memory blocks

### Final intended ENET-area memory layout

| Block / area | Start | End | Size | Notes |
|---|---:|---:|---:|---|
| `RAM_STAGE1_ENET_CORE_CMD_ARG0_81A8D7B0_candidate` | `81a8d7b0` | `81a8d7b3` | `0x4` | Separate 4-byte word because the existing block starts at `81a8d7b4`. |
| `RAM_STAGE1_ENET_CORE_CMD_ARGS_AND_PORT_TABLE_81A8D7B4_candidate` | `81a8d7b4` | `81a8dbff` | `0x44c` | Contains arg1/arg2 words and the 16-entry packet-port table. |
| `RAM_STAGE1_ENET_MANUAL_STATE_81A8DC00` | `81a8dc00` | `81a8dcb7` | `0xb8` | Separate ENET/GMAC state block. Do not merge with table. |
| `RAM_STAGE1_ENET_POLL_WAIT_TIMER_81A8DCB8` | `81a8dcb8` | `81a8dcc7` | `0x10` | Timer/wait state area. |
| `RAM_ENET_EXTPHY_SPI_DRIVER_TABLE_81A8E9A8_candidate` | `81a8e9a8` | `81a8e9af` | `0x8` | External PHY/SPI driver table candidate. |

### Critical boundary

The table must end exactly at:

```text
81a8dbff
```

The next block begins at:

```text
81a8dc00
```

This prevents the packet-port table array from overlapping `g_enet_gmac_init_state_81A8DC00_candidate`.

### Packet-port table bounds

```text
81a8d7c0..81a8dbff = packet_port_submit_table_entry_44_candidate[16]
```

Entry map:

| Entry | Address |
|---:|---:|
| `[0]` | `81a8d7c0` |
| `[1]` | `81a8d804` |
| `[2]` | `81a8d848` |
| `[3]` | `81a8d88c` |
| `[4]` | `81a8d8d0` |
| `[5]` | `81a8d914` |
| `[6]` | `81a8d958` |
| `[7]` | `81a8d99c` |
| `[8]` | `81a8d9e0` |
| `[9]` | `81a8da24` |
| `[10]` | `81a8da68` |
| `[11]` | `81a8daac` |
| `[12]` | `81a8daf0` |
| `[13]` | `81a8db34` |
| `[14]` | `81a8db78` |
| `[15]` | `81a8dbbc` |
| final byte | `81a8dbff` |

## Labels and globals

### ENET command/table globals

| Address | Label | Type / note |
|---:|---|---|
| `81a8d7b0` | `g_enet_core_cmd_arg0_81A8D7B0_candidate` | `uint32_t`; separate 4-byte block. |
| `81a8d7b4` | `g_enet_core_cmd_arg1_81A8D7B4_candidate` | `uint32_t`; copied ENET core command argument word. |
| `81a8d7b8` | `g_enet_core_cmd_arg2_81A8D7B8_candidate` | `uint32_t`; copied ENET core command argument word. |
| `81a8d7c0` | `g_packet_port_submit_table_81A8D7C0_candidate` | `packet_port_submit_table_entry_44_candidate[16]`. |
| `81a8dc00` | `g_enet_gmac_init_state_81A8DC00_candidate` | ENET/GMAC state block; currently `0xb8` bytes. |

### Packet-port control globals

| Address | Label | Type / note |
|---:|---|---|
| `81479f6c` | `g_packet_port_table_first_register_latch_81479F6C_candidate` | `uint8_t`; first/register latch; controls table init path. |
| `81840008` | `g_packet_port_table_base_port_id_81840008_candidate` | `uint32_t`; base port/id used for table indexing. |
| `81479f71` | `g_enet_phy_link_control_enable_81479F71_candidate` | `uint8_t`; link-control enable candidate. |
| `81479f80` | `g_enet_managed_switch_link_monitor_enable_81479F80_candidate` | `uint8_t`; managed-switch/external-PHY path enable. |
| `81840028` | `g_enet_unimac_or_gmac_regs_base_ptr_81840028_candidate` | `/tc7200u/mmio/vuint32_t *`; used with offset `+0x208`. |

## Structures and datatypes

### `/tc7200u/fpm_dma/dma_fpm_packet_submit_descriptor_candidate`

This descriptor is used by the FPM packet token submit bridge at `8002b410`.

```c
struct dma_fpm_packet_submit_descriptor_candidate {
    byte raw_00[0x10];
    uint16_t port_or_profile_10;
    byte raw_12[0x0e];
    void *buffer_addr_20;
    uint32_t packet_len_24;
    byte raw_28[0x18];
    uint16_t flags_40;
    byte raw_42[0x0a];
    uint32_t field_4c_zeroed;
};
```

Known field use:

- `+0x10` receives `descriptor_port_value_36` from the packet-port table.
- `+0x20` receives the translated packet buffer address.
- `+0x24` receives packet length.
- `+0x40` receives flags `0x0001`, and optionally `0x0020` when submit mode/class is at least 3.
- `+0x4c` is zeroed before submit callback invocation.

### `/tc7200u/fpm_dma/packet_port_submit_callback_fn_candidate`

```c
void packet_port_submit_callback_fn_candidate(dma_fpm_packet_submit_descriptor_candidate *submit_desc, void *callback_arg)
```

Used at table entry offset `+0x10`.

### `/tc7200u/fpm_dma/packet_port_status_callback_fn_candidate`

```c
uint32_t packet_port_status_callback_fn_candidate(void *stack_context, void *callback_arg)
```

Used at table entry offset `+0x08`.

Important distinction:

- `status_callback_08` is the callback in each packet-port table entry.
- `fn_enet_gmac_phy_link_control_callback_803ac42c_candidate` is not itself `status_callback_08`; it is installed into the stack/local status-context object built by `803ac1a4`.

### `/tc7200u/fpm_dma/packet_port_submit_table_entry_44_candidate`

Final current structure:

```c
struct packet_port_submit_table_entry_44_candidate {
    uint16_t field_00_candidate;
    uint16_t field_02_candidate;
    void *callback_or_init_04_candidate;
    packet_port_status_callback_fn_candidate *status_callback_08;
    uint32_t field_0c_candidate;
    packet_port_submit_callback_fn_candidate *submit_callback_10;
    byte raw_14[0x14];
    void *core_cmd_args_ptr_28_candidate;
    void *callback_arg_2c;
    uint32_t field_30_candidate;
    uint16_t port_id_high16_34_candidate;
    uint16_t descriptor_port_value_36;
    byte raw_38[0x0c];
};
```

Size: `0x44` bytes.

Known fields:

| Offset | Field | Meaning |
|---:|---|---|
| `+0x08` | `status_callback_08` | Called by register/status path with stack context and callback arg. |
| `+0x10` | `submit_callback_10` | Called by `8002b410` with submit descriptor and callback arg. |
| `+0x28` | `core_cmd_args_ptr_28_candidate` | Optional pointer copied to `81a8d7b0..81a8d7bb`. |
| `+0x2c` | `callback_arg_2c` | Callback argument for both status and submit paths. |
| `+0x34` | `port_id_high16_34_candidate` + `descriptor_port_value_36` | Full 32-bit port/id value is written at `+0x34`. Low half at `+0x36` is copied into descriptor `+0x10`. |

### `/tc7200u/fpm_dma/packet_port_submit_record_34_candidate`

Source registration record copied into table entries by `803ac1a4`.

```c
struct packet_port_submit_record_34_candidate {
    uint16_t field_00_candidate;
    uint16_t field_02_candidate;
    void *callback_or_init_04_candidate;
    packet_port_status_callback_fn_candidate *status_callback_08;
    uint32_t field_0c_candidate;
    packet_port_submit_callback_fn_candidate *submit_callback_10;
    byte raw_14[0x14];
    void *core_cmd_args_ptr_28_candidate;
    void *callback_arg_2c;
    uint32_t field_30_candidate;
};
```

Size: `0x34` bytes.

## Functions analyzed / updated

### `8002b410` — FPM packet token prepare and submit bridge

Rename:

```text
fn_dma_fpm_packet_token_prepare_and_submit_8002b410_candidate
```

Signature:

```c
uint32_t fn_dma_fpm_packet_token_prepare_and_submit_8002b410_candidate(void *packet_token_context, uint32_t submit_mode_or_class, uint32_t unused_arg2_candidate, uint32_t log_arg3_candidate)
```

Behavior:

- Reads `token_word` from `packet_token_context +0x08`.
- Derives `packet_len = token_word & 0x0fff`.
- Accepts packet lengths `0x3c..0x600` inclusive.
- Translates token to backing/data address through `FUN_8002aa3c`.
- Allocates/initializes a submit descriptor through `fn_dma_init_descriptor_from_context_candidate`.
- On success:
  - Performs D-cache operation mode `2` over the packet buffer.
  - Writes descriptor fields:
    - `+0x20 = packet_buffer_addr`
    - `+0x24 = packet_len`
    - `+0x4c = 0`
    - `+0x40 flags |= 0x0001`
    - if `submit_mode_or_class >= 3`, `+0x40 flags |= 0x0020`
  - Resolves a port/index from packet bytes at buffer `+0x06`.
  - Uses table at `81a8d7c0`, stride `0x44`.
  - Copies table entry `+0x36` into descriptor `+0x10`.
  - Calls `submit_callback_10(descriptor, callback_arg_2c)`.
  - Calls `fn_packet_submit_complete_or_poll_kick_8006311c_candidate(1)` if that helper is renamed/signed.
  - Returns `0`.
- Failure paths:
  - Out-of-range packet length increments `g_enet_gmac_init_state_81A8DC00_candidate +0x1c`.
  - Descriptor allocation failure logs an error.
  - Both failure paths free the token through `fn_dma_free_token_wrapper_candidate`.

Important Ghidra note:

- Ghidra may reuse the local originally named `token_word` as `packet_len` after descriptor allocation. After the assignment `token_word = packet_len`, that local no longer holds the original FPM token.

Status: about 85–90% understood.

Remaining callees to resolve:

- `FUN_8002aa3c` — token-to-packet-buffer translation.
- `FUN_803ac11c` — first packet port lookup.
- `FUN_803abdac` — fallback/secondary packet port lookup.
- `FUN_803ab5f4` — packet port/index writeback.
- `FUN_8006311c` — submit completion/poll kick helper.

### `803ac1a4` — Packet-port table register/status-dispatch helper

Rename:

```text
fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate
```

Signature:

```c
uint32_t fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate(packet_port_submit_record_34_candidate *port_record)
```

False Ghidra function splits to delete:

```text
FUN_803ac268
FUN_803ac26c
FUN_803ac318
```

Reason:

- These are internal blocks of the real `803ac1a4` function.
- `803ac1a4` owns the stack prologue.
- The return path restores `ra/s0` and `sp` at `803ac41c..803ac428`.

Behavior:

- Clears `81a8d7b0..81a8d7bb`.
- Builds a local stack status/context record.
- If `g_packet_port_table_first_register_latch_81479F6C_candidate == 1`:
  - Stores base port/id from `port_record +0x04` into `g_packet_port_table_base_port_id_81840008_candidate`.
  - Copies the `0x34`-byte `port_record` into all 16 packet-port table entries.
- Otherwise:
  - Computes `index = port_record->field_04 - g_packet_port_table_base_port_id_81840008_candidate`.
  - Copies the `0x34`-byte `port_record` into `table[index]`.
- If `port_record->core_cmd_args_ptr_28_candidate` is non-null:
  - Copies 12 bytes from that pointer into `81a8d7b0..81a8d7bb`.
- Normal status path:
  - Computes table index from port/base id.
  - Writes `port_record->field_04` into table entry `+0x34`.
  - Calls `table[index].status_callback_08(stack_context, table[index].callback_arg_2c)`.
- First/force path:
  - Clears `g_packet_port_table_first_register_latch_81479F6C_candidate`.
  - Writes `port_record->field_04` into `table[0].+0x34`.
  - Calls `table[0].status_callback_08(stack_context, table[0].callback_arg_2c)`.
- If the status callback returns nonzero:
  - Logs `GOT BFC_STATUS_FAILURE`.
  - Returns `0xc0000001`.
- Otherwise returns `0`.

Status: about 75% understood.

### `803ac42c` — GMAC/PHY link-control callback candidate

Rename:

```text
fn_enet_gmac_phy_link_control_callback_803ac42c_candidate
```

Signature:

```c
int32_t fn_enet_gmac_phy_link_control_callback_803ac42c_candidate(uint32_t request_code, uint32_t unused_arg1_candidate, void *request_buf, int32_t request_arg_or_len)
```

False Ghidra function splits to delete:

```text
FUN_803ac658
FUN_803ac704
FUN_803ac720
FUN_803ac73c
FUN_803ac758
FUN_803ac774
FUN_803ac790
```

Reason:

- These are internal blocks of the real `803ac42c` function.
- `803ac42c` has the stack prologue.
- `803ac790` is the epilogue, restoring saved registers and stack.

Request-code behavior:

| Request code | Interpretation | Behavior |
|---:|---|---|
| `0` | set speed candidate | Accepts `1000`, `100`, `10`. MDIO/BMCR mapping: `1000 -> 0x0040`, `100 -> 0x2000`, `10 -> 0x0000`. |
| `1` | set duplex candidate | Toggles MDIO BMCR full-duplex bit `0x0100`; also toggles GMAC/UniMAC base `+0x208` bit `0x0400`. |
| `2` | autoneg/manual-link mode candidate | Clears BMCR autoneg bit `0x1000` on disabled path; sets `0x1200` on enabled/restart path. |
| `3` | special response | Returns `0x40000106`. |
| `0x400a0011` | byte query/check | Reads a byte through `FUN_8014d340`; returns `0` only when parsed byte is nonzero. |
| other | unsupported | Returns `0xc0010017`. |

Hardware paths:

- Managed-switch/external-PHY path:
  - Uses `fn_enet_extphy_spi_read_offset_checked_803c5cf8_candidate`.
  - Uses `fn_enet_extphy_serial_management_init_sequence_803c5ac8_candidate`.
- Direct-PHY path:
  - Uses `fn_enet_mdio_read16_wait_803af8cc_candidate`.
  - Uses `fn_enet_mdio_write_phy_reg_wait_803affac_candidate`.

Return values:

| Value | Meaning candidate |
|---:|---|
| `0` | success |
| `0xc0000001` | generic failure / disabled path |
| `0xc0010017` | unsupported request code |
| `0x40000106` | special response for request `3` |

Status: about 80% understood.

### `803af8b0` and `803af8cc` — GENET MDIO read paths

Current labels:

```text
803af8b0  fn_enet_mdio_read16_default_phy_wait_803af8b0_candidate
803af8cc  fn_enet_mdio_read16_wait_803af8cc_candidate
```

`803af8b0` is an alternate/default-PHY entry that clamps/selects MDIO bus/default mode and falls through to the read core.

Recommended signature for the core:

```c
uint32_t fn_enet_mdio_read16_wait_803af8cc_candidate(uint32_t mdio_selector, uint32_t reg_num, uint32_t *wait_count, uint32_t mdio_bus_or_unused)
```

Important ABI note:

- The core path appears to use `t0` for PHY address bits in the command word.
- Do not force the final ABI until wrapper/caller evidence is cleaned.

Behavior of `803af8cc`:

- Selects MDIO0 base `b2c00600` or MDIO1 base `b2c02600`.
- Builds MDIO read command:

```text
0x20000000 | 0x08000000 |
((phy_addr & 0x1f) << 21) |
((reg_num  & 0x1f) << 16)
```

- Writes command to base `+0x2c`.
- Polls base `+0x32` bit0 until clear, max `0xc8` polls.
- Stores poll count to `wait_count`.
- Returns zero-extended 16-bit read data from base `+0x2e`, which is an offcut halfword inside the command/read-data word at base `+0x2c`.

Return type note:

- Hardware value is 16-bit, but the MIPS return register is 32-bit zero-extended.
- Use `uint32_t` return type in Ghidra to avoid fake `CONCAT22(extraout_var, ...)` artifacts in callers.

## GENET MDIO MMIO layout

### MDIO0

| Address | Label | Datatype | Notes |
|---:|---|---|---|
| `b2c00600` | `GENET_MDIO0_BASE_B2C00600` | base label | KSEG1 alias for physical `0x12c00600`. |
| `b2c0062c` | `GENET_MDIO0_CMD_B2C0062C` | `/tc7200u/mmio/vuint32_t` | Command/control word; also contains read-data halfword at offcut `+0x2e`. |
| `b2c00630` | `GENET_MDIO0_WDATA_B2C00630` | `/tc7200u/mmio/vuint16_t` | Write-data halfword. |
| `b2c00632` | `GENET_MDIO0_STATUS_B2C00632` | `/tc7200u/mmio/vuint16_t` | Status/busy halfword; bit0 = busy. |

### MDIO1

| Address | Label | Datatype | Notes |
|---:|---|---|---|
| `b2c02600` | `GENET_MDIO1_BASE_B2C02600` | base label | KSEG1 alias for physical `0x12c02600`. |
| `b2c0262c` | `GENET_MDIO1_CMD_B2C0262C` | `/tc7200u/mmio/vuint32_t` | Command/control word; also contains read-data halfword at offcut `+0x2e`. |
| `b2c02630` | `GENET_MDIO1_WDATA_B2C02630` | `/tc7200u/mmio/vuint16_t` | Write-data halfword. |
| `b2c02632` | `GENET_MDIO1_STATUS_B2C02632` | `/tc7200u/mmio/vuint16_t` | Status/busy halfword; bit0 = busy. |

### No standalone `+0x2e` symbols

Do not create these labels/data items:

```text
B2C0062E
B2C0262E
```

Reason:

- `+0x2e` is an offcut halfword inside the existing 32-bit command/read-data word at `+0x2c`.
- Ghidra cannot cleanly represent both `vuint32_t` at `+0x2c` and `vuint16_t` at `+0x2e` as normal non-overlapping data.
- Keep `+0x2e` documented only in comments.

Recommended comments:

```text
Pre comment @b2c0062c:
GENET MDIO0 command/read-data alias register.

Known accesses:
  +0x2c = command/control word, accessed as 32-bit write
  +0x2e = read-data halfword inside the +0x2c word, read by {@symbol fn_enet_mdio_read16_wait_803af8cc_candidate}
  +0x30 = write-data halfword
  +0x32 = status/busy halfword, bit0 = busy

Ghidra note:
  Keep only {@address b2c0062c} as vuint32_t.
  Do not create a separate symbol/data item at b2c0062e because it overlaps the command word.
```

```text
Pre comment @b2c0262c:
GENET MDIO1 command/read-data alias register.

Known accesses:
  +0x2c = command/control word, accessed as 32-bit write
  +0x2e = read-data halfword inside the +0x2c word, read by {@symbol fn_enet_mdio_read16_wait_803af8cc_candidate}
  +0x30 = write-data halfword
  +0x32 = status/busy halfword, bit0 = busy

Ghidra note:
  Keep only {@address b2c0262c} as vuint32_t.
  Do not create a separate symbol/data item at b2c0262e because it overlaps the command word.
```

## Ghidra comments added / recommended

### `81a8d7c0` packet-port table

```text
Pre comment @81a8d7c0:
Packet/FPM per-port submit table.

Entry size is 0x44.
Entry count proven by {@symbol fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate}: 16 entries.

Layout:
  [0]  81a8d7c0
  [1]  81a8d804
  [2]  81a8d848
  [3]  81a8d88c
  [4]  81a8d8d0
  [15] 81a8dbbc
  end  81a8dbff

Known fields:
  +0x08 status_callback_08
  +0x10 submit_callback_10
  +0x28 core_cmd_args_ptr_28_candidate
  +0x2c callback_arg_2c
  +0x34 full port/id value written by register/status path
  +0x36 low half copied into submit descriptor by {@symbol fn_dma_fpm_packet_token_prepare_and_submit_8002b410_candidate}

This table is registered/managed by {@symbol fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate}.
```

### `803ac1a4` packet-port register/status function

```text
Plate comment @803ac1a4:
Packet/FPM port submit-table register and status-dispatch helper.

Input:
  port_record = 0x34-byte packet-port submit/status record

Behavior:
  - clears {@address 81a8d7b0}..{@address 81a8d7bb}
  - builds a local stack status/context record
  - if {@address 81479f6c} == 1:
      stores base port/id from port_record +0x04 into {@address 81840008}
      copies the 0x34-byte port_record into all 16 entries of {@address 81a8d7c0}
  - otherwise:
      index = port_record->field_04 - {@address 81840008}
      copies the 0x34-byte port_record into table[index]
  - if port_record->core_cmd_args_ptr_28_candidate is non-NULL:
      copies 12 bytes from that pointer into {@address 81a8d7b0}..{@address 81a8d7bb}
  - normal status path:
      index = port_record->field_04 - {@address 81840008}
      table[index].+0x34 = port_record->field_04
      calls table[index].status_callback_08(stack_context, table[index].callback_arg_2c)
  - first/force path:
      clears {@address 81479f6c}
      table[0].+0x34 = port_record->field_04
      calls table[0].status_callback_08(stack_context, table[0].callback_arg_2c)
  - if status callback returns nonzero:
      logs "GOT BFC_STATUS_FAILURE"
      returns 0xc0000001
  - otherwise returns 0

Important:
  The blocks at {@address 803ac268}, {@address 803ac26c}, and {@address 803ac318}
  are not standalone functions. They are internal blocks of this function.
```

### `803ac42c` GMAC/PHY link-control callback

```text
Plate comment @803ac42c:
GMAC/PHY link-control callback candidate.

Arguments:
  request_code = link/PHY control request id
  unused_arg1_candidate = not used directly in this function
  request_buf = request/source buffer passed to parser helpers
  request_arg_or_len = forwarded to parser helpers

Request behavior:
  request 0:
    parses speed through {@symbol FUN_8014d2e8}
    accepts 1000, 100, or 10
    MDIO path maps speed to BMCR bits:
      1000 -> 0x0040
      100  -> 0x2000
      10   -> 0x0000

  request 1:
    parses duplex through {@symbol FUN_8014d340}
    MDIO path toggles BMCR full-duplex bit 0x0100
    also toggles GMAC/UniMAC register {@address 81840028}+0x208 bit 0x0400

  request 2:
    parses autoneg/manual-link flag through {@symbol FUN_8014d340}
    MDIO path clears BMCR autoneg bit 0x1000 when disabled
    MDIO path sets BMCR bits 0x1200 when enabled/restarted

  request 3:
    returns 0x40000106

  request 0x400a0011:
    parses one byte through {@symbol FUN_8014d340}
    returns 0 only when parsed byte is nonzero

Hardware paths:
  - managed-switch/external-PHY path uses {@symbol fn_enet_extphy_spi_read_offset_checked_803c5cf8_candidate}
    and {@symbol fn_enet_extphy_serial_management_init_sequence_803c5ac8_candidate}
  - direct-PHY path uses {@symbol fn_enet_mdio_read16_wait_803af8cc_candidate}
    and {@symbol fn_enet_mdio_write_phy_reg_wait_803affac_candidate}

Return values:
  0           success
  0xc0000001 generic failure / disabled path
  0xc0010017 unsupported request code
  0x40000106 special response for request 3

Important:
  This is a link/PHY control callback used by the packet-port status/context path.
  It is not a packet submit callback and not a GENET TDMA ring programming routine.
```

## OpenWrt / hardware relevance

The current findings are useful for OpenWrt bring-up because they confirm several OEM ENET/GENET details:

- OEM stage1 uses GENET MDIO windows corresponding to physical bases:
  - `0x12c00600` / KSEG1 `b2c00600`
  - `0x12c02600` / KSEG1 `b2c02600`
- MDIO busy/status bit is bit0 at `base +0x32`.
- MDIO command is a 32-bit write at `base +0x2c`.
- MDIO write-data is a 16-bit field at `base +0x30`.
- MDIO read-data is accessed as a halfword at `base +0x2e`, but that should remain documented as an offcut alias, not as a standalone Ghidra data item.
- `803ac42c` uses GMAC/UniMAC base pointer at `81840028` and toggles `base +0x208` bit `0x0400` during duplex control.
- This work is packet/FPM/PHY control path evidence; it is not a TDMA descriptor ring programming routine.

## Current uncertainty / do not over-name yet

Keep `_candidate` on these names for now:

- `fn_dma_fpm_packet_token_prepare_and_submit_8002b410_candidate`
- `fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate`
- `fn_enet_gmac_phy_link_control_callback_803ac42c_candidate`
- `fn_enet_mdio_read16_default_phy_wait_803af8b0_candidate`
- `fn_enet_mdio_read16_wait_803af8cc_candidate`
- `packet_port_submit_record_34_candidate`
- `packet_port_submit_table_entry_44_candidate`

Reasons:

- Some callback ABIs are still inferred.
- `FUN_8014d2e8` and `FUN_8014d340` parser/helper formats are not yet fully explained.
- `803af8cc` appears to use `t0` for PHY address bits, so the final ABI is still not completely clean.
- Table fields at `+0x00`, `+0x02`, `+0x04`, `+0x0c`, `+0x14..+0x27`, `+0x30`, and `+0x38..+0x43` remain partially unknown.

## Next recommended Ghidra targets

1. `FUN_803ac7ac`
   - Next callback installed into the stack status/context record by `803ac1a4`.
   - Expected to explain more ENET/GMAC status or initialization behavior.

2. `FUN_8014d2e8`
   - Parser/helper used by link-control request `0` to parse speed.

3. `FUN_8014d340`
   - Parser/helper used to parse duplex/autoneg flags and `0x400a0011` byte query.

4. `FUN_8002aa3c`
   - Token-to-packet-buffer translation used by `8002b410`.

5. `FUN_803ac11c`, `FUN_803abdac`, `FUN_803ab5f4`
   - Packet port lookup and fallback/writeback path for submit bridge.

6. `fn_enet_mdio_write_phy_reg_wait_803affac_candidate`
   - Pair with the confirmed read path to complete MDIO read/write documentation.

## Suggested repository action

Recommended target file path:

```text
records/reverse/2026-06-23-ghidra-enet-fpm-mdio-tables.md
```

Suggested commit message:

```text
reverse: document ENET packet-port table and MDIO findings
```
