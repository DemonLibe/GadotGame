class_name MapView
extends Control
## Бумажная схема линии: открытые сегодня проходы, станция, шахта, комнаты, зарядки и «вы здесь».

const BOUNDS := Rect2(-34.0, -272.0, 80.0, 248.0)  # мир: x, z, ширина, глубина
const PAPER := Color(0.86, 0.82, 0.7)
const INK := Color(0.2, 0.17, 0.14)
const PAD := 28.0

var level: Level
var player: Node3D
var limit_z := -1000.0          # дальше по основному тоннелю сегодня не пройти
var open_branches: Array = []   # индексы открытых штолен
var open_rooms: Array = []      # индексы открытых комнат
var chargers: Array[Vector3] = []


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	var area := size - Vector2(PAD * 2, PAD * 2 + 30)
	var k := minf(area.x / BOUNDS.size.x, area.y / BOUNDS.size.y)
	var x := PAD + (p.x - BOUNDS.position.x) * k
	var y := PAD + 30 + (-p.y + BOUNDS.end.y) * k  # глубже — ниже на листе
	return Vector2(x, y)


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(INK, 0.5), false, 2.0)
	draw_string(font, Vector2(PAD, 30), "СХЕМА ЛИНИИ «ТИХАЯ»", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	if level == null:
		return
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
	# Комнаты, зарядки.
	for ri in open_rooms:
		var c: Vector3 = level.rooms[ri]["center"]
		var p := _to_map(Vector2(c.x, c.z))
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), INK, false, 1.5)
		draw_string(font, p + Vector2(-3, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	for c in chargers:
		draw_circle(_to_map(Vector2(c.x, c.z)), 4.0, Color(0.1, 0.5, 0.2))
	# Вы здесь.
	if player and player.global_position.y < Level.FLOOR_Y + 6.0:
		var pp := _to_map(Vector2(player.global_position.x, player.global_position.z))
		var f := -player.global_transform.basis.z
		var dir := Vector2(f.x, -f.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([pp + dir * 9, pp - dir * 5 + side * 5, pp - dir * 5 - side * 5]), Color(0.75, 0.1, 0.05))
	draw_string(font, Vector2(PAD, size.y - 12), "красный — вы, зелёный — зарядка, ? — комната", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(INK, 0.8))
