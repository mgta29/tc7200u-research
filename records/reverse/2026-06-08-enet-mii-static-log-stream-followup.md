# ENET MII command path, static log stream, and MDIO write helper follow-up

## Scope

This note records additive reverse-engineering findings made after the previous detailed packet allocator and heap-chain log. Preserve old logs and notes. Do not delete or overwrite prior evidence.

The previous detailed log covered:

```text
main FPM hardware allocator path
secondary FPM packet allocation object path
generic heap allocation and free-list behavior
cleanup lifetime ambiguity around 0x8187bc70
```

This follow-up covers:

```text
static-state cluster around 0x81a6c000
0x8187bc60 static-state dispatcher
0x814c2f48 global log or CLI output stream pointer
ENET read_mii command handler
ENET diag readmii/writemii dispatcher
MDIO write helper with busy wait
```

## Static-state block around 0x8187bc60

A RAM block was created or used for:

```text
dma_fpm_token_manager_state_8187bc60
ram:8187bc60-ram:8187be5f
```

Confirmed labels in this area:

```text
0x8187bc60 = g_dma_fpm_packet_alloc_static_state_8187bc60_candidate
0x8187bc68 = g_dma_fpm_packet_alloc_init_done_8187bc68_candidate
0x8187bc70 = g_dma_fpm_packet_alloc_object_8187bc70_candidate
```

Important lifetime conclusion:

```text
A normal heap payload at 0x8187bc70 would require heap header fields at:
  0x8187bc64 = header next/list link
  0x8187bc68 = header previous/backlink pointer
  0x8187bc6c = header total block size

But 0x8187bc68 is already confirmed as the packet allocator init latch, and 0x8187bc60 is active static state. Therefore 0x8187bc64..0x8187bc6f is not clean heap-header space for payload 0x8187bc70.
```

Safe wording:

```text
0x8187bc70 is fixed/static-looking packet allocator object storage. The generic cleanup path that reaches heap-free remains suspicious or context-dependent and is not proof that 0x8187bc70 is a normal heap allocation.
```

## Static-state dispatcher near packet allocator object

Function:

```text
fn_dma_fpm_packet_alloc_static_state_dispatch_800b6cc4_candidate
```

Confirmed behavior:

```text
Only handles sentinel id/value 0xffff.

op == 1:
  fn_static_state_acquire_or_register_ref_80f06430_candidate(&g_dma_fpm_packet_alloc_static_state_8187bc60_candidate, 0xffff, context)

op == 0:
  fn_static_state_release_or_unregister_ref_80f06474_candidate(&g_dma_fpm_packet_alloc_static_state_8187bc60_candidate, 0xffff, context, arg3)
```

This confirms 0x8187bc60 is real active static state and not heap metadata for the packet allocator object.

## Static-state reference-counted acquire and release

Acquire function:

```text
fn_static_state_acquire_or_register_ref_80f06430_candidate
```

Confirmed behavior:

```text
if g_static_state_refcount_8183fcd0_candidate == 0:
  g_static_state_enabled_or_init_state_8183fcd4_candidate = 1
  fn_static_state_register_or_enable_80f061b0_candidate(1, id_or_sentinel, context)

g_static_state_refcount_8183fcd0_candidate++
```

Release function:

```text
fn_static_state_release_or_unregister_ref_80f06474_candidate
```

Confirmed behavior:

```text
g_static_state_refcount_8183fcd0_candidate--
if g_static_state_refcount_8183fcd0_candidate == 0:
  fn_static_state_unregister_or_disable_80f063f8_candidate(static_state_object, id_or_sentinel, context, arg3)
```

Ghidra type note:

```text
id_or_sentinel may be displayed as int * because downstream cleanup helpers use pointer-like parameter types. In the FPM packet allocator static-state dispatcher the value is sentinel 0xffff. Treat it as an opaque 32-bit id or sentinel, not as a real pointer.
```

Suggested labels:

```text
DAT_8183fcd0 -> g_static_state_refcount_8183fcd0_candidate
DAT_8183fcd4 -> g_static_state_enabled_or_init_state_8183fcd4_candidate
FUN_80f06430 -> fn_static_state_acquire_or_register_ref_80f06430_candidate
FUN_80f06474 -> fn_static_state_release_or_unregister_ref_80f06474_candidate
FUN_80f061b0 -> fn_static_state_register_or_enable_80f061b0_candidate
FUN_80f063f8 -> fn_static_state_unregister_or_disable_80f063f8_candidate
```

## Static-state register or enable helper

Function:

```text
fn_static_state_register_or_enable_80f061b0_candidate
```

Confirmed role:

```text
Real static-state register or enable helper called when the global static-state refcount transitions from 0 to 1.
```

Mode selection:

```text
param_1 != 0 -> iVar2 = 1,     iVar3 = 0
param_1 == 0 -> iVar2 = 0x400, iVar3 = 0x400
```

In the FPM packet allocator static-state path:

```text
param_1 = 1
iVar2   = 1
iVar3   = 0
```

Three main static objects initialized:

```text
0x81a6bfe4
0x81a6c08c
0x81a6c134
```

These match the three objects cleaned by the unregister helper.

Static object cluster labels:

```text
0x81a6bfe4 -> g_static_state_object_a_81a6bfe4_candidate
0x81a6c08c -> g_static_state_object_b_81a6c08c_candidate
0x81a6c134 -> g_static_state_object_c_81a6c134_candidate
```

Nearby static node labels:

```text
0x81a6c1dc -> g_static_state_node_b_81a6c1dc_candidate
0x81a6c26c -> g_static_state_node_a_81a6c26c_candidate
0x81a6c2f8 -> g_static_state_node_c_81a6c2f8_candidate
0x81a6c384 -> g_static_state_node_d_81a6c384_candidate
```

Important correction:

```text
0x81a6c26c has many XREFs and is not packet-allocator-specific. It participates in a generic static registry or logging framework.
```

Safer future name for 0x81a6c26c:

```text
g_static_registry_or_list_node_81a6c26c_candidate
```

## Static object init and cleanup pair

Init function:

```text
fn_static_object_init_or_register_80f98264_candidate
```

Cleanup function:

```text
fn_static_object_unregister_or_cleanup_80f983b4_candidate
```

Confirmed cleanup behavior for one static object:

```text
object +0x00 = g_static_object_cleanup_vtable_8183c418_candidate
call fn_static_object_detach_or_flush_80f986a8_candidate(object, ...)
clear byte flag at object +0x9d
cleanup embedded resource or name object at object +0x64 through fn_embedded_name_or_resource_cleanup_80f084b0_candidate
object +0x00 = g_static_object_base_vtable_8183c198_candidate
clear byte flag at object +0x10
clear object +0x08
clear object +0x0c
clear object +0x2c
clear byte flag at object +0x34
cleanup embedded node or list at object +0x30 through fn_static_node_or_list_cleanup_80f06748_candidate
```

This confirms the 0x81a6.... cluster is a real static object framework, not heap-header space for the FPM packet allocator object at 0x8187bc70.

## Global log or CLI output stream pointer

The pointer formerly named around 0x81a6c26c was clarified by ENET MII command handlers.

Better global pointer label:

```text
PTR_g_static_registry_or_list_node_81a6c26c_candidate_814c2f48
  -> g_static_log_stream_ptr_814c2f48_candidate
```

or more specific if desired:

```text
g_log_stream_or_cli_output_ptr_814c2f48_candidate
```

Confirmed role:

```text
CLI/log output stream pointer used by ENET command handlers.
It is not FPM packet allocator state.
```

## ENET MII read command handler

Function:

```text
fn_enet_mii_read_command_803afdac_candidate
```

Confirmed command:

```text
read_mii <phy_addr> <reg_num>
```

Evidence strings:

```text
81063fcc = read_mii
81063fe8 = Reads the specified ethernet MII register from the PHY specified.
8106402c = read_mii 1 0x18 Reads the AUX STATUS REG from the internal PHY on the 3345.
81065658 = Reading MII register...
81065674 = MII Read:  PHY(
```

Behavior:

```text
1. Get ethernet interface list through FUN_803fe32c.
2. Iterate with FUN_803fe4f8 and FUN_803fe51c.
3. Select first interface whose +0x2c field equals 6.
4. If none found, log No ethernet interface found!!!.
5. Read command arguments 2 and 3 from command_context_unaff_s0 +0x20.
6. Convert each argument object to integer through vtable method +0x1c.
7. arg2 -> PHY address.
8. arg3 -> register number.
9. selected_interface +0x144 -> MDIO bus.
10. Call fn_enet_mdio_read_phy_reg(phy_addr, reg_num, scratch_out, mdio_bus).
11. Print MII read result through g_static_log_stream_ptr_814c2f48_candidate when nonzero.
12. Call fn_enet_cli_output_finish_noop_803b013c_candidate.
```

Confirmed interface layout:

```text
selected_enet_iface +0x2c  = interface type or id, matched against 6
selected_enet_iface +0x144 = MDIO bus id
```

Confirmed command argument layout:

```text
command_context +0x20 = argument container
arg index 2 = PHY address object
arg index 3 = register number object
argument object vtable +0x1c = integer conversion method
```

No-op finalizer:

```text
fn_enet_cli_output_finish_noop_803b013c_candidate simply returns.
```

## ENET diagnostic readmii and writemii dispatcher

Function:

```text
fn_enet_diag_readmii_writemii_command_803afcb0_candidate
```

Confirmed command forms:

```text
diag readmii  <phy> <reg>
diag writemii <phy> <reg> <value>
```

Evidence strings:

```text
81065530 = readmii|writemii
81065578 = diag readmii 0 0x18 Reads from ethernet registers / diag writemii 0 0x18 0x400 Writes to ethernet registers
81065658 = Reading MII register...
81065674 = MII Read:  PHY(
810656a0 = Writing MII register...
810656bc = MII Write:  PHY(
```

Selector logic:

```text
arg1 == 0 -> readmii path
arg1 == 1 -> writemii path
otherwise -> FUN_803b0110, likely usage or error output
```

Read path:

```text
arg2 -> PHY address
arg3 -> register number
selected_interface +0x144 -> MDIO bus
fn_enet_mdio_read_phy_reg(phy, reg, &read_scratch_word, mdio_bus)
```

Write path:

```text
arg2 -> PHY address
arg3 -> register number
arg4 -> write value
fn_enet_mdio_write_phy_reg_wait_803affac_candidate(phy, reg, write_value, write_scratch)
```

Important note:

```text
The decompiler reuses the same local across the read and write branches. In the read branch it holds the MDIO bus from selected_interface +0x144. In the write branch it holds arg4 write value.
```

Logging:

```text
g_static_log_stream_ptr_814c2f48_candidate is only used for CLI/log output. It is not FPM packet allocator state.
```

## ENET MDIO write helper with busy wait

Function:

```text
fn_enet_mdio_write_phy_reg_wait_803affac_candidate
```

Confirmed role:

```text
Writes one PHY register through GENET MDIO command register and polls busy until clear or timeout.
```

Normal arguments:

```text
phy_addr
reg_num
write_value
wait_count output pointer
```

Recovered inherited state:

```text
mdio_bus_index is shown by Ghidra as in_t0, not as a normal function argument.
In this decompile, the selected MDIO bus is recovered as inherited register state rather than an explicit parameter. If mdio_bus_index > 1, it is forced to 0.
```

PHY default logic:

```text
phy_addr == 0xff -> use g_enet_selected_phy_addr[mdio_bus_index]
```

MDIO base selection:

```text
default base = GENET_MDIO_BASE_12c00600
if g_enet_selected_mdio_mode[mdio_bus_index] != 0, use GENET_MDIO_BASE_12c02600
```

Command word written to mdio_base +0x2c:

```text
0x20000000
| 0x04000000
| ((phy_addr & 0x1f) << 21)
| ((reg_num  & 0x1f) << 16)
| (write_value & 0xffff)
```

Busy polling:

```text
polls mdio_base +0x32 bit0
stores loop count to *wait_count
poll max is about 201 iterations because poll_count is checked against 200 before increment termination
```

Final helper behavior:

```text
MDIO command register: mdio_base +0x2c
MDIO busy/status byte: mdio_base +0x32 bit0
Default MDIO base:     0x12c00600
Alternate MDIO base:   0x12c02600
PHY fallback:          0xff -> selected PHY for bus
Output:                *wait_count = poll_count
```

## MDIO read and write path comparison

Read command paths pass MDIO bus visibly:

```text
selected_enet_iface +0x144 -> fn_enet_mdio_read_phy_reg(..., mdio_bus)
```

Write diagnostic path passes normal args as:

```text
phy_addr, reg_num, write_value, wait_count
```

and the write helper recovers the MDIO bus index as:

```text
in_t0 inherited register state
```

Therefore the previous question about why write path did not visibly pass selected_interface +0x144 is resolved for now:

```text
The write helper prototype has four normal parameters and an inherited mdio_bus_index shown as in_t0. The bus is not a normal visible argument in the current decompile.
```

## Current conclusions

1. The FPM packet allocator static state at 0x8187bc60 and object at 0x8187bc70 are separate from the generic 0x81a6.... static object framework.
2. The 0x81a6.... framework is real static object and list/registry infrastructure.
3. The global pointer at 0x814c2f48 is used by ENET CLI/log output paths and is not FPM packet allocator state.
4. The ENET MII read and diagnostic read/write commands are now mapped.
5. The MDIO write helper writes GENET MDIO command register +0x2c and polls +0x32 bit0.
6. The MDIO base selection logic uses g_enet_selected_mdio_mode[bus] to choose 0x12c00600 or 0x12c02600.
7. The cleanup/free ambiguity around 0x8187bc70 remains unresolved, but the heap-header interpretation is now unlikely because 0x8187bc64..0x8187bc6f overlaps active static state and the init latch.

## Suggested next reverse targets

```text
fn_enet_mdio_read_phy_reg
FUN_803b0110 usage/error output helper
FUN_803fe32c / FUN_803fe4f8 / FUN_803fe51c ethernet interface iterator helpers
FUN_8028462c command argument lookup helper
```

Highest value next target for MDIO symmetry:

```text
fn_enet_mdio_read_phy_reg
```

Need to compare its bus selection and busy polling logic against fn_enet_mdio_write_phy_reg_wait_803affac_candidate.
