# 2026-06-18 CFE TFTP fast-loop block1 fallback

Scope:
- make the active CFE TFTP host server keep the compiled fast loop when it works, but stop aborting the whole transfer when that path times out before the first ACK

Observed failure:
- host output from the active `C:\tftp\tftp-server-cfe-77-once.ps1` run showed:
  - `Exception calling "SendFile" with "5" argument(s): "Retry limit exceeded on block 1"`
- the failing run details were:
  - RRQ filename: `fresh-tc7200u-20260617-224158.bin`
  - RRQ client endpoint: `192.168.77.1:3860`
  - transfer socket: `192.168.77.2:51530`

Interpretation:
- the compiled fast loop is not fully reliable on every first-block exchange, even though it produced a real speed improvement on other runs
- aborting the full one-shot transfer on a block `1` timeout is too brittle
- a block `1` failure is the safe point to fall back, because the client has not yet acknowledged any DATA block

Repository fix in this command:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`

Behavior change:
- keep `UseFastTransferLoop = true` as the default path
- wrap the compiled `SendFile(...)` call in a `try` or `catch`
- if the fast-loop failure message matches `block 1`, print a host message and retry the transfer immediately with the classic PowerShell loop
- for failures after block `1`, still rethrow instead of guessing how to resume a partial transfer

New host-side fallback message:
- `Fast transfer loop failed before first ACK (...); retrying with classic PowerShell loop`

Why this change is worth keeping:
- preserves the faster path on the runs where it works
- restores reliability for the specific failure class seen on the current run
- avoids backing out the fast loop entirely while still keeping the one-shot server usable

Validation done in this command:
- patched the repo mirror to add automatic block `1` fallback to the classic loop

Validation still pending after this command:
- sync the corrected server script back to `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1`
- rerun a live CFE transfer and confirm the server now falls back instead of aborting on this failure class

Log policy:
- this is a new dated additive status note
- older TFTP refresh and benchmark notes remain unchanged
