# 2026-06-16 CFE TFTP host script refresh

Scope:
- refresh the active host-side CFE one-shot TFTP pair
- keep the change additive and log it in the repo

Repository mirrors updated:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\start-cfe-tftp-77.ps1`

Synced host targets:
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1`
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\start-cfe-tftp-77.ps1`

Backups created before sync:
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\tftp-server-cfe-77-once.ps1.bak-20260616-020616`
- `\\wsl.localhost\Ubuntu\mnt\c\tftp\start-cfe-tftp-77.ps1.bak-20260616-020616`

What changed:
- the server now defaults to a dedicated transfer socket/TID instead of serving the entire session from the listener socket on port `69`
- the server defaults were tightened from `TimeoutMs=1200` and `MaxRetries=25` to `TimeoutMs=700` and `MaxRetries=16`
- transfer progress logging was reduced from every `64` blocks to every `256` blocks
- transfer completion now logs elapsed time and approximate throughput
- the launcher now stops active `ping.exe` processes targeting `192.168.77.1` before starting the one-shot server
- the launcher resolves the server path through `$PSScriptRoot` instead of a second hard-coded file path
- the launcher exposes the new transport-related parameters so the faster defaults can still be overridden manually

Why this change was worth doing:
- serial logs repeatedly showed `Received packet for invalid session...` during CFE TFTP windows
- related host-side capture tooling in this repo has an explicit background `ping.exe` pattern against `192.168.77.1`, which is a plausible source of stray packets during the CFE session
- a dedicated transfer socket is closer to normal TFTP behavior and should reduce session confusion around the data path
- lower timeout and retry defaults should cut wasted wait time when the first session stalls or a block needs to be resent

Expected effect:
- slightly faster failure recovery and slightly faster successful transfers on the direct `192.168.77.0/24` host link
- fewer or no `Received packet for invalid session...` lines when the spam was being caused by host ping traffic or listener-socket session handling
- easier future edits because the current host scripts now have repo mirrors under `scripts/tftp`

Validation done in this command:
- repo mirrors were written first
- the mirrored files were synced out to the active host targets
- the timestamped backup files above were created successfully
- the synced host files were spot-checked by reading them back through `\\wsl.localhost\Ubuntu\mnt\c\tftp`

Validation not done in this command:
- no live modem/CFE TFTP boot run was executed here
- no packet capture was rerun here

Log policy:
- this is a new dated status note
- no older logs or status notes were edited
