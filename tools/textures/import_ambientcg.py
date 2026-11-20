#!/usr/bin/env python3
"""Импорт CC0-материалов ambientCG (https://ambientcg.com) в набор текстур игры.

Для каждого материала из THEMES скачивается 1K-JPG, берутся Color, NormalGL, Roughness (и Metalness / Opacity, если есть),
приводятся к стилю игры (128 px, палитра до 256 цветов, фильтр Nearest) и кладутся в
assets/hope_light_assets_extra/{textures,materials,materials/triplanar} под именами acg_<id>.
Список тем и привязка к ним — в textures/acg_themes.json (по нему игра выбирает материалы для штолен и комнат).

Запуск:  python tools/textures/import_ambientcg.py [id ...]     (без аргументов — все из THEMES)
Нужен доступ к ambientcg.com и acg-download.struffelproductions.com. Лицензия материалов — CC0.
"""
import io, json, os, re, sys, urllib.request, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KIT = os.path.join(ROOT, "assets", "hope_light_assets_extra")
SIZE = 128
COLORS = 256

# тема → материалы. Тема выбирается штольне или комнате; внутри — стены, пол и акценты.
THEMES = {
    "wet":      ["Bricks075B", "Bricks076A", "Bricks089", "Concrete026", "Moss001", "Moss002", "Ground001", "Ground068"],
    "rust":     ["Rust002", "Rust006", "Rust005", "Metal025", "Metal022", "Metal053C", "Metal026", "MetalPlates013", "MetalPlates010",
                 "MetalPlates011", "CorrugatedSteel007C", "Metal017", "Metal047B"],
    "rock":     ["Rock030", "Rock035", "Rock037", "Rock031", "Rock050", "Rock022", "Rock033", "Ground048", "Ground067", "Ground038",
                 "Ground023", "Rocks014", "Rocks011"],
    "oldbrick": ["Bricks003", "Bricks097", "Bricks085", "Bricks054", "Bricks056", "Bricks058", "Bricks023", "Bricks050", "Bricks074", "Bricks042"],
    "bunker":   ["Concrete030", "Concrete031", "Concrete035", "Concrete042A", "Concrete042C", "Concrete044D", "Concrete012", "Concrete033",
                 "Concrete027", "Concrete044B", "Concrete029"],
    "clinic":   ["Tiles107", "Tiles036", "Tiles010", "Tiles032", "Tiles020", "Tiles043", "Tiles054", "Tiles012", "Tiles029", "Tiles007",
                 "Tiles084", "Tiles098"],
    "rooms":    ["PaintedPlaster016", "PaintedPlaster006", "PaintedPlaster010", "PaintedPlaster014", "PaintedPlaster013", "PaintedPlaster008",
                 "PaintedPlaster009", "PaintedPlaster011", "Plaster007", "Wallpaper002C", "PaintedBricks005", "PaintedBricks002"],
    "floors":   ["Terrazzo005", "Terrazzo004", "Terrazzo003", "Carpet012", "Carpet001", "Gravel024", "Gravel028", "DiamondPlate001",
                 "DiamondPlate008C", "DiamondPlate006C", "MetalWalkway013", "MetalWalkway006"],
    "cloth":    ["Leather026", "Leather030", "Leather014", "Leather011", "Fabric026", "Fabric028", "Fabric030", "Fabric045", "Chainmail004", "Net004A"],
}
# предметы: металлы, крашеный металл, дерево, пластик, резина, бумага — для pickup, генератора, вентблоков, ящиков и т. п.
ITEMS = ["Metal046A", "Metal046B", "Metal009", "Metal010", "Metal029", "Metal032", "Metal038", "Metal048B", "Metal047A", "Metal055A", "Metal049A", "Metal021",
         "PaintedMetal001", "PaintedMetal004", "PaintedMetal006", "PaintedMetal016", "PaintedMetal002", "PaintedMetal012", "PaintedMetal017",
         "PaintedMetal018", "PaintedMetal007", "PaintedMetal008",
         "Wood051", "Wood027", "Wood028", "Wood060", "Wood062", "Wood066", "Planks037A", "Planks023A", "Planks014", "Planks020",
         "Plastic006", "Plastic011", "Plastic003", "Plastic009", "Plastic007", "Rubber004", "Rubber001",
         "Paper001", "Paper005", "Paper006", "Cardboard002", "Cardboard001"]
DECALS = ["Leaking001", "Leaking002", "Leaking003", "Leaking004", "Leaking005", "Leaking006", "Leaking007", "Leaking008", "Leaking009", "Rust001", "Grate002"]
UA = {"User-Agent": "Mozilla/5.0"}


def fetch(url, timeout=120):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout).read()


def link_for(asset_id):
    d = json.loads(fetch("https://ambientcg.com/api/v2/full_json?id=%s&include=downloadData" % asset_id))
    a = d["foundAssets"][0]
    for x in a["downloadFolders"]["default"]["downloadFiletypeCategories"]["zip"]["downloads"]:
        if x["attribute"] == "1K-JPG":
            return x["downloadLink"]
    raise RuntimeError("нет 1K-JPG: " + asset_id)


def pick(names, suffix):
    for n in names:
        if re.search(r"_%s\.(jpg|png)$" % suffix, n):
            return n
    return None


def pixelate(img):
    from PIL import Image
    img = img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    return img.quantize(COLORS, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")


def tres(name, tex, nrm, rough, metal, triplanar, decal):
    ext = '[ext_resource type="Texture2D" path="res://assets/hope_light_assets_extra/textures/%s.png" id="1_a"]\n' % tex
    if nrm:
        ext += '[ext_resource type="Texture2D" path="res://assets/hope_light_assets_extra/textures/%s.png" id="2_n"]\n' % nrm
    body = '[gd_resource type="StandardMaterial3D" load_steps=%d format=3]\n\n%s\n[resource]\nresource_name = "M_%s"\n' % (3 if nrm else 2, ext, name)
    if decal:
        body += "transparency = 1\ncull_mode = 2\nshading_mode = 1\n"
    body += 'albedo_texture = ExtResource("1_a")\nroughness = %.2f\n' % rough
    if metal > 0.05:
        body += "metallic = %.2f\n" % metal
    if nrm:
        body += 'normal_enabled = true\nnormal_scale = 0.6\nnormal_texture = ExtResource("2_n")\n'
    if triplanar:
        body += "uv1_triplanar = true\nuv1_world_triplanar = true\n"
    body += "texture_filter = 2\n"
    return body


def mean(img):
    from PIL import ImageStat
    return ImageStat.Stat(img.convert("L")).mean[0] / 255.0


def process(asset_id, decal=False):
    from PIL import Image
    name = "acg_" + asset_id.lower()
    tex_dir = os.path.join(KIT, "textures")
    if os.path.exists(os.path.join(tex_dir, name + ".png")):
        return "уже есть"
    z = zipfile.ZipFile(io.BytesIO(fetch(link_for(asset_id), 300)))
    names = z.namelist()
    col = pick(names, "Color")
    if not col:
        return "нет Color"
    img = Image.open(io.BytesIO(z.read(col)))
    nrm = pick(names, "NormalGL")
    rgh = pick(names, "Roughness")
    mtl = pick(names, "Metalness")
    opa = pick(names, "Opacity")
    if decal:
        small = img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        a = Image.open(io.BytesIO(z.read(opa))).convert("L").resize((SIZE, SIZE), Image.LANCZOS) if opa else None
        if a is None and img.mode == "RGBA":
            a = img.split()[-1].resize((SIZE, SIZE), Image.LANCZOS)
        if a is None:
            return "декаль без Opacity"
        small.putalpha(a)
        small.save(os.path.join(tex_dir, name + ".png"))
        nrm_name = None
    else:
        pixelate(img).save(os.path.join(tex_dir, name + ".png"))
        nrm_name = None
        if nrm:
            Image.open(io.BytesIO(z.read(nrm))).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(tex_dir, name + "_n.png"))
            nrm_name = name + "_n"
    rough = mean(Image.open(io.BytesIO(z.read(rgh)))) if rgh else 0.9
    rough = min(max(rough, 0.35), 1.0)
    metal = mean(Image.open(io.BytesIO(z.read(mtl)))) if mtl else 0.0
    with open(os.path.join(KIT, "materials", "M_%s.tres" % name), "w") as f:
        f.write(tres(name, name, nrm_name, rough, metal, False, decal))
    if not decal:
        with open(os.path.join(KIT, "materials", "triplanar", "M_%s_tri.tres" % name), "w") as f:
            f.write(tres(name, name, nrm_name, rough, metal, True, False))
    return "ok"


def main():
    only = sys.argv[1:]
    todo = []
    for theme, ids in THEMES.items():
        todo += [(i, False) for i in ids]
    todo += [(i, False) for i in ITEMS]
    todo += [(i, True) for i in DECALS]
    seen = set()
    for i, dec in todo:
        if i in seen or (only and i not in only):
            continue
        seen.add(i)
        try:
            print("%-22s %s" % (i, process(i, dec)), flush=True)
        except Exception as e:
            print("%-22s ОШИБКА %s" % (i, e), flush=True)
    themes = {k: ["acg_" + i.lower() for i in v] for k, v in THEMES.items()}
    themes["decals"] = ["acg_" + i.lower() for i in DECALS]
    themes["items"] = ["acg_" + i.lower() for i in ITEMS]
    json.dump(themes, open(os.path.join(KIT, "textures", "acg_themes.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
