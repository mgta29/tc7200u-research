# TC7200.U Safety Rules

## Non-negotiable rules

- RAM boot only.
- Do not flash yet.
- Do not use CFE `d`, `s`, `e`, `E`, or `X` for persistent writes.
- Do not replace the rescue image with an HCS-failing build.
- Do not rename the CFE-requested TFTP file.

## Known-good rescue image

Current known-good RAM boot image:

```text
artifacts/rescue/openwrt-tc7200u-known-good-ramboot-20260515-125821.bin
```

Facts:

- Size: `5097194` bytes.
- SHA256:
  `14b05d771147ab37c388894cd5a66fc2bed230176068902d4444ce29ef1fb8ae`.
- Result: OpenWrt booted to userspace.

Original A825 rescue baseline:

```text
artifacts/rescue/openwrt-ps-irqfallback-GOOD-5696426.bin
```

Facts:

- Received size: `5696426` bytes.
- ProgramStore signature/PID: `a825`.
- Load address: `0x82000000`.
- Result: HCS passed, CFE executed Image 4, OpenWrt booted to userspace.
- SHA256:
  `2ae4afb92e4df065e88d61bcbac9f693c6a853e1ff349e09d3c8e5cfae4ac513`.

## Safe build, wrap, TFTP flow

1. Build OpenWrt first.
2. Run `scripts/tc7200u-wrap-current-openwrt.sh`.
3. Confirm the generated manifest says `size_ok=True`.
4. Serve only `/mnt/c/tftp/openwrt-ps-irqfallback.bin`.
5. Let CFE request `openwrt-ps-irqfallback.bin`; do not rename it inside CFE.

Generated wrap manifests now go to:

```text
research/notes/generated/
```

Override when needed:

```sh
RESEARCH_NOTES_DIR=/tmp/tc7200u-notes scripts/tc7200u-wrap-current-openwrt.sh
```

## Invalid or risky image classes

- Raw OpenWrt initramfs images without the TC7200U `a825` Program Header.
- 12-byte `scripts/cfe-bin-header.py` loader-header images.
- HCS-failing generated images unless explicitly kept as comparison artifacts.
- Any GENET or Ethernet test image that later shows memory corruption, page
  table warnings, or RCU stalls.

## Recovery posture

Keep these separate:

- Rescue baseline: `artifacts/rescue/`.
- Test images: `artifacts/test-images/`.
- Invalid comparison images: `artifacts/invalid/`.

The active CFE/TFTP image remains outside the repo:

```text
/mnt/c/tftp/openwrt-ps-irqfallback.bin
```
