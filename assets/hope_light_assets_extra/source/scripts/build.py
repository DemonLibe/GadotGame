import sys, os, json, traceback
sys.path.insert(0, os.path.dirname(__file__))
import bpy
import lib
import importlib
mod = os.environ.get('ASSET_MODULE', 'assets')
ASSETS = getattr(importlib.import_module(mod), os.environ.get('ASSET_LIST', 'ASSETS'))
EXTRA = mod != 'assets'

OUT = sys.argv[1]
TEXDIR = sys.argv[2]
only = sys.argv[3:] or None

report = []
for folder, name, fn in ASSETS:
    if only and name not in only:
        continue
    lib.reset()
    for d in TEXDIR.split(':'): lib.load_textures(d)
    M = lib.std_mats()
    if EXTRA:
        import assets_extra; assets_extra.extra_mats(M)
    try:
        root = fn(M)
        bpy.context.view_layer.update()
        path = os.path.join(OUT, "models", folder, name + ".glb")
        lib.export(root, path)
        # габариты по видимым мешам
        import mathutils
        mn = mathutils.Vector((1e9,) * 3); mx = -mn
        for o in bpy.context.scene.objects:
            if o.type == "MESH" and not o.name.split("-")[-1].endswith("colonly"):
                for c in o.bound_box:
                    w = o.matrix_world @ mathutils.Vector(c)
                    mn = mathutils.Vector(map(min, mn, w)); mx = mathutils.Vector(map(max, mx, w))
        size = [round(v, 2) for v in (mx - mn)]
        report.append(dict(folder=folder, name=name, tris=lib.stats(root), size_blender_xyz=size,
                           kb=round(os.path.getsize(path) / 1024, 1)))
        print("OK", folder, name, report[-1]["tris"], size)
    except Exception:
        traceback.print_exc()
        print("FAIL", name)
json.dump(report, open(os.path.join(OUT, "_report.json"), "w"), ensure_ascii=False, indent=1)
