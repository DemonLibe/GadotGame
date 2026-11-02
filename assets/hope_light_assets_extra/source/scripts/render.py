"""Импорт каждого GLB обратно в Blender (проверка round-trip) и рендер превью Cycles."""
import sys, os, math, glob
import bpy
from mathutils import Vector

ROOT = sys.argv[1]
OUTDIR = sys.argv[2]
only = sys.argv[3:]
os.makedirs(OUTDIR, exist_ok=True)

INTERIOR = ("tunnel_section", "platform_section", "oldline_vault", "shaft_segment", "shaft_bottom")


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 400
    sc.render.resolution_y = 300
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("W"); sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.018, 0.015, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.view_settings.view_transform = "AgX"
    return sc


def add_light(name, loc, energy, color, size=1.0, kind="AREA"):
    l = bpy.data.lights.new(name, kind)
    l.energy = energy; l.color = color
    if kind == "AREA":
        l.size = size
    o = bpy.data.objects.new(name, l)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    d = Vector((0, 0, 0)) - Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return o


for path in sorted(glob.glob(os.path.join(ROOT, "models", "*", "*.glb"))):
    name = os.path.splitext(os.path.basename(path))[0]
    if only and name not in only:
        continue
    sc = setup()
    bpy.ops.import_scene.gltf(filepath=path)
    vis = [o for o in sc.objects if o.type == "MESH" and not o.name.endswith("colonly")]
    for o in sc.objects:
        if o.type == "MESH" and o.name.endswith("colonly"):
            o.hide_render = True
    mn = Vector((1e9,) * 3); mx = -mn
    for o in vis:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    ctr = (mn + mx) / 2
    size = max((mx - mn).length, 0.05)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam); sc.camera = cam
    if any(name.startswith(p) for p in INTERIOR):
        # вид изнутри вдоль секции; glTF -Z(Godot) = Blender +Y после импорта
        if name.startswith("shaft"):
            eye = Vector((0.3, 0.6, ctr.z + 0.2)); tgt = Vector((0, -1.0, mn.z))
            cam.data.lens = 14
        else:
            eye = Vector((ctr.x + (0.6 if "platform" not in name else 1.0), mn.y - 0.2, 1.6))
            tgt = Vector((ctr.x - 0.3, mx.y + 2, 1.3))
            cam.data.lens = 16
        add_light("Key", eye + Vector((0.3, 0.5, 0.5)), 250, (1.0, 0.75, 0.45), 0.4, "POINT")
        add_light("Fill", Vector((ctr.x, mx.y - 0.5, ctr.z)), 120, (0.5, 0.6, 0.8), 0.4, "POINT")
    else:
        d = Vector((1.0, -1.35, 0.8)).normalized()
        eye = ctr + d * size * 1.25
        tgt = ctr
        cam.data.lens = 50
        add_light("Key", ctr + Vector((2, -2, 3)) * size, 600 * size * size, (1.0, 0.78, 0.5), size * 1.5)
        add_light("Rim", ctr + Vector((-2, 2, 1.5)) * size, 350 * size * size, (0.45, 0.6, 1.0), size * 1.5)
        add_light("Fill", ctr + Vector((-1, -2, 0.2)) * size, 80 * size * size, (0.8, 0.8, 0.8), size * 2)
    cam.location = eye
    cam.rotation_euler = (tgt - eye).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_start = 0.01
    sc.render.filepath = os.path.join(OUTDIR, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("RENDER", name, len(vis))
