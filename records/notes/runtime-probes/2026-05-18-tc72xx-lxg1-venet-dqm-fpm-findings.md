# 2026-05-18 — TC72XX LxG1 OEM tree VENET/DQM/FPM findings

## Summary

The `~/src/tc72xx-oem-lxg1` Linux GPL tree contains Broadcom BCM3384 VENET prebuilt objects, but not the low-level Broadcom DQM/FPM/SEGDMA/UNIMAC source/header layer.

Important objects:

```text
bcmdrivers/broadcom/net/venet/impl3/3384/bcmvenet.o
bcmdrivers/broadcom/net/venet/impl3/3384/bcm_venet.o

file/readelf showed these are:

ELF 32-bit MSB relocatable, MIPS, MIPS32, with debug_info, not stripped

The original source path embedded in DWARF/debug data is:

/home/mailen/git_test2/TC72XX_LxG1.0.10mp5_OpenSrc/bcmdrivers/broadcom/net/venet/bcm93384/bcmvenet.c
Main finding

bcmvenet is not the low-level GENET TDMA driver.

The TX path observed from disassembly is:

bcmvenet_xmit
  -> fpm_alloc_buffer
  -> memcpy
  -> ItcNiSend
  -> fpm_buffer_to_token
  -> bcm_dqm_send

The RX path is:

bcm_dqm_receive
  -> fpm_token_to_buffer
  -> _dma_cache_inv
  -> netif_receive_skb

So the vendor path appears to be:

Linux netdev
  -> VENET
  -> FPM buffer/token
  -> DQM queue
  -> firmware / IOP / SEGDMA / UNIMAC path

not:

Linux netdev
  -> bcmgenet
  -> GENET TDMA ring16 descriptor path
Missing proprietary/generated layer

The following header names appear in object strings/debug data:

fpm_ctrl.h
fpm_pool.h
unimac_mbdma.h
unimac_mbdma_hfb.h
ioproc_dqm64_blockdef.h
ioproc_dqmlite_blockdef.h
segdma_regs.h
bcmdqm.h

But find and grep did not locate them in the GPL tree. This suggests they were part of Broadcom's private/generated build environment and were not released.

Impact on OpenWrt GENET work

This explains why direct upstream bcmgenet TDMA testing can remain stuck even when ring registers, producer index, interrupts, and descriptor RAM look sane.

Current OpenWrt branch remains:

9990 = v2 DMA regmap useful
9991 = normal descriptor status after v2 regmap
next if 9991 fails = descriptor-size / high-word / 16-byte descriptor test

The OEM tree supports checking descriptor-size/high-word handling because the public Broadcom headers expose both DmaDesc and DmaDesc16, plus DMA_DESCSIZE_SEL = 0x00040000.

Conclusion

Do not derive a direct bcmgenet patch from bcmvenet_xmit. It is the wrong layer.

Use the finding as architecture evidence:

BCM3384 vendor Ethernet path may use VENET + DQM/FPM + SEGDMA/UNIMAC/IOP,
while OpenWrt is currently forcing direct GENET TDMA ring16.
