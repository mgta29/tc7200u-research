# Tomorrow plan: TC7200.U NAND / serial cleanup

## First goal

Restore a known booting baseline before any new NAND test.

Acceptable baseline:

    OpenWrt shell appears

Known old NAND baseline:

    bcm6368_nand 14e02200.nand: timeout waiting for command 0x9
    bcm6368_nand 14e02200.nand: intfc status c0000000
    nand: No NAND device found

Do not continue NAND work from an image that panics during unpack_to_rootfs.

## Serial automation

Use:

    tcserial

This should:

- attach USB serial through usbipd
- load usbserial and ch341
- find /dev/ttyUSB* or /dev/ttyACM*
- start picocom at 115200
- write log into ~/tc7200u-research/logs/

Use only one serial terminal. Do not run multiple picocom sessions on the same device.

## Early console cleanup

Keep serial output simple:

    console=ttyS0,115200 earlycon

Avoid adding extra console targets. Goal: one active serial login path with the normal prompt:

    Please press Enter to activate this console.

## NAND debug prints to add

Add as a persistent OpenWrt patch, not direct build_dir edits.

Target debug values:

- BRCMNAND_CS_SELECT before OpenWrt clear
- BRCMNAND_CS_SELECT after OpenWrt clear
- BRCMNAND_CS_SELECT after TC7200.U force
- NAND controller revision register
- NAND command timeout command value
- NAND interrupt/status register around timeout

Expected test force value:

    CS_SELECT = AUTO_DEVICE_ID_CFG | EBI_CS_0_USES_NAND | EBI_CS_0_SEL
    CS_SELECT = 0x40000101

## Current ground-truth clues

CFE reports:

    BCM3383A2
    Chip ID: BCM3383Z-B0
    SPI flash ID 0xc22014, size 1MB
    NAND flash: Device size 64 MB, Block size 16 KB, Page size 512 B
    Switch detected: 53125
    ProbePhy: Found PHY 0, MDIO on MAC 0, data on MAC 0
    Using GMAC0, phy 0

## Rules

RAM/TFTP only. No flash writes.

For kernel/DTS testing:

    cd ~/src/openwrt; make -j$(nproc) target/linux/compile V=s; make -j$(nproc) target/linux/install V=s; cd ~/tc7200u-research; scripts/tc7200u wrap

For broken rootfs/initramfs baseline recovery, use full build:

    cd ~/src/openwrt; make -j$(nproc) V=s; cd ~/tc7200u-research; scripts/tc7200u wrap

Only TFTP after size_ok=True.
