"""Расширение набора ассетов Hope Light: дополнительные пропы и модули по локациям."""
import math
import random
import bmesh
from mathutils import Matrix
from lib import *
from assets import (rot_x, rot_y, rot_z, light_point, bm_track, bm_cables, bm_hoop, box_uv_fit,
                    RAIL_GAUGE, RAIL_TOP, SEG, T_RIN, T_CZ, T_RSKIN, bm_tubing_ring)


def extra_mats(M):
    M.update(
        tile_clean=mat("M_TileWhiteClean", "tile_white_clean", rough=0.35),
        tile_green=mat("M_TileGreen", "tile_green", rough=0.35),
        conc_wet=mat("M_ConcreteWet", "concrete_wet", rough=0.3),
        conc_crack=mat("M_ConcreteCracked", "concrete_floor_cracked", rough=0.95),
        dirt=mat("M_DirtFloor", "dirt_floor", rough=1.0),
        rust=mat("M_RustMetal", "rust_metal", rough=0.85, metal=0.4),
        grate=mat("M_MetalGrate", "metal_grate", rough=0.6, metal=0.6, alpha_clip=True),
        planks=mat("M_WoodPlanksDark", "wood_planks_dark", rough=0.85),
        brick_soot=mat("M_BrickSoot", "brick_soot", rough=0.95),
        brick_moss=mat("M_BrickMoss", "brick_moss", rough=0.95),
        plaster=mat("M_PlasterPeeling", "plaster_peeling", rough=0.9),
        iron_rust=mat("M_CastIronRusty", "tubing_rust_heavy", rough=0.8, metal=0.5),
        stripes=mat("M_WarningStripes", "warning_stripes", rough=0.6),
        rmat=mat("M_RubberMat", "rubber_mat", rough=0.9),
        blanket=mat("M_BlanketWool", "blanket_wool", rough=1.0),
        ceiling=mat("M_CeilingPanels", "ceiling_panels", rough=0.8),
        puddle=mat("M_Puddle", "puddle", rough=0.05, alpha_clip=True),
        poster1=mat("M_PosterSafety", "poster_safety", rough=0.9),
        poster2=mat("M_PosterSchedule", "poster_schedule", rough=0.9),
        scheme=mat("M_LineScheme", "line_scheme", rough=0.6),
        danger=mat("M_DangerPlate", "danger_plate", rough=0.5),
        lamp_green=mat("M_LampGreen", color=(0.1, 0.6, 0.2), emit=(0.1, 1.0, 0.3), emit_strength=4.0),
        white=mat("M_PaintWhite", color=(0.75, 0.73, 0.66), rough=0.6),
    )
    return M


def plane_fit(name, w, h, material, parent, loc=(0, 0, 0), facing="-Y"):
    """Вертикальная (лицом в -Y) или горизонтальная (facing='Z') плоскость с UV 0..1."""
    bm = bmesh.new()
    x, y, z = loc
    if facing == "Z":
        pts = [(x - w / 2, y - h / 2, z), (x + w / 2, y - h / 2, z), (x + w / 2, y + h / 2, z), (x - w / 2, y + h / 2, z)]
    else:
        pts = [(x - w / 2, y, z - h / 2), (x + w / 2, y, z - h / 2), (x + w / 2, y, z + h / 2), (x - w / 2, y, z + h / 2)]
    vs = [bm.verts.new(p) for p in pts]
    bm.faces.new(vs if facing == "Z" else vs)
    o = mesh_from_bm(bm, name, material, parent, uv=None)
    uvl = o.data.uv_layers.new(name="UVMap")
    for i, uv in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
        uvl.data[i].uv = uv
    return o


# ======================================================================= ОБЩЕЕ
def fire_extinguisher(M):
    root = empty("FireExtinguisher")
    cyl("Body", 0.08, 0.5, (0, 0, 0.27), "Z", 14, M["red"], root, uv=0.3)
    cyl("Top", 0.08, 0.04, (0, 0, 0.54), "Z", 14, M["red"], root, uv=None, r2=0.03)
    boxes("Valve", [((0.03, 0.03, 0.07), (0, 0, 0.59)), ((0.14, 0.02, 0.02), (0.04, 0, 0.62))], M["dark"], root, uv=None)
    bm = bmesh.new()
    bm_cyl(bm, 0.012, 0.35, (0.09, 0, 0.42), "Z", 6)
    bm_cyl(bm, 0.02, 0.06, (0.09, 0, 0.22), "Z", 6)
    mesh_from_bm(bm, "Hose", M["rubber"], root, uv=None)
    box("Label", (0.1, 0.005, 0.14), (0, -0.08, 0.3), M["white"], root, uv=None)
    col_box("FireExtinguisher", (0.18, 0.18, 0.64), (0, 0, 0.32), root)
    return root


def fuel_canister(M):
    root = empty("FuelCanister")
    box("Body", (0.17, 0.35, 0.47), (0, 0, 0.235), M["green"], root, uv=0.4)
    boxes("Ribs", [((0.18, 0.02, 0.36), (0, -0.07, 0.22)), ((0.18, 0.02, 0.36), (0, 0.07, 0.22))], M["green"], root, uv=0.4)
    boxes("Handles", [((0.03, 0.05, 0.05), (0, k * 0.08, 0.5)) for k in (-1, 0, 1)] +
          [((0.03, 0.22, 0.02), (0, 0, 0.53))], M["green"], root, uv=None)
    cyl("Spout", 0.025, 0.05, (0, 0.14, 0.49), "Z", 8, M["dark"], root, uv=None)
    col_box("FuelCanister", (0.18, 0.35, 0.55), (0, 0, 0.275), root)
    return root


def fuel_barrel(M):
    root = empty("FuelBarrel")
    cyl("Body", 0.29, 0.88, (0, 0, 0.44), "Z", 16, M["rust"], root, uv=0.9)
    bm = bmesh.new()
    for z in (0.02, 0.3, 0.58, 0.86):
        bm_ring(bm, 0.29, 0.305, 0, 2 * math.pi, z, z + 0.03, 16)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=rot_x(math.pi / 2))
    mesh_from_bm(bm, "Hoops", M["dark"], root, uv=None)
    cyl("Bung", 0.03, 0.02, (0.15, 0, 0.885), "Z", 8, M["dark"], root, uv=None)
    col_box("FuelBarrel", (0.6, 0.6, 0.88), (0, 0, 0.44), root)
    return root


def cable_drum(M):
    root = empty("CableDrum")
    bm = bmesh.new()
    for x in (-0.35, 0.35):
        bm_cyl(bm, 0.55, 0.05, (x, 0, 0.55), "X", 16)
    mesh_from_bm(bm, "Flanges", M["wood"], root)
    cyl("Core", 0.42, 0.65, (0, 0, 0.55), "X", 16, M["rubber"], root)
    cyl("Axle", 0.06, 0.82, (0, 0, 0.55), "X", 8, M["dark"], root, uv=None)
    col_box("CableDrum", (0.8, 1.1, 1.1), (0, 0, 0.55), root)
    return root


def pipe_run_4m(M):
    """Две трубы на хомутах вдоль стены (стена — плоскость X=0)."""
    root = empty("PipeRun4m")
    bm = bmesh.new()
    bm_cyl(bm, 0.08, SEG, (0.14, SEG / 2, 0.0), "Y", 10)
    bm_cyl(bm, 0.05, SEG, (0.12, SEG / 2, 0.22), "Y", 8)
    for y in (0.0, SEG):
        bm_cyl(bm, 0.1, 0.06, (0.14, y + (0.03 if y == 0 else -0.03), 0.0), "Y", 10)
    mesh_from_bm(bm, "Pipes", M["rust"], root, uv=0.5)
    bm = bmesh.new()
    for y in (0.6, 2.0, 3.4):
        bm_box(bm, (0.24, 0.04, 0.03), (0.12, y, -0.09))
        bm_box(bm, (0.2, 0.04, 0.03), (0.1, y, 0.16))
        bm_box(bm, (0.02, 0.06, 0.4), (0.01, y, 0.06))
    mesh_from_bm(bm, "Clamps", M["dark"], root, uv=None)
    return root


def hermetic_door(M):
    """Гермодверь в раме. Створка Door на петле, штурвал Wheel вращается по своей оси."""
    root = empty("HermeticDoor")
    W, H = 1.2, 2.0
    boxes("Frame", [((0.2, 0.4, H + 0.2), (-W / 2 - 0.1, 0, (H + 0.2) / 2)), ((0.2, 0.4, H + 0.2), (W / 2 + 0.1, 0, (H + 0.2) / 2)),
                    ((W + 0.4, 0.4, 0.2), (0, 0, H + 0.1)), ((W, 0.4, 0.06), (0, 0, 0.03))], M["concrete"], root)
    door = empty("Door", root, (-W / 2, -0.2, 0.06))
    box("Leaf", (W, 0.12, H - 0.06), (W / 2, -0.06, (H - 0.06) / 2), M["green"], door)
    bm = bmesh.new()
    for z in (0.3, 0.97, 1.64):
        bm_box(bm, (W - 0.1, 0.03, 0.06), (W / 2, -0.135, z))
    for x in (0.12, W - 0.12):
        bm_box(bm, (0.06, 0.03, H - 0.3), (x, -0.135, H / 2))
    for z in (0.35, 1.6):
        bm_cyl(bm, 0.05, 0.16, (-0.02, -0.06, z), "Z", 8)
    mesh_from_bm(bm, "Ribs", M["dark"], door, uv=None)
    wheel = empty("Wheel", door, (W / 2, -0.22, 1.0))
    bm = bmesh.new()
    bm_ring(bm, 0.2, 0.23, 0, 2 * math.pi, -0.015, 0.015, 16)
    for k in range(3):
        a = k * math.pi / 3
        bm_box(bm, (0.42, 0.02, 0.025), (0, 0, 0), rot_y(a))
    bm_cyl(bm, 0.04, 0.1, (0, 0.04, 0), "Y", 8)
    mesh_from_bm(bm, "WheelMesh", M["red"], wheel, uv=None)
    col_box("Leaf", (W, 0.12, H - 0.06), (W / 2, -0.06, (H - 0.06) / 2), door)
    col_box("FrameL", (0.2, 0.4, H + 0.2), (-W / 2 - 0.1, 0, (H + 0.2) / 2), root)
    col_box("FrameR", (0.2, 0.4, H + 0.2), (W / 2 + 0.1, 0, (H + 0.2) / 2), root)
    col_box("FrameTop", (W + 0.4, 0.4, 0.2), (0, 0, H + 0.1), root)
    return root


def danger_sign(M):
    root = empty("DangerSign")
    box("Plate", (0.3, 0.01, 0.2), (0, -0.005, 0), M["dark"], root, uv=None)
    plane_fit("Face", 0.29, 0.19, M["danger"], root, (0, -0.0105, 0))
    return root


def wooden_pallet(M):
    root = empty("WoodenPallet")
    bm = bmesh.new()
    for k in range(7):
        bm_box(bm, (1.2, 0.1, 0.022), (0, -0.4 + k * 0.133, 0.133))
    for x in (-0.55, 0, 0.55):
        bm_box(bm, (0.1, 0.8, 0.022), (x, 0, 0.011))
        for y in (-0.35, 0, 0.35):
            bm_box(bm, (0.1, 0.1, 0.1), (x, y, 0.072))
    mesh_from_bm(bm, "Pallet", M["wood"], root)
    col_box("Pallet", (1.2, 0.8, 0.145), (0, 0, 0.072), root)
    return root


def puddle_decal(M):
    root = empty("PuddleDecal")
    plane_fit("Puddle", 1.4, 1.0, M["puddle"], root, (0, 0, 0.004), "Z")
    return root


def wall_poster_safety(M):
    root = empty("WallPosterSafety")
    plane_fit("Poster", 0.45, 0.6, M["poster1"], root, (0, -0.003, 0))
    return root


def wall_poster_schedule(M):
    root = empty("WallPosterSchedule")
    plane_fit("Poster", 0.45, 0.6, M["poster2"], root, (0, -0.003, 0))
    return root


def line_scheme_board(M):
    root = empty("LineSchemeBoard")
    box("Board", (1.2, 0.03, 0.62), (0, -0.015, 0), M["dark"], root, uv=None)
    plane_fit("Scheme", 1.14, 0.56, M["scheme"], root, (0, -0.031, 0))
    return root


# ======================================================================= ДЕЖУРКА
def field_telephone(M):
    """Полевой телефон в деревянном/железном корпусе с ручкой индуктора."""
    root = empty("FieldTelephone")
    box("Case", (0.25, 0.18, 0.12), (0, 0, 0.06), M["green"], root, uv=0.3)
    box("Lid", (0.25, 0.01, 0.16), (0, 0.09, 0.2), M["green"], root, uv=0.3)
    bm = bmesh.new()
    bm_box(bm, (0.2, 0.035, 0.03), (0, -0.02, 0.15))
    bm_box(bm, (0.04, 0.05, 0.03), (-0.09, -0.02, 0.135))
    bm_box(bm, (0.04, 0.05, 0.03), (0.09, -0.02, 0.135))
    mesh_from_bm(bm, "Handset", M["rubber"], root, uv=None)
    boxes("Cradle", [((0.02, 0.03, 0.02), (s * 0.06, -0.02, 0.125)) for s in (-1, 1)], M["dark"], root, uv=None)
    crank = empty("Crank", root, (0.125, 0, 0.06))
    boxes("CrankArm", [((0.02, 0.01, 0.06), (0.01, 0, -0.03)), ((0.03, 0.015, 0.015), (0.025, 0, -0.06))], M["dark"], crank, uv=None)
    col_box("FieldTelephone", (0.26, 0.2, 0.28), (0, 0, 0.14), root)
    return root


def shelf_rack(M):
    root = empty("ShelfRack")
    w, d, h = 1.0, 0.4, 1.9
    bm = bmesh.new()
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            bm_box(bm, (0.035, 0.035, h), (x, y, h / 2))
    mesh_from_bm(bm, "Posts", M["dark"], root, uv=None)
    bm = bmesh.new()
    for z in (0.1, 0.55, 1.0, 1.45, 1.88):
        bm_box(bm, (w, d, 0.02), (0, 0, z))
    mesh_from_bm(bm, "Shelves", M["green"], root)
    # немного содержимого
    boxes("Boxes", [((0.3, 0.3, 0.22), (-0.25, 0, 0.22)), ((0.25, 0.28, 0.18), (0.2, 0, 0.65)),
                    ((0.18, 0.25, 0.3), (-0.3, 0, 1.16))], M["paper"], root, uv=0.4)
    cyl("Jar", 0.06, 0.15, (0.3, 0, 1.085), "Z", 8, M["glass"], root, uv=None)
    col_box("ShelfRack", (w + 0.04, d + 0.04, h), (0, 0, h / 2), root)
    return root


def cot(M):
    """Раскладушка с одеялом."""
    root = empty("Cot")
    L, W, H = 1.9, 0.7, 0.4
    bm = bmesh.new()
    for s in (-1, 1):
        bm_cyl(bm, 0.015, L, (s * W / 2, 0, H), "Y", 6)
    for y in (-L / 2 + 0.05, L / 2 - 0.05):
        bm_cyl(bm, 0.015, W, (0, y, H), "X", 6)
    for y in (-0.6, 0.6):
        bm_box(bm, (0.02, 0.02, 0.58), (-0.25, y, H / 2), rot_x(0) @ rot_y(math.radians(-60)))
        bm_box(bm, (0.02, 0.02, 0.58), (0.25, y, H / 2), rot_y(math.radians(60)))
        bm_box(bm, (W, 0.02, 0.02), (0, y, 0.01))
    mesh_from_bm(bm, "Frame", M["steel"], root, uv=None)
    box("Canvas", (W, L - 0.06, 0.02), (0, 0, H - 0.005), M["cloth"], root)
    bm = bmesh.new()
    bm_box(bm, (W + 0.06, 1.2, 0.06), (0, 0.3, H + 0.04))
    bm_box(bm, (0.04, 1.2, 0.2), (W / 2 + 0.03, 0.3, H - 0.06))
    mesh_from_bm(bm, "Blanket", M["blanket"], root, uv=0.6)
    box("Pillow", (0.5, 0.3, 0.1), (0, -0.7, H + 0.05), M["white"], root)
    col_box("Cot", (W + 0.1, L, H + 0.1), (0, 0, (H + 0.1) / 2), root)
    return root


def wall_clock(M):
    """Настенные часы; стрелки — узлы HandHour/HandMinute (вращать по Y в Godot = по оси от стены)."""
    root = empty("WallClock")
    cyl("Rim", 0.16, 0.05, (0, -0.025, 0), "Y", 20, M["dark"], root, uv=None)
    cyl("Face", 0.14, 0.005, (0, -0.052, 0), "Y", 20, M["white"], root, uv=None)
    bm = bmesh.new()
    for k in range(12):
        a = k * math.pi / 6
        bm_box(bm, (0.01, 0.003, 0.025 if k % 3 else 0.04), (0.12 * math.sin(a), -0.056, 0.12 * math.cos(a)), rot_y(-a))
    mesh_from_bm(bm, "Ticks", M["ink"], root, uv=None)
    hh = empty("HandHour", root, (0, -0.058, 0))
    hh.rotation_euler = (0, math.radians(-100), 0)
    box("Hour", (0.012, 0.003, 0.07), (0, 0, 0.03), M["ink"], hh, uv=None)
    hm = empty("HandMinute", root, (0, -0.061, 0))
    hm.rotation_euler = (0, math.radians(-20), 0)
    box("Minute", (0.008, 0.003, 0.11), (0, 0, 0.05), M["ink"], hm, uv=None)
    return root


def first_aid_box(M):
    root = empty("FirstAidBox")
    box("Box", (0.35, 0.12, 0.3), (0, -0.06, 0), M["white"], root, uv=None)
    door = empty("Door", root, (-0.175, -0.12, 0))
    box("Leaf", (0.35, 0.015, 0.3), (0.175, -0.0075, 0), M["white"], door, uv=None)
    boxes("Cross", [((0.12, 0.004, 0.035), (0.175, -0.017, 0)), ((0.035, 0.004, 0.12), (0.175, -0.017, 0))], M["red"], door, uv=None)
    col_box("FirstAidBox", (0.35, 0.14, 0.3), (0, -0.07, 0), root)
    return root


def electric_stove_kettle(M):
    """Электроплитка с чайником."""
    root = empty("StoveKettle")
    box("Stove", (0.3, 0.3, 0.08), (0, 0, 0.04), M["white"], root, uv=None)
    cyl("Coil", 0.1, 0.01, (0, 0, 0.085), "Z", 14, M["dark"], root, uv=None)
    cyl("Knob", 0.015, 0.02, (0.1, -0.155, 0.04), "Y", 8, M["ink"], root, uv=None)
    cyl("Kettle", 0.09, 0.15, (0, 0, 0.165), "Z", 12, M["steel"], root, uv=None, r2=0.07)
    cyl("KettleLid", 0.05, 0.03, (0, 0, 0.255), "Z", 10, M["steel"], root, uv=None, r2=0.02)
    bm = bmesh.new()
    bm_cyl(bm, 0.015, 0.12, (0.11, 0, 0.18), "X", 6, r2=0.008)
    mesh_from_bm(bm, "Spout", M["steel"], root, uv=None)
    bm = bmesh.new()
    bm_hoop(bm, 0, 0, 0, 0.07, 0, math.pi, 6, 0.012, 0.012)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=rot_y(math.pi / 2) @ rot_x(math.pi / 2))
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=(0, 0, 0.25))
    mesh_from_bm(bm, "KettleHandle", M["dark"], root, uv=None)
    col_box("StoveKettle", (0.3, 0.3, 0.27), (0, 0, 0.135), root)
    return root


def ceiling_dome_lamp(M):
    """Плафон на потолок дежурки. Origin — точка крепления, светит вниз."""
    root = empty("CeilingDomeLamp")
    cyl("Base", 0.14, 0.03, (0, 0, -0.015), "Z", 14, M["dark"], root, uv=None)
    cyl("Dome", 0.12, 0.1, (0, 0, -0.08), "Z", 14, M["lamp"], root, uv=None, r2=0.13)
    light_point(root, (0, 0, -0.2))
    return root


def room_ceiling_4x4(M):
    root = empty("RoomCeiling4x4")
    box("Ceiling", (4, 4, 0.05), (0, 0, 0.025), M["ceiling"], root, uv=1.0)
    col_box("Ceiling", (4, 4, 0.05), (0, 0, 0.025), root)
    return root


# ======================================================================= ШАХТА
def shaft_landing_grate(M):
    """Решётчатая площадка-отдых в шахте (под кольцо R=1.4). Половина круга у стены с лестницей."""
    root = empty("ShaftLandingGrate")
    bm = bmesh.new()
    vs = []
    c = bm.verts.new((0, 0.1, 0))
    n = 12
    pts = [bm.verts.new((1.38 * math.cos(math.pi + math.pi * k / n), 1.38 * math.sin(math.pi + math.pi * k / n), 0)) for k in range(n + 1)]
    for k in range(n):
        bm.faces.new((c, pts[k], pts[k + 1]))
    o = mesh_from_bm(bm, "Grate", M["grate"], root, uv=None)
    box_uv(o, 0.5)
    bm = bmesh.new()
    bm_hoop(bm, 0, 0, -0.02, 1.36, math.pi, 2 * math.pi, 16, 0.04, 0.05)
    bm_box(bm, (2.76, 0.05, 0.05), (0, 0, -0.02))
    for x in (-0.8, 0, 0.8):
        bm_box(bm, (0.04, 1.3, 0.04), (x, -0.65, -0.03))
    # ограждение у проёма
    bm_box(bm, (2.6, 0.03, 0.03), (0, 0.02, 1.0))
    for x in (-1.25, -0.6, 0.6, 1.25):
        bm_box(bm, (0.03, 0.03, 1.0), (x, 0.02, 0.5))
    mesh_from_bm(bm, "Frame", M["dark"], root, uv=None)
    col_box("Grate", (2.76, 1.38, 0.05), (0, -0.69, -0.025), root)
    return root


def shaft_bottom_exit(M):
    """Нижний сегмент шахты 2.5 м с проёмом-выходом (в +Y, т.е. Godot −Z) к платформе."""
    root = empty("ShaftBottomExit")
    R, H = 1.4, 2.5
    bm = bmesh.new()
    gap0, gap1 = math.radians(240), math.radians(300)
    bm_ring(bm, R, R + 0.2, gap1, gap0 + 2 * math.pi, 0, H, 18, inner=True, outer=True, sides=True)
    bm_ring(bm, R, R + 0.2, gap0, gap1, 2.1, H, 4, inner=True, outer=True, sides=True)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=rot_x(math.pi / 2))
    mesh_from_bm(bm, "ShaftWall", M["conc_wet"], root)
    box("Floor", (3.2, 3.2, 0.1), (0, 0, -0.05), M["conc_crack"], root)
    hw = abs(R * math.cos(gap0))
    boxes("Passage", [((0.15, 1.2, 2.1), (-hw - 0.075, R + 0.6, 1.05)), ((0.15, 1.2, 2.1), (hw + 0.075, R + 0.6, 1.05)),
                      ((2 * hw + 0.3, 1.2, 0.15), (0, R + 0.6, 2.175)), ((2 * hw, 1.2, 0.1), (0, R + 0.6, -0.05))],
          M["concrete"], root)
    wy = -R
    bm = bmesh.new()
    for k in range(8):
        z = 0.4 + k * 0.25
        bm_box(bm, (0.4, 0.022, 0.022), (0, wy + 0.16, z))
        bm_box(bm, (0.022, 0.18, 0.022), (-0.2, wy + 0.08, z))
        bm_box(bm, (0.022, 0.18, 0.022), (0.2, wy + 0.08, z))
    mesh_from_bm(bm, "Rungs", M["steel"], root, uv=None)
    light_point(root, (0, R + 0.6, 1.9))
    bm = bmesh.new()
    bm_ring(bm, R, R + 0.2, gap1, gap0 + 2 * math.pi, 0, H, 10, inner=True, outer=False, sides=False, ends=False)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=rot_x(math.pi / 2))
    col_mesh("ShaftWall", bm, root)
    col_box("Floor", (3.2, 3.2, 0.1), (0, 0, -0.05), root)
    col_box("PassL", (0.15, 1.2, 2.1), (-hw - 0.075, R + 0.6, 1.05), root)
    col_box("PassR", (0.15, 1.2, 2.1), (hw + 0.075, R + 0.6, 1.05), root)
    return root


# ======================================================================= ПЛАТФОРМА
def platform_barrier(M):
    root = empty("PlatformBarrier")
    bm = bmesh.new()
    for x in (-0.9, 0.9):
        bm_box(bm, (0.05, 0.05, 1.0), (x, 0, 0.5))
        bm_box(bm, (0.3, 0.3, 0.04), (x, 0, 0.02))
    mesh_from_bm(bm, "Posts", M["dark"], root, uv=None)
    boxes("Bar", [((1.9, 0.04, 0.12), (0, 0, 0.9)), ((1.9, 0.04, 0.12), (0, 0, 0.5))], M["stripes"], root, uv=0.5)
    col_box("Barrier", (1.95, 0.3, 1.0), (0, 0, 0.5), root)
    return root


def tool_board(M):
    """Пожарный/путейский щит: лопата, лом, багор, ведро. Каждый инструмент — отдельный узел (можно подобрать)."""
    root = empty("ToolBoard")
    box("Board", (1.2, 0.03, 1.0), (0, -0.015, 0.5), M["red"], root)
    s = empty("Shovel", root, (-0.4, -0.06, 0.5))
    cyl("ShovelHandle", 0.015, 0.75, (0, 0, 0.1), "Z", 6, M["wood"], s, uv=None)
    box("ShovelBlade", (0.22, 0.01, 0.28), (0, 0, -0.38), M["dark"], s, uv=None)
    c = empty("Crowbar", root, (-0.1, -0.05, 0.5))
    cyl("Bar", 0.014, 0.85, (0, 0, 0), "Z", 6, M["dark"], c, uv=None)
    h = empty("Hook", root, (0.2, -0.05, 0.5))
    cyl("Pole", 0.015, 0.9, (0, 0, 0), "Z", 6, M["wood"], h, uv=None)
    boxes("HookHead", [((0.012, 0.012, 0.12), (0, 0, 0.5)), ((0.08, 0.012, 0.012), (0.04, 0, 0.5))], M["dark"], h, uv=None)
    b = empty("Bucket", root, (0.45, -0.12, 0.25))
    bm = bmesh.new()
    bm_cyl(bm, 0.1, 0.22, (0, 0, 0), "Z", 10, r2=0.13, cap=False)
    bm_cyl(bm, 0.1, 0.005, (0, 0, -0.11), "Z", 10)
    mesh_from_bm(bm, "BucketMesh", M["red"], b, uv=None)
    for (n, sz, l) in [("Shovel", (0.24, 0.05, 0.95), (-0.4, -0.06, 0.4)), ("Crowbar", (0.05, 0.05, 0.85), (-0.1, -0.05, 0.5))]:
        pass
    col_box("ToolBoard", (1.2, 0.2, 1.0), (0, -0.1, 0.5), root)
    return root


def buffer_stop(M):
    """Тупиковый упор в конце пути (колея 1.0 м)."""
    root = empty("BufferStop")
    br, bs, bb = bmesh.new(), bmesh.new(), bmesh.new()
    bm_track(br, bs, bb, length=1.5)
    mesh_from_bm(br, "Rails", M["dark"], root)
    mesh_from_bm(bs, "Sleepers", M["wood"], root)
    mesh_from_bm(bb, "Ballast", M["gravel"], root)
    bm = bmesh.new()
    for s in (-1, 1):
        bm_box(bm, (0.1, 1.2, 0.1), (s * RAIL_GAUGE / 2, 0.75, 0.55), rot_x(math.radians(35)))
        bm_box(bm, (0.1, 0.1, 0.65), (s * RAIL_GAUGE / 2, 1.2, 0.5))
    mesh_from_bm(bm, "Struts", M["rust"], root)
    box("Beam", (RAIL_GAUGE + 0.5, 0.25, 0.3), (0, 1.1, 0.75), M["stripes"], root, uv=0.5)
    for s in (-1, 1):
        cyl(f"Buffer{s}", 0.08, 0.2, (s * 0.4, 0.92, 0.75), "Y", 10, M["dark"], root, uv=None)
    col_box("BufferStop", (RAIL_GAUGE + 0.5, 0.6, 0.9), (0, 1.1, 0.45), root)
    return root


def platform_section_4m_column(M):
    """Платформенная секция с опорной колонной из плитки и пожарным щитом на стене (вариант для разнообразия)."""
    from assets import platform_section_4m
    root = platform_section_4m(M)
    root.name = "PlatformSection4mColumn"
    box("Column", (0.6, 0.6, 6.0), (2.2, 2.0, 3.0), M["tile_clean"], root, uv=1.0)
    col_box("Column", (0.6, 0.6, 6.0), (2.2, 2.0, 3.0), root)
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((3.597, 0.775, 1.2), (3.597, 1.225, 1.2), (3.597, 1.225, 1.8), (3.597, 0.775, 1.8))]
    bm.faces.new(vs[::-1])
    p = mesh_from_bm(bm, "Poster", M["poster1"], root, uv=None)
    uvl = p.data.uv_layers.new(name="UVMap")
    for i, uv in enumerate(((1, 0), (0, 0), (0, 1), (1, 1))[::-1]):
        uvl.data[i].uv = uv
    return root


# ======================================================================= ТОННЕЛЬ
def tunnel_signal(M):
    """Тоннельный светофор (2 огня). Origin — стена, лицом в -Y."""
    root = empty("TunnelSignal")
    box("Bracket", (0.06, 0.25, 0.06), (0, -0.125, 0.0), M["dark"], root, uv=None)
    box("Head", (0.22, 0.15, 0.48), (0, -0.3, 0.0), M["dark"], root, uv=None)
    cyl("LensRed", 0.06, 0.02, (0, -0.38, 0.11), "Y", 12, M["lamp_red"], root, uv=None)
    cyl("LensGreen", 0.06, 0.02, (0, -0.38, -0.11), "Y", 12, M["glass"], root, uv=None)
    bm = bmesh.new()
    for z in (0.11, -0.11):
        bm_cyl(bm, 0.08, 0.08, (0, -0.42, z + 0.03), "Y", 10, cap=False)
    mesh_from_bm(bm, "Visors", M["dark"], root, uv=None)
    light_point(root, (0, -0.5, 0.11), "RedLightPoint")
    return root


def tunnel_section_4m_niche(M):
    """Секция тоннеля с технической нишей-укрытием в левой стене (тюбинги выбраны, бетонная ниша)."""
    from assets import tunnel_section
    root = tunnel_section(M, "TunnelSection4mNiche")
    # убрать часть колец слева: проще пересобрать кольца
    rings = bpy.data.objects["TubingRings"]
    bpy.data.objects.remove(rings)
    bm = bmesh.new()
    for i in range(4):
        gaps = [(150, 215)] if i in (1, 2) else ()
        bm_tubing_ring(bm, float(i), gaps)
    o = mesh_from_bm(bm, "TubingRings", M["iron"], root)
    bpy.data.objects.remove(bpy.data.objects["TunnelWalls-colonly"])
    bm = bmesh.new()
    bm_ring(bm, T_RIN, T_RIN + 0.1, math.radians(-145), math.radians(150), 0, SEG, 14, cz=T_CZ, outer=False, sides=False, ends=False)
    for y0 in (0, 3):
        bm_ring(bm, T_RIN, T_RIN + 0.1, math.radians(150), math.radians(215), y0, y0 + 1, 3, cz=T_CZ, outer=False, sides=False, ends=False)
    col_mesh("TunnelWalls", bm, root)
    # бетонная ниша
    x0 = -T_RSKIN + 0.05
    boxes("Niche", [((0.1, 2.0, 2.1), (x0 - 1.0, 2.0, 1.05)), ((1.1, 0.1, 2.1), (x0 - 0.5, 1.0, 1.05)),
                    ((1.1, 0.1, 2.1), (x0 - 0.5, 3.0, 1.05)), ((1.1, 2.0, 0.1), (x0 - 0.5, 2.0, 2.15)),
                    ((1.4, 2.0, 0.1), (x0 - 0.4, 2.0, -0.05))], M["conc_wet"], root)
    plane_fit("Puddle", 0.8, 0.6, M["puddle"], root, (x0 - 0.4, 2.0, 0.004), "Z")
    empty("HidePoint", root, (x0 - 0.5, 2.0, 0.0))
    col_box("NicheBack", (0.1, 2.0, 2.1), (x0 - 1.0, 2.0, 1.05), root)
    col_box("NicheFloor", (1.4, 2.0, 0.1), (x0 - 0.4, 2.0, -0.05), root)
    return root


def tunnel_section_4m_rusty(M):
    """Секция тоннеля с сильной коррозией, лужами и провисшим кабелем (вариант)."""
    from assets import tunnel_section
    root = tunnel_section(M, "TunnelSection4mRusty")
    bpy.data.objects["TubingRings"].data.materials[0] = M["iron_rust"]
    plane_fit("Puddle1", 1.2, 0.9, M["puddle"], root, (0.9, 1.2, 0.07), "Z")
    plane_fit("Puddle2", 0.9, 0.7, M["puddle"], root, (-0.8, 3.1, 0.07), "Z")
    bm = bmesh.new()
    n = 16
    x = -T_RIN + 0.25
    for k in range(n):
        y0, y1 = SEG * k / n, SEG * (k + 1) / n
        sag = lambda y: 1.55 - 0.5 * math.sin(math.pi * y / SEG)
        z0, z1 = sag(y0), sag(y1)
        ln = math.hypot(y1 - y0, z1 - z0)
        ang = math.atan2(z1 - z0, y1 - y0)
        m = Matrix.Translation((x, (y0 + y1) / 2, (z0 + z1) / 2)) @ Matrix.Rotation(math.pi / 2 + ang, 4, "X")
        bmesh.ops.create_cone(bm, cap_ends=False, segments=6, radius1=0.022, radius2=0.022, depth=ln + 0.01, matrix=m)
    mesh_from_bm(bm, "SaggingCable", M["rubber"], root, uv=None)
    return root


def service_door_metal(M):
    """Металлическая дверь служебного помещения в бетонной коробке (ставится в тюбинг или стену)."""
    root = empty("ServiceDoorMetal")
    boxes("Frame", [((0.12, 0.25, 2.1), (-0.51, 0, 1.05)), ((0.12, 0.25, 2.1), (0.51, 0, 1.05)), ((1.14, 0.25, 0.12), (0, 0, 2.16))],
          M["concrete"], root)
    door = empty("Door", root, (-0.45, -0.1, 0))
    door.rotation_euler = (0, 0, math.radians(-25))
    box("Leaf", (0.9, 0.05, 2.08), (0.45, 0, 1.04), M["rust"], door)
    boxes("Hinges", [((0.04, 0.06, 0.12), (0.0, 0, z)) for z in (0.3, 1.75)], M["dark"], door, uv=None)
    box("Handle", (0.12, 0.03, 0.03), (0.78, -0.05, 1.0), M["steel"], door, uv=None)
    plane_fit("Sign", 0.2, 0.13, M["danger"], door, (0.45, -0.027, 1.55))
    col_box("Leaf", (0.9, 0.05, 2.08), (0.45, 0, 1.04), door)
    col_box("FrameL", (0.12, 0.25, 2.1), (-0.51, 0, 1.05), root)
    col_box("FrameR", (0.12, 0.25, 2.1), (0.51, 0, 1.05), root)
    return root


# ======================================================================= СЛУЖЕБНАЯ КОМНАТА
def iron_bed(M):
    root = empty("IronBed")
    L, W = 1.95, 0.85
    bm = bmesh.new()
    for x in (-W / 2, W / 2):
        for y in (-L / 2, L / 2):
            bm_cyl(bm, 0.02, 0.9 if y < 0 else 0.7, (x, y, 0.45 if y < 0 else 0.35), "Z", 6)
    for y, h in ((-L / 2, 0.9), (L / 2, 0.7)):
        bm_cyl(bm, 0.015, W, (0, y, h - 0.03), "X", 6)
        for k in range(5):
            bm_cyl(bm, 0.008, h - 0.45, (-W / 2 + W * (k + 1) / 6, y, (h + 0.42) / 2), "Z", 4)
    for x in (-W / 2, W / 2):
        bm_box(bm, (0.03, L, 0.05), (x, 0, 0.42))
    mesh_from_bm(bm, "Frame", M["rust"], root, uv=None)
    box("Mattress", (W - 0.04, L - 0.06, 0.1), (0, 0, 0.5), M["cloth"], root)
    box("Blanket", (W, 0.9, 0.04), (0, 0.4, 0.56), M["blanket"], root, uv=0.6)
    col_box("IronBed", (W, L, 0.55), (0, 0, 0.275), root)
    return root


def small_table(M):
    root = empty("SmallTable")
    box("Top", (0.7, 0.5, 0.03), (0, 0, 0.71), M["planks"], root)
    boxes("Legs", [((0.04, 0.04, 0.7), (sx * 0.31, sy * 0.21, 0.35)) for sx in (-1, 1) for sy in (-1, 1)], M["planks"], root)
    col_box("SmallTable", (0.7, 0.5, 0.73), (0, 0, 0.365), root)
    return root


def stool(M):
    root = empty("Stool")
    box("Seat", (0.32, 0.32, 0.03), (0, 0, 0.44), M["planks"], root)
    boxes("Legs", [((0.03, 0.03, 0.43), (sx * 0.13, sy * 0.13, 0.215)) for sx in (-1, 1) for sy in (-1, 1)] +
          [((0.26, 0.02, 0.02), (0, sy * 0.13, 0.15)) for sy in (-1, 1)], M["planks"], root)
    col_box("Stool", (0.32, 0.32, 0.45), (0, 0, 0.225), root)
    return root


def bucket(M):
    root = empty("Bucket")
    bm = bmesh.new()
    bm_cyl(bm, 0.12, 0.28, (0, 0, 0.14), "Z", 12, r2=0.15, cap=False)
    bm_cyl(bm, 0.12, 0.005, (0, 0, 0.003), "Z", 12)
    mesh_from_bm(bm, "Body", M["steel"], root, uv=None)
    bm = bmesh.new()
    bm_hoop(bm, 0, 0, 0, 0.15, 0, math.pi, 10, 0.008, 0.008)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=rot_x(math.pi / 2))
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=(0, 0, 0.28))
    mesh_from_bm(bm, "Handle", M["dark"], root, uv=None)
    col_box("Bucket", (0.3, 0.3, 0.29), (0, 0, 0.145), root)
    return root


def wall_shelf(M):
    """Полка на стене с банками и книгой. Origin — стена, лицом в -Y."""
    root = empty("WallShelf")
    box("Board", (0.8, 0.22, 0.025), (0, -0.11, 0), M["planks"], root)
    boxes("Brackets", [((0.025, 0.18, 0.15), (sx * 0.32, -0.09, -0.08)) for sx in (-1, 1)], M["dark"], root, uv=None)
    cyl("Can1", 0.04, 0.1, (-0.25, -0.1, 0.06), "Z", 8, M["rust"], root, uv=None)
    cyl("Can2", 0.04, 0.1, (-0.15, -0.1, 0.06), "Z", 8, M["green"], root, uv=None)
    box("Book", (0.18, 0.13, 0.04), (0.15, -0.1, 0.033), M["red"], root, uv=None)
    return root


def remains_blanket(M):
    """Подстилка/ветошь у стены, где лежат останки (кости — отдельная модель из основной игры)."""
    root = empty("RemainsBedding")
    rnd = random.Random(4)
    bm = bmesh.new()
    for k in range(7):
        bm_box(bm, (rnd.uniform(0.4, 0.8), rnd.uniform(0.3, 0.6), rnd.uniform(0.03, 0.08)),
               (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.3, 0.3), 0.03), rot_z(rnd.random() * 3) @ rot_x(rnd.uniform(-0.1, 0.1)))
    mesh_from_bm(bm, "Bedding", M["blanket"], root, uv=0.5)
    cyl("Flask", 0.05, 0.18, (0.55, 0.2, 0.09), "Z", 8, M["green"], root, uv=None)
    return root


# ======================================================================= СТАРАЯ ЛИНИЯ
def wooden_barrel(M):
    root = empty("WoodenBarrel")
    bm = bmesh.new()
    bm_cyl(bm, 0.25, 0.4, (0, 0, 0.2), "Z", 14, r2=0.3, cap=True)
    bm_cyl(bm, 0.3, 0.4, (0, 0, 0.6), "Z", 14, r2=0.25, cap=True)
    mesh_from_bm(bm, "Staves", M["planks"], root, uv=0.5)
    bm = bmesh.new()
    for z, r in ((0.08, 0.265), (0.4, 0.305), (0.72, 0.265)):
        bm_ring(bm, r, r + 0.012, 0, 2 * math.pi, z, z + 0.04, 14)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=rot_x(math.pi / 2))
    mesh_from_bm(bm, "Hoops", M["rust"], root, uv=None)
    col_box("WoodenBarrel", (0.6, 0.6, 0.8), (0, 0, 0.4), root)
    return root


def switch_lever(M):
    """Стрелочный перевод: рычаг с противовесом. Рычаг — узел Lever (вращать по X)."""
    root = empty("SwitchLever")
    box("Base", (0.5, 0.3, 0.15), (0, 0, 0.075), M["rust"], root, uv=0.5)
    boxes("Cheeks", [((0.04, 0.2, 0.25), (sx * 0.1, 0, 0.27)) for sx in (-1, 1)], M["rust"], root, uv=None)
    lever = empty("Lever", root, (0, 0, 0.32))
    lever.rotation_euler = (math.radians(25), 0, 0)
    cyl("Rod", 0.02, 0.9, (0, 0, 0.45), "Z", 6, M["dark"], lever, uv=None)
    cyl("Grip", 0.03, 0.12, (0, 0, 0.9), "Z", 6, M["wood"], lever, uv=None)
    box("Counterweight", (0.16, 0.2, 0.12), (0, 0.15, -0.02), M["iron"], lever, uv=None)
    plane_fit("Target", 0.18, 0.18, M["white"], lever, (0, -0.025, 0.65))
    col_box("SwitchLever", (0.5, 0.3, 0.4), (0, 0, 0.2), root)
    return root


def oldline_arch_passage(M):
    """Кирпичная стена 4×3.8 м с арочным проходом до пола (ширина 1.6 м)."""
    root = empty("OldLineArchPassage")
    w, h, t = 4.0, 3.8, 0.5
    pl, pr = -0.8, 0.8
    r = 0.8
    spring = 1.9
    faces = [[(-w / 2, 0), (pl, 0), (pl, spring), (-w / 2, spring)],
             [(pr, 0), (w / 2, 0), (w / 2, h), (pr, h), (pr, spring)],
             [(-w / 2, spring), (pl, spring), (pl, h), (-w / 2, h)]]
    seg = 14
    for k in range(seg):
        a0, a1 = math.pi - math.pi * k / seg, math.pi - math.pi * (k + 1) / seg
        p0 = (r * math.cos(a0), spring + r * math.sin(a0))
        p1 = (r * math.cos(a1), spring + r * math.sin(a1))
        faces.append([p0, p1, (p1[0], h), (p0[0], h)])
    bm = bmesh.new()
    bm_poly_extrude(bm, faces, 0, t)
    mesh_from_bm(bm, "Wall", M["brick_soot"], root)
    col_box("WallL", (w / 2 + pl, t, h), ((-w / 2 + pl) / 2, t / 2, h / 2), root)
    col_box("WallR", (w / 2 - pr, t, h), ((w / 2 + pr) / 2, t / 2, h / 2), root)
    col_box("Top", (pr - pl, t, h - spring - r), (0, t / 2, (h + spring + r) / 2), root)
    return root


def oldline_stairs(M):
    """Кирпичная лестница 6 ступеней (подъём 0.9 м) между уровнями старой линии."""
    root = empty("OldLineStairs")
    n, rise, run, w = 6, 0.15, 0.3, 1.6
    bm = bmesh.new()
    for k in range(n):
        bm_box(bm, (w, run * (n - k), rise), (0, run * (k + (n - k) / 2), rise * (k + 0.5)))
    mesh_from_bm(bm, "Steps", M["brick_moss"], root, uv=0.6)
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, run * n, rise * n), (-w / 2, run * n, rise * n))]
    bm.faces.new(vs)
    col_mesh("Ramp", bm, root)
    return root


def iron_grate_door(M):
    """Решётчатая калитка в арке (под oldline_arch_passage). Створка Gate на петле."""
    root = empty("IronGrateDoor")
    gate = empty("Gate", root, (-0.78, 0.25, 0))
    gate.rotation_euler = (0, 0, math.radians(15))
    bm = bmesh.new()
    for k in range(8):
        x = 0.1 + k * 0.2
        bm_box(bm, (0.025, 0.025, 2.4), (x, 0, 1.22))
    for z in (0.1, 1.0, 2.0):
        bm_box(bm, (1.56, 0.02, 0.04), (0.78, 0, z))
    mesh_from_bm(bm, "Bars", M["rust"], gate, uv=None)
    box("Lock", (0.08, 0.06, 0.12), (1.45, -0.03, 1.0), M["dark"], gate, uv=None)
    col_box("Gate", (1.56, 0.05, 2.45), (0.78, 0, 1.22), gate)
    return root


def handcar_wreck(M):
    """Остов старой дрезины на утопленных рельсах (колея 1.0 м)."""
    root = empty("HandcarWreck")
    wr = 0.25
    bm = bmesh.new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            bm_cyl(bm, wr, 0.06, (sx * RAIL_GAUGE / 2, sy * 0.55, wr), "X", 14)
    mesh_from_bm(bm, "Wheels", M["rust"], root, uv=None)
    bm = bmesh.new()
    bm_box(bm, (1.3, 1.6, 0.08), (0, 0, wr + 0.1), rot_y(math.radians(4)))
    for sy in (-1, 1):
        bm_cyl(bm, 0.03, RAIL_GAUGE + 0.1, (0, sy * 0.55, wr), "X", 6)
    bm_box(bm, (0.1, 0.1, 0.8), (0, 0, wr + 0.5))
    bm_box(bm, (1.2, 0.06, 0.06), (0, 0, wr + 0.92), rot_y(math.radians(12)))
    mesh_from_bm(bm, "Frame", M["rust"], root, uv=0.5)
    bm = bmesh.new()
    for k in range(5):
        bm_box(bm, (0.2, 1.5, 0.03), (-0.5 + k * 0.25, 0, wr + 0.16), rot_y(math.radians(4)))
    mesh_from_bm(bm, "Planks", M["planks"], root, uv=0.5)
    col_box("Handcar", (1.3, 1.6, 0.6), (0, 0, 0.3), root)
    return root


def oldline_vault_4m_soot(M):
    """Вариант зала старой линии: закопчённый кирпич, мох, грунтовый пол."""
    from assets import oldline_vault_4m
    root = oldline_vault_4m(M)
    root.name = "OldLineVault4mSoot"
    for n, m in (("WallL", "brick_soot"), ("WallR", "brick_moss"), ("Vault", "brick_soot"), ("Floor", "dirt")):
        bpy.data.objects[n].data.materials[0] = M[m]
    plane_fit("Puddle", 1.3, 0.9, M["puddle"], root, (1.4, 2.6, 0.004), "Z")
    return root


ASSETS_EXTRA = [
    ("common", "fire_extinguisher", fire_extinguisher),
    ("common", "fuel_canister", fuel_canister),
    ("common", "fuel_barrel", fuel_barrel),
    ("common", "cable_drum", cable_drum),
    ("common", "pipe_run_4m", pipe_run_4m),
    ("common", "hermetic_door", hermetic_door),
    ("common", "danger_sign", danger_sign),
    ("common", "wooden_pallet", wooden_pallet),
    ("common", "puddle_decal", puddle_decal),
    ("common", "wall_poster_safety", wall_poster_safety),
    ("common", "wall_poster_schedule", wall_poster_schedule),
    ("common", "line_scheme_board", line_scheme_board),
    ("01_duty_room", "field_telephone", field_telephone),
    ("01_duty_room", "shelf_rack", shelf_rack),
    ("01_duty_room", "cot", cot),
    ("01_duty_room", "wall_clock", wall_clock),
    ("01_duty_room", "first_aid_box", first_aid_box),
    ("01_duty_room", "stove_kettle", electric_stove_kettle),
    ("01_duty_room", "ceiling_dome_lamp", ceiling_dome_lamp),
    ("01_duty_room", "room_ceiling_4x4", room_ceiling_4x4),
    ("02_shaft", "shaft_landing_grate", shaft_landing_grate),
    ("02_shaft", "shaft_bottom_exit", shaft_bottom_exit),
    ("03_platform", "platform_barrier", platform_barrier),
    ("03_platform", "tool_board", tool_board),
    ("03_platform", "buffer_stop", buffer_stop),
    ("03_platform", "platform_section_4m_column", platform_section_4m_column),
    ("04_cast_iron_tunnel", "tunnel_signal", tunnel_signal),
    ("04_cast_iron_tunnel", "tunnel_section_4m_niche", tunnel_section_4m_niche),
    ("04_cast_iron_tunnel", "tunnel_section_4m_rusty", tunnel_section_4m_rusty),
    ("04_cast_iron_tunnel", "service_door_metal", service_door_metal),
    ("05_service_room", "iron_bed", iron_bed),
    ("05_service_room", "small_table", small_table),
    ("05_service_room", "stool", stool),
    ("05_service_room", "bucket", bucket),
    ("05_service_room", "wall_shelf", wall_shelf),
    ("05_service_room", "remains_bedding", remains_blanket),
    ("06_old_line", "wooden_barrel", wooden_barrel),
    ("06_old_line", "switch_lever", switch_lever),
    ("06_old_line", "oldline_arch_passage", oldline_arch_passage),
    ("06_old_line", "oldline_stairs", oldline_stairs),
    ("06_old_line", "iron_grate_door", iron_grate_door),
    ("06_old_line", "handcar_wreck", handcar_wreck),
    ("06_old_line", "oldline_vault_4m_soot", oldline_vault_4m_soot),
]
