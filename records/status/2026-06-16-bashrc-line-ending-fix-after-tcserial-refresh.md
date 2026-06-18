# 2026-06-16 bashrc line-ending fix after tcserial refresh

Scope:
- fix the shell startup `: command not found` issue that appeared after the live `tcserial` alias refresh in `~/.bashrc`

Observed symptom:
- every new interactive shell printed:
  - `: command not found`

Root cause:
- `\\wsl.localhost\Ubuntu\home\mgta29\.bashrc` had mixed line endings after the earlier outside-workspace alias edit
- raw inspection showed:
  - file type: `ASCII text, with CRLF, LF line terminators`
  - a stray raw `^M` line at the end of the TC7200U alias block

Live file fixed in this command:
- `\\wsl.localhost\Ubuntu\home\mgta29\.bashrc`

Backup created before repair:
- `\\wsl.localhost\Ubuntu\home\mgta29\.bashrc.bak-20260616-221316`

Repair applied:
- normalized the entire file to LF-only line endings
- preserved the current `tcserial` alias target:
  - `alias tcserial="$HOME/tc7200u-research/scripts/tcbuilder.sh serial-console"`

Validation done in this command:
- `cat -vet` no longer shows the stray `^M`
- `file ~/.bashrc` now reports plain `ASCII text`
- interactive bash startup resolves:
  - `tcserial -> /home/mgta29/tc7200u-research/scripts/tcbuilder.sh serial-console`
- the startup `: command not found` symptom is gone in the verification shell

Log policy:
- this is a new same-day additive status note
- earlier alias-refresh notes remain unchanged
