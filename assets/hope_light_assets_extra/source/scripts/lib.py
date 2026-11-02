"""Мини-библиотека для сборки ассетов Hope Light в Blender (bpy) и экспорта в GLB под Godot 4.

Соглашения:
  * 1 юнит = 1 метр. Blender Z-up → glTF/Godot Y-up (конвертирует экспортёр).
  * Модульные секции идут вдоль Blender +Y = Godot -Z (forward в Godot).
  * Origin ассета — на полу, в центре начала секции (или в центре основания пропа).
  * Коллизии: дочерние меши с суффиксами Godot (-colonly, -convcolonly).
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix

TEX = {}
MATS = {}


# ---------------------------------------------------------------- сцена
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def empty(name, parent=None, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.3
    e.location = loc
    link(e)
    if parent:
        e.parent = parent
    return e


# ---------------------------------------------------------------- материалы
def load_textures(tex_dir):
    for f in os.listdir(tex_dir):
        if f.endswith(".png"):
            TEX[f[:-4]] = os.path.join(tex_dir, f)


def mat(name, tex=None, color=(0.5, 0.5, 0.5), rough=0.85, metal=0.0, emit=None, emit_strength=1.0,
        alpha_clip=False, tint=None):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if tex:
        img = bpy.data.images.load(TEX[tex], check_existing=True)
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        n.interpolation = "Closest"  # → glTF sampler NEAREST, пиксельный вид
        if tint:
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            nt.links.new(n.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*tint, 1)
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        else:
            nt.links.new(n.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha_clip:
            rnd = nt.nodes.new("ShaderNodeMath")
            rnd.operation = "ROUND"
            nt.links.new(n.outputs["Alpha"], rnd.inputs[0])
            nt.links.new(rnd.outputs[0], bsdf.inputs["Alpha"])
            m.surface_render_method = "DITHERED"
            m.use_backface_culling = False
    else:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    MATS[name] = m
    return m


def std_mats():
    """Общая палитра — одинаковые имена материалов во всех GLB (удобно переназначать в Godot)."""
    return dict(
        tile=mat("M_TileWhite", "tile_white", rough=0.4),
        brick=mat("M_BrickOld", "brick_red", rough=0.95),
        iron=mat("M_CastIron", "cast_iron", rough=0.7, metal=0.6),
        concrete=mat("M_Concrete", "concrete", rough=0.95),
        wood=mat("M_Wood", "wood", rough=0.8),
        wall=mat("M_PaintWall", "paint_wall", rough=0.7),
        green=mat("M_MetalGreen", "metal_green", rough=0.55, metal=0.4),
        dark=mat("M_MetalDark", "metal_dark", rough=0.6, metal=0.7),
        lino=mat("M_Linoleum", "linoleum", rough=0.6),
        gravel=mat("M_Gravel", "gravel", rough=1.0),
        paper=mat("M_Paper", "paper", rough=0.9),
        sign=mat("M_SignPlate", "sign_plate", rough=0.5),
        web=mat("M_Web", "web", rough=1.0, alpha_clip=True),
        rubber=mat("M_Rubber", color=(0.03, 0.03, 0.03), rough=0.9),
        steel=mat("M_Steel", color=(0.35, 0.34, 0.32), rough=0.35, metal=1.0),
        brass=mat("M_Brass", color=(0.55, 0.40, 0.18), rough=0.4, metal=1.0),
        ink=mat("M_Ink", color=(0.05, 0.05, 0.06), rough=0.6),
        red=mat("M_PaintRed", color=(0.45, 0.06, 0.04), rough=0.6),
        chalk=mat("M_Chalk", color=(0.85, 0.85, 0.80), rough=1.0),
        glass=mat("M_GlassDirty", color=(0.55, 0.52, 0.42), rough=0.2),
        lamp=mat("M_LampWarm", color=(1.0, 0.85, 0.6), emit=(1.0, 0.72, 0.38), emit_strength=6.0),
        lamp_red=mat("M_LampRed", color=(0.8, 0.1, 0.05), emit=(1.0, 0.08, 0.03), emit_strength=5.0),
        flame=mat("M_Flame", color=(1.0, 0.6, 0.2), emit=(1.0, 0.55, 0.15), emit_strength=8.0),
        bone=mat("M_Bone", color=(0.62, 0.57, 0.46), rough=0.8),
        cloth=mat("M_Cloth", color=(0.06, 0.05, 0.04), rough=1.0),
    )


# ---------------------------------------------------------------- геометрия
def mesh_from_bm(bm, name, material=None, parent=None, uv=1.0):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me))
    if material:
        obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    if uv:
        box_uv(obj, uv)
    return obj


def bm_box(bm, size, loc=(0, 0, 0), rot=None):
    sx, sy, sz = size
    m = Matrix.Translation(loc)
    if rot:
        m = m @ rot
    m = m @ Matrix.Diagonal((sx, sy, sz, 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def box(name, size, loc=(0, 0, 0), material=None, parent=None, uv=1.0, rot=None):
    """Параллелепипед; loc — центр."""
    bm = bmesh.new()
    bm_box(bm, size, loc, rot)
    return mesh_from_bm(bm, name, material, parent, uv)


def boxes(name, specs, material=None, parent=None, uv=1.0):
    """Один меш из нескольких боксов: specs = [(size, loc), ...] или (size, loc, rot)."""
    bm = bmesh.new()
    for s in specs:
        bm_box(bm, *s)
    return mesh_from_bm(bm, name, material, parent, uv)


def bm_cyl(bm, r, depth, loc=(0, 0, 0), axis="Z", seg=12, r2=None, cap=True):
    if axis == "Z":
        rot = Matrix.Identity(4)
    elif axis == "X":
        rot = Matrix.Rotation(math.pi / 2, 4, "Y")
    else:
        rot = Matrix.Rotation(math.pi / 2, 4, "X")
    m = Matrix.Translation(loc) @ rot
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r,
                          radius2=r if r2 is None else r2, depth=depth, matrix=m)


def cyl(name, r, depth, loc=(0, 0, 0), axis="Z", seg=12, material=None, parent=None, uv=1.0, r2=None, cap=True):
    bm = bmesh.new()
    bm_cyl(bm, r, depth, loc, axis, seg, r2, cap)
    return mesh_from_bm(bm, name, material, parent, uv)


def bm_ring(bm, r_in, r_out, a0, a1, y0, y1, seg, cz=0.0, cx=0.0, inner=True, outer=True, sides=True, ends=True):
    """Сегмент кольца в плоскости XZ, выдавленный по Y. Углы в радианах от +X против часовой (к +Z)."""
    def P(r, a, y):
        return bm.verts.new((cx + r * math.cos(a), y, cz + r * math.sin(a)))
    n = seg + 1
    angs = [a0 + (a1 - a0) * i / seg for i in range(n)]
    vi0 = [P(r_in, a, y0) for a in angs]
    vi1 = [P(r_in, a, y1) for a in angs]
    vo0 = [P(r_out, a, y0) for a in angs]
    vo1 = [P(r_out, a, y1) for a in angs]
    for i in range(seg):
        if inner:
            bm.faces.new((vi0[i], vi1[i], vi1[i + 1], vi0[i + 1]))
        if outer:
            bm.faces.new((vo0[i], vo0[i + 1], vo1[i + 1], vo1[i]))
        if sides:
            bm.faces.new((vi0[i], vi0[i + 1], vo0[i + 1], vo0[i]))
            bm.faces.new((vi1[i], vo1[i], vo1[i + 1], vi1[i + 1]))
    if ends and abs(a1 - a0) < 2 * math.pi - 1e-4:
        bm.faces.new((vi0[0], vo0[0], vo1[0], vi1[0]))
        bm.faces.new((vi0[-1], vi1[-1], vo1[-1], vo0[-1]))


def bm_poly_extrude(bm, faces2d, y0, y1):
    """faces2d: список полигонов [(x,z),...] в плоскости XZ; выдавливание по Y (y0..y1). Общие вершины сливаются."""
    cache = {}
    def V(p):
        k = (round(p[0], 5), round(p[1], 5))
        if k not in cache:
            cache[k] = bm.verts.new((p[0], y0, p[1]))
        return cache[k]
    new = []
    for f in faces2d:
        vs = [V(p) for p in f]
        try:
            new.append(bm.faces.new(vs))
        except ValueError:
            pass
    res = bmesh.ops.extrude_face_region(bm, geom=new)
    verts = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=verts, vec=(0, y1 - y0, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def ray_poly(cx, cz, ang, poly):
    """Расстояние от центра до границы многоугольника по лучу."""
    dx, dz = math.cos(ang), math.sin(ang)
    best = 1e9
    for i in range(len(poly)):
        (x1, z1), (x2, z2) = poly[i], poly[(i + 1) % len(poly)]
        ex, ez = x2 - x1, z2 - z1
        den = dx * ez - dz * ex
        if abs(den) < 1e-9:
            continue
        t = ((x1 - cx) * ez - (z1 - cz) * ex) / den
        u = ((x1 - cx) * dz - (z1 - cz) * dx) / den
        if t > 0 and 0 <= u <= 1:
            best = min(best, t)
    return best


def wall_with_hole_faces(w, h, hole, center, seg=48):
    """Квады стены w×h (x от -w/2..w/2, z 0..h) со звёздным отверстием hole (многоугольник)."""
    cx, cz = center
    outer = [(-w / 2, 0), (w / 2, 0), (w / 2, h), (-w / 2, h)]
    corner_at = {}
    for (x, z) in outer:
        ang = math.atan2(z - cz, x - cx) % (2 * math.pi)
        corner_at[int(ang / (2 * math.pi / seg)) % seg] = (x, z)
    p = lambda r, a: (cx + r * math.cos(a), cz + r * math.sin(a))
    faces = []
    for i in range(seg):
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        ri0, ri1 = ray_poly(cx, cz, a0, hole), ray_poly(cx, cz, a1, hole)
        ro0, ro1 = ray_poly(cx, cz, a0, outer), ray_poly(cx, cz, a1, outer)
        if i in corner_at:
            faces.append([p(ri0, a0), p(ro0, a0), corner_at[i], p(ro1, a1), p(ri1, a1)])
        else:
            faces.append([p(ri0, a0), p(ro0, a0), p(ro1, a1), p(ri1, a1)])
    return faces


def box_uv(obj, scale=1.0, fit=False):
    """Мировая box-проекция UV: одна текстура = scale метров. scale может быть (su, sv)."""
    su, sv = (scale, scale) if not isinstance(scale, (tuple, list)) else scale
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.active
    mw = obj.matrix_world if obj.parent is None else Matrix.Identity(4)
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            co = l.vert.co
            if ax == 2:
                u, v = co.x, co.y
            elif ax == 0:
                u, v = co.y * (1 if n.x > 0 else -1), co.z
            else:
                u, v = co.x * (-1 if n.y > 0 else 1), co.z
            l[uvl].uv = (u / su, v / sv)
    if fit:  # вписать UV в 0..1 (таблички, бумага)
        us = [l[uvl].uv.x for f in bm.faces for l in f.loops]; vs = [l[uvl].uv.y for f in bm.faces for l in f.loops]
        u0, v0 = min(us), min(vs)
        for f in bm.faces:
            for l in f.loops:
                l[uvl].uv = (l[uvl].uv.x - u0, l[uvl].uv.y - v0)
    bm.to_mesh(me)
    bm.free()


def join(objs, name):
    """Склеить меши (все должны иметь одного родителя или не иметь)."""
    objs = [o for o in objs if o]
    if len(objs) == 1:
        objs[0].name = name
        return objs[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]


def text_mesh(name, body, size, loc, material, parent=None, depth=0.005, align="CENTER", rot_x=90):
    c = bpy.data.curves.new(name, "FONT")
    c.body = body
    c.size = size
    c.extrude = depth
    c.align_x = align
    c.align_y = "CENTER"
    o = link(bpy.data.objects.new(name + "_txt", c))
    o.rotation_euler = (math.radians(rot_x), 0, 0)
    o.location = loc
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    bpy.data.objects.remove(o)
    obj = link(bpy.data.objects.new(name, me))
    obj.rotation_euler = (math.radians(rot_x), 0, 0)
    obj.location = loc
    obj.data.materials.clear()
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def col_box(name, size, loc, parent):
    """Выпуклая коллизия-бокс (Godot: -convcolonly → StaticBody3D + ConvexPolygonShape3D)."""
    o = box(name + "-convcolonly", size, loc, None, parent, uv=None)
    o.display_type = "WIRE"
    return o


def col_mesh(name, bm, parent):
    """Вогнутая коллизия (Godot: -colonly → StaticBody3D + ConcavePolygonShape3D)."""
    o = mesh_from_bm(bm, name + "-colonly", None, parent, uv=None)
    o.display_type = "WIRE"
    return o


# ---------------------------------------------------------------- экспорт
def finalize(root):
    """Применить масштаб/поворот ко всем мешам (Godot любит единичные трансформы у мешей)."""
    bpy.context.view_layer.update()


def export(root, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    def sel(o):
        o.select_set(True)
        for c in o.children:
            sel(c)
    sel(root)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True,
        export_materials="EXPORT", export_image_format="AUTO", export_extras=True,
        export_lights=False, export_cameras=False, export_animations=False,
    )


def stats(root):
    tris = 0
    def walk(o):
        nonlocal tris
        if o.type == "MESH" and "col" not in o.name.split("-")[-1]:
            o.data.calc_loop_triangles()
            tris += len(o.data.loop_triangles)
        for c in o.children:
            walk(c)
    walk(root)
    return tris
