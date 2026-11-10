class_name MapView
extends Control
## Бумажная схема линии: открытые сегодня проходы, станция, шахта, комнаты и «вы здесь».

const VIEW_H := 420.0   # сколько метров вглубь видно на листе (сеть длинная — схема едет за обходчиком)
const PAPER := Color(0.86, 0.82, 0.7)
const INK := Color(0.2, 0.17, 0.14)
const PAD := 28.0
const STRIP := 54.0     # справа — вся линия целиком, мелко

var level: Level
var player: Node3D
var limit_z := -1000.0          # дальше по основному тоннелю сегодня не пройти
var open_branches: Array = []   # индексы открытых штолен
var marks: Array = []           # места поручений: [позиция, подпись]
var open_rooms: Array = []      # индексы открытых комнат
var fake := {}                  # штольня, которая есть только на схеме: {z, side, name}
var _view := Rect2()            # видимый кусок мира: x, z (верх листа — z_max)
var _k := 1.0


func _ready() -> void:
	clip_contents = true


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## Окно схемы: вокруг обходчика (наверху — у станции), чуть больше видно вперёд, вглубь.
func _fit_view() -> void:
	var area := size - Vector2(PAD * 2 + STRIP, PAD * 2 + 30)
	_k = area.y / VIEW_H
	var span_x := area.x / _k
	var pz := Level.TUN_Z0 - VIEW_H * 0.3
	var px := Level.TUN_CX
	if player and player.global_position.y < Level.FLOOR_Y + 6.0:
		pz = player.global_position.z
		px = clampf(player.global_position.x, Level.TUN_CX - span_x * 0.35, Level.TUN_CX + span_x * 0.35)
	var top := minf(pz + VIEW_H * 0.4, 0.0)
	_view = Rect2(px - span_x / 2.0, top - VIEW_H, span_x, VIEW_H)


func _to_map(p: Vector2) -> Vector2:
	var x := PAD + (p.x - _view.position.x) * _k
	var y := PAD + 30 + (_view.end.y - p.y) * _k  # глубже — ниже на листе
	return Vector2(x, y)


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(INK, 0.5), false, 2.0)
	if level != null and player != null and level.lower.contains(player.global_position):
		_draw_lower(font)
		return
	draw_string(font, Vector2(PAD, 30), "СХЕМА ЛИНИИ «ТИХАЯ»", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	if level == null:
		return
	_fit_view()
	_draw_strip(font)
	var w := 9.0
	# Станция и шахта.
	var st_a := _to_map(Vector2(-3, -30))
	var st_b := _to_map(Vector2(3, -50))
	draw_rect(Rect2(st_a, st_b - st_a), Color(INK, 0.25))
	draw_rect(Rect2(st_a, st_b - st_a), INK, false, 1.5)
	draw_string(font, st_b + Vector2(6, -6), "станция", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	var sh := _to_map(Vector2(Level.SHAFT_X, Level.SHAFT_Z))
	draw_circle(sh, 4.0, INK)
	draw_string(font, sh + Vector2(-58, 4), "шахта", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	# Основной тоннель до сегодняшнего ограждения.
	var end_z := maxf(limit_z, Level.TUN_Z1)
	var a := _to_map(Vector2(Level.TUN_CX, Level.TUN_Z0))
	var b := _to_map(Vector2(Level.TUN_CX, end_z))
	draw_line(a, b, Color(INK, 0.85), w)
	if limit_z > Level.TUN_Z1:
		draw_line(b + Vector2(-10, 0), b + Vector2(10, 0), Color(0.6, 0.1, 0.05), 3.0)
		draw_string(font, b + Vector2(12, 4), "закрыто", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.1, 0.05))
	elif limit_z <= Level.TUN_Z1:
		var g := _to_map(Vector2(Level.TUN_CX, Level.GRATE_Z))
		draw_line(g + Vector2(-8, 0), g + Vector2(8, 0), INK, 2.0)
		draw_string(font, g + Vector2(12, 4), "решётка", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	# Штольни.
	for i in Level.BRANCHES.size():
		if not open_branches.has(i):
			continue
		var br: Dictionary = Level.BRANCHES[i]
		var o := Level.branch_origin(i)
		var e := o + Level.branch_dir(i) * float(br["length"])
		var pa := _to_map(Vector2(o.x, o.z))
		var pb := _to_map(Vector2(e.x, e.z))
		draw_line(pa, pb, Color(INK, 0.75), w * 0.8)
		draw_string(font, pb + Vector2(-20, 16), str(br["name"]).to_lower(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	# Комнаты.
	for ri in open_rooms:
		var c: Vector3 = level.rooms[ri]["center"]
		var p := _to_map(Vector2(c.x, c.z))
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), INK, false, 1.5)
		draw_string(font, p + Vector2(-3, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	if not fake.is_empty():
		var fo := Vector2(Level.TUN_CX, float(fake["z"]))
		var fd := Vector2(sin(deg_to_rad(38.0)) * float(fake["side"]), -cos(deg_to_rad(38.0)))
		var fa := _to_map(fo)
		var fb := _to_map(fo + fd * 70.0)
		draw_line(fa, fb, Color(INK, 0.75), w * 0.8)
		draw_string(font, fb + Vector2(-20, 16), str(fake["name"]).to_lower(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	for ri in level.gen_rooms:
		var gc: Vector3 = level.rooms[ri]["center"]
		var gp := _to_map(Vector2(gc.x, gc.z))
		draw_string(font, gp + Vector2(-4, 4), "Г", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	# Места поручений — крестик и подпись.
	for m in marks:
		var mp: Vector3 = m[0]
		var q := _to_map(Vector2(mp.x, mp.z))
		var red := Color(0.6, 0.1, 0.05)
		draw_line(q + Vector2(-4, -4), q + Vector2(4, 4), red, 2.0)
		draw_line(q + Vector2(-4, 4), q + Vector2(4, -4), red, 2.0)
		draw_string(font, q + Vector2(6, 4), str(m[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, red)
	# Вы здесь.
	if player and player.global_position.y < Level.FLOOR_Y + 6.0:
		var pp := _to_map(Vector2(player.global_position.x, player.global_position.z))
		var f := -player.global_transform.basis.z
		var dir := Vector2(f.x, -f.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([pp + dir * 9, pp - dir * 5 + side * 5, pp - dir * 5 - side * 5]), Color(0.75, 0.1, 0.05))
	# Пикеты — по краю основного тоннеля, через каждые 100 м.
	var pk := 4
	while Level.TUN_Z0 - Level.PICKET_STEP * pk > maxf(Level.TUN_Z1, limit_z):
		var q := _to_map(Vector2(Level.TUN_CX, Level.TUN_Z0 - Level.PICKET_STEP * pk))
		if q.y > PAD + 30 and q.y < size.y - PAD:
			draw_line(q + Vector2(5, 0), q + Vector2(11, 0), Color(INK, 0.6), 1.0)
			draw_string(font, q + Vector2(13, 4), "ПК %d" % pk, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(INK, 0.7))
		pk += 4
	draw_string(font, Vector2(PAD, size.y - 12), "красный — вы, × — поручение, ? — комната, Г — генераторная", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(INK, 0.8))


## Справа — линия целиком: основной тоннель, развилки, ограждение, поручения, вы и рамка того, что на листе.
func _draw_strip(font: Font) -> void:
	var x := size.x - PAD - STRIP * 0.5
	var y0 := PAD + 40.0
	var y1 := size.y - PAD - 20.0
	var z_end := Level.TUN_Z1
	var at := func(z: float) -> float:
		return lerpf(y0, y1, clampf((Level.TUN_Z0 - z) / (Level.TUN_Z0 - z_end), 0.0, 1.0))
	draw_rect(Rect2(Vector2(size.x - PAD - STRIP, y0 - 14), Vector2(STRIP, y1 - y0 + 28)), Color(INK, 0.06))
	var open_end := maxf(limit_z, z_end)
	draw_line(Vector2(x, y0), Vector2(x, at.call(open_end)), Color(INK, 0.85), 3.0)
	draw_line(Vector2(x, at.call(open_end)), Vector2(x, y1), Color(INK, 0.25), 1.0)
	for i in Level.BRANCHES.size():
		var br: Dictionary = Level.BRANCHES[i]
		if int(br["parent"]) >= 0:
			continue
		var y: float = at.call(float(br["z"]))
		var dx := 9.0 * float(br["side"])
		draw_line(Vector2(x, y), Vector2(x + dx, y + 5.0), Color(INK, 0.8 if open_branches.has(i) else 0.25), 1.5)
	for ri in level.gen_rooms:
		var y: float = at.call((level.rooms[ri]["center"] as Vector3).z)
		draw_string(font, Vector2(x - 20, y + 4), "Г", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
	var g: float = at.call(Level.GRATE_Z)
	draw_line(Vector2(x - 6, g), Vector2(x + 6, g), INK, 2.0)
	if limit_z > Level.GRATE_Z:
		var l: float = at.call(limit_z)
		draw_line(Vector2(x - 7, l), Vector2(x + 7, l), Color(0.6, 0.1, 0.05), 2.0)
	for m in marks:
		var my: float = at.call((m[0] as Vector3).z)
		draw_circle(Vector2(x + 12, my), 2.0, Color(0.6, 0.1, 0.05))
	# Рамка листа.
	var vy0: float = at.call(_view.end.y)
	var vy1: float = at.call(_view.position.y)
	draw_rect(Rect2(Vector2(x - 16, vy0), Vector2(32, maxf(vy1 - vy0, 2.0))), Color(INK, 0.5), false, 1.0)
	if player and player.global_position.y < Level.FLOOR_Y + 6.0:
		draw_circle(Vector2(x, at.call(player.global_position.z)), 3.5, Color(0.75, 0.1, 0.05))
	draw_string(font, Vector2(size.x - PAD - STRIP, y0 - 18), "вся линия", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(INK, 0.8))


## Старая линия: на схеме только то, где уже прошёл (и ходы из этих клеток — обрывками).
func _draw_lower(font: Font) -> void:
	var lower := level.lower
	draw_string(font, Vector2(PAD, 30), "СТАРАЯ ЛИНИЯ — СВОЯ СХЕМА", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	var area := size - Vector2(PAD * 2, PAD * 2 + 50)
	var k := minf(area.x / LowerLine.COLS, area.y / LowerLine.ROWS)
	var at := func(c: Vector2i) -> Vector2:
		return Vector2(PAD + (c.x + 0.5) * k, PAD + 40 + (c.y + 0.5) * k)
	var red := Color(0.6, 0.1, 0.05)
	for c in lower.visited:
		var p: Vector2 = at.call(c)
		var kind: String = lower.cells[c]["kind"]
		var r := k * (0.36 if LowerLine.HALL_KINDS.has(kind) else 0.2)
		draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2), Color(INK, 0.85))
		for n in lower.cells[c]["links"]:
			var q: Vector2 = at.call(n)
			var end := q if lower.visited.has(n) else p.lerp(q, 0.4)
			draw_line(p, end, Color(INK, 0.85), k * 0.22)
		if c == LowerLine.ENTRY:
			draw_string(font, p + Vector2(k * 0.3, 4), "пролом", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		if c == lower.goal:
			draw_string(font, p + Vector2(k * 0.4, 4), "платформа", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, red)
	# Служебки: решётка с номером — как только видел её из коридора.
	for c in lower.locked:
		var front: Vector2i = lower.cells[c]["links"][0]
		if lower.visited.has(front):
			var q: Vector2 = (at.call(c) as Vector2).lerp(at.call(front), 0.5)
			draw_line(q - Vector2(k * 0.2, 0).rotated((at.call(c) - at.call(front)).angle() + PI / 2), q + Vector2(k * 0.2, 0).rotated((at.call(c) - at.call(front)).angle() + PI / 2), red, 3.0)
			draw_string(font, q + Vector2(4, -4), "С-%d" % int(lower.locked[c]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, red)
	# Вы здесь.
	var pp: Vector2 = at.call(lower.cell_of(player.global_position))
	var f := -player.global_transform.basis.z
	var dir := Vector2(f.x, -f.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([pp + dir * 9, pp - dir * 5 + side * 5, pp - dir * 5 - side * 5]), red)
	draw_string(font, Vector2(PAD, size.y - 12), "красный — вы; видно только то, где уже был", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(INK, 0.8))
