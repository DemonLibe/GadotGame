#!/usr/bin/env python3
"""Запекание карт нормалей и шероховатости для моделей с одной цветовой текстурой (предметы, существа, мусор, метро).

Для каждого <имя>.png рядом кладутся <имя>_n.png (нормали, OpenGL) и <имя>_r.png (шероховатость, канал R).
Рельеф берётся из самого рисунка (высокочастотная часть яркости), сверху — мелкая фактура подходящего материала ambientCG
(металл, ржавчина, резина, кожа…), расстеленная по той же UV. Игра подхватывает их сама (ProcTex.model_skin, ExtModels).

Запуск:  python tools/textures/bake_maps.py
"""
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEX = os.path.join(ROOT, "assets", "hope_light_assets_extra", "textures")

# файл → (материал для фактуры, сколько раз повторить по картинке, сила фактуры, сила рельефа из рисунка, базовая шероховатость, разброс)
JOBS = {
    "models/items/jerrycan_albedo.png": ("acg_metal046a", 3, 0.7, 0.9, 0.55, 0.25),
    "models/items/pistol_albedo.png": ("acg_metal046b", 4, 0.7, 0.8, 0.38, 0.25),
    "models/items/propane_albedo.png": ("acg_metal046a", 3, 0.7, 0.9, 0.5, 0.25),
    "models/items/radio_albedo.png": ("acg_plastic006", 3, 0.6, 0.8, 0.6, 0.2),
    "models/bones/bone_albedo.png": ("acg_concrete031", 2, 0.55, 0.9, 0.82, 0.12),
    "models/bones/skull_albedo.png": ("acg_concrete031", 2, 0.5, 0.9, 0.78, 0.12),
    "models/mine/cart_albedo.png": ("acg_rust002", 3, 0.85, 1.0, 0.85, 0.2),
    "models/mine/rails_albedo.png": ("acg_metal025", 2, 0.7, 0.9, 0.7, 0.2),
    "models/huntsman/huntsman_albedo.png": ("acg_rubber004", 3, 0.6, 0.8, 0.55, 0.2),
    "models/other/other_albedo.png": ("acg_leather030", 5, 0.9, 1.0, 0.42, 0.25),
    "models/listener/listener_albedo.png": ("acg_leather014", 5, 0.8, 1.0, 0.5, 0.25),
    "models/trash/trash_Cans.png": ("acg_metal046a", 3, 0.6, 0.8, 0.5, 0.2),
    "models/trash/trash_CansRusty.png": ("acg_rust002", 3, 0.8, 0.9, 0.8, 0.2),
    "models/trash/trash_Bags.png": ("acg_plastic006", 3, 0.5, 0.8, 0.6, 0.15),
    "models/trash/trash_Bottles.png": ("acg_plastic003", 2, 0.2, 0.5, 0.2, 0.1),
    "models/trash/trash_CardboardPaper.png": ("acg_cardboard001", 3, 0.6, 0.7, 0.9, 0.08),
    "models/trash/trash_BrickWheel.png": ("acg_bricks097", 2, 0.6, 0.8, 0.85, 0.1),
    "models/metro_psx/metro_metal_02.png": ("acg_metal046a", 3, 0.6, 0.8, 0.5, 0.2),
    "models/metro_psx/metro_metal_04.png": ("acg_metal046a", 3, 0.6, 0.8, 0.5, 0.2),
    "models/metro_psx/metro_Tiles.png": ("acg_tiles107", 2, 0.5, 0.7, 0.35, 0.15),
    "models/metro_psx/metro_Floor.png": ("acg_terrazzo004", 2, 0.5, 0.8, 0.55, 0.15),
    "models/metro_psx/metro_ConcreteBare.png": ("acg_concrete031", 2, 0.7, 0.9, 0.9, 0.1),
    "models/metro_psx/metro_Chair.png": ("acg_plastic006", 2, 0.4, 0.7, 0.5, 0.15),
    "models/metro_psx/metro_seats.png": ("acg_plastic006", 2, 0.4, 0.7, 0.5, 0.15),
}


def blur(a, sigma):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(sigma)), dtype=np.float32) / 255.0


def overlay_xy(name, size, tiles):
    path = os.path.join(TEX, name + "_n.png")
    if not os.path.exists(path):
        return np.zeros((size[1], size[0]), np.float32), np.zeros((size[1], size[0]), np.float32)
    n = Image.open(path).convert("RGB")
    n = n.resize((max(size[0] // tiles, 8), max(size[1] // tiles, 8)), Image.LANCZOS)
    a = np.asarray(n, dtype=np.float32) / 255.0 * 2.0 - 1.0
    a = np.tile(a, (tiles, tiles, 1))[: size[1], : size[0]]
    pad_y, pad_x = size[1] - a.shape[0], size[0] - a.shape[1]
    if pad_y or pad_x:
        a = np.pad(a, ((0, pad_y), (0, pad_x), (0, 0)), mode="edge")
    return a[..., 0], a[..., 1]


def bake(rel, spec):
    mat, tiles, k_tex, k_img, r0, rvar = spec
    src = os.path.join(ROOT, rel)
    if not os.path.exists(src):
        return "нет файла"
    img = Image.open(src).convert("RGB")
    w, h = img.size
    rgb = np.asarray(img, dtype=np.float32) / 255.0
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    # рельеф из рисунка: высокая частота яркости, чтобы пятна и швы на текстуре читались как углубления
    sigma = max(1.2, w / 48.0)
    hi = lum - blur(lum, sigma)
    gx = (np.roll(hi, -1, 1) - np.roll(hi, 1, 1)) * 0.5
    gy = (np.roll(hi, -1, 0) - np.roll(hi, 1, 0)) * 0.5
    ox, oy = overlay_xy(mat, (w, h), tiles)
    nx = -gx * k_img * 6.0 + ox * k_tex
    ny = gy * k_img * 6.0 + oy * k_tex
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5
    out = os.path.splitext(src)[0]
    Image.fromarray((n * 255).astype(np.uint8)).save(out + "_n.png")
    # шероховатость: тёмные углубления шершавее, светлые потёртые места глаже
    rough = np.clip(r0 + (blur(lum, sigma) - lum) * rvar * 4.0 + (0.5 - lum) * rvar, 0.05, 1.0)
    Image.fromarray((rough * 255).astype(np.uint8)).convert("L").save(out + "_r.png")
    return "ok"


if __name__ == "__main__":
    for rel, spec in JOBS.items():
        print("%-48s %s" % (rel, bake(rel, spec)))
