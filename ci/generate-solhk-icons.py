#!/usr/bin/env python3
"""Rebuild all iOS icon sizes from the user-selected silver STRA mark.

The compressed RGB source is deliberately checked into this independent fork.
Only Python stdlib and macOS built-in sips are needed on GitHub Actions.
"""
from __future__ import annotations

import base64
import json
from pathlib import Path
import struct
import subprocess
import tempfile
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
        b"\\x00" + pixels[y * stride:(y + 1) * stride]
        for y in range(size)
    )
    return (b"\\x89PNG\\r\\n\\x1a\\n"
            + chunk(b"IHDR", struct.pack(">2I5B", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(scanlines, level=9))
            + chunk(b"IEND", b""))


def main() -> None:
    raw = zlib.decompress(base64.b64decode(SOURCE.read_text().strip()))
    expected = MASTER_SIZE * MASTER_SIZE * 3
    if len(raw) != expected:
        raise ValueError(f"silver icon is corrupted: {len(raw)} != {expected}")

    # Preserve the chosen silver-on-white artwork; never overlay the old
    # '120'/SOLHK bitmap font or the speedometer halo.
    rgba = bytearray(MASTER_SIZE * MASTER_SIZE * 4)
    for i in range(MASTER_SIZE * MASTER_SIZE):
        rgba[4 * i:4 * i + 3] = raw[3 * i:3 * i + 3]
        rgba[4 * i + 3] = 255

    with tempfile.TemporaryDirectory(prefix="stra-icon-") as temp:
        master = Path(temp) / "STRA-silver.png"
        master.write_bytes(png_bytes(MASTER_SIZE, rgba))
        contents = json.loads((ASSETS / "Contents.json").read_text())
        generated = 0
        for asset in contents["images"]:
            filename = asset.get("filename")
            if not filename:
                continue
            points = float(asset["size"].split("x")[0])
            scale = float(asset.get("scale", "1x").removesuffix("x"))
            pixels = round(points * scale)
            if pixels == MASTER_SIZE:
                (ASSETS / filename).write_bytes(master.read_bytes())
            else:
                subprocess.run([
                    "sips", "-s", "format", "png",
                    "-z", str(pixels), str(pixels),
                    str(master), "--out", str(ASSETS / filename)
                ], check=True, capture_output=True)
            generated += 1
    print(f"Generated {generated} minimalist silver STRA app icon assets")


if __name__ == "__main__":
    main()
