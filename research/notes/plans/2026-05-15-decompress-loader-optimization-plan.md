# TC7200.U decompression / loader / image-size optimization plan

Date: 2026-05-15
Scope: RAM boot only. Do not flash.

## Reason

Known-good rescue image boots to OpenWrt shell:

- wrapped size: 5696426 bytes
- payload size: 5696334 bytes
- HCS: 1b46
- CRC: f0b0a5b5
- result: boots to OpenWrt shell
- Ethernet: no active Ethernet node

Fresh rebuilt images around 5717xxx bytes are CFE-valid but runtime-bad or under test:

- enetsw image: 5717206 bytes, eth0 probes, then /init SIGSEGV panic
- UART-only rebuilt image: 5717126 bytes, CFE accepts, currently under boot test

## Main suspicion

The blocker is now image / loader / decompression / memory layout, not Ethernet.

Important repeated warning:

    Kernel sections are not in the memory maps

The image is loaded at:

    CFE load address: 0x82000000
    kernel runtime/decompress target: 0x80010000

The larger rebuilt image may cross a bad memory/layout boundary or differ in rootfs/initramfs content.

## Working branch

    research/decompress-loader-optimization

## Rules

- RAM boot only.
- Do not flash.
- Keep known-good 5696426 rescue image preserved.
- Do not continue Ethernet debugging until a freshly rebuilt UART-only image boots to shell.
- Only TFTP after wrapper manifest says size_ok=True.
- CFE filename remains openwrt-ps-irqfallback.bin.

## First tasks

1. Compare known-good 5696426 image against fresh UART-only 5717126 image.
2. Compare payload sizes, headers, and decompressed kernel target range.
3. Identify what changed between good and current raw initramfs.
4. Try to reduce image size back below known-good range or change loader/decompression placement safely.
5. Re-test UART-only image before re-adding Ethernet.
