"""Ассеты локаций Hope Light. Каждая функция строит ассет под корневым Empty и возвращает его."""
import math
import random
import bmesh
from mathutils import Matrix, Vector
from lib import *

RAIL_GAUGE = 1.0      # между осями рельсов, м (узкая служебная колея)
RAIL_TOP = 0.22       # высота головки рельса над полом в путевых секциях
SEG = 4.0             # длина модульной секции, м

# Чугунный тоннель
T_RIN, T_RSKIN, T_CZ = 2.75, 2.95, 1.75


def box_uv_fit(o):
    s = o.dimensions
    box_uv(o, (max(s.x, s.y), s.z) if s.z > 0.01 else (s.x, s.y), fit=True)
    return o


def rot_y(a):
    return Matrix.Rotation(a, 4, "Y")


def rot_z(a):
    return Matrix.Rotation(a, 4, "Z")


def rot_x(a):
    return Matrix.Rotation(a, 4, "X")


def light_point(root, loc, name="LightPoint"):
    """Маркер для OmniLight3D/SpotLight3D в Godot."""
    return empty(name, root, loc)


# ======================================================================= ОБЩЕЕ
def bm_track(bm_rail, bm_sleep, bm_ballast, length=SEG, x0=0.0, z0=0.0, sleeper_step=0.5, ballast=True):
    for s in (-1, 1):
        x = x0 + s * RAIL_GAUGE / 2
        bm_box(bm_rail, (0.07, length, 0.04), (x, length / 2, z0 + RAIL_TOP - 0.02))   # головка
        bm_box(bm_rail, (0.02, length, 0.07), (x, length / 2, z0 + RAIL_TOP - 0.075))  # шейка
        bm_box(bm_rail, (0.12, length, 0.02), (x, length / 2, z0 + RAIL_TOP - 0.12))   # подошва
    n = int(round(length / sleeper_step))
    for i in range(n):
        bm_box(bm_sleep, (RAIL_GAUGE + 0.6, 0.18, 0.1), (x0, sleeper_step * (i + 0.5), z0 + 0.05))
    if ballast:
        bm_box(bm_ballast, (RAIL_GAUGE + 1.0, length, 0.06), (x0, length / 2, z0 + 0.03))


def track_straight_4m(M):
    root = empty("TrackStraight4m")
    br, bs, bb = bmesh.new(), bmesh.new(), bmesh.new()
    bm_track(br, bs, bb)
    mesh_from_bm(br, "Rails", M["dark"], root)
    mesh_from_bm(bs, "Sleepers", M["wood"], root)
    mesh_from_bm(bb, "Ballast", M["gravel"], root)
    col_box("Track", (RAIL_GAUGE + 1.0, SEG, RAIL_TOP), (0, SEG / 2, RAIL_TOP / 2), root)
    return root


def bm_cables(bm, length, pts, r=0.022):
    for (x, z) in pts:
        bm_cyl(bm, r, length, (x, length / 2, z), "Y", seg=6)


def cable_run_4m(M):
    """Три кабеля на кронштейнах вдоль стены. Стена — плоскость x=0, кабели в +X."""
    root = empty("CableRun4m")
    bc, bb = bmesh.new(), bmesh.new()
    bm_cables(bc, SEG, [(0.08, 0.0), (0.08, 0.12), (0.08, 0.24)])
    for i in range(4):
        y = 0.5 + i
        bm_box(bb, (0.14, 0.04, 0.02), (0.07, y, -0.03))
        bm_box(bb, (0.14, 0.04, 0.02), (0.07, y, 0.09))
        bm_box(bb, (0.14, 0.04, 0.02), (0.07, y, 0.21))
        bm_box(bb, (0.02, 0.06, 0.34), (0.01, y, 0.1))
    mesh_from_bm(bc, "Cables", M["rubber"], root)
    mesh_from_bm(bb, "Brackets", M["dark"], root)
    return root


def wall_lamp_caged(M):
    """Лампа в сетке (тоннельный светильник). Крепится к стене, светит в -Y."""
    root = empty("WallLampCaged")
    boxes("Base", [((0.22, 0.05, 0.22), (0, -0.025, 0))], M["dark"], root)
    cyl("Glass", 0.08, 0.1, (0, -0.1, 0), "Y", 10, M["lamp"], root)
    bm = bmesh.new()
    for k in range(4):
        a = k * math.pi / 4
        bm_box(bm, (0.012, 0.14, 0.012), (0.1 * math.cos(a), -0.1, 0.1 * math.sin(a)))
        bm_box(bm, (0.012, 0.14, 0.012), (-0.1 * math.cos(a), -0.1, -0.1 * math.sin(a)))
    bm_ring(bm, 0.095, 0.105, 0, 2 * math.pi, -0.17, -0.16, 12)
    bm_ring(bm, 0.095, 0.105, 0, 2 * math.pi, -0.08, -0.07, 12)
    mesh_from_bm(bm, "Cage", M["dark"], root)
    light_point(root, (0, -0.25, 0))
    return root


def junction_box(M):
    root = empty("JunctionBox")
    box("Box", (0.3, 0.12, 0.4), (0, -0.06, 0), M["metal_green" if False else "green"], root)
    boxes("Details", [((0.04, 0.04, 0.4), (0, -0.04, 0.38)), ((0.26, 0.01, 0.02), (0, -0.125, 0.12)),
                      ((0.03, 0.02, 0.03), (0.1, -0.13, -0.15))], M["dark"], root)
    box("Warning", (0.08, 0.005, 0.06), (0, -0.123, 0.05), M["red"], root, uv=None)
    return root


# ======================================================================= ДЕЖУРКА
def room_wall_4m(M):
    """Стена 4×3 м, двухцветная казённая покраска. Лицевая сторона в -Y."""
    root = empty("RoomWall4m")
    box("Wall", (4.0, 0.15, 3.0), (0, 0.075, 1.5), M["wall"], root, uv=(1.5, 3.0))
    box("Baseboard", (4.0, 0.02, 0.1), (0, -0.01, 0.05), M["wood"], root)
    col_box("Wall", (4.0, 0.15, 3.0), (0, 0.075, 1.5), root)
    return root


def room_wall_door_4m(M):
    root = empty("RoomWallDoor4m")
    dw, dh = 0.9, 2.1
    side = (4.0 - dw) / 2
    w = boxes("Wall", [((side, 0.15, 3.0), (-2 + side / 2, 0.075, 1.5)),
                       ((side, 0.15, 3.0), (2 - side / 2, 0.075, 1.5)),
                       ((dw, 0.15, 3.0 - dh), (0, 0.075, dh + (3.0 - dh) / 2))], M["wall"], root, uv=(1.5, 3.0))
    boxes("Frame", [((0.06, 0.2, dh), (-dw / 2 - 0.03, 0.075, dh / 2)), ((0.06, 0.2, dh), (dw / 2 + 0.03, 0.075, dh / 2)),
                    ((dw + 0.12, 0.2, 0.06), (0, 0.075, dh + 0.03))], M["wood"], root)
    # Дверь: origin на петле, открывается вращением вокруг Z
    door = empty("Door", root, (-dw / 2, 0.02, 0))
    box("DoorLeaf", (dw - 0.02, 0.04, dh - 0.02), (dw / 2, 0, dh / 2), M["green"], door)
    boxes("Handle", [((0.12, 0.02, 0.02), (dw - 0.12, -0.04, 1.0)), ((0.02, 0.04, 0.02), (dw - 0.07, -0.025, 1.0))],
          M["steel"], door, uv=None)
    col_box("DoorLeaf", (dw - 0.02, 0.04, dh - 0.02), (dw / 2, 0, dh / 2), door)
    col_box("WallL", (side, 0.15, 3.0), (-2 + side / 2, 0.075, 1.5), root)
    col_box("WallR", (side, 0.15, 3.0), (2 - side / 2, 0.075, 1.5), root)
    col_box("Lintel", (dw, 0.15, 3.0 - dh), (0, 0.075, dh + (3.0 - dh) / 2), root)
    return root


def room_floor_4x4(M):
    root = empty("RoomFloor4x4")
    box("Floor", (4, 4, 0.05), (0, 0, -0.025), M["lino"], root, uv=1.0)
    col_box("Floor", (4, 4, 0.05), (0, 0, -0.025), root)
    return root


def floor_hatch(M):
    """Люк в полу дежурки над шахтой. Крышка — узел Lid с origin на петле (ось X), открыта на ~110°."""
    root = empty("FloorHatch")
    o, i = 1.1, 0.8
    t = (o - i) / 2
    boxes("Frame", [((o, t, 0.06), (0, (i + t) / 2, 0.03)), ((o, t, 0.06), (0, -(i + t) / 2, 0.03)),
                    ((t, i, 0.06), ((i + t) / 2, 0, 0.03)), ((t, i, 0.06), (-(i + t) / 2, 0, 0.03))], M["dark"], root)
    # горловина вниз
    bm = bmesh.new()
    for (sx, sy, x, y) in ((i, 0.1, 0, i / 2 + 0.05), (i, 0.1, 0, -i / 2 - 0.05), (0.1, i, i / 2 + 0.05, 0), (0.1, i, -i / 2 - 0.05, 0)):
        bm_box(bm, (sx, sy, 1.0), (x, y, -0.5))
    mesh_from_bm(bm, "Throat", M["concrete"], root)
    # верхние скобы лестницы
    bm = bmesh.new()
    for k in range(3):
        z = -0.25 - k * 0.3
        bm_box(bm, (0.4, 0.025, 0.025), (0, -i / 2 + 0.15, z))
        bm_box(bm, (0.025, 0.15, 0.025), (-0.2, -i / 2 + 0.075, z))
        bm_box(bm, (0.025, 0.15, 0.025), (0.2, -i / 2 + 0.075, z))
    mesh_from_bm(bm, "Rungs", M["steel"], root, uv=None)
    lid = empty("Lid", root, (0, i / 2, 0.06))
    lid.rotation_euler = (math.radians(-110), 0, 0)
    box("LidPlate", (i - 0.02, i - 0.02, 0.04), (0, -i / 2, 0.02), M["green"], lid)
    boxes("LidRibs", [((0.04, i - 0.1, 0.03), (-0.2, -i / 2, -0.015)), ((0.04, i - 0.1, 0.03), (0.2, -i / 2, -0.015))],
          M["dark"], lid)
    boxes("LidHandle", [((0.16, 0.02, 0.02), (0, -i + 0.1, 0.07)), ((0.02, 0.02, 0.05), (-0.07, -i + 0.1, 0.045)),
                        ((0.02, 0.02, 0.05), (0.07, -i + 0.1, 0.045))], M["steel"], lid, uv=None)
    col_box("Lid", (i - 0.02, i - 0.02, 0.04), (0, -i / 2, 0.02), lid)
    light_point(root, (0, 0, -0.6), "LadderTop")
    return root


def desk(M):
    root = empty("Desk")
    boxes("Top", [((1.2, 0.7, 0.04), (0, 0, 0.73))], M["wood"], root)
    legs = [((0.05, 0.05, 0.71), (sx * 0.55, sy * 0.3, 0.355)) for sx in (-1, 1) for sy in (-1, 1)]
    boxes("Legs", legs + [((1.1, 0.03, 0.1), (0, 0.3, 0.62))], M["wood"], root)
    boxes("Drawer", [((0.4, 0.62, 0.16), (0.33, 0, 0.62))], M["wood"], root)
    box("DrawerKnob", (0.04, 0.02, 0.02), (0.33, -0.32, 0.62), M["brass"], root, uv=None)
    col_box("Desk", (1.2, 0.7, 0.75), (0, 0, 0.375), root)
    return root


def chair(M):
    root = empty("Chair")
    boxes("Seat", [((0.42, 0.42, 0.03), (0, 0, 0.45)), ((0.42, 0.03, 0.35), (0, 0.2, 0.75))], M["wood"], root)
    boxes("Frame", [((0.03, 0.03, 0.45), (sx * 0.19, sy * 0.19, 0.225)) for sx in (-1, 1) for sy in (-1, 1)]
          + [((0.03, 0.03, 0.4), (sx * 0.19, 0.2, 0.65)) for sx in (-1, 1)], M["dark"], root)
    col_box("Chair", (0.42, 0.42, 0.95), (0, 0, 0.475), root)
    return root


def weapon_crate(M):
    """Оружейный ящик; крышка Lid на петле по задней кромке."""
    root = empty("WeaponCrate")
    L, W, H = 1.0, 0.45, 0.36
    bm = bmesh.new()
    th = 0.025
    for (s, l) in [((L, th, H), (0, W / 2 - th / 2, H / 2)), ((L, th, H), (0, -W / 2 + th / 2, H / 2)),
                   ((th, W, H), (L / 2 - th / 2, 0, H / 2)), ((th, W, H), (-L / 2 + th / 2, 0, H / 2)),
                   ((L, W, th), (0, 0, th / 2))]:
        bm_box(bm, s, l)
    mesh_from_bm(bm, "Body", M["wood"], root)
    bm = bmesh.new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            bm_box(bm, (0.05, 0.05, H + 0.01), (sx * (L / 2 - 0.02), sy * (W / 2 - 0.02), H / 2))
    for sx in (-1, 1):
        bm_box(bm, (0.03, 0.12, 0.04), (sx * (L / 2 + 0.015), 0, H * 0.7))
    mesh_from_bm(bm, "Corners", M["dark"], root)
    text_mesh("Stencil", "ОП-7", 0.08, (0, -W / 2 - 0.002, H * 0.5), M["chalk"], root, 0.001)
    lid = empty("Lid", root, (0, W / 2, H))
    lid.rotation_euler = (math.radians(-12), 0, 0)
    box("LidBoard", (L, W, 0.03), (0, -W / 2, 0.015), M["wood"], lid)
    box("Latch", (0.06, 0.02, 0.06), (0, -W - 0.005, -0.01), M["steel"], lid, uv=None)
    col_box("Crate", (L, W, H), (0, 0, H / 2), root)
    return root


def locker(M):
    """Шкафчик с фото на дверце. Дверь Door на петле (левая кромка), фото — узел Photo (замените текстуру)."""
    root = empty("Locker")
    w, d, h = 0.5, 0.5, 1.85
    th = 0.02
    bm = bmesh.new()
    for (s, l) in [((th, d, h), (-w / 2 + th / 2, 0, h / 2)), ((th, d, h), (w / 2 - th / 2, 0, h / 2)),
                   ((w, th, h), (0, d / 2 - th / 2, h / 2)), ((w, d, th), (0, 0, th / 2 + 0.08)),
                   ((w, d, th), (0, 0, h - th / 2)), ((w, d, th), (0, 0, 1.55)), ((w, d, 0.08), (0, 0, 0.04))]:
        bm_box(bm, s, l)
    mesh_from_bm(bm, "Body", M["green"], root)
    door = empty("Door", root, (-w / 2, -d / 2, 0.08))
    door.rotation_euler = (0, 0, math.radians(-8))
    box("DoorLeaf", (w, 0.02, h - 0.08), (w / 2, -0.01, (h - 0.08) / 2), M["green"], door)
    bm = bmesh.new()
    for k in range(5):
        bm_box(bm, (0.24, 0.004, 0.012), (w / 2, -0.022, 1.45 + k * 0.035))
    mesh_from_bm(bm, "Vents", M["ink"], door, uv=None)
    box("Handle", (0.02, 0.03, 0.12), (w - 0.06, -0.035, 0.9), M["steel"], door, uv=None)
    box_uv_fit(box("Photo", (0.1, 0.003, 0.14), (w / 2 - 0.05, -0.022, 1.2), M["paper"], door, uv=0.15))
    box("Tape", (0.04, 0.004, 0.012), (w / 2 - 0.05, -0.023, 1.27), M["glass"], door, uv=None)
    col_box("Locker", (w, d, h), (0, 0, h / 2), root)
    return root


def letter(M):
    root = empty("Letter")
    box_uv_fit(box("Sheet", (0.21, 0.297, 0.002), (0, 0, 0.001), M["paper"], root, uv=(0.21, 0.297)))
    col_box("Letter", (0.21, 0.297, 0.01), (0, 0, 0.005), root)
    return root


# ======================================================================= ШАХТА
def bm_hoop(bm, cx, cy, z, r, a0, a1, seg, thick=0.012, height=0.04):
    for k in range(seg):
        a = a0 + (a1 - a0) * (k + 0.5) / seg
        ln = 2 * r * math.sin(abs(a1 - a0) / seg / 2) + 0.004
        bm_box(bm, (ln, thick, height), (cx + r * math.cos(a), cy + r * math.sin(a), z), rot_z(a + math.pi / 2))


def shaft_segment_2m(M):
    """Сегмент вертикальной шахты 2 м: бетонное кольцо, скобы, дуги ограждения, кабели. Стыкуется по Z."""
    root = empty("ShaftSegment2m")
    R = 1.4
    # кольцо шахты в плоскости XY: строим в XZ и поворачиваем
    bm = bmesh.new()
    bm_ring(bm, R, R + 0.2, 0, 2 * math.pi, 0, 2.0, 20, inner=True, outer=False, sides=False)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=rot_x(math.pi / 2))
    mesh_from_bm(bm, "ShaftWall", M["concrete"], root)
    # скобы (U) на стене -Y
    wy = -R
    bm = bmesh.new()
    for k in range(8):
        z = 0.125 + k * 0.25
        bm_box(bm, (0.4, 0.022, 0.022), (0, wy + 0.16, z))
        bm_box(bm, (0.022, 0.18, 0.022), (-0.2, wy + 0.08, z))
        bm_box(bm, (0.022, 0.18, 0.022), (0.2, wy + 0.08, z))
    mesh_from_bm(bm, "Rungs", M["steel"], root, uv=None)
    # дуги ограждения + вертикальные полосы
    bm = bmesh.new()
    hr, hcy = 0.38, wy + 0.55
    for z in (0.5, 1.5):
        bm_hoop(bm, 0, hcy, z, hr, math.radians(-40), math.radians(220), 14)
        for s in (-1, 1):
            bm_box(bm, (0.04, 0.3, 0.012), (s * 0.29, wy + 0.15 + 0.05, z))
    for a in (-20, 30, 90, 150, 200):
        ar = math.radians(a)
        bm_box(bm, (0.035, 0.012, 2.0), (hr * math.cos(ar), hcy + hr * math.sin(ar), 1.0), rot_z(ar + math.pi / 2))
    mesh_from_bm(bm, "CageHoops", M["dark"], root, uv=None)
    # кабели по стене
    bm = bmesh.new()
    for k, a in enumerate((25, 32, 39)):
        ar = math.radians(a)
        bm_cyl(bm, 0.02, 2.0, ((R - 0.06) * math.cos(ar), (R - 0.06) * math.sin(ar), 1.0), "Z", 6)
    mesh_from_bm(bm, "Cables", M["rubber"], root)
    # коллизия: внутренняя поверхность
    bm = bmesh.new()
    bm_ring(bm, R, R + 0.2, 0, 2 * math.pi, 0, 2.0, 12, inner=True, outer=False, sides=False)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=rot_x(math.pi / 2))
    col_mesh("ShaftWall", bm, root)
    return root


# ======================================================================= ПЛАТФОРМА
def platform_section_4m(M):
    """Станция на одну вагонетку: путь слева (пол пути −1.1 м), платформа справа (z=0), плитка, свод."""
    root = empty("PlatformSection4m")
    tz = -1.1
    box("WallTileL", (0.1, SEG, 3.0 - tz), (-3.65, SEG / 2, (3.0 + tz) / 2), M["tile"], root)
    box("WallTileR", (0.1, SEG, 3.0), (3.65, SEG / 2, 1.5), M["tile"], root)
    bm = bmesh.new()
    bm_ring(bm, 3.6, 3.8, 0, math.pi, 0, SEG, 24, cz=3.0)
    mesh_from_bm(bm, "Vault", M["concrete"], root, uv=2.0)
    box("PlatformSlab", (4.8, SEG, -tz), (1.2, SEG / 2, tz / 2), M["concrete"], root)
    box("EdgeCoping", (0.35, SEG, 0.04), (-1.02, SEG / 2, 0.02), M["tile"], root, uv=0.5)
    box("TrackFloor", (2.4, SEG, 0.1), (-2.4, SEG / 2, tz - 0.05), M["gravel"], root)
    br, bs, bb = bmesh.new(), bmesh.new(), bmesh.new()
    bm_track(br, bs, bb, x0=-2.4, z0=tz, ballast=False)
    mesh_from_bm(br, "Rails", M["dark"], root)
    mesh_from_bm(bs, "Sleepers", M["wood"], root)
    bc = bmesh.new()
    bm_cables(bc, SEG, [(-3.55, 1.8), (-3.55, 1.92), (3.55, 2.4)])
    mesh_from_bm(bc, "Cables", M["rubber"], root)
    col_box("WallL", (0.1, SEG, 3.0 - tz), (-3.65, SEG / 2, (3.0 + tz) / 2), root)
    col_box("WallR", (0.1, SEG, 3.0), (3.65, SEG / 2, 1.5), root)
    col_box("Slab", (4.8, SEG, -tz), (1.2, SEG / 2, tz / 2), root)
    col_box("TrackFloor", (2.4, SEG, 0.1), (-2.4, SEG / 2, tz - 0.05), root)
    bm = bmesh.new()
    bm_ring(bm, 3.6, 3.8, 0, math.pi, 0, SEG, 10, cz=3.0, outer=False, sides=False, ends=False)
    col_mesh("Vault", bm, root)
    return root


def platform_end_wall(M):
    """Торцевая стена станции с порталом тоннеля (под ширину платформенной секции)."""
    root = empty("PlatformEndWall")
    zb, top, x0, x1 = -1.1, 6.8, -3.7, 3.7
    pl, pr = -3.55, -1.25                   # портал над путём
    pc, r = (pl + pr) / 2, (pr - pl) / 2
    spring = zb + 2.1
    faces = [[(x0, zb), (pl, zb), (pl, spring), (x0, spring)],
             [(pr, zb), (x1, zb), (x1, top), (pr, top), (pr, spring)],
             [(x0, spring), (pl, spring), (pl, top), (x0, top)]]
    seg = 16
    for k in range(seg):
        a0, a1 = math.pi - math.pi * k / seg, math.pi - math.pi * (k + 1) / seg
        p0 = (pc + r * math.cos(a0), spring + r * math.sin(a0))
        p1 = (pc + r * math.cos(a1), spring + r * math.sin(a1))
        faces.append([p0, p1, (p1[0], top), (p0[0], top)])
    bm = bmesh.new()
    bm_poly_extrude(bm, faces, -0.3, 0.0)
    mesh_from_bm(bm, "EndWall", M["tile"], root)
    col_box("EndWallR", (x1 - pr, 0.3, top - zb), ((x1 + pr) / 2, -0.15, (top + zb) / 2), root)
    col_box("EndWallTop", (pr - x0, 0.3, top - spring - r), ((pr + x0) / 2, -0.15, (top + spring + r) / 2), root)
    col_box("EndWallL", (pl - x0, 0.3, top - zb), ((pl + x0) / 2, -0.15, (top + zb) / 2), root)
    return root


def hanging_lamp(M):
    """Подвесная лампа. Origin — точка крепления к своду; лампа на 1 м ниже."""
    root = empty("HangingLamp")
    cyl("Rod", 0.012, 0.9, (0, 0, -0.45), "Z", 6, M["dark"], root, uv=None)
    cyl("Shade", 0.06, 0.18, (0, 0, -0.98), "Z", 14, M["green"], root, r2=0.0, cap=True)
    bm = bmesh.new()
    bm_cyl(bm, 0.28, 0.14, (0, 0, -1.0), "Z", 16, r2=0.06, cap=False)
    mesh_from_bm(bm, "ShadeCone", M["green"], root)
    cyl("Bulb", 0.05, 0.08, (0, 0, -1.08), "Z", 10, M["lamp"], root, uv=None)
    light_point(root, (0, 0, -1.12))
    return root


def diesel_generator(M):
    """Старый дизель-генератор: без него лампы в тоннелях не горят. Origin — центр основания."""
    root = empty("DieselGenerator")
    boxes("Skid", [((1.7, 0.08, 0.12), (0, 0.32, 0.06)), ((1.7, 0.08, 0.12), (0, -0.32, 0.06)),
                   ((0.08, 0.72, 0.1), (-0.8, 0, 0.05)), ((0.08, 0.72, 0.1), (0.8, 0, 0.05))], M["dark"], root)
    box("Engine", (0.75, 0.55, 0.55), (-0.25, 0, 0.42), M["green"], root)
    box("Head", (0.6, 0.45, 0.16), (-0.25, 0, 0.77), M["green"], root)
    bm = bmesh.new()
    for k in range(4):
        bm_box(bm, (0.06, 0.47, 0.03), (-0.46 + k * 0.14, 0, 0.865))
    mesh_from_bm(bm, "ValveCovers", M["dark"], root)
    box("Radiator", (0.12, 0.7, 0.75), (-0.72, 0, 0.5), M["dark"], root)
    bm = bmesh.new()
    for k in range(10):
        bm_box(bm, (0.01, 0.62, 0.02), (-0.785, 0, 0.18 + k * 0.065))
    mesh_from_bm(bm, "Grille", M["steel"], root, uv=None)
    cyl("Flywheel", 0.3, 0.08, (0.17, 0, 0.42), "X", 18, M["dark"], root)
    cyl("Alternator", 0.25, 0.5, (0.47, 0, 0.42), "X", 16, M["green"], root)
    cyl("FuelTank", 0.17, 0.75, (-0.15, 0.15, 1.05), "X", 12, M["red"], root)
    cyl("FuelCap", 0.04, 0.05, (0.0, 0.15, 1.23), "Z", 8, M["dark"], root, uv=None)
    bm = bmesh.new()
    bm_cyl(bm, 0.04, 0.55, (-0.4, -0.18, 1.1), "Z", 8)
    bm_cyl(bm, 0.05, 0.08, (-0.4, -0.18, 1.4), "Z", 8)
    mesh_from_bm(bm, "Exhaust", M["iron"], root)
    box("ControlBox", (0.3, 0.12, 0.3), (0.45, -0.3, 0.85), M["green"], root)
    cyl("StartButton", 0.025, 0.03, (0.4, -0.37, 0.88), "Y", 8, M["red"], root, uv=None)
    cyl("Gauge", 0.04, 0.02, (0.5, -0.37, 0.88), "Y", 10, M["glass"], root, uv=None)
    light_point(root, (-0.4, -0.18, 1.45), "ExhaustPoint")
    col_box("Generator", (1.7, 0.75, 1.3), (0, 0, 0.65), root)
    return root


def mine_cart(M):
    """Вагонетка. Origin — уровень головки рельса, по центру колеи (колея 1.0 м)."""
    root = empty("MineCart")
    wr = 0.17
    bm = bmesh.new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            bm_cyl(bm, wr, 0.06, (sx * RAIL_GAUGE / 2, sy * 0.38, wr), "X", 14)
            bm_cyl(bm, wr + 0.02, 0.015, (sx * (RAIL_GAUGE / 2 - 0.035), sy * 0.38, wr), "X", 14)
    mesh_from_bm(bm, "Wheels", M["dark"], root)
    bm = bmesh.new()
    for sy in (-1, 1):
        bm_cyl(bm, 0.03, RAIL_GAUGE + 0.08, (0, sy * 0.38, wr), "X", 8)
    bm_box(bm, (0.08, 1.3, 0.1), (-0.4, 0, wr + 0.1))
    bm_box(bm, (0.08, 1.3, 0.1), (0.4, 0, wr + 0.1))
    for sy in (-1, 1):
        bm_box(bm, (0.12, 0.2, 0.06), (0, sy * 0.72, wr + 0.12))
        bm_cyl(bm, 0.04, 0.08, (0, sy * 0.84, wr + 0.12), "Y", 8)
    mesh_from_bm(bm, "Frame", M["iron"], root)
    # ковш: трапеция без верха + толщина
    bm = bmesh.new()
    z0, z1 = wr + 0.15, wr + 0.75
    b = [(-0.45, -0.6), (0.45, -0.6), (0.45, 0.6), (-0.45, 0.6)]
    t = [(-0.56, -0.74), (0.56, -0.74), (0.56, 0.74), (-0.56, 0.74)]
    vb = [bm.verts.new((x, y, z0)) for x, y in b]
    vt = [bm.verts.new((x, y, z1)) for x, y in t]
    bm.faces.new(vb[::-1])
    for k in range(4):
        bm.faces.new((vb[k], vb[(k + 1) % 4], vt[(k + 1) % 4], vt[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.03)
    mesh_from_bm(bm, "Bucket", M["iron"], root, uv=0.6)
    bm = bmesh.new()
    for x, y, sx, sy in ((0, -0.745, 1.14, 0.04), (0, 0.745, 1.14, 0.04), (-0.565, 0, 0.04, 1.5), (0.565, 0, 0.04, 1.5)):
        bm_box(bm, (sx, sy, 0.05), (x, y, z1 - 0.02))
    mesh_from_bm(bm, "Rim", M["dark"], root)
    col_box("Cart", (1.14, 1.5, z1), (0, 0, z1 / 2), root)
    return root


def station_sign(M, text="ТИХАЯ", name="StationSign"):
    """Табличка станции. Лицевая сторона в -Y (Godot +Z), origin — центр задней грани (к стене)."""
    root = empty(name)
    box_uv_fit(box("Plate", (1.6, 0.03, 0.42), (0, -0.015, 0), M["sign"], root, uv=(1.6, 0.42)))
    text_mesh("Text", text, 0.26, (0, -0.032, -0.01), M["ink"], root, 0.003)
    col_box(name, (1.6, 0.03, 0.42), (0, -0.015, 0), root)
    return root


def bench(M):
    root = empty("Bench")
    bm = bmesh.new()
    for k in range(3):
        bm_box(bm, (1.6, 0.1, 0.03), (0, -0.12 + k * 0.12, 0.45))
    for k in range(2):
        bm_box(bm, (1.6, 0.025, 0.1), (0, 0.2, 0.62 + k * 0.14))
    mesh_from_bm(bm, "Slats", M["wood"], root)
    bm = bmesh.new()
    for sx in (-0.65, 0.65):
        bm_box(bm, (0.04, 0.35, 0.04), (sx, 0, 0.42))
        bm_box(bm, (0.04, 0.04, 0.44), (sx, -0.15, 0.22))
        bm_box(bm, (0.04, 0.04, 0.85), (sx, 0.18, 0.42), rot_x(math.radians(-6)))
    mesh_from_bm(bm, "Legs", M["dark"], root, uv=None)
    col_box("Bench", (1.6, 0.45, 0.85), (0, 0.02, 0.42), root)
    return root


# ======================================================================= ЧУГУННЫЙ ТОННЕЛЬ
def bm_tubing_ring(bm, y0, gaps=()):
    """Кольцо чугунных тюбингов шириной 1 м: оболочка, кольцевые фланцы, радиальные рёбра, болты.
    gaps — список (a0, a1) в градусах, где кольцо выбито (пролом)."""
    def arcs():
        cuts = sorted((math.radians(a), math.radians(b)) for a, b in gaps)
        a = -math.pi / 2
        out = []
        for c0, c1 in cuts:
            out.append((a, c0))
            a = c1
        out.append((a, 3 * math.pi / 2))
        return [(p, q) for p, q in out if q - p > 1e-3]

    def in_gap(a):
        d = math.degrees(a)
        d = (d + 90) % 360 - 90
        return any(g0 <= d <= g1 for g0, g1 in gaps)

    for a0, a1 in arcs():
        seg = max(2, int(32 * (a1 - a0) / (2 * math.pi)))
        bm_ring(bm, T_RSKIN, T_RSKIN + 0.04, a0, a1, y0, y0 + 1.0, seg, cz=T_CZ, sides=False)
        bm_ring(bm, T_RIN, T_RSKIN, a0, a1, y0, y0 + 0.045, seg, cz=T_CZ)
        bm_ring(bm, T_RIN, T_RSKIN, a0, a1, y0 + 0.955, y0 + 1.0, seg, cz=T_CZ)
    for k in range(10):
        a = k * 2 * math.pi / 10 + 0.1
        if in_gap(a):
            continue
        r = (T_RIN + T_RSKIN) / 2
        bm_box(bm, (T_RSKIN - T_RIN, 0.91, 0.04), (r * math.cos(a), y0 + 0.5, T_CZ + r * math.sin(a)), rot_y(-a))
    for k in range(30):
        a = (k + 0.5) * 2 * math.pi / 30
        if in_gap(a):
            continue
        r = T_RIN + 0.07
        for yy in (y0 + 0.07, y0 + 0.93):
            bm_cyl(bm, 0.022, 0.05, (r * math.cos(a), yy, T_CZ + r * math.sin(a)), "Y", 6)


def tubing_ring_1m(M):
    root = empty("TubingRing1m")
    bm = bmesh.new()
    bm_tubing_ring(bm, 0.0)
    mesh_from_bm(bm, "Ring", M["iron"], root)
    bm = bmesh.new()
    bm_ring(bm, T_RIN, T_RIN + 0.1, 0, 2 * math.pi, 0, 1.0, 16, cz=T_CZ, outer=False, sides=False)
    col_mesh("Ring", bm, root)
    return root


def tunnel_section(M, name, breach=False):
    root = empty(name)
    bm = bmesh.new()
    for i in range(4):
        gaps = [(-28, 30)] if breach and i in (1, 2) else ()
        bm_tubing_ring(bm, float(i), gaps)
    mesh_from_bm(bm, "TubingRings", M["iron"], root)
    hw = math.sqrt(T_RIN ** 2 - T_CZ ** 2)
    box("TrackBed", (2 * hw + 0.4, SEG, 0.8), (0, SEG / 2, -0.4), M["concrete"], root)
    br, bs, bb = bmesh.new(), bmesh.new(), bmesh.new()
    bm_track(br, bs, bb)
    mesh_from_bm(br, "Rails", M["dark"], root)
    mesh_from_bm(bs, "Sleepers", M["wood"], root)
    mesh_from_bm(bb, "Ballast", M["gravel"], root)
    # кабели на кронштейнах по левой стене
    bc, bk = bmesh.new(), bmesh.new()
    pts = []
    for k, z in enumerate((1.25, 1.4, 1.55)):
        x = -math.sqrt(T_RIN ** 2 - (z - T_CZ) ** 2) + 0.12
        pts.append((x, z))
    bm_cables(bc, SEG, pts)
    for i in range(4):
        y = 0.5 + i
        for (x, z) in pts:
            bm_box(bk, (0.18, 0.04, 0.02), (x - 0.05, y, z - 0.03))
    mesh_from_bm(bc, "Cables", M["rubber"], root)
    mesh_from_bm(bk, "Brackets", M["dark"], root)
    if breach:
        # выломанные тюбинги и кирпич из-за пролома
        rnd = random.Random(3)
        bm = bmesh.new()
        for k in range(6):
            bm_box(bm, (0.6 + rnd.random() * 0.4, 0.25, 0.9), (1.4 + rnd.random() * 0.6, 1.1 + k * 0.32, 0.15),
                   Matrix.Rotation(rnd.uniform(-1.3, -0.3), 4, "Y") @ rot_z(rnd.uniform(-0.4, 0.4)))
        mesh_from_bm(bm, "FallenPlates", M["iron"], root)
        bm = bmesh.new()
        for k in range(18):
            bm_box(bm, (0.25, 0.12, 0.065), (2.0 + rnd.random() * 0.6, 1.0 + rnd.random() * 2.0, 0.04 + rnd.random() * 0.3),
                   rot_z(rnd.random() * 3) @ rot_y(rnd.random()))
        mesh_from_bm(bm, "Bricks", M["brick"], root, uv=0.5)
        # кирпичная кладка старой линии видна в проломе
        bm = bmesh.new()
        bm_ring(bm, T_RSKIN + 0.4, T_RSKIN + 0.9, math.radians(-30), math.radians(32), 0.9, 3.1, 6, cz=T_CZ)
        mesh_from_bm(bm, "OldBrickBehind", M["brick"], root)
        light_point(root, (2.6, 2.0, 1.2), "BreachPoint")
    # коллизия
    bm = bmesh.new()
    if breach:
        bm_ring(bm, T_RIN, T_RIN + 0.1, math.radians(30), math.radians(332), 0, SEG, 14, cz=T_CZ, outer=False, sides=False, ends=False)
        bm_ring(bm, T_RIN, T_RIN + 0.1, math.radians(-28), math.radians(30), 0, 1, 3, cz=T_CZ, outer=False, sides=False, ends=False)
        bm_ring(bm, T_RIN, T_RIN + 0.1, math.radians(-28), math.radians(30), 3, 4, 3, cz=T_CZ, outer=False, sides=False, ends=False)
    else:
        bm_ring(bm, T_RIN, T_RIN + 0.1, 0, 2 * math.pi, 0, SEG, 16, cz=T_CZ, outer=False, sides=False)
    col_mesh("TunnelWalls", bm, root)
    col_box("TrackBed", (2 * hw + 0.4, SEG, 0.8), (0, SEG / 2, -0.4), root)
    return root


def tunnel_section_4m(M):
    return tunnel_section(M, "TunnelSection4m")


def tunnel_section_4m_breach(M):
    return tunnel_section(M, "TunnelSection4mBreach", breach=True)


def vent_block(M):
    """Забитый вентблок с красной лампой. Крепится к стене, лицом в -Y."""
    root = empty("VentBlock")
    bm = bmesh.new()
    for (s, l) in [((0.9, 0.35, 0.06), (0, -0.175, 0.87)), ((0.9, 0.35, 0.06), (0, -0.175, 0.03)),
                   ((0.06, 0.35, 0.9), (-0.42, -0.175, 0.45)), ((0.06, 0.35, 0.9), (0.42, -0.175, 0.45)),
                   ((0.9, 0.04, 0.9), (0, -0.02, 0.45))]:
        bm_box(bm, s, l)
    mesh_from_bm(bm, "Housing", M["dark"], root)
    bm = bmesh.new()
    for k in range(8):
        bm_box(bm, (0.78, 0.015, 0.09), (0, -0.25, 0.1 + k * 0.095), rot_x(math.radians(35)))
    mesh_from_bm(bm, "Louvers", M["iron"], root, uv=None)
    rnd = random.Random(11)
    bm = bmesh.new()
    for k in range(9):
        bm_box(bm, (rnd.uniform(0.1, 0.3), 0.08, rnd.uniform(0.05, 0.15)),
               (rnd.uniform(-0.3, 0.3), -0.28, rnd.uniform(0.15, 0.75)), rot_y(rnd.uniform(-1, 1)))
    mesh_from_bm(bm, "Clog", M["cloth"], root, uv=None)
    cyl("RedLampBase", 0.07, 0.04, (0, -0.02, 1.05), "Y", 10, M["dark"], root, uv=None)
    cyl("RedLamp", 0.055, 0.07, (0, -0.07, 1.05), "Y", 10, M["lamp_red"], root, uv=None)
    light_point(root, (0, -0.2, 1.05), "RedLightPoint")
    col_box("VentBlock", (0.9, 0.35, 0.9), (0, -0.175, 0.45), root)
    return root


def hiding_cabinet(M):
    """Шкаф-укрытие: полый внутри, дверь Door на петле, щели на уровне глаз (сквозные)."""
    root = empty("HidingCabinet")
    w, d, h, th = 0.85, 0.65, 2.0, 0.03
    bm = bmesh.new()
    for (s, l) in [((th, d, h), (-w / 2 + th / 2, 0, h / 2)), ((th, d, h), (w / 2 - th / 2, 0, h / 2)),
                   ((w, th, h), (0, d / 2 - th / 2, h / 2)), ((w, d, th), (0, 0, th / 2 + 0.05)),
                   ((w, d, th), (0, 0, h - th / 2)), ((w + 0.04, d + 0.04, 0.05), (0, 0, 0.025))]:
        bm_box(bm, s, l)
    mesh_from_bm(bm, "Body", M["green"], root)
    door = empty("Door", root, (-w / 2, -d / 2, 0.05))
    door.rotation_euler = (0, 0, math.radians(-5))
    dh = h - 0.05
    bm = bmesh.new()
    bm_box(bm, (w, th, 1.45), (w / 2, -th / 2, 0.725))
    bm_box(bm, (w, th, dh - 1.68), (w / 2, -th / 2, 1.68 + (dh - 1.68) / 2))
    bm_box(bm, (0.15, th, 0.23), (0.075, -th / 2, 1.565))
    bm_box(bm, (0.15, th, 0.23), (w - 0.075, -th / 2, 1.565))
    for k in range(4):
        bm_box(bm, (w - 0.3, th * 0.6, 0.03), (w / 2, -th / 2, 1.47 + k * 0.06), rot_x(math.radians(-30)))
    mesh_from_bm(bm, "DoorLeaf", M["green"], door)
    box("Handle", (0.03, 0.04, 0.15), (w - 0.07, -0.05, 1.0), M["steel"], door, uv=None)
    col_box("DoorLeaf", (w, th, dh), (w / 2, -th / 2, dh / 2), door)
    col_box("Back", (w, th, h), (0, d / 2 - th / 2, h / 2), root)
    col_box("SideL", (th, d, h), (-w / 2 + th / 2, 0, h / 2), root)
    col_box("SideR", (th, d, h), (w / 2 - th / 2, 0, h / 2), root)
    col_box("Roof", (w, d, th), (0, 0, h - th / 2), root)
    empty("HidePoint", root, (0, 0.05, 0.05))
    return root


def spider_web_large(M):
    """Паутина во весь тоннель (двусторонняя, alpha-clip). Центрирована по оси тоннеля."""
    root = empty("SpiderWebLarge")
    s = 2 * T_RIN + 0.1
    bm = bmesh.new()
    vs = [bm.verts.new((x, 0, z)) for x, z in ((-s / 2, T_CZ - s / 2), (s / 2, T_CZ - s / 2), (s / 2, T_CZ + s / 2), (-s / 2, T_CZ + s / 2))]
    bm.faces.new(vs)
    o = mesh_from_bm(bm, "Web", M["web"], root, uv=None)
    uvl = o.data.uv_layers.new(name="UVMap")
    for li, uv in zip(range(4), ((0, 0), (1, 0), (1, 1), (0, 1))):
        uvl.data[li].uv = uv
    empty("WebVolume", root, (0, 0, T_CZ))
    return root


def spider_web_corner(M):
    root = empty("SpiderWebCorner")
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((0, 0, 0), (1.2, 0, 0), (1.2, 0, 1.2), (0, 0, 1.2))]
    bm.faces.new(vs)
    o = mesh_from_bm(bm, "Web", M["web"], root, uv=None)
    uvl = o.data.uv_layers.new(name="UVMap")
    for li, uv in zip(range(4), ((0.5, 0.5), (1, 0.5), (1, 1), (0.5, 1))):
        uvl.data[li].uv = uv
    return root


def pk_marker(M, n):
    root = empty(f"PKMarker{n}")
    box_uv_fit(box("Plate", (0.5, 0.02, 0.3), (0, -0.01, 0), M["sign"], root, uv=(0.5, 0.3)))
    text_mesh("Text", f"ПК {n}", 0.16, (0, -0.022, -0.005), M["ink"], root, 0.002)
    return root


# ======================================================================= СЛУЖЕБНАЯ КОМНАТА
def hurricane_lantern(M, name="HurricaneLantern", lit=True):
    """Керосиновый фонарь «летучая мышь» прежнего обходчика."""
    root = empty(name)
    cyl("Tank", 0.08, 0.07, (0, 0, 0.035), "Z", 14, M["red"], root)
    cyl("Burner", 0.035, 0.03, (0, 0, 0.085), "Z", 10, M["brass"], root, uv=None)
    cyl("Globe", 0.055, 0.13, (0, 0, 0.165), "Z", 12, M["glass"], root, uv=None)
    if lit:
        cyl("Flame", 0.012, 0.035, (0, 0, 0.13), "Z", 6, M["flame"], root, uv=None, r2=0.002)
    cyl("Cap", 0.065, 0.04, (0, 0, 0.25), "Z", 12, M["red"], root, r2=0.03)
    bm = bmesh.new()
    for a in range(0, 360, 90):
        ar = math.radians(a)
        bm_box(bm, (0.008, 0.008, 0.2), (0.07 * math.cos(ar), 0.07 * math.sin(ar), 0.17))
    bm_hoop(bm, 0, 0, 0.32, 0.075, 0, math.pi, 8, 0.008, 0.008)
    for s in (-1, 1):
        bm_box(bm, (0.008, 0.008, 0.07), (s * 0.075, 0, 0.29))
    mesh_from_bm(bm, "Wires", M["dark"], root, uv=None)
    if lit:
        light_point(root, (0, 0, 0.14))
    col_box(name, (0.17, 0.17, 0.33), (0, 0, 0.165), root)
    return root


def note_paper(M):
    root = empty("NotePaper")
    box_uv_fit(box("Sheet", (0.12, 0.16, 0.002), (0, 0, 0.001), M["paper"], root, uv=(0.12, 0.16)))
    return root


def chalk_tally(M):
    """Счёт дней мелом: 4 пятёрки + 3. Плоская геометрия, кладётся на стену (лицом в -Y)."""
    root = empty("ChalkTally")
    bm = bmesh.new()
    x = 0
    for g in range(5):
        cnt = 3 if g == 4 else 4
        for k in range(cnt):
            bm_box(bm, (0.012, 0.002, 0.16), (x + k * 0.04, -0.001, 0.08), rot_y(random.Random(g * 9 + k).uniform(-0.08, 0.08)))
        if cnt == 4:
            bm_box(bm, (0.2, 0.002, 0.012), (x + 0.06, -0.001, 0.08), rot_y(math.radians(-35)))
        x += 0.22
    mesh_from_bm(bm, "Marks", M["chalk"], root, uv=None)
    return root


# ======================================================================= СТАРАЯ ЛИНИЯ
OL_HW, OL_WALL_H, OL_RISE = 3.5, 2.4, 1.4


def oldline_vault_4m(M):
    """Дореволюционный зал: кирпичные стены, лучковый свод, утопленные рельсы."""
    root = empty("OldLineVault4m")
    R = (OL_HW ** 2 + OL_RISE ** 2) / (2 * OL_RISE)
    cz = OL_WALL_H + OL_RISE - R
    a0 = math.atan2(OL_WALL_H - cz, OL_HW)
    box("WallL", (0.5, SEG, OL_WALL_H), (-OL_HW - 0.25, SEG / 2, OL_WALL_H / 2), M["brick"], root)
    box("WallR", (0.5, SEG, OL_WALL_H), (OL_HW + 0.25, SEG / 2, OL_WALL_H / 2), M["brick"], root)
    bm = bmesh.new()
    bm_ring(bm, R, R + 0.45, a0, math.pi - a0, 0, SEG, 20, cz=cz)
    mesh_from_bm(bm, "Vault", M["brick"], root)
    box("Floor", (2 * OL_HW, SEG, 0.2), (0, SEG / 2, -0.1), M["gravel"], root)
    bm = bmesh.new()
    for s in (-1, 1):
        bm_box(bm, (0.07, SEG, 0.05), (s * RAIL_GAUGE / 2, SEG / 2, 0.0))
    mesh_from_bm(bm, "SunkenRails", M["dark"], root)
    # кирпичный бортик-поребрик вдоль стен
    boxes("Curbs", [((0.4, SEG, 0.15), (-OL_HW + 0.2, SEG / 2, 0.075)), ((0.4, SEG, 0.15), (OL_HW - 0.2, SEG / 2, 0.075))],
          M["brick"], root, uv=0.5)
    col_box("WallL", (0.5, SEG, OL_WALL_H), (-OL_HW - 0.25, SEG / 2, OL_WALL_H / 2), root)
    col_box("WallR", (0.5, SEG, OL_WALL_H), (OL_HW + 0.25, SEG / 2, OL_WALL_H / 2), root)
    col_box("Floor", (2 * OL_HW, SEG, 0.2), (0, SEG / 2, -0.1), root)
    bm = bmesh.new()
    bm_ring(bm, R, R + 0.45, a0, math.pi - a0, 0, SEG, 8, cz=cz, outer=False, sides=False, ends=False)
    col_mesh("Vault", bm, root)
    return root


def oldline_column(M):
    root = empty("OldLineColumn")
    boxes("Shaft", [((0.7, 0.7, 2.1), (0, 0, 1.25))], M["brick"], root, uv=1.0)
    boxes("Plinth", [((0.9, 0.9, 0.2), (0, 0, 0.1))], M["brick"], root, uv=1.0)
    boxes("Capital", [((0.85, 0.85, 0.12), (0, 0, 2.36)), ((1.0, 1.0, 0.1), (0, 0, 2.47))], M["brick"], root, uv=1.0)
    col_box("Column", (0.9, 0.9, 2.52), (0, 0, 1.26), root)
    return root


def _wall_hole(M, name, hole, center, w=4.0, h=3.8, t=0.5, material="brick"):
    root = empty(name)
    faces = wall_with_hole_faces(w, h, hole, center, 56)
    bm = bmesh.new()
    bm_poly_extrude(bm, faces, 0.0, t)
    mesh_from_bm(bm, "Wall", M[material], root)
    return root


def oldline_arch_window_wall(M):
    """Кирпичная стена 4×3.8 м с арочным проёмом и решёткой."""
    sill, spring, r = 1.0, 2.2, 0.7
    hole = [(-r, sill), (r, sill)] + [(r * math.cos(math.pi * k / 16), spring + r * math.sin(math.pi * k / 16)) for k in range(17)]
    root = _wall_hole(M, "OldLineArchWindowWall", hole, (0, 2.0))
    bm = bmesh.new()
    for k in range(-3, 4):
        x = k * 0.2
        top = spring + math.sqrt(max(r * r - x * x, 0)) if abs(x) < r else spring
        bm_box(bm, (0.025, 0.025, top - sill), (x, 0.25, sill + (top - sill) / 2))
    for z in (1.5, 2.1):
        bm_box(bm, (2 * r, 0.02, 0.03), (0, 0.25, z))
    mesh_from_bm(bm, "Grille", M["dark"], root, uv=None)
    col_box("WallL", (2 - r, 0.5, 3.8), (-(2 + r) / 2, 0.25, 1.9), root)
    col_box("WallR", (2 - r, 0.5, 3.8), ((2 + r) / 2, 0.25, 1.9), root)
    col_box("Sill", (2 * r, 0.5, sill), (0, 0.25, sill / 2), root)
    col_box("Top", (2 * r, 0.5, 3.8 - spring), (0, 0.25, spring + (3.8 - spring) / 2), root)
    return root


def oldline_breach_wall(M):
    """Кирпичная стена с рваным проломом (переход из чугунного тоннеля)."""
    rnd = random.Random(5)
    cx, cz = 0.1, 1.25
    hole = []
    for k in range(22):
        a = 2 * math.pi * k / 22
        rx, rz = 0.95, 1.2
        rr = 1 + rnd.uniform(-0.18, 0.18)
        hole.append((cx + rx * rr * math.cos(a), max(0.12, cz + rz * rr * math.sin(a))))
    root = _wall_hole(M, "OldLineBreachWall", hole, (cx, cz))
    rubble_into(M, root, (cx, -0.6), 26, rnd)
    col_box("WallL", (1.0, 0.5, 3.8), (-1.5, 0.25, 1.9), root)
    col_box("WallR", (1.0, 0.5, 3.8), (1.6, 0.25, 1.9), root)
    col_box("Top", (2.0, 0.5, 1.2), (0.05, 0.25, 3.2), root)
    return root


def rubble_into(M, root, c, n, rnd, spread=0.9):
    bm = bmesh.new()
    for k in range(n):
        r = spread * math.sqrt(rnd.random())
        a = rnd.random() * 2 * math.pi
        z = max(0.03, (spread - r) * 0.35 * rnd.random() + 0.03)
        bm_box(bm, (0.25, 0.12, 0.065), (c[0] + r * math.cos(a), c[1] + r * math.sin(a), z),
               rot_z(rnd.random() * 3.14) @ rot_x(rnd.uniform(-0.5, 0.5)))
    for k in range(5):
        bm_box(bm, (rnd.uniform(0.3, 0.5), rnd.uniform(0.2, 0.35), rnd.uniform(0.15, 0.25)),
               (c[0] + rnd.uniform(-0.4, 0.4), c[1] + rnd.uniform(-0.4, 0.4), 0.08), rot_z(rnd.random() * 3))
    mesh_from_bm(bm, "Rubble", M["brick"], root, uv=0.5)


def brick_rubble_pile(M):
    root = empty("BrickRubblePile")
    rubble_into(M, root, (0, 0), 40, random.Random(21), 1.0)
    col_box("Rubble", (1.6, 1.6, 0.35), (0, 0, 0.17), root)
    return root


def railway_lantern(M, lit=False, name="RailwayLantern"):
    """Путейский фонарь — находка на старой линии (подбираемый предмет)."""
    root = empty(name)
    s = 0.17
    box("Body", (s, s, 0.24), (0, 0, 0.14), M["dark"], root, uv=0.3)
    box("Base", (s + 0.03, s + 0.03, 0.03), (0, 0, 0.015), M["dark"], root, uv=0.3)
    cyl("Roof", 0.13, 0.06, (0, 0, 0.29), "Z", 4, M["dark"], root, uv=0.3, r2=0.03)
    cyl("Vent", 0.03, 0.05, (0, 0, 0.345), "Z", 8, M["dark"], root, uv=None)
    lens_mats = [M["lamp"] if lit else M["glass"], M["red"], M["glass"], M["green"]]
    for k, m in enumerate(lens_mats):
        a = k * math.pi / 2
        cyl(f"Lens{k}", 0.05, 0.02, (0.09 * math.sin(a), -0.09 * math.cos(a), 0.15),
            "Y" if k % 2 == 0 else "X", 12, m, root, uv=None)
    bm = bmesh.new()
    bm_hoop(bm, 0, 0, 0.0, 0.09, 0, math.pi, 8, 0.012, 0.012)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=rot_x(math.pi / 2))
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=(0, 0, 0.30))
    mesh_from_bm(bm, "Handle", M["steel"], root, uv=None)
    if lit:
        light_point(root, (0, -0.12, 0.15))
    col_box(name, (0.2, 0.2, 0.42), (0, 0, 0.21), root)
    empty("PickupPoint", root, (0, 0, 0.21))
    return root


# ======================================================================= РЕЕСТР
ASSETS = [
    ("common", "track_straight_4m", track_straight_4m),
    ("common", "cable_run_4m", cable_run_4m),
    ("common", "wall_lamp_caged", wall_lamp_caged),
    ("common", "junction_box", junction_box),
    ("01_duty_room", "room_wall_4m", room_wall_4m),
    ("01_duty_room", "room_wall_door_4m", room_wall_door_4m),
    ("01_duty_room", "room_floor_4x4", room_floor_4x4),
    ("01_duty_room", "floor_hatch", floor_hatch),
    ("01_duty_room", "desk", desk),
    ("01_duty_room", "chair", chair),
    ("01_duty_room", "weapon_crate", weapon_crate),
    ("01_duty_room", "locker", locker),
    ("01_duty_room", "letter", letter),
    ("02_shaft", "shaft_segment_2m", shaft_segment_2m),
    ("03_platform", "platform_section_4m", platform_section_4m),
    ("03_platform", "platform_end_wall", platform_end_wall),
    ("03_platform", "hanging_lamp", hanging_lamp),
    ("03_platform", "diesel_generator", diesel_generator),
    ("03_platform", "mine_cart", mine_cart),
    ("03_platform", "station_sign_tikhaya", station_sign),
    ("03_platform", "bench", bench),
    ("04_cast_iron_tunnel", "tubing_ring_1m", tubing_ring_1m),
    ("04_cast_iron_tunnel", "tunnel_section_4m", tunnel_section_4m),
    ("04_cast_iron_tunnel", "tunnel_section_4m_breach", tunnel_section_4m_breach),
    ("04_cast_iron_tunnel", "vent_block", vent_block),
    ("04_cast_iron_tunnel", "hiding_cabinet", hiding_cabinet),
    ("04_cast_iron_tunnel", "spider_web_large", spider_web_large),
    ("04_cast_iron_tunnel", "spider_web_corner", spider_web_corner),
    ("04_cast_iron_tunnel", "pk_marker_0", lambda M: pk_marker(M, 0)),
    ("04_cast_iron_tunnel", "pk_marker_1", lambda M: pk_marker(M, 1)),
    ("04_cast_iron_tunnel", "pk_marker_2", lambda M: pk_marker(M, 2)),
    ("05_service_room", "hurricane_lantern", hurricane_lantern),
    ("05_service_room", "hurricane_lantern_off", lambda M: hurricane_lantern(M, "HurricaneLanternOff", lit=False)),
    ("05_service_room", "note_paper", note_paper),
    ("05_service_room", "chalk_tally", chalk_tally),
    ("06_old_line", "oldline_vault_4m", oldline_vault_4m),
    ("06_old_line", "oldline_column", oldline_column),
    ("06_old_line", "oldline_arch_window_wall", oldline_arch_window_wall),
    ("06_old_line", "oldline_breach_wall", oldline_breach_wall),
    ("06_old_line", "brick_rubble_pile", brick_rubble_pile),
    ("06_old_line", "railway_lantern", railway_lantern),
    ("06_old_line", "railway_lantern_lit", lambda M: railway_lantern(M, True, "RailwayLanternLit")),
]
