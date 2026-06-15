# TC7200U status-note summary

Date: 2026-06-14
Scope: summarize the project-state and workflow notes under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status`

## Executive summary

The `records/status` directory is not a raw experiment log. It is the project’s milestone, control-policy, and operator-workflow layer. The notes in this directory do three different jobs:

- freeze the current technical baseline and known-good control images
- record higher-level reverse-engineering conclusions that changed the project direction
- document the canonical helper, repo, and artifact-handling workflow so later work stays reproducible

The biggest durable lessons from this directory are:

- boot/container format and full userspace shell were already solved well enough to support focused Ethernet work
- the project must keep the known-good console family separate from newer rebuilt payload families
- helper and repo workflow were deliberately tightened so build, wrap, verify, logging, and candidate generation stay traceable

## Main themes in this directory

### 1. Baseline control and gate discipline

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-05-16-current-tc7200u-bringup-baseline.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-05-31-openwrt-port-checklist.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\20260614-214814-console-family-split.md`

What these notes establish:

- boot progression should be judged through explicit gates, not by vague impressions
- there is a known-good control-image family that reaches userspace shell
- there is also a later rebuilt family that can fail in different ways and must not be conflated with the control family

Most important operational rule from this cluster:

- before comparing Ethernet behavior, pin and compare:
  - served filename
  - file length
  - raw hash
  - wrapped hash
  - load address
  - kernel version line

Why this matters:

- several failures later in the project were not pure "same image rerun" regressions
- they were different payload families that only looked similar from a distance

### 2. Boot path moved from historical working profiles to a maintained canonical flow

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-05-31-openwrt-port-checklist.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-02-canonical-a825-wrapped-flow.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-working-settings-modes-compression-build-summary.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-guideline-next-better-working-image.md`

What this cluster records:

- the project had an earlier proven `0x80004000` stage-2 working path
- later workflow standardized on preserving the known-good `A825` envelope from the console-good baseline
- the maintained operator path now treats the canonical wrapped-image load policy as `0x82000000`

Important consequence:

- both histories matter
- they should not be mixed casually
- wrapper/load-address changes are no longer the default debugging axis when the goal is "better Ethernet behavior"

The current operator rule recorded by the later notes is:

- keep the canonical preserve-from template
- keep the console-good control image available for A/B checks
- treat Ethernet improvement as the metric, not wrapper churn

### 3. Reverse-engineering milestones that changed the live project

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-05-31-stage1-reverse-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-07-stage1-mips32-confirmation.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-07-ghidra-interactive-mapping-findings.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-08-bootlinux-mips32-remap.md`

What these notes add:

- the stage1 image import mode was corrected to `MIPS:BE:32:default`
- BootLinux, NAND replacement, and TP-handshake paths were mapped at a much higher confidence level
- earlier misreads from pre-cleanup or wrong-ISA interpretation were explicitly retracted

Most useful durable findings from this cluster:

- stage1 reverse work identified real failure anchors:
  - NAND replacement failure path
  - TP handshake/unexpected-message loop
- the project became more disciplined about:
  - trusting string xrefs
  - deleting false function splits
  - preserving correction notes so stale labels are not reused

### 4. GMAC/GENET findings were narrowed to real link-enable clues plus deeper packet-path blockers

Key source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-01-openwrt-gmac-findings.md`

Most important result:

- `0x14e000ec |= 0x100` is recorded as a real required or strongly useful link-enable style write

What it did not solve:

- packet movement
- RX accounting
- descriptor/ring correctness

Why this note matters:

- it marks the project’s shift from top-control or link-up debugging into descriptor, ring, DMA, or version-mismatch debugging

### 5. Helper, logging, and repo workflow were intentionally made reproducible

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-05-31-script-wrapper-provenance-update.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-07-tcbuilder-interactive-default.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-tcbuilder-candidate-mode.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-tcbuilder-modular-main-flow.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-generated-dir-cleanup.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-repo-tree-doc-refresh.md`

What this cluster records:

- `scripts/tcbuilder.sh` became the single canonical helper surface
- interactive vs auto behavior was formalized
- candidate-mode packaging, patch capture, logging, and hash reporting were added
- repo documentation and log placement were cleaned up to match the real tree

Most important practical effect:

- build, wrap, verify, state capture, candidate prep, and serial/log artifact placement became easier to reproduce and audit

## Durable conclusions from this directory

- The `status` directory is the best place to reconstruct the project’s current operator rules.
- It preserves the distinction between:
  - historical working boot profiles
  - current canonical helper flow
  - known-good console control images
  - newer mutable rebuild families
- It also preserves corrections, not just conclusions, which is important because several earlier interpretations were intentionally revoked later.

## Practical baseline for future work

If work resumes from this directory alone, the best assumptions to carry forward are:

- use the known-good console family as the control baseline
- do not mix payload families during regression claims
- keep wrapper/container changes frozen unless wrapper behavior itself is under test
- focus new "better image" work on measurable Ethernet improvement
- use the canonical `tcbuilder` workflow so every candidate is reproducible and logged

## Suggested reading order

For the fastest reconstruction of current project state:

1. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-05-16-current-tc7200u-bringup-baseline.md`
2. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-05-31-openwrt-port-checklist.md`
3. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-01-openwrt-gmac-findings.md`
4. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-06-14-guideline-next-better-working-image.md`
5. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\20260614-214814-console-family-split.md`

## Change log

- 2026-06-14: created this summary in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\summary` from the existing status notes.
- 2026-06-14: no older log or note file was edited by this summary pass.
