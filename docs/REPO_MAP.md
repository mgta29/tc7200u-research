# TC7200.U Repo Map

Active scripts:
scripts/tc7200u - master command dispatcher
scripts/tc7200u-auto-build-install-wrap.sh - build/install/wrap/check workflow
scripts/tc7200u-wrap-current-openwrt.sh - wrap current OpenWrt initramfs
scripts/tc7200u-a825-wrap.py - A825 header writer
scripts/tc7200u-verify-a825-image.py - A825 image verifier
scripts/tc7200u-capture-current-state.sh - state capture helper

Obsolete scripts:
scripts/obsolete/make_tc7200u_ps_brcm.py - old experiment; wrong output filename

Important output:
/mnt/c/tftp/openwrt-ps-irqfallback.bin

Use only after:
size_ok=True
