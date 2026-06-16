# 2026-06-16 CFE TFTP host script refresh v2

Scope:
- second same-day pass on the active CFE TFTP host scripts
- keep the earlier note intact and record the new changes separately

Why a v2 pass was needed:
- the refreshed pair from the earlier same-day pass still showed `Received packet for invalid session...` bursts in the latest serial capture
- latest evidence path:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\picocom-20260616-014743.log`
- that capture still completed transfer and reached kernel handoff, but the session was still noisier and slower than intended

Repository mirrors changed in this pass:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\start-cfe-tftp-77.ps1`

What changed in v2:
- lowered defaults again to `TimeoutMs=500` and `MaxRetries=10`
- lowered launch delay default to `PreStartDelayMs=0`
- reduced progress logging frequency again to every `512` blocks
- raised socket send and receive buffers to `1048576`
- replaced per-block byte-array allocation with a reusable packet buffer and `Buffer.BlockCopy`
- connected the transfer socket to the client TID during the live transfer path
- added RRQ option parsing so filename, mode, and any extra TFTP options are visible
- added conditional OACK support for client-requested `blksize`, `timeout`, and `tsize`
- capped negotiated `blksize` with a default `MaxBlksize=1428`
- added transfer logging for requested and negotiated RRQ options

Why these changes are worth keeping:
- the old per-block PowerShell loop allocated a fresh payload array for every 512-byte block, which is unnecessary overhead on multi-megabyte images
- if the CFE client already requests RFC 2347 options, especially `blksize`, the previous scripts ignored that opportunity and stayed at 512-byte blocks
- even when the client does not request larger blocks, the reusable buffer path should reduce host-side overhead and improve the direct-link transfer loop

Expected effect from v2:
- faster successful transfers from lower interpreter overhead in the DATA send loop
- much faster transfers if the CFE RRQ already includes `blksize` and accepts OACK
- faster failure recovery on stalled sessions from the lower timeout and retry defaults
- better next-pass visibility because RRQ option strings will now be logged explicitly

Validation done in this command:
- repo copies were updated only; no older status note was edited
- the v2 transport logic was read back and manually checked after patching

Validation still pending after this command:
- sync the v2 pair to `\\wsl.localhost\Ubuntu\mnt\c\tftp`
- run another live CFE transfer to confirm whether RRQ option negotiation occurs and whether the invalid-session burst is reduced

Log policy:
- this is a new additive status record
- the earlier same-day note remains unchanged
- no older serial logs were edited here
