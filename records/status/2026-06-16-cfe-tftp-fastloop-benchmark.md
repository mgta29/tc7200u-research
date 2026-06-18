# 2026-06-16 CFE TFTP fast-loop benchmark

Scope:
- record the first live benchmark result after enabling the compiled fast-transfer loop
- keep this as a new additive note rather than rewriting the consolidated refresh summary

Compared runs:

Baseline before fast-loop path:
- image size:
  - `7142822` bytes
- host result:
  - `TFTP complete: sent 7142822 bytes in 23.592s (~295.7 KiB/s), block_size=512 final block 13951`

First live run with fast-loop path active:
- image name:
  - `rdjshn-nomod-20260616-032548.bin`
- image size:
  - `7143548` bytes
- host result:
  - `TFTP complete: sent 7143548 bytes in 21.63s (~322.5 KiB/s), block_size=512 final block 13953`

Observed delta:
- elapsed time improved by about `1.962s`
- throughput improved from about `295.7 KiB/s` to about `322.5 KiB/s`
- this is roughly an `8.3%` reduction in transfer time and about a `9.1%` throughput increase

Important constraint still visible:
- the successful fast-loop run still used:
  - `block_size=512`
- therefore the client is still not negotiating a larger TFTP block size
- the transfer remains standard `512`-byte stop-and-wait TFTP

Interpretation:
- the compiled host-side loop did produce a real improvement
- the host-side interpreter overhead was part of the transfer cost
- however the remaining ceiling is still dominated by the client-side `512`-byte stop-and-wait behavior

Practical conclusion:
- the current host scripts are faster than the earlier PowerShell-only transfer path
- there may still be room for minor host-side gains, but a large next jump is unlikely without a client-side protocol change such as larger negotiated blocks

Related current files:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\tftp-server-cfe-77-once.ps1`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tftp\start-cfe-tftp-77.ps1`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-16-cfe-tftp-script-refresh.md`

Log policy:
- this is a new same-day additive benchmark note
- existing refresh notes remain unchanged
