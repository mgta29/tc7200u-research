
## 2026-06-08 01:25:43 UTC - GMAC init_step2 / MDIO1 mode findings
- fn_enet_gmac_init_step2(param_1): if param_1==0 sets GENET_REG_12c00070 bits 0x1 and 0x2, then always sets 0x1000 and 0x2000.
- fn_enet_gmac_disable_step2(param_1): inverse cleanup; if param_1==0 clears bits 0x2 and 0x1, then always clears 0x2000 and 0x1000.
- fn_enet_mdio1_set_mode_0400: delay wrapper then GENET_MDIO_BASE_12c02600 |= 0x400.
- fn_enet_mdio1_clear_mode_0400: delay wrapper then GENET_MDIO_BASE_12c02600 &= 0xfffffbff.
