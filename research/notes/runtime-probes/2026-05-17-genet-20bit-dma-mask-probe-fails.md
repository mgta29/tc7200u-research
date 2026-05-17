# TC7200.U GENET 20-bit DMA mask test failed at probe

Scope:
- RAM/TFTP boot only.
- Do not flash.
- Test patch: 9977-bcmgenet-tc7200u-20bit-dma-mask-test.patch.

Observed:
- Image booted far enough to kernel.
- GENET probe failed:
  - bcmgenet 12c00000.ethernet: probe with driver bcmgenet failed with error -5
- No eth0 runtime test was possible.
- Later boot hit unhandled kernel unaligned access and panic during rootfs unpack.

Interpretation:
- Forcing dma_set_mask_and_coherent(... DMA_BIT_MASK(20)) is not usable in this kernel/platform configuration.
- This does not disprove the 20-bit descriptor address-window theory.
- It only proves that normal Linux DMA mask forcing is not the right test path.

Next:
- Remove 9977.
- Return to descriptor readback diagnostics.
- Investigate BCM3383 GENET DMA address translation/window/base setup.
- Possible next direction: device-tree dma-ranges or BCM3383-specific DMA base register, not DMA_BIT_MASK(20).

Do not do:
- Do not keep booting the 20-bit DMA mask image.
- Do not flash.
