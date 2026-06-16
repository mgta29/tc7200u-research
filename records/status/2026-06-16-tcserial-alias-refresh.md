# 2026-06-16 tcserial alias refresh

Scope:
- refresh the `tcserial` alias so it uses the current `tcbuilder` serial-console entrypoint
- keep the alias/documentation change additive and logged

Reason:
- the live shell alias in `\\wsl.localhost\Ubuntu\home\mgta29\.bashrc` still pointed at the obsolete path `scripts/tc7200u-serial-console.sh`
- that old script path is no longer present in the repo
- the canonical serial-console path is now `tcbuild serial-console`

Repository updates made in this command:
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\AI_HELPER.json`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\docs\WORKFLOW.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\docs\REPO_MAP.md`

Repository alias result:
- `tcserial -> ~/tc7200u-research/scripts/tcbuilder.sh serial-console`

Expected live shell update:
- `\\wsl.localhost\Ubuntu\home\mgta29\.bashrc`
- old:
  - `alias tcserial="$HOME/tc7200u-research/scripts/tc7200u-serial-console.sh"`
- new:
  - `alias tcserial="$HOME/tc7200u-research/scripts/tcbuilder.sh serial-console"`

Why this change is worth keeping:
- `tcserial` remains available as a short operator command
- the alias now follows the canonical helper surface instead of a removed standalone script
- helper metadata and operator docs stay aligned with the live shell alias

Live shell update completed in this command:
- updated `\\wsl.localhost\Ubuntu\home\mgta29\.bashrc`
- backup created:
  - `\\wsl.localhost\Ubuntu\home\mgta29\.bashrc.bak-20260616-025246`

Validation done in this command:
- confirmed the old alias target was present in `~/.bashrc`
- confirmed `scripts/tc7200u-serial-console.sh` is missing
- updated the repo-side alias metadata and docs
- confirmed in an interactive bash that:
  - `tcserial -> /home/mgta29/tc7200u-research/scripts/tcbuilder.sh serial-console`

Validation still pending after this command:
- reload the shell or start a new shell and run `type tcserial`

Log policy:
- this is a new dated status note
- no older logs or status notes were edited
