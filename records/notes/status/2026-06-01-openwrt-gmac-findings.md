# 2026-06-01 TC7200U OpenWrt GMAC findings

## Build/source state

- OpenWrt target config confirmed: `bmips / bcm63268 / technicolor_tc7200u / Linux 6.12`.
- Active BMIPS GENET driver path: `build_dir/target-mips_mips32_musl/linux-bmips_bcm63268/linux-6.12.91/drivers/net/ethernet/broadcom/genet/bcmgenet.c`.
- Earlier `find | head -1` selected the wrong AArch64/Mediatek `bcmgenet.c`; ignore that path.
- `target/linux/bmips/patches-6.12` is clean. Only the active `998-bmips-tc7200u-gmac-init.patch` exists for the TC7200U GMAC patch.
- `target/linux/prepare` now applies `998-bmips-tc7200u-gmac-init.patch` successfully. Hunk 3 applies at line 293 with fuzz 1.

## Reverse-engineering findings

- `fn_enet_gmac_init_step1()` is only a wrapper around `fn_enet_gmac_init_core()`.
- `fn_enet_gmac_init_core()` performs top-control/reset/clock style writes, not direct GENET DMA setup.
- Important top-control register from stage1: `0x14e000ec`; OEM sets bit `0x100`.
- `fn_enet_gmac_init_step2()` stages GMAC command bits through `0x12c00070`.
- Runtime showed `0x12c00070 = 0x00030003`, so the correct stage1-style bits are `0x00030000` and `0x00000003`, not `0x00003000`.
- `fn_enet_gmac_init_step6()` programs UNIMAC/GMAC interface registers including offsets `0x208`, `0x214`, `0x01c`, and `0x020` from the interface base.
- Reverse output shows `reg[0x214] = (reg & 0xffffc000) | 0x00000800`; the patch previously used `0x00008000`, which was wrong.

## Runtime findings

- `0x14e000ec` was initially `0x00000000` on OpenWrt.
- Manual write `0x14e000ec |= 0x100` sticks and changes it to `0x00000100`.
- Manual write to `0x140002cc` did not stick; it stayed `0x00000001`, so do not include it in the current patch.
- After setting `0x14e000ec |= 0x100`, link comes up at `1Gbps/Full`.
- Packet path still fails: `rx_packets = 0`, `rx_bytes = 0`, ping has 100 percent packet loss.
- TX attempts increase, but RX remains completely dead.
- Debug traces show suspicious descriptor/ring behavior: `rb_len` and `rb_addr` equal `bd_addr`, and `free=` values become impossible large numbers such as `95251` and `99062`.

## Patch changes made

- Added `TC7200U_GMAC_MISC_CTRL` for `0x14e000ec`.
- Added OEM-style write: `val |= 0x100` to `TC7200U_GMAC_MISC_CTRL`.
- Corrected `0x00008000` to `0x00000800` for the `base + 0x214` seed.
- Updated first patch hunk header to `@@ -144,6 +145,105 @@`.

## Current conclusion

- `0x14e000ec |= 0x100` is likely required for GMAC/link enable.
- The remaining blocker is not basic link enable.
- The active blocker is likely GENET ring or descriptor handling: descriptor layout, ring producer/consumer offsets, DMA descriptor address calculation, or GENET version mismatch.

## Next steps

1. Finish kernel compile and install.
2. Boot new image.
3. Verify `devmem 0x14e000ec 32` returns `0x00000100` before manual writes.
4. Verify `0x12c02814` reflects the corrected `0x00000800` style programming, not old `0x00008000`.
5. Continue investigation in the GENET descriptor/ring path, not top-control reset bits.

## 2026-06-01 build/run record: console-good based update

- Built new candidate from current `~/src/openwrt` tree using the console-good image as ProgramStore preserve template:
  - output: `/mnt/c/tftp/tc7200-stage2-console-good-gmac-r1.bin`
  - wrapped sha256: `52f87755bd3c70c161bf2b820b48ff71d09433ddf2492ee66cca1f98845da6fe`
  - raw sha256: `d26a3c7c82d358acfc79b776772b79636b2b303219ea08b87b176f8f00ce76e0`
- Preserve-from baseline used:
  - `/mnt/c/tftp/tc7200-stage2-console-good.bin`
  - baseline sha256: `a2b9fa164d092387dc0382698cbdff940bb97cce6c41a029ac70c1b357497c4b`
  - effective wrapped load: `0x82000000`
- Build and wrap logs:
  - `records/logs/builds/2026-06-01-220558-build-provenance.log`
  - `records/logs/builds/2026-06-01-220558-target-linux-install.log`
  - `records/logs/builds/2026-06-01-220558-wrap.log`
  - `records/logs/builds/2026-06-01-220558-verify.log`
- Note: default patch precheck failed for `build-mode=auto/install` due linux tree path mismatch; successful run used `--skip-precheck`:
  - failure log: `records/logs/builds/2026-06-01-220527-patch-precheck.log`

## 2026-06-01 syncconfig recovery (single-repo flow)

- Failure root-cause confirmed from `records/logs/builds/2026-06-01-223648-target-linux-compile.log`:
  - Kconfig interactive prompt at `RTC_DRV_BRCMSTB (NEW)` triggered `syncconfig` failure.
- Recovery applied in single repo (`~/src/openwrt`):
  - restored TC7200U files from stash (`bcm63268.mk`, TC7200U DTS files, `998-bmips-tc7200u-gmac-init.patch`)
  - ensured kernel config contains `# CONFIG_RTC_DRV_BRCMSTB is not set`
- Validation:
  - `make -j16 target/linux/compile V=s` now exits `0` on commit `6865d489d2` (r34427 lineage).
- New candidate built from recovered state, preserving console-good wrapper envelope:
  - output: `/mnt/c/tftp/tc7200-stage2-console-good-gmac-r34427-r2.bin`
  - build report: `records/logs/builds/2026-06-01-225438-build-provenance.log`
  - verify log: `records/logs/builds/2026-06-01-225438-verify.log`
