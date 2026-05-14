# TC7200.U runtime result: minimal AMAC node probes but hangs before userspace

Date: 2026-05-15  
Scope: RAM boot only. Do not flash.

## Test image

Minimal AMAC test image was wrapped and accepted by CFE.

```text
Received 5697957 bytes
File Length: 5697865 bytes
Load Address: 82000000
HCS: 77b0
```

Manifest:

```text
raw_sha256=795aefe6bf4de81584e31bece94cf195702c73f0ae3f56e005852eff8648ae71
wrapped_sha256=db7f1229b37cdc8d7df00950881fb5197dae77979d3458b9ebdf2ca5e5ecc0d4
raw_size=5697865
wrapped_size=5697957
size_ok=True
```

## DTS node tested

```dts
ethernet@14e01000 {
	compatible = "brcm,amac";
	reg = <0x14e01000 0x1000>;
	reg-names = "amac_base";
	interrupt-parent = <&periph_intc>;
	interrupts = <0>;
	status = "okay";
};
```

## Runtime output

Boot reached bgmac probe:

```text
bgmac-enet 14e01000.ethernet: MAC address not present in device tree
bgmac-enet 14e01000.ethernet: Invalid MAC addr: 00:00:00:00:00:00
bgmac-enet 14e01000.ethernet: Using random MAC: b6:04:73:9c:25:d9
```

After this, OpenWrt did not reach:

```text
init: Console is alive
```

No shell was reached.

## Interpretation

The AMAC path binds and starts probing, so `compatible = "brcm,amac"` and `reg-names = "amac_base"` are accepted.

However, the minimal AMAC node is not runtime-safe. It likely hangs during or after `bgmac_enet_probe()`, before userspace starts.

Current status:

- `bcm6368-enetsw` path: creates eth0 but packet I/O does not complete.
- DMA swap on enetsw: no improvement.
- minimal `brcm,amac` path: bgmac probes, then boot hangs before userspace.

## Next direction

Do not keep the minimal AMAC node as-is.

Next safer tests should use one change at a time:

1. Revert to known-booting enetsw DTS before continuing.
2. Add AMAC MAC address only if retesting AMAC:
   `local-mac-address = [86 8a 92 10 80 4b];`
3. Investigate whether bgmac needs valid `phy-handle`, MDIO/B53 switch node, `idm_base`, `nicpm_base`, clocks, or reset resources before enabling it again.
