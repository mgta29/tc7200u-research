# TC7200.U Workflow

Safe flow:
build OpenWrt -> wrap initramfs -> verify size_ok=True -> TFTP fixed filename

Main command:
tcwrap

Manual check:
tccheck

Verify wrapped image:
tcverify

Safe TFTP file:
/mnt/c/tftp/openwrt-ps-irqfallback.bin

Required success marker:
size_ok=True

Do not rename:
openwrt-ps-irqfallback.bin
