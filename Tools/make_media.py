"""Generate Glass UI's own textures into Media/ (never hand-edit the outputs).

    python Tools/make_media.py

  Arrow   64 x 64, RestedXP's waypoint arrow in glass (#56, docs/RESTEDXP.md;
          the audited exception in docs/PLAN.md). The owner's mockup's
          arrowhead: a chevron pointing up (the angle RestedXP's own texture
          has at rotation 0), its base notched: the apex at (32, 5), the base
          corners at (9, 57) and (55, 57), the notch at (32, 43). White, so the
          suite accent tints it (SetVertexColor), with the gloss in its RGB:
          1.0 at the top to 0.7 at the bottom, a 1.5 px darker edge inside its
          bounds (0.55 of that). Its shape in alpha, 4 x 4 supersampled.

Plain Python, no dependencies: 32-bit uncompressed TGA (BGRA, 8-bit alpha),
top-left origin, power-of-two sides.

Not from here: Media/QuestBook.tga, the quest popup's portrait, is the
owner's art (128 x 128, RLE like Glass Mail's envelope), committed as given.
"""

import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, "Media")

SS = 4  # supersamples per side


def write_tga(path, size, pixels):
    """pixels: rows top to bottom of (r, g, b, a) floats in 0..1."""
    w, h = size
    # Image type 2 (uncompressed true colour), 32 bpp, descriptor 0x28: 8
    # alpha bits, top-left origin.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x28)
    out = bytearray(header)
    for row in pixels:
        for r, g, b, a in row:
            out += bytes((round(b * 255), round(g * 255), round(r * 255), round(a * 255)))
    with open(path, "wb") as f:
        f.write(out)


def inside(poly, x, y):
    """Even-odd point in polygon."""
    hit = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            hit = not hit
    return hit


def edge_distance(poly, x, y):
    """Distance from (x, y) to the polygon's outline."""
    best = math.inf
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(x - (x1 + t * dx), y - (y1 + t * dy)))
    return best


def arrow():
    size = 64
    poly = [(32, 5), (55, 57), (32, 43), (9, 57)]
    top, bottom = 5, 57
    rows = []
    for py in range(size):
        row = []
        for px in range(size):
            cover, shade = 0, 0.0
            for sy in range(SS):
                for sx in range(SS):
                    x = px + (sx + 0.5) / SS
                    y = py + (sy + 0.5) / SS
                    if not inside(poly, x, y):
                        continue
                    cover += 1
                    gloss = 1.0 - 0.3 * max(0.0, min(1.0, (y - top) / (bottom - top)))
                    if edge_distance(poly, x, y) < 1.5:
                        gloss *= 0.55
                    shade += gloss
            a = cover / (SS * SS)
            v = shade / cover if cover else 0.0
            row.append((v, v, v, a))
        rows.append(row)
    return (size, size), rows


def main():
    os.makedirs(MEDIA, exist_ok=True)
    size, pixels = arrow()
    path = os.path.join(MEDIA, "Arrow.tga")
    write_tga(path, size, pixels)
    print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
