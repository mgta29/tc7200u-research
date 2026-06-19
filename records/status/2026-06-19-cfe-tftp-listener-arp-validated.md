# 2026-06-19 CFE TFTP listener path validated after ARP-gate relax

Scope:
- record the first clean validation run after relaxing the launcher-side ARP clear gate

Validated host output from 2026-06-19:
- `Using listener socket for data transfer (port 69).`
- `RRQ fresh-genet-txdump-20260619-014936.bin. mode=octet from 192.168.77.1:3425`
- `TFTP complete: sent 5708476 bytes in 15.956s (~349.4 KiB/s), block_size=512 final block 11150`

Current known-good combination:
- listener-socket transfer mode on port `69`
- `TimeoutMs=500`
- `MaxRetries=10`
- `UseFastTransferLoop=true`
- launcher ARP clear attempt enabled, but non-blocking on verification failure

Interpretation:
- the current host-side defaults are usable for live CFE transfer
- the relaxed ARP gate no longer blocks startup on this host
- the measured transfer rate is slightly better than the earlier `16.406s / ~339.8 KiB/s` success

Repository context:
- launcher:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\start-cfe-tftp-77.ps1`
- one-shot server:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`
