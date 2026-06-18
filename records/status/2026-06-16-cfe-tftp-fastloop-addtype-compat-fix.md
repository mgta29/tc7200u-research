# 2026-06-16 CFE TFTP fast-loop Add-Type compatibility fix

Scope:
- fix the embedded C# fast-transfer helper so it compiles under the active Windows PowerShell `Add-Type` path
- keep this as a new same-day additive note rather than rewriting the consolidated refresh summary

Observed failure:
- the active host run failed during `Add-Type` compilation with:
  - `{ expected`
  - failure at `catch (SocketException ex) when (ex.SocketErrorCode == SocketError.TimedOut)`
- host script path:
  - `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1`

Root cause:
- the embedded C# helper used language features that the active `Add-Type` compiler path does not accept
- confirmed incompatible syntax in the helper:
  - exception filter `catch (...) when (...)`
- additionally downgraded other likely-newer syntax in the same helper to reduce the chance of another compile-stop:
  - `nameof(...)`
  - `Array.Empty<int>()`

Repository fix in this command:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`

Code changes:
- replaced `nameof(...)` arguments with plain string literals
- replaced:
  - `catch (SocketException ex) when (ex.SocketErrorCode == SocketError.TimedOut)`
- with:
  - `catch (SocketException ex) { if (ex.SocketErrorCode != SocketError.TimedOut) { throw; } ... }`
- replaced:
  - `Array.Empty<int>()`
- with:
  - `new int[0]`

Why this change is worth keeping:
- restores the fast-loop code path without backing out the compiled transfer helper entirely
- keeps the semantics of timeout retry handling while using older C# syntax
- reduces the chance of a second compile failure on the same host PowerShell toolchain

Validation done in this command:
- patched the repo mirror to older C# syntax compatible with the reported compiler failure class

Validation still pending after this command:
- sync the corrected server script back to `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1`
- rerun the host script and confirm `Add-Type` compiles cleanly

Log policy:
- this is a new same-day additive status note
- the consolidated refresh summary remains in place
