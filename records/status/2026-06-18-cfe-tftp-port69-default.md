# 2026-06-18 CFE TFTP port69 default and first-block listener fallback

Scope:
- restore the active one-shot CFE TFTP server to a more reliable default transport after repeated first-block failures on the dedicated transfer socket path

Fresh evidence from the current session:
- host run on 2026-06-18 printed:
  - `Dedicated transfer socket enabled.`
  - `Fast transfer loop failed before first ACK (Exception calling "SendFile" with "5" argument(s): "Retry limit exceeded on block 1"); retrying with classic PowerShell loop`
  - `Retry limit exceeded on block 1`
- the corresponding serial log `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\picocom-20260618-220702.log` showed:
  - `ETHrxData Error: LAN RX status = 204, token = b02bf080`
  - `Received a bad packet...discarding!!!`
  - repeated `Tftp timeout...`
  - `Retry limit exceeded on block 1....Aborting session`

Relevant older evidence kept unchanged:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-cfe-tftp-script-refresh.md` already noted repeated serial-side `Received packet for invalid session...`
- the serial corpus still contains many such bursts across earlier bring-up attempts

Repository changes in this command:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\start-cfe-tftp-77.ps1`

Behavior change:
- change `UseTransferPort` default from `true` to `false` in both scripts
- print `Using listener socket for data transfer (port 69).` on the default path
- keep the dedicated transfer socket code available as an explicit opt-in
- when a dedicated-port transfer times out before `ACK block 1`, close that session socket and retry the same RRQ over the listener socket on port `69`

Reasoning:
- the compiled fast loop itself is not enough when the client never accepts the dedicated-port session
- retrying the same dead transport path wastes the full timeout budget twice
- falling back before any acknowledged DATA block is the safe point to change the server-side port

Expected operator-visible result after sync:
- a normal `start-cfe-tftp-77.ps1` run should no longer announce `Dedicated transfer socket enabled.`
- if someone explicitly enables `-UseTransferPort $true`, first-block failure should now log a listener-port retry instead of dying on the same socket

Validation done in this command:
- patched the repository mirror for the new default and the first-block listener fallback path

Validation still pending after this command:
- syntax-check the patched PowerShell scripts
- sync both updated scripts to `\\wsl.localhost\Ubuntu\mnt\c\tftp\`
- rerun a live transfer against CFE and confirm block `1` progresses on the default port `69` path
