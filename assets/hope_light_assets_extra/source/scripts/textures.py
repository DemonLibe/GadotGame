"""Процедурные низкоразрешённые текстуры в духе концепт-арта Hope Light.
Все текстуры тайлятся, 64x64 = 1 м (кроме отмеченных). Пиксельные, под фильтр nearest."""
import numpy as np
from PIL import Image
import os

rng = np.random.default_rng(7)


def noise(h, w, scale=1.0):
    return rng.random((h, w)) * scale


def blur_tile(a, k=1):
    out = a.copy()
    for _ in range(k):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5
    return out


def to_img(rgb):
    return Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8), "RGB")


def colorize(v, c0, c1):
    c0, c1 = np.array(c0), np.array(c1)
    return c0 + (c1 - c0) * v[..., None]


def stains(h, w, n, strength, rad=(3, 10)):
    m = np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w]
    for _ in range(n):
        cy, cx, r = rng.integers(0, h), rng.integers(0, w), rng.integers(*rad)
        dy = np.minimum(abs(yy - cy), h - abs(yy - cy))
        dx = np.minimum(abs(xx - cx), w - abs(xx - cx))
        m += np.clip(1 - np.sqrt(dx ** 2 + dy ** 2) / r, 0, 1)
    return np.clip(m, 0, 1) * strength


def tile_white(s=64):
    """Белая метро-плитка 8x4 на метр, с выбитыми клетками."""
    img = colorize(blur_tile(noise(s, s), 1) * 0.15 + 0.85, (0.62, 0.58, 0.50), (0.86, 0.82, 0.72))
    th, tw = s // 8, s // 4
    for y in range(s):
        for x in range(s):
            if y % th == 0 or x % tw == 0:
                img[y, x] = (0.36, 0.33, 0.28)
    for _ in range(9):  # выбитые плитки
        ty, tx = rng.integers(0, 8), rng.integers(0, 4)
        img[ty * th + 1:(ty + 1) * th, tx * tw + 1:(tx + 1) * tw] = (0.30, 0.28, 0.25) + rng.random(3) * 0.04
    img -= stains(s, s, 6, 0.18)[..., None] * np.array([0.6, 0.8, 1.0])
    return img


def brick_red(s=64):
    """Дореволюционный кирпич: 250x65 мм ~ 16x4 px."""
    img = np.zeros((s, s, 3))
    bh, bw = 4, 16
    base = noise(s, s)
    for y in range(s):
        row = y // bh
        off = (bw // 2) * (row % 2)
        for x in range(s):
            bx = (x + off) // bw
            tint = ((row * 7 + bx * 13) % 5) / 5
            if y % bh == 0 or (x + off) % bw == 0:
                img[y, x] = (0.22, 0.18, 0.15)
            else:
                v = 0.75 + tint * 0.2 + base[y, x] * 0.12
                img[y, x] = np.array((0.52, 0.24, 0.16)) * v
    img -= stains(s, s, 5, 0.25)[..., None] * np.array([0.5, 0.6, 0.5])
    # селитра/плесень зеленоватыми пятнами
    m = stains(s, s, 3, 0.35, (4, 12))[..., None]
    img = img * (1 - m) + np.array((0.22, 0.30, 0.27)) * m
    return img


def cast_iron(s=64):
    """Чугун тюбинга: тёмный, с рыжими потёками сверху вниз."""
    v = blur_tile(noise(s, s), 1)
    img = colorize(v, (0.10, 0.09, 0.08), (0.20, 0.18, 0.16))
    streak = np.zeros((s, s))
    for _ in range(10):
        x = rng.integers(0, s)
        y0 = rng.integers(0, s)
        ln = rng.integers(10, 40)
        for i in range(ln):
            streak[(y0 + i) % s, x] = 1 - i / ln
            streak[(y0 + i) % s, (x + 1) % s] = (1 - i / ln) * 0.5
    rust = np.clip(stains(s, s, 7, 0.6) + streak * 0.8, 0, 1)[..., None]
    img = img * (1 - rust) + np.array((0.42, 0.20, 0.08)) * rust
    return img


def concrete(s=64):
    v = blur_tile(noise(s, s), 2) * 0.5 + noise(s, s) * 0.15
    img = colorize(v, (0.30, 0.28, 0.25), (0.55, 0.52, 0.47))
    img -= stains(s, s, 6, 0.2)[..., None] * 0.6
    return img


def wood(s=64):
    img = np.zeros((s, s, 3))
    g = noise(s, 1)
    for x in range(s):
        for y in range(s):
            v = 0.7 + 0.2 * np.sin(x * 0.9 + g[y % s, 0] * 3 + y * 0.05) * 0.5 + g[x, 0] * 0.1
            if x % 16 == 0:
                v = 0.35
            img[y, x] = np.array((0.42, 0.28, 0.15)) * v
    return img


def paint_green(s=64):
    """Казённая двухцветная покраска: зелёный низ (верх 0.5 текстуры), побелка (низ). V=0 низ стены."""
    img = np.zeros((s, s, 3))
    n = blur_tile(noise(s, s), 1)
    for y in range(s):
        if y >= s // 2:  # PIL row 0 = top => нижние строки = низ стены
            img[y] = colorize(n[y], (0.18, 0.30, 0.24), (0.24, 0.38, 0.30))
        elif y == s // 2 - 1:
            img[y] = (0.10, 0.16, 0.13)
        else:
            img[y] = colorize(n[y], (0.68, 0.66, 0.58), (0.80, 0.78, 0.70))
    img -= stains(s, s, 5, 0.15)[..., None] * 0.5
    return img


def metal_green(s=64):
    n = blur_tile(noise(s, s), 1)
    img = colorize(n, (0.16, 0.24, 0.19), (0.24, 0.33, 0.26))
    chips = (noise(s, s) > 0.985)
    img[chips] = (0.35, 0.30, 0.25)
    img -= stains(s, s, 4, 0.2)[..., None] * np.array([0.3, 0.5, 0.6])
    return img


def metal_dark(s=64):
    n = blur_tile(noise(s, s), 1)
    img = colorize(n, (0.12, 0.12, 0.12), (0.22, 0.21, 0.20))
    rust = stains(s, s, 5, 0.5)[..., None]
    return img * (1 - rust) + np.array((0.35, 0.18, 0.08)) * rust


def linoleum(s=64):
    n = blur_tile(noise(s, s), 1)
    img = colorize(n, (0.35, 0.20, 0.13), (0.45, 0.27, 0.17))
    for y in range(s):
        for x in range(s):
            if (x // 16 + y // 16) % 2:
                img[y, x] *= 0.85
    img -= stains(s, s, 6, 0.2)[..., None] * 0.5
    return img


def gravel(s=64):
    n = noise(s, s)
    img = colorize(blur_tile(n, 1) * 0.6 + n * 0.4, (0.12, 0.11, 0.10), (0.32, 0.29, 0.25))
    return img


def web(s=128):
    """RGBA паутина: радиальные нити + спираль."""
    a = np.zeros((s, s))
    c = s / 2
    yy, xx = np.mgrid[0:s, 0:s]
    ang = np.arctan2(yy - c, xx - c)
    r = np.sqrt((xx - c) ** 2 + (yy - c) ** 2)
    spokes = 14
    d = np.abs(((ang / (2 * np.pi) * spokes) % 1) - 0.5) * 2 * np.pi * r / spokes
    a[(np.abs(d - np.pi * r / spokes) < 0.8) & (r < c)] = 1
    spiral = (r + ang / (2 * np.pi) * 6) % 6
    a[(spiral < 0.9) & (r < c - 1) & (r > 3)] = 0.85
    a *= (noise(s, s) > 0.12)
    rgb = np.ones((s, s, 3)) * np.array((0.80, 0.78, 0.70))
    rgba = np.concatenate([rgb, a[..., None]], -1)
    return Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")


def paper(s=32):
    img = colorize(blur_tile(noise(s, s), 1), (0.70, 0.66, 0.55), (0.82, 0.78, 0.66))
    for y in range(6, s - 4, 3):
        L = rng.integers(s // 2, s - 6)
        img[y, 4:L] = (0.25, 0.25, 0.30)
    return img


def sign_plate(s=64):
    """Эмалированная табличка ТИХАЯ: тёмная рамка (текст — геометрией)."""
    img = colorize(blur_tile(noise(s, s), 1), (0.70, 0.67, 0.58), (0.80, 0.77, 0.68))
    img[:3], img[-3:], img[:, :3], img[:, -3:] = 0.12, 0.12, 0.12, 0.12
    return img


TEXTURES = {
    "tile_white": tile_white, "brick_red": brick_red, "cast_iron": cast_iron, "concrete": concrete,
    "wood": wood, "paint_wall": paint_green, "metal_green": metal_green, "metal_dark": metal_dark,
    "linoleum": linoleum, "gravel": gravel, "paper": paper, "sign_plate": sign_plate,
}


def generate(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    paths = {}
    for name, fn in TEXTURES.items():
        p = os.path.join(out_dir, name + ".png")
        to_img(fn()).save(p)
        paths[name] = p
    p = os.path.join(out_dir, "web.png")
    web().save(p)
    paths["web"] = p
    return paths


if __name__ == "__main__":
    import sys
    print(generate(sys.argv[1]))
