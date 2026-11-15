"""Cuts full-body character sheets (flat magenta background) into art/hero and art/enemy.

    python3 tools/slice_sprites.py <folder with hero-fullbody-sheet.png and enemy-act1-sheet.png>

Sprites are found by the gaps between them, so uneven grids are fine. Each one is
keyed out of the magenta, padded to a square with its feet on the bottom edge and
saved at 192 px.
"""
import sys, os
import numpy as np
from PIL import Image, ImageFilter

HEROES = ["shieldman", "gladiator", "archer", "rogue", "pyro", "frost", "healer", "bard"]
ENEMIES = ["rat", "goblin", "skeleton", "shroom", "wolf", "imp", "ogre", "boneknight", "rustknight"]
OUT = 192


def background(a):
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    return (r > 150) & (b > 150) & ((r + b) // 2 - g > 80)


def bands(filled, min_gap, min_size):
    out, start, gap = [], None, 0
    for i, v in enumerate(list(filled) + [False] * (min_gap + 1)):
        if v:
            if start is None:
                start = i
            gap = 0
        elif start is not None:
            gap += 1
            if gap > min_gap:
                end = i - gap + 1
                if end - start >= min_size:
                    out.append((start, end))
                start = None
    return out


def cut(path, names, cols, folder):
    im = Image.open(path).convert("RGB")
    a = np.array(im)
    fg = ~background(a)
    fg = np.array(Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5))) > 0
    boxes = []
    for y0, y1 in bands(fg.sum(1) > 6, 10, 60):
        for x0, x1 in bands(fg[y0:y1].sum(0) > 3, 24, 60):
            ys = np.where(fg[y0:y1, x0:x1].sum(1) > 0)[0]
            boxes.append((x0, y0 + ys[0], x1, y0 + ys[-1] + 1))
    if len(boxes) != len(names):
        # rows overlap: split into columns first, then rows inside each column
        boxes = []
        for x0, x1 in bands(fg.sum(0) > 6, 24, 60):
            for y0, y1 in bands(fg[:, x0:x1].sum(1) > 3, 10, 60):
                xs = np.where(fg[y0:y1, x0:x1].sum(0) > 0)[0]
                boxes.append((x0 + xs[0], y0, x0 + xs[-1] + 1, y1))
        row_h = a.shape[0] / (len(names) / cols)
        boxes.sort(key=lambda b: (int(((b[1] + b[3]) / 2) // row_h), b[0]))
    if len(boxes) != len(names):
        raise SystemExit("%s: found %d sprites, expected %d" % (path, len(boxes), len(names)))
    os.makedirs(folder, exist_ok=True)
    for name, (x0, y0, x1, y1) in zip(names, boxes):
        crop = a[y0:y1, x0:x1]
        alpha = np.where(background(crop), 0, 255).astype(np.uint8)
        alpha = np.array(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)))
        spr = Image.fromarray(np.dstack([crop, alpha]), "RGBA")
        side = max(spr.size) + 8
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(spr, ((side - spr.size[0]) // 2, side - spr.size[1] - 4))
        sq.resize((OUT, OUT), Image.LANCZOS).save(os.path.join(folder, name + ".png"))
        print(name, spr.size)


if __name__ == "__main__":
    src = sys.argv[1]
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
    cut(os.path.join(src, "hero-fullbody-sheet.png"), HEROES, 4, os.path.join(root, "hero"))
    cut(os.path.join(src, "enemy-act1-sheet.png"), ENEMIES, 3, os.path.join(root, "enemy"))
