# Logs

This directory stores raw and run-level logs close to their original form.

## Layout

- `serial/`: serial boot logs, picocom captures, and runtime collection logs.
- `cfe/`: CFE filename, HCS failure, and recovery logs.
- `tftp/`: host-side TFTP, packet, route, neighbor, link, and ping proof
  captures. Store each run in a dedicated subdirectory named
  `<YYYY-MM-DD>-<version>/`.
- `builds/`: OpenWrt build, install, wrap, verify, and package-profile logs.

## Current Highlights

- `serial/picocom-20260524-*.log` and `serial/picocom-20260525-*.log`: latest
  GENET/TDMA serial capture batches.
- `tftp/2026-05-26-v14-rxonly/`: latest host-side TFTP and packet capture batch.
- `builds/`: compile/install/wrap records created by the helper.

Keep summaries in `records/notes/` and generated manifests in
`records/generated/`.
