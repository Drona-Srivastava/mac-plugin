#!/usr/bin/env python3
"""Generate Graphite Tide, an original wallpaper, using only Python's stdlib.

No downloaded imagery, proprietary assets, fonts, logos, or random state.
Defaults: 2560 x 1600 PNG. This generator and its output are CC0-1.0.
"""

import argparse
import math
from pathlib import Path
import struct
import zlib


def chunk(kind, payload):
    return struct.pack("!I", len(payload)) + kind + payload + struct.pack("!I", zlib.crc32(kind + payload))


def render(width, height):
    compressor = zlib.compressobj(9)
    compressed = bytearray()
    exp, sin, sqrt = math.exp, math.sin, math.sqrt
    xs = [x / width for x in range(width)]
    # Asymmetric ribbons leave the upper desktop quiet and legible.
    curves = [(0.66 + 0.12 * sin(x * 5.0 - 0.3) - 0.24 * x,
               0.90 - 0.41 * x + 0.055 * sin(x * 7.0),
               0.99 - 0.27 * x + 0.07 * sin(x * 5.2 + 0.6)) for x in xs]
    for y in range(height):
        v = y / height
        row = bytearray([0])  # PNG filter: none.
        for x, u in enumerate(xs):
            glow = exp(-((u - 0.72) ** 2 / 0.28 + (v - 0.49) ** 2 / 0.31))
            vignette = max(0.0, 1.0 - 0.46 * sqrt((u - 0.53) ** 2 + (v - 0.47) ** 2))
            rgb = [11 + 6 * glow, 15 + 14 * glow, 24 + 27 * glow]
            for n, edge in enumerate(curves[x]):
                distance = v - edge
                if distance >= 0:
                    body = exp(-distance * (8.0 + n * 1.8))
                    rim = exp(-distance * (240.0 - n * 30.0))
                    envelope = 0.43 + 0.57 * sin(u * 2.8 + 0.12) ** 2
                    target = ((27, 65, 111), (27, 42, 65), (39, 50, 69))[n]
                    for c in range(3):
                        rgb[c] = rgb[c] * 0.2 + (target[c] * body + (3, 8, 16)[c] * rim) * envelope + (8, 11, 17)[c]
                else:
                    rim = exp(-(distance / 0.007) ** 2) * (0.35 + 0.65 * u)
                    for c in range(3):
                        rgb[c] += (3, 8, 15)[c] * rim
            # Subtle ordered dither prevents banding without a large/noisy asset.
            dither = ((x * 13 + y * 7) % 17) / 17.0 - 0.5
            row.extend(max(0, min(255, round(value * vignette + dither * 0.7))) for value in rgb)
        compressed.extend(compressor.compress(row))
    compressed.extend(compressor.flush())
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack("!2I5B", width, height, 8, 2, 0, 0, 0))
            + chunk(b"tEXt", b"Title\x00Graphite Tide - original drona.mac artwork (CC0-1.0)")
            + chunk(b"IDAT", bytes(compressed)) + chunk(b"IEND", b""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--width", type=int, default=2560)
    parser.add_argument("--height", type=int, default=1600)
    parser.add_argument("--output", type=Path, default=Path(__file__).parent / "wallpapers/graphite-tide.png")
    args = parser.parse_args()
    if not 16 <= args.width <= 7680 or not 16 <= args.height <= 4320:
        parser.error("Use dimensions between 16x16 and 7680x4320")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(render(args.width, args.height))
    print(f"Wrote {args.output} ({args.width}x{args.height})")


if __name__ == "__main__":
    main()
