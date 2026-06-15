# TC7200U image-format summary

Date: 2026-06-14
Scope: summarize the notes and sidecar records currently under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format`

## Executive summary

The `records/image-format` directory captures the first focused investigation into what kind of TFTP image the TC7200U CFE will actually accept and execute. The durable result is that this is primarily a CFE-header and wrapping problem, not just a raw-kernel problem. The known-good path is an `a825` CFE Program Header wrapped image that preserves the expected load address and embedded filename format. Ad hoc alternatives, especially files starting with a simple 12-byte loader header or incorrectly staged MMIO/logger candidates, are explicitly marked invalid.

The most important preserved baseline in this directory is the known-good `openwrt-ps-irqfallback` family image recorded at `5696426` bytes. That image is noted as CFE-accepted and as successfully reaching the OpenWrt kernel loader. Several nearby candidates, especially the `5696896` MMIO/HCSFAIL images, never reached kernel execution at all because CFE rejected them first.

The directory also records two operational corrections that matter for later experiments:

- a failed wrapper attempt was initially misinterpreted because the old known-good image was still staged
- the correct wrapping path should follow the BMIPS/OpenWrt CFE image flow, not a raw `scripts/cfe-bin-header.py` invocation with unsupported arguments

## Main conclusions

- TC7200U CFE expects an `a825`-style Program Header, not a 12-byte loader header.
- The external TFTP filename and the embedded header filename are different fields and both matter:
  - TFTP request name recorded: `openwrt-ps-irqfallback.bin`
  - embedded CFE header filename recorded: `openwrt-initramfs.bin`
- The recorded CFE load address is `0x82000000`.
- The known-good rescue baseline is the `5696426`-byte irqfallback image.
- A `5696896`-byte MMIO/logger candidate is explicitly marked as HCS-failed and invalid as a kernel-runtime test.
- One incorrect test flow was later corrected: the supposed MMIO logger image had not actually been staged because the wrapper command failed.
- A smaller `16 MiB` dictionary LZMA test image exists and may boot, but the notes prefer the restored `8 MiB` dictionary image for repeated TFTP testing because decompression is faster.

## Timeline

### 2026-05-14: header layout and good-vs-bad baseline established

Sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-222622-tftp-image-manifest.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-222909-image-file-map.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-cfe-header-analysis.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-cfe-header-byte-diff.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-known-good-image.json`

What these records establish:

- The raw initramfs image and the staged TFTP image are not identical files.
- The staged TFTP image carries a CFE header that includes:
  - `a825` signature bytes
  - a file-length field
  - load address `0x82000000`
  - embedded filename `openwrt-initramfs.bin`
- The known-good image record says CFE accepted the image and executed the OpenWrt kernel loader.

Most important durable good-state record:

- `received_bytes`: `5696426`
- `file_length`: `5696334`
- `hcs`: `1b46`
- `crc`: `f0b0a5b5`
- status: `CFE accepted image and executed OpenWrt kernel loader`

Interpretation:

- This directory’s baseline is not merely "a raw OpenWrt initramfs exists."
- The baseline is "a specifically wrapped CFE-accepted image exists, and its header fields are known enough to preserve."

### 2026-05-14: OpenWrt wrapper search narrowed the correct build path

Sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-222859-image-recipe-lzma.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-222907-image-recipe-lzma.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-openwrt-wrapper-search.txt`

What these searches contribute:

- The OpenWrt BMIPS image flow already contains CFE-aware LZMA and CFE build steps.
- The notes surface `lzma-cfe`, `cfe-bin`, and `cfe-jffs2-kernel` as relevant pieces of the upstream image path.
- The wrapper search also ties the TC7200U target to the BMIPS `technicolor_tc7200u` image definition.

Practical meaning:

- The right long-term approach is to reuse or mirror the existing OpenWrt BMIPS CFE wrapping logic.
- A hand-built header or a generic helper script is not assumed to be equivalent.

### 2026-05-14: invalid image forms were ruled out

Sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-not-cfe-12byte-loader-header.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-hcsfail-5696896.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-hcsfail-5696896-mmio.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-hcsfail-vs-good-header-cmp.txt`

What was ruled out:

- A file beginning with the 12-byte loader header from `scripts/cfe-bin-header.py` is explicitly marked not valid for TC7200U CFE TFTP boot.
- The `5696896` MMIO/logger candidate is explicitly marked as rejected by CFE before kernel start.
- Therefore any MMIO conclusions from that candidate are invalid.

Most important caution from these notes:

- "HCS failed" here means the kernel never ran.
- These failures are image-format failures first, not runtime-kernel failures.

### 2026-05-14: staging mistake identified and corrected

Source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-mmio-wrap-attempt-correction.txt`

What this correction changes:

- A previous assumption that the MMIO logger image had been tested was wrong.
- The wrapper command failed because `scripts/cfe-bin-header.py` did not support the attempted `--input`, `--output`, and `--name` arguments.
- The file actually staged at that moment was still the old known-good image.

Durable lesson:

- Do not trust a boot result unless the wrapped artifact identity was verified after staging.
- The note points toward the correct wrapper path being the host image tools such as `imagetag`, not the failed raw helper invocation.

### 2026-05-14: baseline preservation and dictionary-size preference recorded

Sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-test-lzma16m-image.json`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-restore-8m-dictionary-image.json`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-restored-known-good-after-mmio-hcsfail.txt`

What these records say:

- A smaller `16 MiB` dictionary LZMA variant was staged for TFTP-only testing.
- That test image recorded:
  - size `5684200`
  - `a825` signature
  - load address `0x82000000`
  - embedded filename `openwrt-initramfs.bin`
  - `hcs` `f445`
  - `crc` `6972317e`
- Even though that variant may boot, the notes explicitly restore the earlier `8 MiB` dictionary irqfallback image for normal repeated testing because decompression is slower on the `16 MiB` variant.

Operational baseline after restoration:

- preferred TFTP image remains the restored known-good `5696426`-byte irqfallback image
- known kernel status for that baseline: boots to OpenWrt shell
- known functional limitation remains: Ethernet still not active

## Artifact families in this directory

This directory mixes several record types:

- explanatory notes about CFE acceptance and wrapper choice
- JSON manifests for individual test images
- raw header hex dumps and size sidecars
- comparison artifacts between known-good and HCS-failed candidates

For follow-up work, the safest interpretation is:

- use the notes and JSON manifests to decide which candidate is authoritative
- treat raw header dumps and size files as supporting evidence, not the primary verdict source

## Practical baseline for future image work

If work resumes from this directory alone, the baseline to carry forward is:

- preserve the known-good `5696426`-byte irqfallback image as the rescue/control payload
- keep the `a825` Program Header structure intact
- preserve the embedded filename and load-address behavior already observed in the accepted image
- treat HCS-failed images as format failures, not kernel test results
- verify the staged artifact identity after every wrap or copy step
- prefer the established BMIPS/OpenWrt CFE wrapper flow over ad hoc script wrapping

## Suggested reading order

For the fastest review of the image-format record:

1. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-known-good-image.json`
2. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-cfe-header-analysis.txt`
3. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-not-cfe-12byte-loader-header.txt`
4. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-mmio-wrap-attempt-correction.txt`
5. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\image-format\2026-05-14-restore-8m-dictionary-image.json`

## Change log

- 2026-06-14: created this summary in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\summary` from the existing image-format records.
- 2026-06-14: no older log or note file was edited by this summary pass.

## 2026-06-15 correction: obsolete fixed-name reading

This summary records `openwrt-ps-irqfallback.bin` because that was the historical filename used in the cited image-format notes.

That filename is not a current fixed requirement.

Current interpretation:

- `openwrt-ps-irqfallback.bin` is a historical example
- the TFTP-served image can be named arbitrarily
- the only real requirement is that the served filename matches the filename CFE requests for that run

This correction is additive only and keeps the older filename references intact for provenance.
