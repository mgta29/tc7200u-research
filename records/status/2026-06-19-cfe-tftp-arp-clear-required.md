# 2026-06-19 CFE TFTP ARP clear requirement on host

Scope:
- capture the live finding that explicit host-side ARP cache deletion is the difference between failing and succeeding CFE TFTP runs
- harden the launcher so it does not silently continue when that prerequisite was not actually met

Fresh evidence from the 2026-06-19 run:
- manual host command:
  - `arp -d 192.168.77.1`
- immediate follow-up host transfer succeeded with:
  - `Using listener socket for data transfer (port 69).`
  - `TFTP complete: sent 5708559 bytes in 16.406s (~339.8 KiB/s), block_size=512 final block 11150`

Interpretation:
- the recent instability is strongly correlated with stale host neighbor state for `192.168.77.1`
- the existing launcher behavior was too permissive because ARP delete failures only logged `(continuing)` messages and then started the transfer anyway
- a run should stop before TFTP startup if the host still cannot prove that the entry was cleared

Repository change in this command:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\start-cfe-tftp-77.ps1`

Behavior change:
- keep `ClearClientArp = true` as the default
- check whether the ARP entry exists before startup
- attempt ARP deletion up to three times with a short delay
- verify the entry is gone after delete attempts
- request UAC elevation when needed
- throw and stop the launcher if the ARP entry still cannot be cleared

Live host sync in this command:
- updated `\\wsl.localhost\Ubuntu\mnt\c\tftp\start-cfe-tftp-77.ps1`
- backup created:
  - `\\wsl.localhost\Ubuntu\mnt\c\tftp\start-cfe-tftp-77.ps1.bak-20260619-001121`

Why this change is worth keeping:
- it turns the manual recovery step into a first-class launcher prerequisite
- it prevents wasting a full CFE boot window on a transfer that was already likely to fail
- it keeps the successful listener-socket and fast-loop path available when the host neighbor state is clean
