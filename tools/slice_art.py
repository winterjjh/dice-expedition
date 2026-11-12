"""Cuts the ChatGPT art sheets into the single files the game loads.
Usage: python3 tools/slice_art.py <folder with the numbered sheets> <repo root>
"""
import sys, os
from PIL import Image

src, root = sys.argv[1], sys.argv[2]


def out(path):
    full = os.path.join(root, "art", path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def cells(im, cols, rows):
    w, h = im.size
    for r in range(rows):
        for c in range(cols):
            yield im.crop((c * w // cols, r * h // rows, (c + 1) * w // cols, (r + 1) * h // rows))


def drop_edge_bits(im):
    """Removes slivers of the neighbouring picture that leak in at the cell edge."""
    import numpy as np
    arr = np.array(im)
    for axis in (0, 1):
        used = (arr[:, :, 3] > 24).any(axis=axis)
        n = len(used)
        runs, start = [], None
        for i, u in enumerate(list(used) + [False]):
            if u and start is None:
                start = i
            elif not u and start is not None:
                runs.append((start, i))
                start = None
        for a, b in runs:
            if (a == 0 or b == n) and b - a < n * 0.12 and len(runs) > 1:
                if axis == 0:
                    arr[:, a:b, 3] = 0
                else:
                    arr[a:b, :, 3] = 0
    return Image.fromarray(arr)


def trim_alpha(im, pad=0.04):
    im = drop_edge_bits(im)
    box = im.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    im = im.crop(box)
    side = int(max(im.size) * (1 + pad * 2))
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq


def trim_white(im):
    g = im.convert("L").point(lambda v: 0 if v > 235 else 255)
    box = g.getbbox()
    im = im.crop(box)
    s = min(im.size)
    l, t = (im.width - s) // 2, (im.height - s) // 2
    return im.crop((l, t, l + s, t + s))


def sheet(name, cols, rows, folder, keys, size, mode="alpha"):
    path = os.path.join(src, name)
    if not os.path.exists(path):
        print("skip", name)
        return
    im = Image.open(path).convert("RGBA" if mode == "alpha" else "RGB")
    for key, cell in zip(keys, cells(im, cols, rows)):
        if key is None:
            continue
        cell = trim_alpha(cell) if mode == "alpha" else trim_white(cell)
        cell = cell.resize((size, size), Image.LANCZOS)
        cell.save(out("%s/%s.png" % (folder, key)), optimize=True)
        print("ok", folder, key)


def background(name, key, width=1600):
    path = os.path.join(src, name)
    if not os.path.exists(path):
        print("skip", name)
        return
    im = Image.open(path).convert("RGB")
    im = im.resize((width, width * im.height // im.width), Image.LANCZOS)
    im.save(out("bg/%s.jpg" % key), quality=86)
    print("ok bg", key)


sheet("01-hero-portraits-martial.png", 2, 2, "hero", ["shieldman", "gladiator", "archer", "rogue"], 256, "white")
sheet("02-hero-portraits-magic.png", 2, 2, "hero", ["pyro", "frost", "healer", "bard"], 256, "white")
sheet("03-enemies-common.png", 5, 1, "enemy", ["rat", "goblin", "skeleton", "shroom", "wolf"], 256)
sheet("04-enemies-elite.png", 2, 2, "enemy", ["imp", "ogre", "boneknight", "rustknight"], 320)
sheet("05-ui-icons.png", 4, 3, "ui", ["die_blank", "die_frame", "heart", "shield", "poison", "stun", "freeze", "target", "mana", "coin", "reroll", "skull"], 128)
sheet("07-shieldbearer-die-icons.png", 3, 2, "skill", ["taunt", "shieldadj", "bash", "thorns", "guardhit", "wall"], 160)
background("00-style-key-art.png", "title")
background("06-combat-background.png", "act1")
