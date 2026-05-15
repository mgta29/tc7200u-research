from pathlib import Path
import struct, time

def brcm_crc(data, width, poly):
    mask = (1 << width) - 1
    top = 1 << (width - 1)
    crc = mask
    for b in data:
        crc ^= b << (width - 8)
        for _ in range(8):
            if crc & top:
                crc = ((crc << 1) ^ poly) & mask
            else:
                crc = (crc << 1) & mask
    return (~crc) & mask

payload_path = Path("bin/targets/bmips/bcm63268/openwrt-bmips-bcm63268-technicolor_tc7200u-initramfs.bin")
payload = payload_path.read_bytes()

sig = 0xa825
ctrl = 0x0000
maj = 0x0100
minr = 0x04ff
build_time = int(time.time())
file_len = len(payload)
load_addr = 0x82000000
name = b"openwrt-initramfs.bin".ljust(48, b"\x00")
pad = b"\x00" * 8
len1 = 0
len2 = 0

hdr84 = struct.pack(">HHHHIII48s8sII", sig, ctrl, maj, minr, build_time, file_len, load_addr, name, pad, len1, len2)
hcs = brcm_crc(hdr84, 16, 0x1021)
crc = brcm_crc(payload, 32, 0x04c11db7)
hdr = hdr84 + struct.pack(">HHI", hcs, 0, crc)

assert len(hdr) == 92
out = hdr + payload
Path("/mnt/c/tftp/openwrt-ps-brcm.bin").write_bytes(out)

print(f"payload={len(payload)}")
print(f"header={len(hdr)}")
print(f"total={len(out)}")
print(f"hcs=0x{hcs:04x}")
print(f"crc=0x{crc:08x}")
