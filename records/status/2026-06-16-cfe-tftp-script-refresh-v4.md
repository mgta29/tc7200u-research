# 2026-06-16 CFE TFTP host script refresh v4

Scope:
- reduce successful CFE TFTP transfer time after the live host run still completed at roughly `23.6s` for a `7142822` byte image
- keep the change additive and separate from the earlier same-day transport fixes

Observed result that triggered this pass:
- host output showed:
  - `TFTP complete: sent 7142822 bytes in 23.592s (~295.7 KiB/s), block_size=512 final block 13951`
- the same host output did not show any `RRQ options:` line
- that means the client is not requesting `blksize`, so the transfer remains standard `512`-byte stop-and-wait TFTP

Implication:
- there is no protocol-level speedup available from the client side at the moment
- the remaining host-side speed lever is reducing the per-block interpreter overhead in the send or ACK loop

Repository changes in this pass:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\start-cfe-tftp-77.ps1`

What changed:
- added `UseFastTransferLoop` with default `true`
- moved the main DATA or ACK hot path into an embedded compiled C# helper loaded through `Add-Type`
- the fast path now uses `Socket.Send(...)` and `Socket.Receive(...)` on the connected UDP transfer socket instead of PowerShell method dispatch for every block
- kept the PowerShell loop as a fallback path under `UseFastTransferLoop = false`
- raised the default progress interval from `512` blocks to `2048` blocks to reduce console I/O overhead
- the launcher now forwards `UseFastTransferLoop` and the new progress default

Why this change is worth keeping:
- CFE is still using `block_size=512`, so there are about `13951` DATA or ACK round trips for the sample image
- at that point PowerShell per-iteration overhead becomes a meaningful part of total transfer time
- the embedded C# loop keeps the current behavior but removes most of that interpreter overhead from the transfer hot path

Expected effect:
- faster successful transfers even when the client never requests `blksize`
- less host console noise during transfer progress
- no protocol change for the client; only the host implementation changes

Validation done in this command:
- confirmed the latest host run completed at `block_size=512`
- confirmed no RRQ option negotiation happened in that run
- patched the repo copies to add the compiled fast path while preserving a PowerShell fallback

Validation still pending after this command:
- sync the refreshed scripts to `\\wsl.localhost\Ubuntu\mnt\c\tftp`
- rerun a live CFE transfer and compare elapsed time against the `23.592s` baseline

Log policy:
- this is a new same-day additive status note
- earlier same-day TFTP refresh notes remain unchanged
