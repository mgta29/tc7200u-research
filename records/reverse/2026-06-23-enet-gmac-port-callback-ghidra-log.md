# 2026-06-23 ENET/GMAC port callback Ghidra log

## Scope

This log records the current reverse-engineering cleanup for the TC7200U Stage1 ENET/GMAC packet-port registration, PHY link-control, MDIO, managed-switch status, packet-port submit table, and related Ghidra datatype/memory-block work.

The main functions covered are:

- `fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate`
- `fn_enet_gmac_phy_link_control_callback_803ac42c_candidate`
- `fn_enet_gmac_port_status_query_callback_803ac7ac_candidate`
- `fn_enet_mdio_read16_default_phy_wait_803af8b0_candidate`
- `fn_enet_mdio_read16_wait_803af8cc_candidate`

The current result is a cleaner model of the ENET packet-port status/context callbacks and the table at `81a8d7c0`, while keeping uncertain hardware/API naming marked as candidate.

## High-level result

The ENET/GMAC area now separates into three related but distinct objects:

1. **Core command arguments** at `81a8d7b0..81a8d7bb`
2. **Packet/FPM submit table** at `81a8d7c0..81a8dbff`
3. **Manual ENET/GMAC runtime state** at `81a8dc00..81a8dcb7`

The callback chain is now clearer:

- `803ac1a4` registers/copies packet-port submit records into the runtime table.
- It builds a local stack status/context record.
- Table field `status_callback_08` is invoked with:
  - `stack_context`
  - `table[index].callback_arg_2c`
- Inside that stack context:
  - `+0x18` points to `803ac42c`, the link-control callback.
  - `+0x1c` points to `803ac7ac`, the port status/query callback.

Important correction: `803ac42c` and `803ac7ac` are not packet TX submit callbacks. They are ENET status/control callbacks carried inside the status/context object that is passed into `status_callback_08`.

## Memory block and table boundaries

### Confirmed RAM regions

| Range | Size | Label | Interpretation |
|---:|---:|---|---|
| `81a8d7b0..81a8d7b3` | `0x4` | `RAM_STAGE1_ENET_CORE_CMD_ARG0_81A8D7B0_candidate` | Core command arg0 |
| `81a8d7b4..81a8dbff` | `0x44c` | `RAM_STAGE1_ENET_CORE_CMD_ARGS_AND_PORT_TABLE_81A8D7B4_candidate` | Core command args 1/2 plus submit table |
| `81a8d7c0..81a8dbff` | `0x440` | `g_packet_port_submit_table_81A8D7C0_candidate` | `packet_port_submit_table_entry_44_candidate[16]` |
| `81a8dc00..81a8dcb7` | `0xb8` | `RAM_STAGE1_ENET_MANUAL_STATE_81A8DC00` | ENET/GMAC manual runtime state |

Do not merge `81a8dc00` into the packet-port submit table. The table ends at `81a8dbff`; the `81a8dc00` block is a separate ENET/GMAC runtime state block.

### Core command globals

Apply or verify these labels and types:

```text
81a8d7b0  g_enet_core_cmd_arg0_81A8D7B0_candidate  uint32_t
81a8d7b4  g_enet_core_cmd_arg1_81A8D7B4_candidate  uint32_t
81a8d7b8  g_enet_core_cmd_arg2_81A8D7B8_candidate  uint32_t
```

Remove the duplicate overlapping underscore symbol if present:

```text
_g_enet_core_cmd_arg0_81A8D7B0_candidate
```

Keep only:

```text
g_enet_core_cmd_arg0_81A8D7B0_candidate
```

This resolves the warning:

```text
Globals starting with '_' overlap smaller symbols at the same address
```

Expected decompile after cleanup:

```c
g_enet_core_cmd_arg0_81A8D7B0_candidate = puVar6[0];
g_enet_core_cmd_arg1_81A8D7B4_candidate = puVar6[1];
g_enet_core_cmd_arg2_81A8D7B8_candidate = puVar6[2];
```

### Packet-port submit table

Table base:

```text
81a8d7c0  g_packet_port_submit_table_81A8D7C0_candidate
```

Datatype:

```text
packet_port_submit_table_entry_44_candidate[16]
```

Layout:

```text
entry size:  0x44
entry count: 16
total size:  0x440
range:       81a8d7c0..81a8dbff
```

Important entry addresses:

```text
[0]  81a8d7c0
[1]  81a8d804
[2]  81a8d848
[3]  81a8d88c
[4]  81a8d8d0
[15] 81a8dbbc
end  81a8dbff
```

### ENET/GMAC runtime state block

Label:

```text
81a8dc00  g_enet_gmac_init_state_81A8DC00_candidate
```

Block:

```text
RAM_STAGE1_ENET_MANUAL_STATE_81A8DC00
81a8dc00..81a8dcb7
size: 0xb8
```

Current minimal datatype:

```c
struct enet_gmac_init_state_b8_candidate {
    byte raw_00[0x1c];
    uint32_t packet_len_or_error_counter_1c_candidate;
    byte raw_20[0x1c];
    uint8_t link_or_port_state_3c_candidate;
    byte raw_3d[0x7b];
};
```

Category:

```text
/tc7200u/fpm_dma
```

Known current accesses:

- `803acff8` reads `g_enet_gmac_init_state_81A8DC00_candidate +0x1c`
- `803ad248` reads `g_enet_gmac_init_state_81A8DC00_candidate +0x3c`
- `8002b4a8..8002b4b0` increments the `+0x1c` field on packet length out-of-range path

Field meanings are still candidate; keep the struct suffix.

## MMIO/MDIO cleanup

### MDIO physical and KSEG1 aliases

Known physical bases:

```text
0x12c00600  MDIO0 physical base
0x12c02600  MDIO1 physical base
```

Known KSEG1 aliases:

```text
0xb2c00600  MDIO0 KSEG1 alias
0xb2c02600  MDIO1 KSEG1 alias
```

### Ghidra labels to keep

Keep only these MDIO labels in Ghidra:

```text
b2c00600  GENET_MDIO0_BASE_B2C00600
b2c0062c  GENET_MDIO0_CMD_B2C0062C      vuint32_t
b2c00630  GENET_MDIO0_WDATA_B2C00630    vuint16_t
b2c00632  GENET_MDIO0_STATUS_B2C00632   vuint16_t

b2c02600  GENET_MDIO1_BASE_B2C02600
b2c0262c  GENET_MDIO1_CMD_B2C0262C      vuint32_t
b2c02630  GENET_MDIO1_WDATA_B2C02630    vuint16_t
b2c02632  GENET_MDIO1_STATUS_B2C02632   vuint16_t
```

Do not create standalone labels at:

```text
b2c0062e
b2c0262e
```

Reason: `+0x2e` is an offcut halfword inside the `+0x2c` command/read-data word. It remains a real hardware offset for OpenWrt/devmem use, but should not be modeled as a separate normal data item in Ghidra when `+0x2c` is already `vuint32_t`.

### MDIO register comments

Use this comment at `b2c0062c`:

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

Use the equivalent MDIO1 comment at `b2c0262c`.

### MDIO read helpers

Use labels:

```text
803af8b0  fn_enet_mdio_read16_default_phy_wait_803af8b0_candidate
803af8cc  fn_enet_mdio_read16_wait_803af8cc_candidate
```

Use return type `uint32_t`, not `uint16_t`, for `803af8cc`.

Reason: hardware read data is 16-bit, but the MIPS return register is zero-extended to 32-bit:

```text
lhu  v0, 0x2e(mdio_base)
andi v0, v0, 0xffff
jr   ra
```

A `uint16_t` return caused fake decompiler artifacts such as:

```c
CONCAT22(extraout_var, uVar3)
```

Recommended signature:

```c
uint32_t fn_enet_mdio_read16_wait_803af8cc_candidate(uint32_t mdio_selector, uint32_t reg_num, uint32_t *wait_count, uint32_t mdio_bus_or_unused)
```

Keep this warning in the plate comment:

```text
PHY address appears to be carried through t0 in this core path. Do not force the final ABI until the wrapper/default-PHY entry at 803af8b0 is fully cleaned.
```

## Function: 803ac1a4 packet-port table register/status dispatch

### Function label

```text
803ac1a4  fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate
```

### Signature

```c
uint32_t fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate(packet_port_submit_record_34_candidate *port_record)
```

### Behavior

The function:

1. Clears `81a8d7b0..81a8d7bb` with `fn_memset_or_zero_80e93bf0_candidate`.
2. Builds a local `enet_port_status_context_38_candidate`-like stack record.
3. On first-register latch path:
   - sets `g_packet_port_table_base_port_id_81840008_candidate = port_record->port_id_04`
   - copies the same 0x34-byte source record into all 16 entries of the table at `81a8d7c0`
4. On normal path:
   - computes `index = port_record->port_id_04 - g_packet_port_table_base_port_id_81840008_candidate`
   - copies the 0x34-byte source record into `g_packet_port_submit_table_81A8D7C0_candidate[index]`
5. If `port_record->core_cmd_args_ptr_28_candidate` is non-NULL:
   - copies three words into `81a8d7b0..81a8d7bb`
6. Writes the full port id to table field `+0x34`.
7. Calls the table entry status callback:
   - `status_callback_08(&local_status_context, callback_arg_2c)`
8. If the callback returns nonzero:
   - logs `GOT BFC_STATUS_FAILURE`
   - returns `0xc0000001`
9. Otherwise returns `0`.

### False splits to delete

Delete these if Ghidra created them:

```text
FUN_803ac268
FUN_803ac26c
FUN_803ac318
```

They are internal blocks of `803ac1a4`, not standalone functions.

### Corrected field meaning

Important correction:

```text
packet_port_submit_record_34_candidate +0x04 is port_id_04, not callback_or_init_04_candidate.
```

Change:

```text
old: +0x04  void *    callback_or_init_04_candidate
new: +0x04  uint32_t  port_id_04
```

Apply the same correction to `packet_port_submit_table_entry_44_candidate +0x04`.

### Plate comment update

Use this corrected wording:

```text
Plate comment @803ac1a4:
Packet/FPM port submit-table register and status-dispatch helper.

Input:
  port_record = 0x34-byte packet-port submit/status record

Behavior:
  - clears 81a8d7b0..81a8d7bb
  - builds a local stack status/context record
  - if 81479f6c == 1:
      stores base port id from port_record->port_id_04 into 81840008
      copies the 0x34-byte port_record into all 16 entries of 81a8d7c0
  - otherwise:
      index = port_record->port_id_04 - 81840008
      copies the 0x34-byte port_record into table[index]
  - if port_record->core_cmd_args_ptr_28_candidate is non-NULL:
      copies 12 bytes from that pointer into 81a8d7b0..81a8d7bb
  - normal status path:
      index = port_record->port_id_04 - 81840008
      table[index].registered_port_id_34 = port_record->port_id_04
      calls table[index].status_callback_08(stack_context, table[index].callback_arg_2c)
  - first/force path:
      clears 81479f6c
      table[0].registered_port_id_34 = port_record->port_id_04
      calls table[0].status_callback_08(stack_context, table[0].callback_arg_2c)
  - if status callback returns nonzero:
      logs "GOT BFC_STATUS_FAILURE"
      returns 0xc0000001
  - otherwise returns 0

Important:
  The blocks at 803ac268, 803ac26c, and 803ac318 are not standalone functions.
  They are internal blocks of this function.
```

## Function: 803ac42c link-control callback

### Function label

```text
803ac42c  fn_enet_gmac_phy_link_control_callback_803ac42c_candidate
```

### Signature

```c
int32_t fn_enet_gmac_phy_link_control_callback_803ac42c_candidate(uint32_t request_code, uint32_t unused_arg1_candidate, void *request_buf, int32_t request_arg_or_len)
```

### Behavior summary

This is the link/PHY control callback in the ENET status/context object.

It handles request codes:

| Request | Behavior |
|---:|---|
| `0` | set speed candidate; accepts 1000, 100, 10 |
| `1` | set duplex candidate; toggles BMCR bit `0x0100` and GMAC/UniMAC register bit `0x0400` at base+0x208 |
| `2` | set autoneg/manual-link candidate; clears `0x1000` or sets `0x1200` in BMCR |
| `3` | returns `0x40000106` |
| `0x400a0011` | parses one byte; returns `0` only when parsed byte is nonzero |

Unsupported request codes return:

```text
0xc0010017
```

Disabled/generic failure returns:

```text
0xc0000001
```

### False splits to delete

Delete these if present:

```text
FUN_803ac658
FUN_803ac704
FUN_803ac720
FUN_803ac73c
FUN_803ac758
FUN_803ac774
FUN_803ac790
```

Real function range:

```text
803ac42c..803ac7a8
```

## Function: 803ac7ac port status/query callback

### Function label

```text
803ac7ac  fn_enet_gmac_port_status_query_callback_803ac7ac_candidate
```

### Signature

```c
int32_t fn_enet_gmac_port_status_query_callback_803ac7ac_candidate(uint32_t request_code, uint32_t port_id, void *out_buf, uint32_t *out_len)
```

### Behavior summary

This is the read/query side of the ENET port callback interface. It is paired with `803ac42c`, which handles set/control-style link requests.

It:

- normalizes `port_id` against `g_packet_port_table_base_port_id_81840008_candidate`
- returns scalar values through `fn_stage1_result_put_uint32_8003874c_candidate`
- returns small integer values through `fn_stage1_result_put_int_8014d384_candidate`
- returns boolean/enum values through `fn_stage1_result_put_bool_8014d3c4_candidate`
- reads direct PHY state through MDIO register `0x19`
- reads managed-switch/EXT-PHY state through `fn_enet_managed_switch_stat_read_803aba74_candidate` and `fn_enet_extphy_spi_read_offset_checked_803c5cf8_candidate`
- reads direct GMAC counters through `g_enet_unimac_or_gmac_regs_base_ptr_81840028_candidate`
- reads a small amount of state from `g_enet_gmac_init_state_81A8DC00_candidate`

### False splits to delete

Delete these if Ghidra created them:

```text
FUN_803acac0
FUN_803acb30
FUN_803acb94
FUN_803acc10
FUN_803accd8
FUN_803acd00
FUN_803acd78
FUN_803ad6fc
```

Real function range:

```text
803ac7ac..803ad720
```

### Main request-code map

| Request | Current interpretation |
|---:|---|
| `0x00000000` | current speed in Mbps candidate: 10, 100, 1000, or fallback 0x28 |
| `0x00000001` | link-up/link-present boolean candidate |
| `0x00000002` | duplex/status boolean candidate from MDIO reg `0x19` bit `0x10` or EXT-PHY bit `0x10` |
| `0x00000003` | returns `0x40000106` |
| `0x40016d04` | returns Broadcom BCM/revision/Ethernet string |
| `0x40016d06` | returns MTU 1500 |
| `0x40016d07` | returns link speed in bps: 1G/100M/10M/0 |
| `0x40016d08` | returns port/link enum candidate: 1, 2, or 5 |
| `0x40016d0c` | per-port offset `0x50`, or GMAC base+`0x670` for special port `0xffff` |
| `0x40016d0d` | per-port offset `0x94` |
| `0x40016d0f` | `g_enet_gmac_init_state_81A8DC00_candidate +0x1c` |
| `0x40016d10` | sum of managed-switch offsets `0x58+0x78+0x80+0x84+0xa4+0xa8+0xac` |
| `0x40016d12` | per-port offset `0x00`, or GMAC base+`0x6ec` for port `0xffff` |
| `0x40016d13` | per-port offset `0x18` |
| `0x40016d14` | sum of offsets `0x14+0x10` |
| `0x40016d16` | sum of offsets `0x1c+0x20+0x24+0x28+0x2c+0x30+0x34` |
| `0x40016d17` | `g_enet_gmac_init_state_81A8DC00_candidate +0x3c` |
| `0x400a0003` | managed-switch offset `0x98` |
| `0x400a0004` | managed-switch offset `0x9c` |
| `0x400a0005` | managed-switch offset `0x14` |
| `0x400a0006` | managed-switch offset `0x10` |
| `0x400a0010` | current speed in Mbps candidate: 10, 100, 1000 |
| `0x400a0011` | boolean true |
| `0x400a0012` | boolean true |
| `0x400a0014` | boolean false |
| `0x400a0102` | GMAC base+`0x610`, or managed-switch offset `0x80` |
| `0x400a0103` | GMAC base+`0x600`, or managed-switch offset `0x84` |
| `0x400a0104` | GMAC base+`0x6a0`, or managed-switch offset `0x20` |
| `0x400a0105` | GMAC base+`0x6a4`, or managed-switch offset `0x24` |
| `0x400a0106` | returns 0 |
| `0x400a0107` | GMAC base+`0x698`, or managed-switch offset `0x28` |
| `0x400a0108` | GMAC base+`0x6a8`, or managed-switch offset `0x2c` |
| `0x400a0109` | GMAC base+`0x6ac`, or managed-switch offset `0x30` |
| `0x400a010a` | returns 0 |
| `0x400a010b` | GMAC base+`0x61c`, or returns `0x40000106` in managed-switch path |
| `0x400a010d` | GMAC base+`0x620` + base+`0x624`, or managed-switch offsets `0x78+0x7c` |
| `0x400a0110` | managed-switch offset `0x90` |
| `0x400a0112` | managed-switch offset `0xac` |
| `0x400a0113` | link-state enum candidate: 1/2/3 |
| `0x41100002` | link-state enum candidate using `+0x3c` path |

Unsupported selectors return:

```text
0xc0010017
```

### Function labels inside 803ac7ac

Apply these as labels only, not standalone functions:

```text
803ac7ac  fn_enet_gmac_port_status_query_callback_803ac7ac_candidate
803acab4  LAB_enet_query_speed_mbps_803acab4
803acbd8  LAB_enet_query_link_present_bool_803acbd8
803acc80  LAB_enet_query_duplex_or_status_bool_803acc80
803acd08  LAB_enet_query_driver_name_string_803acd08
803acd74  LAB_enet_query_mtu_1500_803acd74
803acd8c  LAB_enet_query_speed_bps_803acd8c
803acf24  LAB_enet_query_port_enum_803acf24
803ad638  LAB_enet_query_put_u32_803ad638
803ad6ec  LAB_enet_query_put_bool_or_enum_803ad6ec
803ad700  LAB_enet_query_epilogue_803ad700
```

## Datatypes

### Function definitions

Create under:

```text
/tc7200u/fpm_dma
```

```c
int32_t enet_port_link_control_callback_fn_candidate(uint32_t request_code, uint32_t unused_arg1_candidate, void *request_buf, int32_t request_arg_or_len)
```

```c
int32_t enet_port_status_query_callback_fn_candidate(uint32_t request_code, uint32_t port_id, void *out_buf, uint32_t *out_len)
```

### packet_port_status_callback_fn_candidate

```c
uint32_t packet_port_status_callback_fn_candidate(void *stack_context, void *callback_arg)
```

Used by:

```text
packet_port_submit_record_34_candidate +0x08
packet_port_submit_table_entry_44_candidate +0x08
```

### packet_port_submit_callback_fn_candidate

Keep current function definition if already present. Suggested candidate shape:

```c
void packet_port_submit_callback_fn_candidate(void *submit_desc, void *callback_arg)
```

Do not over-finalize until its caller and descriptor struct are fully clean.

### packet_port_submit_record_34_candidate

Corrected layout:

```c
struct packet_port_submit_record_34_candidate {
    uint16_t field_00_candidate;
    uint16_t field_02_candidate;
    uint32_t port_id_04;
    packet_port_status_callback_fn_candidate *status_callback_08;
    uint32_t field_0c_candidate;
    packet_port_submit_callback_fn_candidate *submit_callback_10;
    byte raw_14[0x14];
    uint32_t *core_cmd_args_ptr_28_candidate;
    void *callback_arg_2c;
    uint32_t field_30_candidate;
};
```

Category:

```text
/tc7200u/fpm_dma
```

### packet_port_submit_table_entry_44_candidate

Corrected table entry layout:

```c
struct packet_port_submit_table_entry_44_candidate {
    uint16_t field_00_candidate;
    uint16_t field_02_candidate;
    uint32_t port_id_04;
    packet_port_status_callback_fn_candidate *status_callback_08;
    uint32_t field_0c_candidate;
    packet_port_submit_callback_fn_candidate *submit_callback_10;
    byte raw_14[0x14];
    uint32_t *core_cmd_args_ptr_28_candidate;
    void *callback_arg_2c;
    uint32_t field_30_candidate;
    uint32_t registered_port_id_34;
    byte raw_38[0x0c];
};
```

Size:

```text
0x44
```

Important component comment for `+0x34`:

```text
Full 32-bit port id written by {@symbol fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate}.
Low 16 bits at +0x36 are later used as descriptor_port_value_36 by {@symbol fn_dma_fpm_packet_token_prepare_and_submit_8002b410_candidate}.
```

If preserving the old split field is more useful for `8002b410`, keep the split as comments only; avoid overlapping data fields unless required.

### enet_port_status_context_38_candidate

The user-created layout is correct in size and offsets. Since Ghidra Data Type Manager does not offer `code *`, keep unknown callback/function-address slots as `void *` and document targets in component comments.

Final Ghidra-safe layout:

```c
struct enet_port_status_context_38_candidate {
    uint16_t field_00;
    uint16_t field_02;
    void *init_main_04;
    uint32_t field_08_uninit_candidate;
    uint32_t field_0c_zero;
    uint32_t field_10_uninit_candidate;
    uint32_t field_14_uninit_candidate;
    enet_port_link_control_callback_fn_candidate *link_control_callback_18;
    enet_port_status_query_callback_fn_candidate *status_query_callback_1c;
    void *callback_20_candidate;
    void *callback_24_candidate;
    uint32_t field_28_zero;
    void *packet_free_callback_2c;
    uint32_t field_30_zero;
    void *callback_34_candidate;
};
```

Size:

```text
0x38
```

Category:

```text
/tc7200u/fpm_dma
```

Component comments:

```text
+0x04  -> {@symbol fn_enet_gmac_init_main_803ad874_candidate}
+0x18  -> {@symbol fn_enet_gmac_phy_link_control_callback_803ac42c_candidate}
+0x1c  -> {@symbol fn_enet_gmac_port_status_query_callback_803ac7ac_candidate}
+0x20  -> {@symbol FUN_803aedd4}
+0x24  -> {@symbol FUN_803aeeb0}
+0x2c  -> {@symbol fn_dma_fpm_packet_free_callback_8002a4ac_candidate}
+0x34  -> {@symbol FUN_80032f28}
```

Do not force this structure onto the stack if Ghidra decompilation becomes worse. Keeping it in the Data Type Manager plus comments is sufficient.

## Helper signatures

### Managed-switch stat helper

```c
int32_t fn_enet_managed_switch_stat_read_803aba74_candidate(uint32_t port_index, uint32_t stat_offset, uint32_t *out_value)
```

This helper is the next main reverse target. It controls the meaning of the managed-switch stat offsets used heavily by `803ac7ac`.

### Managed-switch port active helper

```c
bool fn_enet_managed_switch_port_active_803ab9b4_candidate(uint32_t port_index)
```

### Result-output helpers

Keep these candidate signatures until one more caller confirms the exact output format:

```c
int32_t fn_stage1_result_put_uint32_8003874c_candidate(void *out_buf, uint32_t *out_len, uint32_t value)
```

```c
int32_t fn_stage1_result_put_int_8014d384_candidate(void *out_buf, uint32_t *out_len, uint32_t value)
```

```c
int32_t fn_stage1_result_put_bool_8014d3c4_candidate(void *out_buf, uint32_t *out_len, uint32_t value)
```

### String/format helpers

Current evidence shows `803ac7ac` uses:

```text
FUN_8014d418
func_0x8014d448
FUN_80e99988
FUN_80ea0820
```

for the `0x40016d04` Broadcom/Ethernet string path.

Do not finalize these names until their own callers are checked.

## Globals

Apply or verify:

```text
81479f6c  g_packet_port_table_first_register_latch_81479F6C_candidate  uint8_t
81479f71  g_enet_phy_link_control_enable_81479F71_candidate            uint8_t
81479f80  g_enet_managed_switch_link_monitor_enable_81479F80_candidate uint8_t
81840008  g_packet_port_table_base_port_id_81840008_candidate          uint32_t
81840028  g_enet_unimac_or_gmac_regs_base_ptr_81840028_candidate       /tc7200u/mmio/vuint32_t *
81a8d7b0  g_enet_core_cmd_arg0_81A8D7B0_candidate                      uint32_t
81a8d7b4  g_enet_core_cmd_arg1_81A8D7B4_candidate                      uint32_t
81a8d7b8  g_enet_core_cmd_arg2_81A8D7B8_candidate                      uint32_t
81a8d7c0  g_packet_port_submit_table_81A8D7C0_candidate                packet_port_submit_table_entry_44_candidate[16]
81a8dc00  g_enet_gmac_init_state_81A8DC00_candidate                    enet_gmac_init_state_b8_candidate
```

## Ghidra comment/action list

### Pre comments in `803ac1a4`

```text
Pre comment @803ac1e8:
Stores {@symbol fn_enet_gmac_phy_link_control_callback_803ac42c_candidate}
into enet_port_status_context_38_candidate.+0x18.
```

```text
Pre comment @803ac1f4:
Stores {@symbol fn_enet_gmac_port_status_query_callback_803ac7ac_candidate}
into enet_port_status_context_38_candidate.+0x1c.
```

### Table pre-comment at `81a8d7c0`

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
  +0x04 port_id_04
  +0x08 status_callback_08
  +0x10 submit_callback_10
  +0x28 core_cmd_args_ptr_28_candidate
  +0x2c callback_arg_2c
  +0x34 registered_port_id_34

This table is registered/managed by {@symbol fn_packet_port_submit_table_register_and_status_dispatch_803ac1a4_candidate}.
```

### Manual state pre-comment at `81a8dc00`

```text
Pre comment @81a8dc00:
ENET/GMAC manual init/runtime state block.

Size: 0xb8 bytes.
Range: {@address 81a8dc00}..{@address 81a8dcb7}.
This starts immediately after the packet/FPM submit table at {@address 81a8d7c0}..{@address 81a8dbff}; do not merge with the 0x44-entry table.

Known current fields:
  +0x1c packet_len_or_error_counter_1c_candidate
  +0x3c link_or_port_state_3c_candidate

Build additional fields only from concrete reads/writes in GMAC init and status/query functions.
```

## Scalar-search decimal values

Ghidra scalar search in this setup uses decimal input. Useful request-code decimals:

```text
0x40016d04 = 1073835268
0x40016d06 = 1073835270
0x40016d07 = 1073835271
0x40016d08 = 1073835272
0x40016d0c = 1073835276
0x40016d0d = 1073835277
0x40016d0f = 1073835279
0x40016d10 = 1073835280
0x40016d12 = 1073835282
0x40016d13 = 1073835283
0x40016d14 = 1073835284
0x40016d16 = 1073835286
0x40016d17 = 1073835287
0x400a0003 = 1074397187
0x400a0004 = 1074397188
0x400a0005 = 1074397189
0x400a0006 = 1074397190
0x400a0010 = 1074397200
0x400a0011 = 1074397201
0x400a0012 = 1074397202
0x400a0014 = 1074397204
0x400a0102 = 1074397442
0x400a0103 = 1074397443
0x400a0104 = 1074397444
0x400a0105 = 1074397445
0x400a0106 = 1074397446
0x400a0107 = 1074397447
0x400a0108 = 1074397448
0x400a0109 = 1074397449
0x400a010a = 1074397450
0x400a010b = 1074397451
0x400a010d = 1074397453
0x400a0110 = 1074397456
0x400a0112 = 1074397458
0x400a0113 = 1074397459
0x41100002 = 1091567618
```

## OpenWrt-facing implications

The cleanup reinforces these points for the TC7200U OpenWrt ENET bring-up:

- MDIO bases remain high-confidence:
  - `0x12c00600`
  - `0x12c02600`
- MDIO offsets remain:
  - `+0x2c` command/control
  - `+0x2e` read-data halfword, hardware/devmem only; do not make separate Ghidra data label if it overlaps `+0x2c`
  - `+0x30` write-data
  - `+0x32` status/busy bit0
- `803ac7ac` maps many OEM status/query requests to direct GMAC counter offsets.
- Managed-switch stat offsets are not yet final register names; `803aba74` must be cleaned before promoting those offsets to final OpenWrt constants.
- The `81a8dc00` runtime state block is not the packet table and should remain separate.

## Completed cleanup status

Completed / high-confidence:

```text
- packet-port table boundary at 81a8d7c0..81a8dbff
- separate ENET/GMAC state block at 81a8dc00..81a8dcb7
- 803ac1a4 role as packet-port table register/status-dispatch helper
- 803ac42c role as link-control callback
- 803ac7ac role as status/query callback
- +0x04 port id correction in packet_port_submit_record_34_candidate
- +0x34 registered port id field in runtime table entry
- MDIO +0x2e no-standalone-label rule in Ghidra
- callback function definitions for +0x18 and +0x1c status context fields
- `void *` remains correct for unknown function-pointer slots when Ghidra lacks selectable `code *`
```

Still candidate / next work:

```text
- exact public/API names for request codes
- exact meaning of many managed-switch stat offsets
- exact callback ABIs for context fields +0x20, +0x24, +0x2c, +0x34
- exact full layout of enet_gmac_init_state_b8_candidate
- exact direct GMAC counter names at base+0x600..0x6ec
- final ABI for MDIO read core due to t0-carried PHY address evidence
```

## Next reverse targets

### 1. `FUN_803aba74`

Priority target.

Reason: it is the managed-switch/stat read helper used heavily by `803ac7ac`. Cleaning it should turn offsets like `0x10`, `0x14`, `0x18`, `0x20`, `0x24`, `0x28`, `0x2c`, `0x30`, `0x34`, `0x58`, `0x78`, `0x7c`, `0x80`, `0x84`, `0x90`, `0x94`, `0x98`, `0x9c`, `0xa4`, `0xa8`, and `0xac` into a real switch-stat/register model.

Suggested label:

```text
fn_enet_managed_switch_stat_read_803aba74_candidate
```

Suggested current signature:

```c
int32_t fn_enet_managed_switch_stat_read_803aba74_candidate(uint32_t port_index, uint32_t stat_offset, uint32_t *out_value)
```

### 2. `FUN_803ab9b4`

Reason: used by `803ac7ac` request `0x40016d08` to decide port enum/status result.

Suggested label:

```text
fn_enet_managed_switch_port_active_803ab9b4_candidate
```

### 3. `fn_enet_gmac_init_main_803ad874_candidate`

Reason: first callback in the local status/context record at `+0x04`; likely explains how `g_enet_gmac_init_state_81A8DC00_candidate` fields are initialized.

## Repo handling notes

Requested destination:

```text
u:\home\mgta29\tc7200u-research\records\reverse\
```

WSL equivalent:

```text
~/tc7200u-research/records/reverse/
```

Preserve old logs and records. Do not delete or overwrite existing reverse logs. Add this file as a new dated record.

Suggested commit message:

```text
reverse: document ENET GMAC port callback cleanup
```
