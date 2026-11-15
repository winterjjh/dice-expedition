"""Cuts full-body character sheets (flat magenta background) into art/hero and art/enemy.

    python3 tools/slice_sprites.py <folder with hero-fullbody-sheet.png and enemy-act1-sheet.png>

Sprites are found as connected areas, so uneven grids are fine. Each one is
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


def components(fg, grow):
    """Bounding boxes of sprites: connected areas after closing gaps of about `grow` px,
    so loose bits (smoke, dice, cloth) stay with their owner. Works on a 1/4 scale mask."""
    small = Image.fromarray((fg * 255).astype(np.uint8)).resize((fg.shape[1] // 4, fg.shape[0] // 4), Image.BOX)
    k = max(3, (grow // 4) | 1)
    m = np.array(small.filter(ImageFilter.MaxFilter(k))) > 40
    h, w = m.shape
    seen = np.zeros_like(m)
    label = np.zeros(m.shape, dtype=np.int32)
    out = []
    for sy in range(h):
        for sx in range(w):
            if not m[sy, sx] or seen[sy, sx]:
                continue
            stack = [(sy, sx)]
            seen[sy, sx] = True
            lid = len(out) + 1
            x0 = x1 = sx
            y0 = y1 = sy
            n = 0
            while stack:
                y, x = stack.pop()
                label[y, x] = lid
                n += 1
                x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
                for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                    if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            out.append((n, x0 * 4, y0 * 4, min(fg.shape[1], (x1 + 1) * 4), min(fg.shape[0], (y1 + 1) * 4), lid))
    return out, label


def cut(path, names, rows, folder):
    im = Image.open(path).convert("RGB")
    a = np.array(im)
    fg = ~background(a)
    fg = np.array(Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5))) > 0
    boxes = []
    owner = None
    for grow in (20, 12, 28, 8):
        comps, label = components(fg, grow)
        found = sorted(comps, reverse=True)[: len(names)]
        if len(found) == len(names) and found[-1][0] > found[0][0] * 0.06:
            boxes = [b[1:] for b in found]
            owner = np.array(Image.fromarray(label).resize((fg.shape[1], fg.shape[0]), Image.NEAREST))
            break
    if not boxes:
        # two sprites touch: fall back to the empty gaps between columns, then rows
        for x0, x1 in bands(fg.sum(0) > 6, 24, 60):
            for y0, y1 in bands(fg[:, x0:x1].sum(1) > 3, 10, 60):
                boxes.append((x0, y0, x1, y1, 0))
    if len(boxes) != len(names):
        raise SystemExit("%s: could not find %d separate sprites" % (path, len(names)))
    row_h = a.shape[0] / rows
    boxes.sort(key=lambda b: (int(((b[1] + b[3]) / 2) // row_h), b[0]))
    os.makedirs(folder, exist_ok=True)
    for name, (x0, y0, x1, y1, lid) in zip(names, boxes):
        crop = a[y0:y1, x0:x1]
        alpha = np.where(background(crop), 0, 255).astype(np.uint8)
        if owner is not None:
            # drop bits of neighbouring sprites that poke into this box
            alpha[owner[y0:y1, x0:x1] != lid] = 0
        alpha = np.array(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)))
        spr = Image.fromarray(np.dstack([crop, alpha]), "RGBA")
        box = spr.getbbox()
        spr = spr.crop(box)
        side = max(spr.size) + 8
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(spr, ((side - spr.size[0]) // 2, side - spr.size[1] - 4))
        sq.resize((OUT, OUT), Image.LANCZOS).save(os.path.join(folder, name + ".png"))
        print(name, spr.size)


SHEETS = [
    ("hero-fullbody-sheet.png", HEROES, 2, "hero"),
    ("enemy-act1-sheet.png", ENEMIES, 3, "enemy"),
    ("enemy-act2-sheet.png", ["bandit", "shade", "plaguerat", "statue", "cultist", "bloodknight", "golem", "witch"], 2, "enemy"),
    ("enemy-act3-sheet.png", ["bowman", "armor", "viper", "wraith", "giant", "reaper", "gambler"], 2, "enemy"),
]

if __name__ == "__main__":
    src = sys.argv[1]
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
    for fname, names, rows, folder in SHEETS:
        if os.path.exists(os.path.join(src, fname)):
            cut(os.path.join(src, fname), names, rows, os.path.join(root, folder))
