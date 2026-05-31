#!/usr/bin/env python3
import argparse
import hashlib
import lzma
import struct
from pathlib import Path

HEADER_SIZE = 92


def crc16_ccitt_hcs(data: bytes) -> int:
    crc = 0xFFFF
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc ^ 0xFFFF


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_programstore_header(data: bytes) -> dict:
    if len(data) < HEADER_SIZE:
        raise SystemExit("FAIL: file is smaller than ProgramStore header size (92 bytes)")

    hdr = data[:HEADER_SIZE]
    sig, control, major, minor = struct.unpack(">HHHH", hdr[0:8])
    build_time, file_len, load_addr = struct.unpack(">III", hdr[8:20])
    filename = hdr[20:84].split(b"\x00", 1)[0].decode("ascii", errors="replace")
    hcs = struct.unpack(">H", hdr[84:86])[0]
    crc = struct.unpack(">I", hdr[88:92])[0]
    calc_hcs = crc16_ccitt_hcs(hdr[:84])
    return {
        "signature": sig,
        "control": control,
        "major": major,
        "minor": minor,
        "build_time": build_time,
        "file_len": file_len,
        "load_addr": load_addr,
        "filename": filename,
        "hcs": hcs,
        "calc_hcs": calc_hcs,
        "crc": crc,
    }


def parse_lzma1_props(prop: bytes) -> tuple[int, int, int, int]:
    if len(prop) < 5:
        raise ValueError("payload too short for LZMA properties")
    p0 = prop[0]
    if p0 >= 225:
        raise ValueError(f"invalid LZMA properties byte: 0x{p0:02x}")
    pb = p0 // 45
    rem = p0 % 45
    lp = rem // 9
    lc = rem % 9
    dict_size = int.from_bytes(prop[1:5], "little")
    return lc, lp, pb, dict_size


def try_decompress_lzma1(payload: bytes) -> tuple[bytes | None, dict]:
    meta: dict = {"is_lzma": False}
    try:
        lc, lp, pb, dict_size = parse_lzma1_props(payload[:5])
    except ValueError as ex:
        meta["error"] = str(ex)
        return None, meta

    meta.update(
        {
            "is_lzma": True,
            "lc": lc,
            "lp": lp,
            "pb": pb,
            "dict_size": dict_size,
        }
    )

    try:
        dec = lzma.LZMADecompressor(
            format=lzma.FORMAT_RAW,
            filters=[
                {
                    "id": lzma.FILTER_LZMA1,
                    "lc": lc,
                    "lp": lp,
                    "pb": pb,
                    "dict_size": dict_size,
                }
            ],
        )
        raw = dec.decompress(payload[5:])
        if not dec.eof and dec.unused_data == b"":
            meta["warning"] = "stream did not reach explicit EOF marker"
        return raw, meta
    except lzma.LZMAError as ex:
        meta["error"] = f"LZMA decode failed: {ex}"
        return None, meta


def safe_tag(name: str) -> str:
    out = []
    for ch in name:
        if ch.isalnum() or ch in ("-", "_", "."):
            out.append(ch)
        else:
            out.append("-")
    return "".join(out).strip("-") or "image"


def find_ascii_offsets(blob: bytes, needle: bytes) -> list[int]:
    hits = []
    i = 0
    while True:
        pos = blob.find(needle, i)
        if pos < 0:
            break
        hits.append(pos)
        i = pos + 1
    return hits


def write_marker_report(path: Path, raw: bytes, load_addr: int) -> None:
    markers = [
        b"Booting Linux on TP1...",
        b"Linux Boot Args:",
        b"<<<<< rx_thread sent initial handshake >>>>>>",
        b"HandShakeMsg = %08lx",
        b"unhandled message %08lx",
        b"<<<<< %s sent initial handshake >>>>>>",
        b"Error: getHostDqmMessage(handshake) on %s",
        b"Error: handshake rx unexpected message",
        b"<<<<< %s sent reply handshake message >>>>>>",
        b"init_service_handshake",
        b"%s unexpected message %08lx",
        b"%s: unexpected message %d",
        b"Creating DOCSIS Control Thread...",
        b"CM DOCSIS Control Thread Commands",
        b"Creating TR-069 Thread...",
        b"BcmBfcTr69Thread::Singleton mutex",
        b"BcmBfcTr69Thread: Initializing Core",
        b"TR-069 settings and commands.",
        b"Thread processor handshake. Secondary app initialized properly.",
        b"Incompatible Firmware",
    ]
    lines = []
    lines.append(f"load_address=0x{load_addr:08x}")
    lines.append("marker_hits:")
    for m in markers:
        hits = find_ascii_offsets(raw, m)
        if not hits:
            lines.append(f"  - {m.decode('ascii', errors='replace')}: none")
            continue
        for off in hits[:8]:
            lines.append(
                f"  - {m.decode('ascii', errors='replace')}: file_off=0x{off:08x} runtime=0x{(load_addr + off):08x}"
            )
        if len(hits) > 8:
            lines.append(f"  - ... ({len(hits) - 8} more hits)")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Extract and inspect TC7200 stage1 ProgramStore image safely."
    )
    ap.add_argument("--input", required=True, help="Wrapped ProgramStore image path")
    ap.add_argument(
        "--out-dir",
        default=None,
        help="Output directory (default: ~/tc7200u-research/research/reverse/<input-base>)",
    )
    ap.add_argument(
        "--force-load",
        default=None,
        help="Override load address (e.g. 0x80004000) for marker runtime addresses",
    )
    args = ap.parse_args()

    src = Path(args.input).expanduser().resolve()
    if not src.exists():
        raise SystemExit(f"FAIL: input not found: {src}")

    if args.out_dir:
        out_dir = Path(args.out_dir).expanduser().resolve()
    else:
        out_dir = (
            Path.home()
            / "tc7200u-research"
            / "research"
            / "reverse"
            / safe_tag(src.name)
        )
    out_dir.mkdir(parents=True, exist_ok=True)

    wrapped = src.read_bytes()
    header = parse_programstore_header(wrapped)
    payload = wrapped[HEADER_SIZE:]

    header_log = out_dir / "programstore_header.txt"
    raw_payload_path = out_dir / "payload.lzma"
    raw_image_path = out_dir / "image.raw"
    marker_report = out_dir / "marker_report.txt"
    summary_path = out_dir / "summary.txt"

    raw_payload_path.write_bytes(payload)

    decoded, lz_meta = try_decompress_lzma1(payload)
    if decoded is None:
        # Keep pipeline moving: if decode fails, treat payload as raw image candidate.
        decoded = payload
        decode_mode = "passthrough"
    else:
        decode_mode = "lzma_raw"
    raw_image_path.write_bytes(decoded)

    load_addr = int(args.force_load, 0) if args.force_load else header["load_addr"]
    write_marker_report(marker_report, decoded, load_addr)

    header_lines = [
        f"source={src}",
        f"wrapped_size={len(wrapped)}",
        f"signature=0x{header['signature']:04x}",
        f"control=0x{header['control']:04x}",
        f"major=0x{header['major']:04x}",
        f"minor=0x{header['minor']:04x}",
        f"build_time=0x{header['build_time']:08x}",
        f"file_length={header['file_len']}",
        f"load_address=0x{header['load_addr']:08x}",
        f"filename={header['filename']}",
        f"hcs=0x{header['hcs']:04x}",
        f"expected_hcs=0x{header['calc_hcs']:04x}",
        f"crc=0x{header['crc']:08x}",
        f"payload_size={len(payload)}",
        f"payload_sha256={sha256_hex(payload)}",
    ]
    header_log.write_text("\n".join(header_lines) + "\n", encoding="utf-8")

    summary = [
        f"input={src}",
        f"out_dir={out_dir}",
        f"payload={raw_payload_path}",
        f"image_raw={raw_image_path}",
        f"header_log={header_log}",
        f"marker_report={marker_report}",
        f"decode_mode={decode_mode}",
        f"raw_image_size={len(decoded)}",
        f"raw_image_sha256={sha256_hex(decoded)}",
    ]
    if lz_meta:
        for k in ("is_lzma", "lc", "lp", "pb", "dict_size", "warning", "error"):
            if k in lz_meta:
                summary.append(f"{k}={lz_meta[k]}")

    summary_path.write_text("\n".join(summary) + "\n", encoding="utf-8")
    print("\n".join(summary))


if __name__ == "__main__":
    main()
