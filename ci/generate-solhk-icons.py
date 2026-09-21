#!/usr/bin/env python3
"""Rebuild all iOS icon sizes from the user-selected silver STRA mark.

The compressed RGB source is deliberately checked into this independent fork.
Only the Python standard library is needed on GitHub Actions.
"""
from __future__ import annotations

import base64
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "pip_swift/pip_swift/Assets.xcassets/AppIcon.appiconset"
SOURCE = ROOT / "ci/stra-silver-icon.rgb.zlib.base64"
MASTER_SIZE = 96


def png_bytes(size: int, pixels: bytearray) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    stride = size * 4
    scanlines = b"".join(
        b"\x00" + pixels[y * stride:(y + 1) * stride]
        for y in range(size)
    )
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">2I5B", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(scanlines, level=9))
            + chunk(b"IEND", b""))


def resize_pixels(raw: bytes, size: int) -> bytearray:
    """Bilinear resampling without Pillow/sips: reproducible on CI and locally."""
    out = bytearray(size * size * 4)
    xcoords = []
    for x in range(size):
        sx = max(0.0, min(MASTER_SIZE - 1.0, (x + 0.5) * MASTER_SIZE / size - 0.5))
        x0 = int(sx)
        xcoords.append((x0, min(MASTER_SIZE - 1, x0 + 1), sx - x0))
    for y in range(size):
        sy = max(0.0, min(MASTER_SIZE - 1.0, (y + 0.5) * MASTER_SIZE / size - 0.5))
        y0 = int(sy)
        y1 = min(MASTER_SIZE - 1, y0 + 1)
        ty = sy - y0
        row0 = y0 * MASTER_SIZE * 3
        row1 = y1 * MASTER_SIZE * 3
        for x, (x0, x1, tx) in enumerate(xcoords):
            top = row0 + x0 * 3
            top_right = row0 + x1 * 3
            bottom = row1 + x0 * 3
            bottom_right = row1 + x1 * 3
            pos = (y * size + x) * 4
            for channel in range(3):
                high = raw[top + channel] * (1 - tx) + raw[top_right + channel] * tx
                low = raw[bottom + channel] * (1 - tx) + raw[bottom_right + channel] * tx
                out[pos + channel] = round(high * (1 - ty) + low * ty)
            out[pos + 3] = 255
    return out


def main() -> None:
    raw = zlib.decompress(base64.b64decode(SOURCE.read_text().strip()))
    expected = MASTER_SIZE * MASTER_SIZE * 3
    if len(raw) != expected:
        raise ValueError(f"silver icon is corrupted: {len(raw)} != {expected}")

    # Use the user-selected silver mark. Do not overlay the old speedometer,
    # pixel-font watermark or test-version numerals.
    contents = json.loads((ASSETS / "Contents.json").read_text())
    generated = 0
    for asset in contents["images"]:
        filename = asset.get("filename")
        if not filename:
            continue
        points = float(asset["size"].split("x")[0])
        scale = float(asset.get("scale", "1x").removesuffix("x"))
        pixels = round(points * scale)
        image = resize_pixels(raw, pixels)
        (ASSETS / filename).write_bytes(png_bytes(pixels, image))
        generated += 1
    print(f"Generated {generated} minimalist silver STRA app icon assets")


if __name__ == "__main__":
    main()
