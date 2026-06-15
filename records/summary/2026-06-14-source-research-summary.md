# TC7200U source-research summary

Date: 2026-06-14
Scope: summarize the reference notes under `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research`

## Executive summary

The `source-research` directory is the external-reference bucket for the TC7200U work. Its most important value is not broad family background, but a small set of direct source-tree findings that changed implementation choices in the live port.

The strongest actionable conclusions from this directory are:

- `0x14e01000` should be treated as HSSPI, not the primary Ethernet MAC
- the likely Linux/OpenWrt Ethernet direction is `GENET @ 0x12c00000` with BCM3383-specific GMAC init
- NAND should be approached as a BCM3383-specific `brcmnand v4` style problem, not by assuming the earlier `v5` guess was correct
- stock and similar firmware are useful as format and layout references only, not as safe flashing targets

The directory also shows a confidence split:

- direct source-tree notes from `linux-technicolor-tc7200` and TC72XX OEM trees are the highest-value technical references
- firmware-version and family reports are useful context, but lower-confidence for register-level porting choices

## Highest-value actionable findings

### Ethernet direction changed because of source evidence

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-linux-technicolor-genet-finding.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-17-similar-firmware-useful-map-data.md`

Most important technical result:

- the Technicolor Linux tree maps:
  - `spi@14e01000`
  - `ethernet@12c00000` as `brcm,genet-v1`
- the same source tree carries a BCM3383 GMAC init path that includes pinmux, clock, and reset behavior

Why this mattered:

- it directly undermined the earlier `bcm6368-enetsw @ 0x14e01000` line of testing
- it gave the first strong source-backed reason to move runtime work toward `GENET`

Related high-value map data:

- the similar-firmware mapping note adds KSEG1 aliases, interrupt-bank clues, NAND and HSSPI identities, and the warning not to mix OEM `0x84010000` Linux layout assumptions with the observed OpenWrt `0x82000000` RAM-boot behavior

### NAND direction changed because of OEM tree evidence

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-oem-bcm3383-nand-v4-clue.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-tc72xx-oem-bcm3383-nand-source-found.md`

Most important technical result:

- OEM TC72XX sources include BCM3383-specific NAND code and defconfigs
- the notes point to `BRCMNAND_MAJOR_VERS=4`
- this contradicts the earlier OpenWrt-side `brcmnand-v5` assumption that was timing out

Why this mattered:

- it changed NAND work from blind probing toward a BCM3383-specific comparison against OEM code and platform setup
- it reinforced the "read-only first" rule for flash-map work

## Useful but lower-level supporting research

### jclehner/tc7200 README findings

Key source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-jclehner-tc7200-readme-findings.md`

What it usefully provided:

- Broadcom ProgramStore context
- partition and dump-method clues
- eCos/Linux split context

What it did not solve:

- Ethernet register locations
- MDIO details
- switch init
- DTS

Practical value:

- useful for partition and firmware-layout orientation
- not enough by itself to solve the live OpenWrt Ethernet port

### Similar firmware and variant notes

Key sources:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-tc7200-similar-firmware.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-hungarian-vodafone-upc-tc7200-firmware-versions.md`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-17-tc7200-family-docsis3-firmware-notes.md`

What these notes contribute:

- firmware naming patterns
- variant-risk warnings across TC7200, TC7200.U, TC7200.20, TC7200.d, TC7210, and TC7230
- examples of ProgramStore-related filenames and firmware branch labels
- confirmation that official firmware distribution is ISP-controlled, not a public download path

Practical project rule repeated across these notes:

- use similar or stock firmware only as reference material
- do not flash random ISP or variant images

### Generic porting guidance

Key source:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-17-openwrt-new-device-porting-guide.md`

Practical role in this directory:

- general OpenWrt porting checklist
- useful as background process guidance
- not a device-specific source of truth

## Confidence model for this directory

Highest confidence for implementation decisions:

- `linux-technicolor-tc7200` tree findings
- TC72XX OEM source-tree findings
- direct file/path/mapping notes extracted from those trees

Medium confidence:

- README-level device notes
- similar-firmware comparison notes

Lower confidence or context-only:

- broad firmware-version surveys
- generic device-porting guide material
- family-wide research reports that are useful for orientation but not definitive for live register behavior

## Durable conclusions from this directory

- The source evidence strongly supports the `GENET @ 0x12c00000` direction.
- `14e01000` should stay classified as HSSPI.
- BCM3383-specific NAND handling is likely required.
- OEM source trees are more valuable than generic modem-family reports when there is a conflict.
- Similar firmware references are useful for wrapper, ProgramStore, partition, and naming comparisons, not for direct flashing or blind board assumptions.

## Practical baseline for future research use

If work resumes from this directory alone, the best use of it is:

- use the direct source-tree notes first for hardware mapping
- use similar-firmware notes second for image-format and variant comparison
- treat broad community reports as context, not final proof
- preserve the "reference only, no flashing" rule for stock and ISP firmware

## Suggested reading order

For the fastest technical review:

1. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-linux-technicolor-genet-finding.md`
2. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-17-similar-firmware-useful-map-data.md`
3. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-oem-bcm3383-nand-v4-clue.md`
4. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-jclehner-tc7200-readme-findings.md`
5. `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\source-research\2026-05-15-tc7200-similar-firmware.md`

## Change log

- 2026-06-14: created this summary in `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\summary` from the existing source-research notes.
- 2026-06-14: no older log or note file was edited by this summary pass.
