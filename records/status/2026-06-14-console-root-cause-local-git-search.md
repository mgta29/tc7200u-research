# TC7200U console root-cause search across local git (2026-06-14)

## Scope

This note records the result of a local-git search requested on 2026-06-14 to
answer one question:

- why newer TC7200U OpenWrt images were failing to reach a usable serial console

Repos and sources searched in this pass:

- research repo:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research`
- live OpenWrt repo:
  - `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt`
- historical `openwrt-r34427` build lineage as preserved in provenance logs under:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds`

This is a new dated status note. Older logs and notes were left unchanged.

## Short answer

The failure was not primarily the A825 wrapper, CFE/TFTP transport, or the
physical serial setup.

The earlier broken rebuild family had two overlapping problems:

1. payload-family and provenance drift from the known-good console baseline
2. a real UART definition problem in the local OpenWrt source tree, where the
   inherited Viper `uart0` path was still based on the wrong register block for
   TC7200U rebuilds

Later on 2026-06-14, a rebuilt image did recover a usable console after the
local OpenWrt tree moved the inherited UART base to `0x14e00500`, kept
`CONFIG_BCM7120_L2_IRQ=y`, and disabled NAND for the test path.

So "cannot make a new image with usable console" was true for the earlier
broken rebuild family, but it stopped being true after the local UART/L2/NAND
source fixes were applied.

## Research-repo evidence

Key git-recorded status lineage inside:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research`

Important commits found:

- `8d50c49`
  - records the 2026-06-01 console-ready baseline refresh
- `312133d`
  - records the init-SIGSEGV regression lineage
- `4e99ddd`
  - records the console payload-family split
- `eae6ab4`
  - records the console baseline-family split summary

Known-good console baseline evidence:

- serial log:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\picocom-20260601-193010.log`
- gate report:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\2026-06-01-195304-check-gates-picocom-20260601-193010.txt`
- baseline note:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status\2026-05-16-current-tc7200u-bringup-baseline.md`

Known-good runtime markers in that serial log:

- `earlycon: bcm63xx_uart0 at MMIO 0x14e00500`
- `Kernel command line: console=ttyS0,115200 earlycon`
- `14e00500.serial: ttyS0 at MMIO 0x14e00500`
- `procd: - init -`
- `Please press Enter to activate this console.`
- `root login on 'ttyS0'`

Broken rebuild-family evidence:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\picocom-20260601-233331.log`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\picocom-20260614-131456.log`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\picocom-20260614-135834.log`

Common broken markers:

- `earlycon: bcm63xx_uart0 at MMIO 0x14e00500`
- `bcm63xx_uart 14e00500.serial: probe with driver bcm63xx_uart failed with error -16`
- `Warning: unable to open an initial console.`
- `Run /init as init process`
- `Kernel panic - not syncing: Attempted to kill init!`

This proves the broken images were still reaching earlycon and kernel start, but
they were not registering the real `ttyS0` console.

## Provenance-drift evidence

The research repo also preserves evidence that not all "new rebuilds" were the
same payload family.

Known-good raw and wrapped identity:

- verify log:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\2026-05-31-083754-verify.log`
- recorded values:
  - `raw_sha256=a17f022f1ef947ee16f60f0481f315fc399278ca574fb73c6ddcf548efbe0deb`
  - `wrapped_sha256=a2b9fa164d092387dc0382698cbdff940bb97cce6c41a029ac70c1b357497c4b`
  - `load_address=0x82000000`
  - `filename=openwrt-initramfs.bin`

Known-bad rebuilt family example:

- provenance log:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\2026-05-31-223226-build-provenance.log`
- recorded values:
  - `raw_sha256=d7251f8429d27521fbe45680306ae2b883d354dacd877b5e238dfb20c7cb1906`
  - `wrapped_sha256=46f4bb5693b97b52826d1a9fd497d49cd96db12a59eea9dbea5334ea6fe582d7`
  - wrapped from `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt-r34427`

Important nuance:

- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\generated\2026-06-01-190025-current-state.txt`
- `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\generated\2026-06-14-133154-current-state.txt`

Both state captures show the same board-DTS hash:

- `6745c8a99a2e2819ac0846cb6ec6f2dd4393fffc22bb88b059302cb0eb48802b`

But they show different raw-initramfs and `vmlinux` hashes.

Meaning:

- the board DTS alone did not explain the whole failure history
- payload lineage and build provenance were also drifting

## Live OpenWrt local-git evidence

The more concrete console failure reason came from the live local OpenWrt tree:

- `\\wsl.localhost\Ubuntu\home\mgta29\src\openwrt`

The local OpenWrt repo history does not yet contain committed upstream TC7200U
console fixes. The TC7200U board, UART, and config changes are local staged or
working-tree edits on top of upstream BMIPS history.

### Earlier local staged TC7200U state

Local staged diff showed:

- `target/linux/bmips/dts/bcm3384_viper.dtsi`
  - inherited `uart0: serial@14e00520`
- `target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts`
  - board override changed `&uart0` to `reg = <0x14e00500 0x18>`
- `target/linux/bmips/image/bcm63268.mk`
  - local TC7200U image recipe was added

That state is important because it leaves the base Viper UART identity wrong
while the board-level override tries to remap it later.

This matches the broken runtime symptom well:

- earlycon can print from the intended MMIO base
- the late real serial driver registration can still collide or fail
- the failure code is `-16`, which is `EBUSY`

### Later local working-tree recovery state

Local working-tree diff then showed the recovery-side changes:

- `target/linux/bmips/dts/bcm3384_viper.dtsi`
  - move inherited `uart0` base from `0x14e00520` to `0x14e00500`
- `target/linux/bmips/dts/bcm3383-technicolor-tc7200u.dts`
  - disable NAND for the RAM-boot console test path
- `target/linux/bmips/bcm63268/config-6.12`
  - enable `CONFIG_BCM7120_L2_IRQ=y`
  - enable `CONFIG_DEVTMPFS=y`
  - enable `CONFIG_DEVTMPFS_MOUNT=y`
  - enable `CONFIG_DEVTMPFS_SAFE=y`

Important interpretation:

- `CONFIG_DEVTMPFS*` was not the first blocker
- the earlier logs fail before a usable initial console exists
- the UART base/path cleanup and `CONFIG_BCM7120_L2_IRQ=y` are the stronger
  console-recovery changes
- NAND disable reduced a separate stall/noise source in the RAM-boot path

## Recovered new-image proof

Later on 2026-06-14, a new rebuilt image did recover the usable console path.

Relevant records:

- build provenance:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\2026-06-14-205815-build-provenance.log`
- verify log:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\builds\2026-06-14-205815-verify.log`
- serial log:
  - `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\logs\serial\picocom-20260614-212432.log`

Recovered image identity:

- filename:
  - `tc7200u-uart500-l2-nandoff.bin`
- `raw_sha256=9d0fc5958a37bae4348fa293287e340ad0ba6bc5936afbabb35fbf61e9646921`
- `wrapped_sha256=b5448b778f204383ea0586aeedfa70c39f81ab0e72ed820c3317d858a381ffaa`
- `load_address=0x82000000`

Recovered runtime markers:

- `Please press Enter to activate this console.`
- `login[376]: root login on 'ttyS0'`

So by the end of 2026-06-14, a new image with usable console had been rebuilt.

## Root cause conclusion

The local-git search supports this conclusion:

1. The A825 wrapper and CFE transport were not the main blocker.
2. The known-good console family and the broken rebuild family were being mixed
   together in earlier comparisons.
3. The broken rebuild family had a real local source-tree UART problem:
   - base Viper UART definition still pointed at the wrong register base
   - board-level remap alone was not enough for a clean late `ttyS0` bind
   - runtime symptom was `bcm63xx_uart ... failed with error -16`
4. `CONFIG_BCM7120_L2_IRQ=y` remained necessary for the serial path.
5. NAND disable was a useful companion change for RAM-boot console recovery.
6. After those local source changes, a rebuilt image again reached a usable
   serial console.

## Practical rule going forward

For future TC7200U rebuilds, treat these as the required local baseline until a
cleaner upstreamed form exists:

- inherited Viper `uart0` based on `0x14e00500`
- TC7200U board DTS using the same real UART path
- `CONFIG_BCM7120_L2_IRQ=y`
- exact image identity recorded for every test:
  - filename
  - file length
  - raw SHA256
  - wrapped SHA256
  - load address
  - kernel version line
- known-good console family kept separate from experimental rebuild families

## Change log

- 2026-06-14: created this new status note in
  `\\wsl.localhost\Ubuntu\home\mgta29\tc7200u-research\records\status`
  from the local-git search findings.
- 2026-06-14: no older logs or notes were edited by this logging pass.
