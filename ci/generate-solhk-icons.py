#!/usr/bin/env python3
"""Generate SOLHK-owned app icon assets before Xcode asset compilation.

Only standard-library modules are used. Re-running this script produces the same
icons for Release and simulator builds; it does not modify the upstream NOTICE.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import struct
import zlib

ASSETS = Path(__file__).resolve().parents[1] / "pip_swift/pip_swift/Assets.xcassets/AppIcon.appiconset"
GLYPHS = {
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["11110", "00001", "00001", "01110", "10000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
}

def png_bytes(width: int, height: int, pixels: bytearray) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    stride = width * 4
    raw = b"".join(b"\x00" + pixels[y * stride:(y + 1) * stride] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">2I5B", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, level=8))
            + chunk(b"IEND", b""))

def make_icon(size: int, tinted: bool = False, dark: bool = False) -> bytearray:
    data = bytearray(size * size * 4)
    den = max(size - 1, 1)

    def blend(x: int, y: int, color: tuple[int, int, int], alpha: float = 1.0) -> None:
        if not (0 <= x < size and 0 <= y < size):
            return
        idx = (y * size + x) * 4
        old_alpha = data[idx + 3] / 255.0
        total = alpha + old_alpha * (1 - alpha)
        if total <= 0:
            return
        for c in range(3):
            data[idx + c] = min(255, round((color[c] * alpha + data[idx + c] * old_alpha * (1 - alpha)) / total))
        data[idx + 3] = min(255, round(total * 255))

    for y in range(size):
        fy = y / den
        for x in range(size):
            fx = x / den
            if not tinted:
                glow = max(0.0, 1.0 - math.hypot(fx - 0.22, fy - 0.19) / 0.96)
                violet = max(0.0, 1.0 - math.hypot(fx - 0.92, fy - 0.91) / 0.95)
                base = (4, 12, 29) if dark else (8, 20, 41)
                idx = (y * size + x) * 4
                data[idx] = min(255, int(base[0] + 6 * fx + 17 * glow + 14 * violet))
                data[idx + 1] = min(255, int(base[1] + 13 * fy + 30 * glow + 7 * violet))
                data[idx + 2] = min(255, int(base[2] + 14 * fx + 44 * glow + 38 * violet))
                data[idx + 3] = 255
            # A circular speedometer-like halo is part of the SOLHK identity.
            radial = math.hypot(fx - 0.50, fy - 0.50)
            edge = abs(radial - 0.385)
            if edge < 0.012:
                blend(x, y, (92, 233, 253) if not tinted else (255, 255, 255),
                      (0.47 if not tinted else 0.95) * (1 - edge / 0.012))
            # A short bright arc, rather than a full glowing disk.
            if 0.365 < radial < 0.387 and (fx < 0.48 and fy < 0.52):
                blend(x, y, (60, 205, 255) if not tinted else (255, 255, 255), 0.70)

    def rect(x0: int, y0: int, w: int, h: int, color: tuple[int, int, int]) -> None:
        for yy in range(max(0, y0), min(size, y0 + h)):
            for xx in range(max(0, x0), min(size, x0 + w)):
                blend(xx, yy, color)

    def text(label: str, center_x: float, top: float, block: int, color: tuple[int, int, int]) -> None:
        width = (len(label) * 6 - 1) * block
        start_x = round(size * center_x - width / 2)
        start_y = round(size * top)
        for i, ch in enumerate(label):
            for y, row in enumerate(GLYPHS[ch]):
                for x, pixel in enumerate(row):
                    if pixel == "1":
                        rect(start_x + (i * 6 + x) * block, start_y + y * block, block, block, color)

    scale = max(1, round(size / 38))
    # Keep the identity readable at tiny notification-icon sizes.
    scale = min(scale, max(1, size // 22))
    text("120", 0.50, 0.33, scale, (241, 252, 255) if not tinted else (255, 255, 255))
    if size >= 96:
        label_scale = max(1, round(size / 110))
        text("SOLHK", 0.50, 0.71, label_scale, (75, 221, 251) if not tinted else (255, 255, 255))
    return data

def main() -> None:
    contents = json.loads((ASSETS / "Contents.json").read_text())
    count = 0
    for asset in contents["images"]:
        filename = asset.get("filename")
        if not filename:
            continue
        points = float(asset["size"].split("x")[0])
        scale = float(asset.get("scale", "1x").removesuffix("x"))
        pixels = round(points * scale)
        tinted = any(a.get("value") == "tinted" for a in asset.get("appearances", []))
        dark = any(a.get("value") == "dark" for a in asset.get("appearances", []))
        image = make_icon(pixels, tinted=tinted, dark=dark)
        (ASSETS / filename).write_bytes(png_bytes(pixels, pixels, image))
        count += 1
    print(f"Generated {count} SOLHK app icons from Contents.json")

if __name__ == "__main__":
    main()
