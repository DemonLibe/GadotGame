"""Дополнительные текстуры Hope Light + карты нормалей для всех текстур."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from textures import noise, blur_tile, colorize, stains, to_img, rng, TEXTURES as BASE, web


def tile_white_clean(s=64):
    img = colorize(blur_tile(noise(s, s), 1) * 0.1 + 0.9, (0.70, 0.67, 0.58), (0.86, 0.83, 0.74))
    th, tw = s // 8, s // 4
    for y in range(s):
        for x in range(s):
            off = (tw // 2) * ((y // th) % 2)
            if y % th == 0 or (x + off) % tw == 0:
                img[y, x] = (0.40, 0.37, 0.32)
    return img


def tile_green(s=64):
    """Зелёная казённая плитка 8×8 (санузел/дежурка)."""
    img = colorize(blur_tile(noise(s, s), 1), (0.20, 0.34, 0.28), (0.28, 0.44, 0.36))
    for y in range(s):
        for x in range(s):
            if y % 8 == 0 or x % 8 == 0:
                img[y, x] = (0.55, 0.55, 0.48)
    img -= stains(s, s, 4, 0.15)[..., None] * 0.5
    return img


def concrete_wet(s=64):
    v = blur_tile(noise(s, s), 2) * 0.5 + noise(s, s) * 0.1
    img = colorize(v, (0.14, 0.13, 0.12), (0.30, 0.28, 0.25))
    wet = stains(s, s, 8, 0.6, (5, 14))[..., None]
    return img * (1 - wet * 0.5)


def concrete_floor_cracked(s=64):
    img = concrete()
    for _ in range(4):
        y, x = rng.integers(0, s, 2)
        for i in range(rng.integers(15, 40)):
            img[y % s, x % s] = (0.12, 0.11, 0.10)
            y += rng.integers(-1, 2); x += rng.integers(0, 2)
    return img


def concrete():
    return BASE["concrete"]()


def dirt_floor(s=64):
    n = blur_tile(noise(s, s), 2) * 0.6 + noise(s, s) * 0.4
    img = colorize(n, (0.13, 0.10, 0.07), (0.30, 0.24, 0.17))
    pebbles = noise(s, s) > 0.97
    img[pebbles] = (0.42, 0.38, 0.32)
    return img


def rust_metal(s=64):
    n = blur_tile(noise(s, s), 1)
    img = colorize(n, (0.28, 0.12, 0.05), (0.48, 0.24, 0.10))
    m = stains(s, s, 6, 0.6)[..., None]
    return img * (1 - m) + np.array((0.15, 0.12, 0.10)) * m


def metal_grate(s=64):
    """RGBA решётка (просечка) — alpha-clip."""
    a = np.zeros((s, s))
    for y in range(s):
        for x in range(s):
            if x % 8 < 2 or y % 8 < 2:
                a[y, x] = 1
    rgb = colorize(blur_tile(noise(s, s), 1), (0.12, 0.11, 0.10), (0.25, 0.22, 0.19))
    rgba = np.concatenate([rgb, a[..., None]], -1)
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")


def wood_planks_dark(s=64):
    img = np.zeros((s, s, 3))
    g = noise(s, 1)
    for y in range(s):
        for x in range(s):
            v = 0.6 + 0.15 * np.sin(y * 0.7 + g[x % s, 0] * 4) + g[y, 0] * 0.1
            if y % 16 == 0:
                v = 0.2
            img[y, x] = np.array((0.25, 0.17, 0.10)) * v
    img -= stains(s, s, 4, 0.15)[..., None] * 0.4
    return img


def brick_soot(s=64):
    img = BASE["brick_red"]()
    soot = blur_tile(noise(s, s), 3)
    grad = np.linspace(0.8, 0.2, s)[:, None]
    k = np.clip(soot * 0.6 + grad * 0.6, 0, 1)[..., None]
    return img * (1 - k * 0.75)


def brick_moss(s=64):
    img = BASE["brick_red"]()
    m = stains(s, s, 6, 0.8, (6, 16))[..., None]
    return img * (1 - m) + np.array((0.16, 0.24, 0.12)) * m


def plaster_peeling(s=64):
    img = colorize(blur_tile(noise(s, s), 1), (0.62, 0.60, 0.53), (0.74, 0.72, 0.64))
    m = (stains(s, s, 7, 1.0, (4, 12)) > 0.3)
    br = BASE["brick_red"]()
    img[m] = br[m] * 0.9
    edge = m ^ np.roll(m, 1, 0)
    img[edge] = (0.30, 0.27, 0.22)
    return img


def tubing_rust_heavy(s=64):
    img = BASE["cast_iron"]()
    m = np.clip(stains(s, s, 10, 0.9) + blur_tile(noise(s, s), 2) * 0.3, 0, 1)[..., None]
    return img * (1 - m) + np.array((0.45, 0.22, 0.08)) * m


def warning_stripes(s=64):
    img = np.zeros((s, s, 3))
    for y in range(s):
        for x in range(s):
            img[y, x] = (0.75, 0.58, 0.10) if ((x + y) // 8) % 2 == 0 else (0.08, 0.08, 0.07)
    img -= stains(s, s, 6, 0.3)[..., None] * 0.5
    return img


def rubber_mat(s=64):
    img = colorize(noise(s, s) * 0.3, (0.05, 0.05, 0.05), (0.12, 0.12, 0.12))
    for y in range(s):
        for x in range(s):
            if (x % 8 in (3, 4)) and (y % 8 in (1, 2, 3, 4, 5, 6)) if (y // 8 + x // 8) % 2 else (y % 8 in (3, 4)) and (x % 8 in (1, 2, 3, 4, 5, 6)):
                img[y, x] = (0.16, 0.16, 0.15)
    return img


def blanket_wool(s=64):
    n = noise(s, s)
    img = colorize(n * 0.4 + 0.6, (0.18, 0.20, 0.15), (0.26, 0.28, 0.20))
    for y in range(s):
        if (y // 4) % 8 == 0:
            img[y] *= 0.6
    return img


def ceiling_panels(s=64):
    img = colorize(blur_tile(noise(s, s), 1), (0.55, 0.53, 0.47), (0.66, 0.64, 0.57))
    for y in range(s):
        for x in range(s):
            if y % 32 == 0 or x % 32 == 0:
                img[y, x] = (0.25, 0.24, 0.21)
            elif (x % 4 == 2 and y % 4 == 2):
                img[y, x] *= 0.75
    img -= stains(s, s, 4, 0.25)[..., None] * np.array([0.4, 0.5, 0.7])
    return img


def puddle(s=64):
    """RGBA лужа: тёмная вода с краями, alpha-clip."""
    yy, xx = np.mgrid[0:s, 0:s]
    r = np.sqrt((xx - s / 2) ** 2 + (yy - s / 2) ** 2) / (s / 2)
    edge = blur_tile(noise(s, s), 3) * 0.5
    a = (r + edge - 0.25 < 0.75).astype(float)
    rgb = np.ones((s, s, 3)) * np.array((0.04, 0.045, 0.05))
    return Image.fromarray((np.concatenate([rgb, a[..., None]], -1) * 255).astype(np.uint8), "RGBA")


def _font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def _poster(lines, bg, fg, s=(96, 128), stripe=None):
    im = Image.new("RGB", s, bg)
    d = ImageDraw.Draw(im)
    if stripe:
        d.rectangle([0, 0, s[0], 18], fill=stripe)
    y = 24
    for txt, sz in lines:
        f = _font(sz)
        w = d.textlength(txt, font=f)
        d.text(((s[0] - w) / 2, y), txt, font=f, fill=fg)
        y += sz + 6
    a = np.asarray(im).astype(float) / 255
    a = a * (1 - stains(s[1], s[0], 6, 0.3)[..., None] * 0.5)
    return to_img(a)


def poster_safety():
    return _poster([("ОСТОРОЖНО", 11), ("ПОЕЗД", 15), ("", 6), ("НЕ ХОДИ", 11), ("ПО ПУТЯМ", 11)],
                   (190, 180, 150), (30, 25, 20), stripe=(140, 30, 20))


def poster_schedule():
    im = _poster([("ГРАФИК", 13), ("ОБХОДА", 13)], (185, 178, 152), (35, 30, 25))
    d = ImageDraw.Draw(im)
    for k in range(7):
        y = 66 + k * 8
        d.line([10, y, 86, y], fill=(80, 70, 60))
        d.text((12, y - 1), f"{k + 1}", font=_font(7), fill=(40, 35, 30))
    return im


def line_scheme():
    """Схема линии: Тихая → ПК0..ПК2 → Старая линия."""
    im = Image.new("RGB", (128, 64), (195, 188, 162))
    d = ImageDraw.Draw(im)
    d.line([12, 22, 116, 22], fill=(150, 30, 25), width=4)
    d.line([84, 22, 104, 50], fill=(110, 60, 40), width=3)
    for x in (12, 48, 66, 84):
        d.ellipse([x - 4, 18, x + 4, 26], fill=(240, 235, 220), outline=(40, 30, 25))
    f = _font(8)
    d.text((4, 30), "ТИХАЯ", font=f, fill=(30, 25, 20))
    d.text((40, 4), "ПК0", font=f, fill=(30, 25, 20))
    d.text((60, 30), "ПК1", font=f, fill=(30, 25, 20))
    d.text((80, 4), "ПК2", font=f, fill=(30, 25, 20))
    d.text((70, 52), "СТАР. ЛИНИЯ", font=_font(7), fill=(90, 40, 30))
    return im


def danger_plate():
    """Табличка «ОПАСНО / ВЫСОКОЕ НАПРЯЖЕНИЕ» (типовая, без бренда)."""
    im = Image.new("RGB", (96, 64), (225, 220, 205))
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 93, 61], outline=(150, 25, 20), width=3)
    d.polygon([(48, 8), (40, 28), (49, 26), (44, 40), (56, 20), (47, 22)], fill=(150, 25, 20))
    f = _font(10)
    for i, t in enumerate(("ОПАСНО", "НАПРЯЖЕНИЕ")):
        w = d.textlength(t, font=_font(10 if i == 0 else 8))
        d.text(((96 - w) / 2, 42 + i * 10), t, font=_font(10 if i == 0 else 8), fill=(30, 25, 20))
    return to_img(np.asarray(im) / 255 * (1 - stains(64, 96, 4, 0.25)[..., None] * 0.4))


EXTRA = {
    "tile_white_clean": tile_white_clean, "tile_green": tile_green, "concrete_wet": concrete_wet,
    "concrete_floor_cracked": concrete_floor_cracked, "dirt_floor": dirt_floor, "rust_metal": rust_metal,
    "wood_planks_dark": wood_planks_dark, "brick_soot": brick_soot, "brick_moss": brick_moss,
    "plaster_peeling": plaster_peeling, "tubing_rust_heavy": tubing_rust_heavy, "warning_stripes": warning_stripes,
    "rubber_mat": rubber_mat, "blanket_wool": blanket_wool, "ceiling_panels": ceiling_panels,
}
EXTRA_IMG = {  # уже PIL-изображения (RGBA/надписи)
    "metal_grate": metal_grate, "puddle": puddle, "poster_safety": poster_safety,
    "poster_schedule": poster_schedule, "line_scheme": line_scheme, "danger_plate": danger_plate,
}


def normal_from(img, strength=2.0):
    a = np.asarray(img.convert("L")).astype(float) / 255
    a = blur_tile(a, 1)
    dx = (np.roll(a, -1, 1) - np.roll(a, 1, 1)) * strength
    dy = (np.roll(a, -1, 0) - np.roll(a, 1, 0)) * strength
    n = np.dstack([-dx, dy, np.ones_like(a)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def generate(out, base_dir):
    os.makedirs(out, exist_ok=True)
    names = []
    for k, fn in EXTRA.items():
        to_img(fn()).save(f"{out}/{k}.png"); names.append(k)
    for k, fn in EXTRA_IMG.items():
        fn().save(f"{out}/{k}.png"); names.append(k)
    # нормали для всех (старых и новых), кроме надписей и альфа-декалей
    for f in sorted(os.listdir(out)) + sorted(os.listdir(base_dir)):
        if not f.endswith(".png") or f.endswith("_n.png"):
            continue
        k = f[:-4]
        if k in ("poster_safety", "poster_schedule", "line_scheme", "danger_plate", "paper", "puddle", "web"):
            continue
        src = f"{out}/{f}" if os.path.exists(f"{out}/{f}") else f"{base_dir}/{f}"
        normal_from(Image.open(src).convert("RGB")).save(f"{out}/{k}_n.png")
    return names


if __name__ == "__main__":
    print(generate(sys.argv[1], sys.argv[2]))
