# 2026-06-21 NATP / Host-DQM Ghidra Reverse Log

## Metadata

| Field | Value |
|---|---|
| Date | 2026-06-21 |
| Program | `image.raw` / TC7200U stage1 firmware |
| Ghidra language/base | `MIPS:BE:32:default`, base `0x80004000` |
| Export snapshot | labels exported at `20260621-171929` |
| Exported labels | `1465` |
| Exported datatypes | `247` |
| Exported memory blocks | `58` |
| Working area | Host-DQM, FAP/bypass DQM queues, NATP/no-match RX manager |

## Scope

This log records the Ghidra work and findings from the current Host-DQM / downstream-DQM / NATP no-match RX pass. It preserves the concrete findings, structures, datatypes, tables, function labels, false function splits, and memory-block assumptions needed to continue the reverse-engineering work without redoing the same cleanup.

The focus was the object model and command path around:

```text
808440b0  Host-DQM base/channel object init
80845484  downstream/DTP command-channel object init
80845a7c  downstream queue object init
80845c58  NATP/no-match RX manager init
80845de0  NATP/no-match RX manager singleton getter
80845e44  InitializeNapDqmMessageChannel command
80845f34  NatpFfeOffsets query command
81826978  base Host-DQM ops table
81826988  downstream command-channel ops table
81826998  downstream queue ops table
```

## High-level results

1. The Host-DQM object model is now substantially mapped.
2. `host_dqm_channel_obj_candidate` is the base object, length `0x5c`.
3. `host_downstream_dqm_queue_obj_candidate` embeds the base object at `+0x00` and extends it to `0x6c`.
4. The ops-table cluster at `81826978..818269a7` is a vtable-like cleanup table cluster, not single pointer data.
5. The two ops entries are now understood as:
   - `destroy_00`: cleanup without freeing self
   - `destroy_and_free_04`: cleanup and heap-free self
6. `fn_host_downstream_dqm_command_channel_obj_init_80845484_candidate` creates an MSP command-channel object.
7. `fn_host_downstream_dqm_queue_obj_init_80845a7c_candidate` creates downstream data/bypass queue objects and stores the FPM allocator pointer at `+0x68`.
8. `fn_natp_nomatch_rx_manager_init_80845c58_candidate` creates a Host-DQM object using selector `4 / MPEG_PROC`, queue index `0x10`, channel index `0x11`.
9. NATP/no-match RX manager singleton is at `8173fb24`.
10. Two NATP Host-DQM commands were identified:
    - opcode `0x02`: initialize NATP/NAP DQM message channel
    - opcode `0x0e`: query NATP FFE offsets
11. Several Ghidra false function splits were identified and should be removed as function definitions only.

## Memory-block status

### Required Host-DQM MMIO blocks

These blocks must remain `rwv`, volatile, non-executable, uninitialized, non-overlay.

| Address range | Name | Role |
|---:|---|---|
| `b8000000..b8001fff` | `MMIO_HOST_DQM_UTP_B8000000_candidate` | Host-DQM UTP selector 0 |
| `b8200000..b8201fff` | `MMIO_HOST_DQM_MSP_B8200000_candidate` | Host-DQM MSP selector 1 |
| `b8400000..b8401fff` | `MMIO_HOST_DQM_FAP_B8400000_candidate` | Host-DQM FAP selector 2 |
| `b8600000..b8601fff` | `MMIO_HOST_DQM_MSG_PROC_B8600000_candidate` | Host-DQM MSG_PROC selector 3 |
| `b8a00000..b8a01fff` | `MMIO_HOST_DQM_MPEG_PROC_B8A00000_candidate` | Host-DQM MPEG_PROC selector 4 |
| `b8800000..b8801fff` | `MMIO_HOST_DQM_PMC_B8800000_candidate` | Host-DQM PMC selector 5 |

### Other relevant MMIO / RAM blocks

| Address range | Name | Role |
|---:|---|---|
| `12200000..12200fff` | `MMIO_FPM_PHYS_12200000` | FPM physical window |
| `b2200000..b2200fff` | `MMIO_FPM_KSEG1_B2200000` | FPM KSEG1 MMIO window |
| `12c00000..12c03fff` | `MMIO_GENET_PHYS_12C00000` | GENET physical window |
| `b2c00000..b2c03fff` | `MMIO_GENET_KSEG1_B2C00000` | GENET KSEG1 window |
| `14e00000..14e00fff` | `MMIO_PERIPH_INTC_PHYS_14E00000` | physical peripheral IRQ/control window |
| `b4e00000..b4e00fff` | split `MMIO_PERIPH_INTC_KSEG1_*` blocks | KSEG1 peripheral IRQ/control window |
| `81910000..8191ffff` | `RAM_UNKNOWN_81910000_candidate` | contains Host-DQM dispatch table region `81916fd8/819172d8` and NATP statics around `819176xx` |
| `81883e00..81883fff` | `BSS_STAGE1_FAP_BYPASS_81883E00_candidate` | FAP/bypass singleton region; needed for `81883e18` and `81883e20` |

### No new memory blocks required from the latest functions

The NATP/no-match RX object in `80845c58` uses selector `4 / MPEG_PROC`; all resolved Host-DQM windows stay inside `b8a00000..b8a01fff`:

```text
host_dqm_base                  = b8a00000
register_block                 = b8a01800
tx_submit_window_3c            = b8a01d00
tx_credit_or_depth_ptr_40      = b8a01f40
record_words                   = b8a01d10
queue_index_or_cursor_ptr_44   = b8a01f44
```

## Core Host-DQM object datatypes

### `host_dqm_object_ops_candidate`

Located in category:

```text
/tc7200u/dqm_host_fap
```

```text
typedef void host_dqm_obj_ops_fn_candidate(void *self);

typedef struct host_dqm_object_ops_candidate {
    host_dqm_obj_ops_fn_candidate *destroy_00;
    host_dqm_obj_ops_fn_candidate *destroy_and_free_04;
    host_dqm_obj_ops_fn_candidate *method_08_null;
    host_dqm_obj_ops_fn_candidate *method_0c_null;
} host_dqm_object_ops_candidate;
```

### `host_dqm_channel_obj_candidate`

Current confirmed layout:

```text
typedef struct host_dqm_channel_obj_candidate {
    host_dqm_object_ops_candidate *ops_table;              // +0x00
    char *name_copy_04;                                    // +0x04
    uint32_t queue_index_a_08;                             // +0x08
    uint32_t channel_index;                                // +0x0c
    uint32_t init_flag_byte_10;                            // +0x10
    uint32_t queue_or_expected_index_14;                   // +0x14
    uint32_t queue_a_initial_index_18;                     // +0x18
    dma_allocator_global_state_81848740_candidate *fpm_allocator_1c; // +0x1c
    uint32_t record_word_count_or_limit;                   // +0x20
    uint32_t host_dqm_selector;                            // +0x24
    uint32_t host_dqm_base;                                // +0x28
    host_dqm_register_block_1800_candidate *register_block; // +0x2c
    uint32_t *queue_a_window_1a00_30;                      // +0x30
    uint32_t *queue_b_window_1a00_34;                      // +0x34
    uint32_t *record_words;                                // +0x38
    uint32_t *tx_submit_window_3c;                         // +0x3c
    uint32_t *tx_credit_or_depth_ptr_40;                   // +0x40
    uint32_t *queue_index_or_cursor_ptr_44;                // +0x44
    uint32_t tx_submit_count_48;                           // +0x48
    uint32_t tx_no_credit_error_count_4c;                  // +0x4c
    uint32_t ready_copy_count_50;                          // +0x50
    uint32_t field_54_dead_len_check_candidate;            // +0x54
    uint32_t queue_delta_high_water_58;                    // +0x58
} host_dqm_channel_obj_candidate;
```

Notes:

- `+0x00` ops table can point to `81826978`, `81826988`, or `81826998`.
- `+0x24` is the Host-DQM selector: `0..5`.
- `+0x28` is the selected Host-DQM base.
- `+0x2c` is normally `base + 0x1800`.
- `+0x3c` is the submit payload destination window.
- `+0x40` is checked with `& 0x3fff` as the TX credit/depth source.
- `+0x38` is used by the ready-payload copy path.

### `host_downstream_dqm_queue_obj_candidate`

```text
typedef struct host_downstream_dqm_queue_obj_candidate {
    host_dqm_channel_obj_candidate base;                         // +0x00..+0x5b
    uint8_t active_flag_5c;                                      // +0x5c
    uint8_t pad_5d[3];                                           // +0x5d..+0x5f
    uint32_t field_60_unknown;                                   // +0x60
    uint32_t field_64_unknown;                                   // +0x64
    dma_allocator_global_state_81848740_candidate *fpm_allocator_68; // +0x68
} host_downstream_dqm_queue_obj_candidate;
```

Confirmed by `80845a7c`:

```text
obj->active_flag_5c = 0;
obj->field_60_unknown = 0;
obj->field_64_unknown = 0;
obj->fpm_allocator_68 = fn_dma_fpm_allocator_get_or_init_8002a798();
```

### `natp_nomatch_rx_manager_candidate`

New structure for the NATP/no-match RX manager:

```text
typedef struct natp_nomatch_rx_manager_candidate {
    host_dqm_channel_obj_candidate *host_dqm_obj_00; // +0x00
    uint8_t flag_04;                                // +0x04
    uint8_t flag_05;                                // +0x05
    uint8_t flag_06;                                // +0x06
    uint8_t pad_07;                                 // +0x07
    uint32_t field_08;                              // +0x08
    void *state_block_0c;                            // +0x0c, allocated 0xdc and initialized/cleared
} natp_nomatch_rx_manager_candidate;
```

Confirmed behavior from `80845c58`:

```text
ctx->host_dqm_obj_00 = allocated Host-DQM object, size 0x5c
ctx->flag_04 = 0
ctx->flag_05 = 0
ctx->flag_06 = 0
ctx->field_08 = 0
ctx->state_block_0c = allocated 0xdc-byte state block
```

## FAP/bypass context datatype note

The existing `fap_bypass_context_candidate` is already usable. Do not rebuild it. Only optional precision improvements remain.

Recommended precise version:

```text
typedef struct fap_bypass_context_candidate {
    void *ops_table_00;                                      // +0x00
    undefined4 field_04_unknown;                             // +0x04
    undefined4 field_08_unknown;                             // +0x08
    uint32_t event_raise_mask_0c;                             // +0x0c
    uint32_t event_slot_id_10;                                // +0x10
    uint32_t enabled_queue_mask_14;                           // +0x14
    int32_t active_queue_index_18;                            // +0x18
    int32_t data_enabled_queue_last_index_1c;                 // +0x1c
    int32_t bypass_queue_last_index_20;                       // +0x20
    host_dqm_channel_obj_candidate *command_channel_obj_24;   // +0x24, selector 1/MSP command channel
    host_downstream_dqm_queue_obj_candidate *active_queue_obj_28; // +0x28
    host_downstream_dqm_queue_obj_candidate *data_queue_objs_2c[8]; // +0x2c
    host_downstream_dqm_queue_obj_candidate *bypass_queue_objs_4c[2]; // +0x4c
    uint8_t data_mode_enabled_54;                             // +0x54
    uint8_t pad_55[3];                                        // +0x55
    host_downstream_dqm_queue_obj_candidate *mac_message_queue_obj_58; // +0x58, channel 0x13
    host_dqm_channel_obj_candidate *async_message_channel_obj_5c;      // +0x5c, channel 0x12
} fap_bypass_context_candidate;
```

Field-type rule used here:

- `undefined4` is correct for unknown 4-byte storage.
- `uint32_t` is correct for confirmed masks, counters, IDs, words, and unsigned fields.
- `int32_t` is correct for queue indexes with `-1` sentinel behavior.
- pointer types are used when the field is proven to point to another object.

## Host-DQM ops tables

### Table labels

```text
81826978  g_host_dqm_channel_obj_ops_81826978_candidate
81826988  g_host_downstream_dqm_command_channel_ops_81826988_candidate
81826998  g_host_downstream_dqm_queue_obj_ops_81826998_candidate
```

### Table contents

```text
g_host_dqm_channel_obj_ops_81826978_candidate
  +0x00 -> fn_host_dqm_channel_obj_unregister_and_free_name_808444d0_candidate
  +0x04 -> fn_host_dqm_channel_obj_unregister_free_name_and_self_80844518_candidate
  +0x08 -> NULL
  +0x0c -> NULL

g_host_downstream_dqm_command_channel_ops_81826988_candidate
  +0x00 -> fn_host_downstream_dqm_command_obj_destroy_80f6cf60_candidate
  +0x04 -> fn_host_downstream_dqm_command_obj_destroy_and_free_80f6cf84_candidate
  +0x08 -> NULL
  +0x0c -> NULL

g_host_downstream_dqm_queue_obj_ops_81826998_candidate
  +0x00 -> fn_host_downstream_dqm_queue_obj_destroy_80f6cfbc_candidate
  +0x04 -> fn_host_downstream_dqm_queue_obj_destroy_and_free_80f6cfe0_candidate
  +0x08 -> NULL
  +0x0c -> NULL
```

### Ops meaning

The derived methods are destructor wrappers. They restore the derived ops table, delegate to the base cleanup helper, and the `destroy_and_free_04` form additionally frees `self` through `fn_heap_free_if_nonnull_80f08cbc_candidate`.

## Host-DQM selector table

| Selector | Name | Base | Register block | Encoded IRQ | Group/child | Handler slot |
|---:|---|---:|---:|---:|---|---:|
| 0 | UTP | `b8000000` | `b8001800` | `0x88` | `0x23 / 3` | `8174552c` |
| 1 | MSP | `b8200000` | `b8201800` | `0x7e` | `0x24 / 3` | `8174562c` |
| 2 | FAP | `b8400000` | `b8401800` | `0x74` | `0x27 / 3` | `8174592c` |
| 3 | MSG_PROC | `b8600000` | `b8601800` | `0x6a` | `0x26 / 3` | `8174582c` |
| 4 | MPEG_PROC | `b8a00000` | `b8a01800` | `0x60` | `0x25 / 3` | `8174572c` |
| 5 | PMC | `b8800000` | `b8801800` | `0x56` | `0x28 / 3` | `81745a2c` |

## Function findings and labels

### Base and downstream Host-DQM constructors

```text
808440b0  fn_host_dqm_channel_obj_init_808440b0_candidate
80845484  fn_host_downstream_dqm_command_channel_obj_init_80845484_candidate
80845a7c  fn_host_downstream_dqm_queue_obj_init_80845a7c_candidate
80845aec  fn_host_dqm_queue_obj_set_active_flag_80845aec_candidate
80845af8  fn_host_dqm_queue_obj_clear_active_flag_80845af8_candidate
```

#### `80845484` result

This is the downstream/DTP command-channel object initializer. It forces hidden register input:

```text
t0 = 1   // selector 1 / MSP
```

It calls the base Host-DQM initializer, installs `g_host_downstream_dqm_command_channel_ops_81826988_candidate`, and logs command-channel creation.

Recommended signature:

```text
void fn_host_downstream_dqm_command_channel_obj_init_80845484_candidate(
    host_dqm_channel_obj_candidate *obj,
    uint32_t queue_index_a,
    uint32_t channel_index,
    uint32_t init_flag_bool);
```

#### `80845a7c` result

This initializes the downstream data/bypass queue object. It uses hidden `t0/t1` for selector/name into the base init path, installs `g_host_downstream_dqm_queue_obj_ops_81826998_candidate`, clears downstream fields, and stores the main FPM allocator pointer at `+0x68`.

Recommended signature:

```text
void fn_host_downstream_dqm_queue_obj_init_80845a7c_candidate(
    host_downstream_dqm_queue_obj_candidate *obj,
    uint32_t queue_index_a,
    uint32_t channel_index,
    uint32_t init_flag_bool);
```

### Static-state helper families

Two static-state key families are now separated.

#### Family A: downstream-DQM key `8191760a`

```text
80845b00  fn_host_downstream_dqm_static_state_enable_or_release_80845b00_candidate
80845b6c  fn_host_downstream_dqm_static_state_enable_wrapper_80845b6c_candidate
80845b8c  fn_host_downstream_dqm_static_state_release_wrapper_80845b8c_candidate
8191760a  static key / state byte candidate
```

Behavior:

```text
if state_id_or_ffff == 0xffff && enable_flag == 1:
    FUN_80f06430(8191760a)

if state_id_or_ffff == 0xffff && enable_flag == 0:
    fn_static_state_release_or_unregister_ref(8191760a)
```

#### Family B: NATP/no-match RX key `81917614`

```text
80845bac  fn_natp_nomatch_rx_static_state_enable_or_release_80845bac_candidate
80845c18  fn_natp_nomatch_rx_static_state_enable_wrapper_80845c18_candidate
80845c38  fn_natp_nomatch_rx_static_state_release_wrapper_80845c38_candidate
81917614  g_natp_nomatch_rx_static_state_key_81917614_candidate
```

Behavior:

```text
if state_id_or_ffff == 0xffff && enable_flag == 1:
    FUN_80f06430(81917614)

if state_id_or_ffff == 0xffff && enable_flag == 0:
    fn_static_state_release_or_unregister_ref(81917614)
```

### NATP/no-match RX manager init

Recommended label/signature:

```text
void fn_natp_nomatch_rx_manager_init_80845c58_candidate(
    natp_nomatch_rx_manager_candidate *ctx);
```

Confirmed flow:

```text
- sets g_natp_nomatch_rx_host_dqm_selector_81917634_candidate = 4
- allocates Host-DQM object size 0x5c
- initializes Host-DQM object with:
    queue_index_a = 0x10
    channel_index = 0x11
    selector      = 4 / MPEG_PROC through t0
    name string   = 8116e39c through t1
- stores object at ctx->host_dqm_obj_00
- sends/validates InitializeNapDqmMessageChannel through 80845e44
- stores static allocator/object pointer at 8173faec
- clears ctx->flag_04, flag_05, flag_06
- resolves eth0-like context and stores observed fields at 8173fafc / 8173fb00
- calls FUN_80846f54(ctx)
- obtains auxiliary contexts through FUN_806e12a8 and stores 8173fb04 / 8173fb08
- calls FUN_80847034(ctx) and FUN_80847114(ctx) when the respective contexts exist
- allocates and initializes a 0xdc-byte state block at ctx->state_block_0c
- clears ctx->field_08
```

Global labels:

```text
81917634  g_natp_nomatch_rx_host_dqm_selector_81917634_candidate
8173faec  g_natp_nomatch_rx_dma_allocator_or_static_alloc_8173FAEC_candidate
8173fafc  g_natp_nomatch_rx_eth0_field18_8173FAFC_candidate
8173fb00  g_natp_nomatch_rx_eth0_context_8173FB00_candidate
8173fb04  g_natp_nomatch_rx_context0_8173FB04_candidate
8173fb08  g_natp_nomatch_rx_context1_8173FB08_candidate
8173fb24  g_natp_nomatch_rx_manager_8173FB24_candidate
```

### NATP/no-match RX manager singleton getter

Recommended label/signature:

```text
natp_nomatch_rx_manager_candidate *
fn_natp_nomatch_rx_manager_get_or_init_80845de0_candidate(
    uint8_t create_if_missing);
```

Behavior:

```text
if g_natp_nomatch_rx_manager_8173FB24_candidate == NULL && create_if_missing == 1:
    ctx = malloc(0x10)
    fn_natp_nomatch_rx_manager_init_80845c58_candidate(ctx)
    g_natp_nomatch_rx_manager_8173FB24_candidate = ctx

return g_natp_nomatch_rx_manager_8173FB24_candidate;
```

Note: because `host_dqm_obj_00` is at offset `+0x00`, the decompiler may display the return as `&ctx->host_dqm_obj_00`; this is address-equivalent to `ctx`.

### NATP command opcode `0x02`: initialize DQM message channel

Recommended label/signature:

```text
int32_t fn_natp_initialize_dqm_message_channel_80845e44_candidate(
    natp_nomatch_rx_manager_candidate *ctx);
```

Command record:

```text
record[0] = 4
record[1] low byte = 0x02
record[2] = 0xdeadbeef
record[3] = 0
record[4] = 0
```

Flow:

```text
- submits command through ctx->host_dqm_obj_00
- polls fn_host_dqm_copy_ready_payload_if_reg20_set_8002b998_candidate()
- up to 10 tries
- delay 100 between misses
- logs InitializeNapDqmMessageChannel SUCCESS on response
- logs InitializeNapDqmMessageChannel TIMEOUT on timeout
- returns 0 on response
- returns -1 on timeout
```

### NATP command opcode `0x0e`: query FFE offsets

Recommended label/signature:

```text
int32_t fn_natp_query_ffe_offsets_80845f34_candidate(
    natp_nomatch_rx_manager_candidate *ctx,
    uint32_t *out_ffe_offset_a,
    uint32_t *out_ffe_offset_b);
```

Command record:

```text
record[0] = 4
record[1] low byte = 0x0e
record[2] = 0
record[3] = 0
record[4] = 0
```

Flow:

```text
- submits command through ctx->host_dqm_obj_00
- polls fn_host_dqm_copy_ready_payload_if_reg20_set_8002b998_candidate()
- up to 10 tries
- delay 100 between misses
- on success:
    out_ffe_offset_a = lhu(response + 0x08)
    out_ffe_offset_b = lhu(response + 0x0c)
    logs NatpFfeOffsets SUCCESS
    returns 0
- on timeout:
    logs NatpFfeOffsets TIMEOUT
    returns -1
```

## Ghidra false function splits

Delete the function definition only. Keep labels if useful.

| False function | Reason | Suggested label |
|---:|---|---|
| `FUN_808454a0` | continuation of `80845484`, delay-slot/base-init call area | `LAB_host_downstream_dqm_command_channel_base_init_call_808454a0` |
| `FUN_80f6d018` onward? | separate object families near `80f6d0xx`; do not merge without body evidence | keep separate until inspected |
| `FUN_80845d30` | continuation inside `80845c58` | `LAB_natp_nomatch_rx_eth0_second_lookup_80845d30` |
| `FUN_80845d4c` | continuation inside `80845c58` | `LAB_natp_nomatch_rx_store_eth0_context_80845d4c` |
| `FUN_80845d78` | continuation inside `80845c58` | `LAB_natp_nomatch_rx_context0_post_init_call_80845d78` |
| `FUN_80845f08` | timeout path inside `80845e44` | `LAB_natp_initialize_dqm_message_channel_timeout_log_80845f08` |

Also verify that `80845de0` is the real function start and that `80845de4` is not kept as a separate function.

## Comments to apply

### `80845e44`

```text
/* Initialize NATP/NAP DQM message channel through Host-DQM.

   Arguments:
     ctx = NATP/no-match RX manager; ctx->host_dqm_obj_00 is the Host-DQM object

   Command:
     word_count = 4
     opcode     = 0x02
     word2      = 0xdeadbeef

   Flow:
     - submits the 5-word command record through
       {@symbol fn_host_dqm_submit_record_words_8002b860_candidate}
     - polls response through
       {@symbol fn_host_dqm_copy_ready_payload_if_reg20_set_8002b998_candidate}
       up to 10 times, delaying 100 between attempts
     - logs InitializeNapDqmMessageChannel SUCCESS on response
     - logs InitializeNapDqmMessageChannel TIMEOUT on timeout

   Returns:
     0 on response
     -1 on timeout
*/
```

### `80845f34`

```text
/* Query NATP FFE offsets through Host-DQM.

   Arguments:
     ctx              = NATP/no-match RX manager
     out_ffe_offset_a = receives first 16-bit offset value, widened to uint32_t
     out_ffe_offset_b = receives second 16-bit offset value, widened to uint32_t

   Command:
     word_count = 4
     opcode     = 0x0e

   Flow:
     - submits command through
       {@symbol fn_host_dqm_submit_record_words_8002b860_candidate}
       using ctx->host_dqm_obj_00
     - polls response through
       {@symbol fn_host_dqm_copy_ready_payload_if_reg20_set_8002b998_candidate}
       up to 10 times, delaying 100 between attempts
     - on response:
         reads two unsigned 16-bit values from the response buffer
         stores them to the output uint32_t pointers
         logs NatpFfeOffsets SUCCESS
         returns 0
     - on timeout:
         logs NatpFfeOffsets TIMEOUT
         returns -1
*/
```

### `80845c58`

```text
/* Initialize NATP/no-match RX manager candidate.

   Arguments:
     ctx = manager/context object

   Flow:
     - sets {@address 81917634} = 4
       Host-DQM selector 4 / MPEG_PROC
     - allocates a base Host-DQM object, size 0x5c
     - initializes it through
       {@symbol fn_host_dqm_channel_obj_init_808440b0_candidate}
       with:
         queue_index_a = 0x10
         channel_index = 0x11
         selector      = 4 / MPEG_PROC via t0
     - stores the Host-DQM object at ctx->host_dqm_obj_00
     - calls {@symbol fn_natp_initialize_dqm_message_channel_80845e44_candidate}
       and logs one of two status strings
     - stores a static allocator/object pointer at {@address 8173faec}
     - clears ctx->flag_04, ctx->flag_05, ctx->flag_06
     - resolves eth0-like object/context and stores observed fields at:
         {@address 8173fafc}
         {@address 8173fb00}
     - calls {@symbol FUN_80846f54}
     - obtains two auxiliary contexts through {@symbol FUN_806e12a8}
       and stores them at:
         {@address 8173fb04}
         {@address 8173fb08}
     - if those contexts exist, calls:
         {@symbol FUN_80847034}
         {@symbol FUN_80847114}
     - allocates 0xdc bytes, initializes/clears it through {@symbol SUB_8047f368}
     - stores that block at ctx->state_block_0c
     - clears ctx->field_08

   Current interpretation:
     NATP/no-match RX manager initialization path using Host-DQM selector
     MPEG_PROC, queue 0x10, channel 0x11.
*/
```

## Current status checklist

| Area | Status |
|---|---|
| Host-DQM base object | confirmed |
| Host-DQM ops table cluster | confirmed |
| Derived command-channel ops | confirmed destructor wrappers |
| Derived downstream queue ops | confirmed destructor wrappers |
| Downstream queue object extension | confirmed through `80845a7c` |
| FAP/bypass context | usable; only optional precision cleanup remains |
| NATP/no-match RX manager layout | candidate but strongly supported |
| NATP manager singleton | confirmed at `8173fb24` |
| NATP Host-DQM selector | confirmed selector `4 / MPEG_PROC` |
| NATP opcode `0x02` | confirmed initialize message-channel command |
| NATP opcode `0x0e` | confirmed FFE offsets query |
| False function splits | identified; should be removed as function definitions |
| New memory block requirement from latest NATP pass | none |

## Remaining unknowns

1. Exact role of `ctx->flag_04`, `flag_05`, and `flag_06`.
2. Exact role of `ctx->field_08`.
3. Exact layout of the `0xdc` state block at `ctx->state_block_0c`.
4. Exact identity of the context pair at `8173fb04` and `8173fb08`.
5. Exact behavior of `FUN_80846f54`, `FUN_80847034`, and `FUN_80847114`.
6. Exact response payload layout for opcode `0x0e`; only the two halfword outputs are confirmed.
7. Whether `8173fb04/8173fb08` map directly to previously named ch12/ch13 workers or a different paired context system.

## Next Ghidra targets

Continue in this order:

```text
80846040..80846180   NATP/no-match RX command/use path after FFE offsets
80846164             existing ch12 worker candidate
80846620             existing ch13 worker candidate
80846f54             manager sub-init called from 80845c58
80847034             context0 post-init helper
80847114             context1 post-init helper
FUN_806e12a8         auxiliary context allocator/getter
SUB_8047f368         0xdc state-block initializer/clearer
```

## Repository placement

Target path in repo:

```text
~/tc7200u-research/records/reverse/2026-06-21-natp-host-dqm-ghidra-log.md
```

Windows download source expected after browser download:

```text
/mnt/c/Users/mgta29/Downloads/2026-06-21-natp-host-dqm-ghidra-log.md
```

## Suggested commit message

```text
reverse: document NATP Host-DQM Ghidra findings
```
