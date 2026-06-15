# Logs

This directory stores raw and run-level logs close to their original form.

## Layout

- `serial/`: serial boot logs, picocom captures, and runtime collection logs.
- `cfe/`: CFE filename, HCS failure, and recovery logs.
- `devmen/`: raw devmem/devmen captures kept under the current directory name.
- `tftp/`: host-side TFTP, packet, route, neighbor, link, and ping proof
  captures. Store each run in a dedicated subdirectory named
  `<YYYY-MM-DD>-<version>/`.
- `builds/`: OpenWrt build, install, wrap, verify, and package-profile logs.

Keep summaries in the matching top-level topic directory under `records/` and
generated manifests in `records/generated/`. Do not place new summaries under
`records/notes/`.
