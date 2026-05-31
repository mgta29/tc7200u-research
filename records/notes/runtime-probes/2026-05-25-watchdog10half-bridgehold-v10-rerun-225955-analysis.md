# 2026-05-25 v10 rerun freeze (`picocom-20260525-225955.log`)

## Artifact
- Serial: `records/logs/serial/picocom-20260525-225955.log`

## What this run is
- This is **not** the RX-only v11 script.
- Marker confirms old TX-stress script path:
  - `=== phase1 fill tx ring (6 rounds x 120 one-shot stress) ===`

## Completion status
- Incomplete run.
- Reached:
  - `phase1 round 1/6` (delta `0`)
  - `phase1 round 2/6` (delta `0`)
  - `phase1 round 3/6` and stopped at `burst progress 40/120`
- Missing:
  - `post1`, `post2`, `done`
- No manual interrupt recorded:
  - `ctrlc=0`

## Pre-checkpoint low-level state (before freeze)
- `txq0_packets=714`
- `rxq0_packets=0`
- `rbuf_err_cnt=1588`
- `mdf_err_cnt=1592`
- This matches prior v10 post-state baseline and shows no new RX evidence.

## Interpretation
- Repeat of prior stall pattern in TX-stress loop.
- No new RX-path signal gained from this run.
- Indicates script-selection/process issue more than a new network behavior change.

## Action
- Use RX-only v11 script path explicitly:
  - `/home/mgta29/send-next-watchdog-fill-10half-bridgehold-v11.txt`
- Verify banner line **before** run:
  - expected: `=== phase1 rx-only observe window (8 x 30s) ===`
