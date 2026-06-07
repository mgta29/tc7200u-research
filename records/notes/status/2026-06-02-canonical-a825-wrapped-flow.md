# 2026-06-02 Canonical A825 Wrapped Flow

Changed the surfaced OpenWrt build path to the canonical A825 ProgramStore-wrapped flow.

What changed:
- Promoted `tcbuild` as the primary helper entrypoint in the operator docs and helper metadata.
- Kept `tcwrap`, `tccheck`, and `tcverify` as compatibility aliases only.
- Kept the canonical preserve-from template on `records/artifacts/rescue/tc7200-stage2-console-good.bin`.
- Preserved the canonical `0x82000000` header/load address policy for wrapped auto builds.

Verification:
- `bash -n scripts/tcbuilder.sh`
- `./scripts/tcbuilder.sh selftest`
- `./scripts/tcbuilder.sh paths`

Notes:
- No old logs were edited.
- This note records the command-surface change only; it does not alter the preserved rescue images or historical logs.
