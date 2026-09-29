#!/usr/bin/env python3
"""Prism Night: original violet/cobalt/teal light fans. Generator + image: CC0-1.0.

Inspired by the palette and spacious composition of the user's reference, not
traced or sampled from Apple artwork. Standard library only; deterministic PNG.
"""
import argparse
import math
from pathlib import Path
import struct
import zlib

STOPS = [(-1.6, (15, 5, 43)), (-0.7, (38, 9, 104)), (-0.27, (54, 20, 143)),
         (-0.04, (31, 54, 154)), (0.22, (42, 108, 165)), (0.52, (88, 163, 157)),
         (0.9, (63, 122, 168)), (1.6, (36, 66, 142))]


def chunk(kind, payload):
    return struct.pack('!I', len(payload)) + kind + payload + struct.pack('!I', zlib.crc32(kind + payload))


def render(width, height):
    compressor = zlib.compressobj(9)
    compressed = bytearray()
    for y in range(height):
        v = y / height
        row = bytearray([0])
        for x in range(width):
            u = x / width
            angle = math.atan2((u - 0.60) * 1.32, v + 0.22)
            index = 0
            while index < len(STOPS) - 2 and angle > STOPS[index + 1][0]:
                index += 1
            a, b = STOPS[index], STOPS[index + 1]
            t = max(0, min(1, (angle - a[0]) / (b[0] - a[0])))
            t = t * t * (3 - 2 * t)
            # Soft, non-repeating fan edges rather than photo/copyrighted assets.
            fan = ((angle + 1.9 + 0.045 * math.sin(v * 2.4)) * 10.5) % 1
            rib = 0.79 + 0.21 * (fan ** 0.38)
            light = (1.05 - 0.28 * v) * rib
            glow = math.exp(-((u - 0.61) ** 2 / 0.04 + (v + 0.06) ** 2 / 0.14))
            dither = ((x * 13 + y * 7) % 17) / 17 - 0.5
            for c in range(3):
                value = (a[1][c] * (1 - t) + b[1][c] * t) * light + (19, 26, 31)[c] * glow
                row.append(max(0, min(255, round(value + dither * 0.7))))
        compressed.extend(compressor.compress(row))
    compressed.extend(compressor.flush())
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', width, height, 8, 2, 0, 0, 0))
            + chunk(b'tEXt', b'Title\0Prism Night - original drona.mac artwork (CC0-1.0)')
            + chunk(b'IDAT', bytes(compressed)) + chunk(b'IEND', b''))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--width', type=int, default=2560)
    parser.add_argument('--height', type=int, default=1600)
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'wallpapers/prism-night.png')
    args = parser.parse_args()
    if not 16 <= args.width <= 7680 or not 16 <= args.height <= 4320:
        parser.error('Use dimensions between 16x16 and 7680x4320')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(render(args.width, args.height))
    print(args.output)


if __name__ == '__main__':
    main()
