# 2026-06-20 tcbuilder ENET carry refresh

## Scope

Updated the TC7200U helper so `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\scripts\tcbuilder.sh` carries the current ENET-facing defaults and reference values that are now stable enough to use from the maintained status/reverse notes.

This change is intentionally limited to:

- canonical no-template wrap defaults
- operator-visible helper reporting
- build provenance context

It does not change old logs, and it does not hardcode live runtime register contents that are still marked comparison-only.

## Source notes used

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\important-openwrt-tc7200u-enet-usable-values.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\reverse\important-openwrt-tc7200u-enet-usable-status.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-guideline-next-better-working-image.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-17-fresh-openwrt-console-success.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-devmem-fpm-genet-baseline.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-18-genet-fixedlink-probe-watchdog.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-fpm-live-mbdma-unprogrammed.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-txdump-tdma-stuck.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-19-genet-ctrlmap-debug-findings.md`

## Changes made

- changed the canonical no-template wrap-load default from `0x80004000` to `0x82000000`
- applied the same automatic canonical load default to `candidate` mode when no `--source-image` or `--preserve-from` template is present
- added carried ENET reference-note paths to:
  - `status`
  - `paths`
  - `capture-state`
  - build provenance logs
- added the current carried ENET compare-set addresses to helper output:
  - FPM compare set
  - GENET/MBDMA compare set
  - profile compare set
  - MDIO compare set
- added the current OEM comparison anchors to helper output without promoting the live runtime values themselves to hardcoded policy

## Why these changes are justified

The June 14 guideline and later maintained ENET status note make the load-address policy explicit:

- `0x82000000` is the canonical wrapped-image load address for new image work
- `0x80004000` remains a historical or experiment-specific path

The June 20 maintained ENET status note also cleanly separates:

- values that are stable enough to carry in the helper as compare targets
- live runtime readings that should remain observation-only until the GENET mapped-read repair is trustworthy

That means `tcbuilder` can safely carry:

- note references
- compare address sets
- OEM comparison anchors
- the canonical `0x82000000` default

but should not hardcode the current live FPM or GENET register contents as if they were final Linux policy.

## Verification

- `bash -n ./scripts/tcbuilder.sh ./scripts/tcbuilder/*.sh`
- `./scripts/tcbuilder.sh paths`
- `./scripts/tcbuilder.sh status`
