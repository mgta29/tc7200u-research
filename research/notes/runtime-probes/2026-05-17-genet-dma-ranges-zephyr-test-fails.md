# TC7200.U GENET Zephyr-style dma-ranges test failed

Scope:
- RAM/TFTP boot only.
- Do not flash.
- Test: added Zephyr-style dma-ranges to /ubus:
  - dma-ranges = <0x00000000 0x08000000 0x08000000>;

Observed:
- Kernel booted to shell.
- GENET did not reach useful TX descriptor diagnostic.
- Boot/runtime errors:
  - bcmgenet 12c00000.ethernet: unable to find MDIO bus node
  - bcmgenet 12c00000.ethernet eth0: failed to initialize Rx queues
  - bcmgenet 12c00000.ethernet eth0: failed to initialize DMA
  - RTNETLINK answers: Out of memory
- Runtime:
  - ip link set eth0 up failed with Out of memory
  - no TC7200U DESCRB output
  - no TC7200U TXPOLL output

Interpretation:
- Zephyr-style dma-ranges is wrong for TC7200.U/Viper.
- It breaks GENET DMA/RX initialization before descriptor diagnostics.
- This does not disprove the 20-bit descriptor window theory.
- Do not keep this dma-ranges property.

Reverted:
- Removed the dma-ranges diagnostic block.
- Restored bootargs to:
  - console=ttyS0,115200 earlycon

Next:
- Confirm baseline image again:
  - no dma-ranges
  - no 20-bit DMA mask
  - GENET diagnostic patches still active
- Continue with BCM3383-specific GENET DMA base/window investigation.
