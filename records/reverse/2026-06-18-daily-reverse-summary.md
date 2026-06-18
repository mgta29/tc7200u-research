# TC7200U reverse daily summary - 2026-06-18

## Scope

This is the daily detailed summary note after a full reread of:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse`

Control result for the requested path:

- no live `records\notes\reverse` tree is present in the current repository
- the live reverse-note tree remains `records\reverse`

Preserve older logs and summaries. This note is additive and exists to freeze the current June 18 reverse state in one place.

## Control result

The full reread did not produce contradictions against the current layered OEM model.

The only new dated reverse log after the prior carry pass is:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-16-stage1-socket-object-type2-setsockopt.md`

That pass adds one more Stage1 software layer above the already-carried signal-object and select-wait model:

- `808381f4` is now the Stage1 socket-object create/configure helper
- `808385f4` is now the Stage1 socket-object close/cleanup helper
- `808381b4` is now the Stage1 socket-object destroy/free wrapper
- `80ef80a8` is now a socket-provider `setsockopt`-like type2 dispatcher
- the socket-object vtable global is now worth carrying at `0x81825d98`

No new ENET, GENET, MDIO, FPM, DQM, or Host-DQM MMIO constants were introduced by this pass.

## Source notes folded into this daily summary

The June 18 closure came from:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\2026-06-16-stage1-socket-object-type2-setsockopt.md`
- current live export cross-check against `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\structures.h`

Earlier June 15 signal-object and select-wait carry remains valid and is not replaced.

## New Stage1 socket-object and type2 option-dispatch facts worth carrying

High-value new facts:

- socket-object wrapper layout is now worth carrying:
  - `+0x00 = vtable_00`
  - `+0x04 = signal_index_or_socket_handle_04`
  - `+0x0c = create_flags_or_t0_0c_candidate`
  - `+0x10 = boot_context_base_10_candidate`
- socket-object vtable layout is now worth carrying:
  - `+0x10 = close_or_reset_10_candidate`
  - `+0x38 = getsockopt_t0_method_38_candidate`
- type2 ops table refinement is now worth carrying:
  - `+0x14 = callback_14_candidate`
  - `+0x1c = setsockopt_t0_callback_1c_candidate`
- observed socket-option setup calls include:
  - `level 0xffff`, normalized option, optlen `4`
  - `level 0x29`, option `0x2e`, optlen `0x14`
  - `level 0xffff`, option `0x04`, optlen `4`
  - `level 0`, option `0x13`, optlen `4`
  - `level 0x29`, option `0x0e`, optlen `4`
- close/cleanup probes option `0x1008` through a getsockopt-like vtable call before closing the signal-object handle

Current best behavior model:

- `808381f4` creates a provider-backed Stage1 signal object, stores the returned handle in the socket wrapper, applies initial socket options through the type2 `+0x1c` dispatcher, and records boot-context state on success
- `80ef80a8` forwards hidden incoming `t0` to the type2 callback, and in the observed socket path that hidden value is the option length
- `808385f4` queries socket state through vtable `+0x38`, then closes the Stage1 signal-object index and clears the wrapper handle field
- `808381b4` restores the vtable pointer to `0x81825d98`, runs close/cleanup, runs secondary cleanup, and frees the wrapper object

Important cautions:

- keep `0x81825d98` as Stage1 software object/vtable state, not hardware state
- do not model hidden `t0` as a normal C parameter unless a custom calling convention is explicitly introduced
- do not assign final public semantics to option `0x1008`, `8006111c`, or `800611b0` until those helper bodies are opened

## OpenWrt-facing implication

Current best staged model for the TC7200U port now extends one layer further:

- stage 13: signal-object table state, select or wait generation flow, provider or related-object callback dispatch, and timeout-to-ticks conversion
- stage 14: socket-object wrapper state, type2 setsockopt/getsockopt dispatch, and socket close/cleanup behavior

Practical implication:

- if OpenWrt comparison reaches the OEM Stage1 socket-provider abstraction and still diverges, the next software correlation layer is:
  - `stage1_socket_object_candidate +0x04/+0x0c/+0x10`
  - `g_stage1_socket_object_vtable_81825d98_candidate`
  - `stage1_signal_object_type2_ops_candidate +0x1c`
  - `fn_stage1_signal_object_type2_setsockopt_t0_dispatch_80ef80a8`
- this layer is useful for reverse-side explanation of OEM control flow
- it still does not add new OpenWrt-safe MMIO constants

## Repository updates recorded here

Recorded modifications worth keeping:

- created this new June 18 daily summary instead of editing older daily summaries
- folded the June 16 socket-object/type2 setsockopt note into the maintained reverse state
- updated the OpenWrt carry note with a fourteenth-pass software correlation layer
- updated the structure reference with `stage1_socket_object_candidate`, `stage1_socket_object_vtable_candidate`, and the refined type2 ops slots
