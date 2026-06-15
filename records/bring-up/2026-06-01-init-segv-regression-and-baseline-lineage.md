# 2026-06-01 init SIGSEGV regression and baseline lineage

Question answered: "Do we know how the last working one was made?"

Yes. The project has two different payload families. They were mixed during
testing, which created the "running in circles" effect.

## Family A (known console-working baseline)

- Serial evidence:
  - `records/logs/serial/picocom-20260531-050727.log`
  - `records/logs/serial/picocom-20260531-182309.log`
- Boot markers:
  - `Load Address: 80004000`
  - `File Length: 6417987 bytes`
  - `Linux version ... #0 SMP Sun May 17 18:30:33 2026`
  - `procd: - init -`
  - `Please press Enter to activate this console.`
  - `BusyBox v1.37.0 ...`
- Source lineage:
  - Wrapped from `openwrt-ps-irqfallback.bin` payload.
  - payload hash: `a17f022f1ef947ee16f60f0481f315fc399278ca574fb73c6ddcf548efbe0deb`
  - evidence: `records/logs/builds/2026-05-31-083754-verify.log`

## Family B (current failing r34427-built payloads)

- Serial evidence:
  - `records/logs/serial/picocom-20260531-215656.log`
  - `records/logs/serial/picocom-20260531-223409.log`
- Boot markers:
  - `Run /init as init process`
  - `do_page_fault(): sending SIGSEGV to init`
  - `Kernel panic - not syncing: Attempted to kill init!`
- Example payload:
  - `tc7200-stage2-r34427-nand-ok-r1.bin`
  - `raw_sha256 d7251f8429d27521fbe45680306ae2b883d354dacd877b5e238dfb20c7cb1906`
  - evidence: `records/logs/builds/2026-05-31-223226-build-provenance.log`

## Why it looked circular

- Gate A/C/D kept passing, so kernel load and early boot looked healthy.
- Gate E flipped between PASS/FAIL depending on which payload family was
  booted, not because of the same unchanged image.
- Some runs were also observed too early (`boot_not_fully_observed`), hiding
  the later `init` panic.

## Rule going forward

For every boot result, always log and compare these four IDs before concluding
regression/fix:

1. `Filename`
2. `File Length`
3. `raw_sha256`
4. `wrapped_sha256`

If any of these differ, treat it as a different candidate, not a rerun.
