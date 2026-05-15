from pathlib import Path

p = Path("README.md")
s = p.read_text()

old = """Known CFE network:
- Modem/CFE: 192.168.77.1
- TFTP server/PC: 192.168.77.2
- TFTP filename: openwrt-ps-irqfallback.bin

Important finding:
"""

new = """Known CFE network:
- Modem/CFE: 192.168.77.1
- TFTP server/PC: 192.168.77.2
- TFTP filename forced by CFE: openwrt-ps-irqfallback.bin

Image / CFE state:
- Known-good RAM image: artifacts/openwrt-ps-irqfallback-GOOD-5696426.bin
- Known-good received size: 5696426 bytes
- Known-good ProgramStore signature/PID: a825
- Known-good load address: 0x82000000
- Known-good result: HCS passed; CFE executed Image 4; OpenWrt booted to userspace
- Known-bad image size: 5697264 bytes
- Known-bad result: HCS failed on Image 3 Program Header; kernel did not start; no flash write was done
- Do not replace /mnt/c/tftp/openwrt-ps-irqfallback.bin with HCS-failing builds

Safe build/wrap/TFTP rule:
- Always build OpenWrt first.
- Always run scripts/tc7200u-wrap-current-openwrt.sh.
- Only TFTP /mnt/c/tftp/openwrt-ps-irqfallback.bin after the wrapper manifest says size_ok=True.
- Do not rename the file inside CFE; serve the filename CFE asks for.

Important finding:
"""

if old not in s:
    raise SystemExit("README pattern not found; not changed")

p.write_text(s.replace(old, new))
print("README updated")
