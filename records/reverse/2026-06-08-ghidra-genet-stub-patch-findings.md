
## 2026-06-08T03:13:57 Ghidra GENET stub-patch findings

- Mapped/typed `g_stub_patch_cmd_record` at `b6001df0` as `uint[4]`; `fn_stub_patch_store_cmd_record` and alt copy 4-word runtime patch records into it.
- `fn_runtime_stub_patch_dispatcher` / `fn_runtime_stub_patch_dispatcher_alt` are stub/board-option dispatchers, not direct GENET init.
- Dispatcher case `0x11` selects `GENET_REG_12c00500` or `GENET_REG_12c00510` and installs pointers into generated stub slots `0x80007118` / `0x8000711c`.
- `fn_stub_patch_install_genet_500_510` and alt install `GENET_REG_12c00510 -> 0x80007118` and `GENET_REG_12c00500 -> 0x8000711c`, then call `fn_stub_patch_adjust_stack_offsets(0xc)`.
- `fn_stub_patch_adjust_stack_offsets` at `80c80160` aligns size and patches stub instruction words at `0x80007000` / `0x80007004`; not GENET/MMIO logic.
- `FUN_80c89d2c` is only a wrapper around `fn_stub_patch_adjust_stack_offsets(0xc)`.
- No new confirmed direct GMAC/MIB init registers found in this cluster; confirmed GENET refs from stub path remain `12c00500` and `12c00510`. Next search target: `12c004` / `b2c004` for active GMAC/MIB window.
