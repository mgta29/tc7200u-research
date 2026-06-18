# 2026-06-16 CFE TFTP host script refresh

Scope:
- consolidate the same-day CFE TFTP refresh work into one canonical status record
- replace the former same-day `v2`, `v3`, `v4`, and merged variants with this single file

Merged source notes removed in this cleanup:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-cfe-tftp-script-refresh-v2.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-cfe-tftp-script-refresh-v3.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-cfe-tftp-script-refresh-v4.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-cfe-tftp-script-refresh-merged.md`

Current active script mirrors:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\start-cfe-tftp-77.ps1`

Current active host targets:
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1`
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\start-cfe-tftp-77.ps1`

Backups created across the same-day refresh sequence:
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1.bak-20260616-020616`
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\start-cfe-tftp-77.ps1.bak-20260616-020616`
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1.bak-20260616-024033`
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\start-cfe-tftp-77.ps1.bak-20260616-024033`
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1.bak-20260616-025519`
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1.bak-20260616-030013`
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\start-cfe-tftp-77.ps1.bak-20260616-030013`

Why the refresh series started:
- serial logs repeatedly showed `Received packet for invalid session...` during CFE TFTP windows
- related host-side tooling in this repo includes a background `ping.exe` pattern against `192.168.77.1`, which is a plausible stray-packet source during CFE sessions
- the original host server loop was fully PowerShell-driven and used a single listener socket path, which left room for both correctness and performance cleanup

Same-day timeline and net effect:

Initial refresh:
- added repo mirrors for the active Windows host scripts
- moved the transfer path to a dedicated transfer socket or TID instead of using the listener socket on `69` for the full session
- tightened defaults from `TimeoutMs=1200` and `MaxRetries=25` to `TimeoutMs=700` and `MaxRetries=16`
- reduced progress logging from every `64` blocks to every `256` blocks
- added elapsed-time and throughput logging at transfer completion
- changed the launcher to stop active `ping.exe` processes targeting `192.168.77.1`
- changed the launcher to resolve the server path through `$PSScriptRoot`

Second pass:
- lowered defaults again to `TimeoutMs=500` and `MaxRetries=10`
- lowered `PreStartDelayMs` to `0`
- raised socket send and receive buffers to `1048576`
- replaced per-block payload allocation with a reusable buffer and `Buffer.BlockCopy`
- added RRQ option parsing
- added conditional OACK support for `blksize`, `timeout`, and `tsize`
- capped negotiated `blksize` with `MaxBlksize=1428`
- reduced progress logging frequency again, later settled at every `2048` blocks

Regression fix:
- corrected the dedicated transfer connect call from:
  - `$xferSock.Client.Connect($remote)`
- to:
  - `$xferSock.Connect($remote)`
- this fixed the runtime error:
  - `The operation is not allowed on non-connected sockets.`

Performance-focused pass:
- added `UseFastTransferLoop = true`
- moved the DATA or ACK hot loop into compiled C# loaded through `Add-Type`
- kept the PowerShell loop as a fallback under `UseFastTransferLoop = false`
- raised the default progress interval to `2048` blocks to cut console I/O overhead

Current script behavior after the merged sequence:
- dedicated transfer socket enabled by default
- `TimeoutMs=500`
- `MaxRetries=10`
- `ProgressIntervalBlocks=2048`
- `EnableOptionAck=true`
- `MaxBlksize=1428`
- `UseFastTransferLoop=true`
- launcher stops active host `ping.exe` traffic aimed at `192.168.77.1`
- launcher forwards the fast-loop and transport parameters into the server script

Key live evidence collected during the series:
- successful host-side transfer before the compiled fast-loop pass:
  - `TFTP complete: sent 7142822 bytes in 23.592s (~295.7 KiB/s), block_size=512 final block 13951`
- implication from that run:
  - no `RRQ options:` line was shown
  - the CFE client is not requesting `blksize`
  - the transfer stays standard `512`-byte stop-and-wait TFTP

What that means technically:
- there is currently no protocol-level speedup available from client-side `blksize` negotiation
- the remaining host-side speed lever is reducing per-block overhead while keeping standard TFTP semantics
- the compiled fast loop is the current best host-only attempt at that

Current expectation:
- fewer host-side correctness failures than the original listener-only PowerShell loop
- lower host-side overhead during successful `512`-byte stop-and-wait transfers
- possibly faster completion than the `23.592s` baseline, but that still requires a fresh live run to prove

What is still pending after this consolidated note:
- rerun a live CFE transfer with the current active host scripts
- compare the next `TFTP complete:` elapsed time against the `23.592s` baseline
- confirm whether the compiled fast-loop path materially improves the transfer on this CFE client

Cleanup result for this command:
- there is now one canonical same-day CFE TFTP refresh note under this original filename
- the same-day variant notes were removed at user request for this cleanup

Log policy:
- this note is the consolidated replacement for the earlier same-day variants
