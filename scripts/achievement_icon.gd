class_name AchievementIcon
extends Control
## Значок достижения: рисуется кодом. Полученное — янтарный знак на тёплом фоне,
## не полученное — серый знак и замочек в углу, скрытое — вопрос.

const AMBER := Color(1.0, 0.75, 0.3)
const GREY := Color(0.42, 0.41, 0.39)

var icon := "star"
var unlocked := false


func _draw() -> void:
	var s := minf(size.x, size.y)
	var r := Rect2(Vector2.ZERO, Vector2(s, s))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.24, 0.16, 0.06) if unlocked else Color(0.12, 0.12, 0.12)
	bg.border_color = AMBER if unlocked else Color(0.25, 0.25, 0.25)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	draw_style_box(bg, r)
	var c := Vector2(s, s) * 0.5
	var k := s / 56.0  # рисунки ниже — для значка 56×56
	var fg := AMBER if unlocked else GREY
	var dark := bg.bg_color
	match icon:
		"moon":
			draw_circle(c, 15 * k, fg)
			draw_circle(c + Vector2(7, -5) * k, 13 * k, dark)
			draw_circle(c + Vector2(10, 9) * k, 1.6 * k, fg)
			draw_circle(c + Vector2(14, -14) * k, 1.2 * k, fg)
		"door":
			draw_rect(Rect2(c + Vector2(-11, -17) * k, Vector2(22, 34) * k), fg, false, 3 * k)
			draw_rect(Rect2(c + Vector2(-6, -12) * k, Vector2(12, 10) * k), fg, false, 2 * k)
			draw_circle(c + Vector2(6, 3) * k, 2.2 * k, fg)
		"note":
			draw_rect(Rect2(c + Vector2(-12, -16) * k, Vector2(24, 32) * k), fg)
			for i in 4:
				draw_line(c + Vector2(-8, -9 + i * 6) * k, c + Vector2(8 - (6 if i == 3 else 0), -9 + i * 6) * k, dark, 2 * k)
		"flame":
			draw_colored_polygon(_flame(c, 1.0 * k), fg)
			draw_colored_polygon(_flame(c + Vector2(0, 7) * k, 0.45 * k), dark)
		"cross":
			draw_arc(c, 14 * k, 0, TAU, 32, fg, 3 * k)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * 7 * k, c + d * 19 * k, fg, 3 * k)
			draw_circle(c, 2.5 * k, fg)
		"cabinet":
			# Шкаф с двумя дверцами в щелях и глаза в темноте между ними.
			draw_rect(Rect2(c + Vector2(-14, -18) * k, Vector2(28, 36) * k), fg, false, 3 * k)
			draw_line(c + Vector2(0, -17) * k, c + Vector2(0, 17) * k, fg, 2 * k)
			for i in 3:
				draw_line(c + Vector2(-10, -12 + i * 4) * k, c + Vector2(-3, -12 + i * 4) * k, fg, 1.4 * k)
				draw_line(c + Vector2(3, -12 + i * 4) * k, c + Vector2(10, -12 + i * 4) * k, fg, 1.4 * k)
			draw_circle(c + Vector2(-3.5, 4) * k, 1.8 * k, fg)
			draw_circle(c + Vector2(3.5, 4) * k, 1.8 * k, fg)
		"steps":
			for p in [[Vector2(-7, 6), 0.2], [Vector2(7, -6), -0.2]]:
				var o: Vector2 = c + p[0] * k
				draw_set_transform(o, p[1], Vector2(1.0, 1.6))
				draw_circle(Vector2.ZERO, 5 * k, fg)
				draw_set_transform(Vector2.ZERO)
				draw_circle(o + Vector2(0, -12) * k, 3 * k, fg)
		"heart":
			draw_circle(c + Vector2(-7, -5) * k, 8 * k, fg)
			draw_circle(c + Vector2(7, -5) * k, 8 * k, fg)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-14.6, -2) * k, c + Vector2(14.6, -2) * k, c + Vector2(0, 16) * k]), fg)
		"lamp":
			draw_circle(c, 8 * k, fg)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				draw_line(c + d * 12 * k, c + d * 19 * k, fg, 2.5 * k)
		"battery":
			draw_rect(Rect2(c + Vector2(-9, -14) * k, Vector2(18, 30) * k), fg, false, 3 * k)
			draw_rect(Rect2(c + Vector2(-4, -18) * k, Vector2(8, 4) * k), fg)
			draw_rect(Rect2(c + Vector2(-5, -1) * k, Vector2(10, 13) * k), fg)
		"pill":
			draw_set_transform(c, -0.7)
			draw_rect(Rect2(Vector2(-9, -7) * k, Vector2(18, 14) * k), fg)
			draw_circle(Vector2(-9, 0) * k, 7 * k, fg)
			draw_circle(Vector2(9, 0) * k, 7 * k, dark if unlocked else fg.darkened(0.3))
			draw_arc(Vector2(9, 0) * k, 7 * k, -PI / 2, PI / 2, 12, fg, 2 * k)
			draw_line(Vector2(0, -7) * k, Vector2(0, 7) * k, dark, 1.5 * k)
			draw_set_transform(Vector2.ZERO)
		"duck":
			draw_circle(c + Vector2(-2, 6) * k, 11 * k, fg)
			draw_circle(c + Vector2(6, -8) * k, 7 * k, fg)
			draw_colored_polygon(PackedVector2Array([c + Vector2(12, -9) * k, c + Vector2(19, -7) * k, c + Vector2(12, -5) * k]), fg.darkened(0.25))
			draw_circle(c + Vector2(7, -10) * k, 1.4 * k, dark)
		"chalk":
			draw_polyline(PackedVector2Array([c + Vector2(-16, -10) * k, c + Vector2(-9, 10) * k, c + Vector2(-2, -10) * k]), fg, 3 * k)
			draw_polyline(PackedVector2Array([c + Vector2(4, -10) * k, c + Vector2(4, 10) * k, c + Vector2(14, 10) * k]), fg, 3 * k)
			draw_line(c + Vector2(-16, 15) * k, c + Vector2(16, 15) * k, fg, 1.5 * k)
		"hidden":
			var font := get_theme_default_font()
			draw_string(font, c + Vector2(-9, 11) * k, "?", HORIZONTAL_ALIGNMENT_CENTER, 18 * k, int(32 * k), fg)
		_:
			draw_colored_polygon(_star(c, 17 * k, 7 * k), fg)
	if not unlocked and icon != "hidden":
		# Замочек в правом нижнем углу.
		var o := Vector2(s - 13 * k, s - 12 * k)
		draw_arc(o + Vector2(0, -3) * k, 4 * k, PI, TAU, 10, Color(0.75, 0.75, 0.75), 2 * k)
		draw_rect(Rect2(o + Vector2(-6, -3) * k, Vector2(12, 9) * k), Color(0.75, 0.75, 0.75))


static func _flame(c: Vector2, k: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var r := 11.0 + 9.0 * maxf(0.0, -sin(a)) * absf(sin(a))
		var p := Vector2(cos(a) * 11.0 * (1.0 - 0.5 * maxf(0.0, -sin(a))), sin(a) * r)
		pts.append(c + Vector2(p.x, p.y + 4.0) * k)
	return pts


static func _star(c: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		pts.append(c + Vector2.from_angle(a) * (outer if i % 2 == 0 else inner))
	return pts
