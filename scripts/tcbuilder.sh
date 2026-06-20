#!/usr/bin/env bash
set -euo pipefail

cat >&2 <<'EOF'
tcbuilder was removed.
Use ./scripts/programstore.sh directly.

Example:
  ./scripts/programstore.sh --input <raw-or-wrapped-image> --output <output-image> --filename openwrt-initramfs.bin
EOF

exit 1

