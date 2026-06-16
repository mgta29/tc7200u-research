# 2026-06-16 CFE TFTP host script refresh v3

Scope:
- fix the connected UDP transport regression introduced in the earlier same-day TFTP refresh
- keep the change additive with a separate dated note

Observed failure:
- host output from the active `C:\tftp\tftp-server-cfe-77-once.ps1` run showed:
  - `Exception calling "Send" with "2" argument(s): "The operation is not allowed on non-connected sockets."`
- failure point:
  - `Send-UdpPacket()` calling `UdpClient.Send(byte[], int)` after the transfer socket had been connected through `$xferSock.Client.Connect($remote)`

Root cause:
- the earlier pass connected the underlying socket object instead of the `UdpClient` wrapper itself
- `UdpClient.Send(byte[], int)` requires the `UdpClient` instance to have been connected through `UdpClient.Connect(...)`
- therefore the send path raised an exception on the first DATA packet even though the socket object had a remote endpoint

Repository fix in this command:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`

Code change:
- old:
  - `$xferSock.Client.Connect($remote)`
- new:
  - `$xferSock.Connect($remote)`

Why this change is worth keeping:
- restores the intended dedicated transfer socket behavior
- keeps the reusable packet-buffer and option-negotiation work from v2 intact
- removes the immediate runtime crash on the first DATA send

Validation done in this command:
- identified the exact failing line from the user-provided host exception output
- patched the repo mirror to use `UdpClient.Connect(...)`

Validation still pending after this command:
- sync the corrected server script back to `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1`
- rerun a live CFE transfer and confirm the DATA send no longer throws

Log policy:
- this is a new same-day additive status note
- older TFTP refresh notes remain unchanged
