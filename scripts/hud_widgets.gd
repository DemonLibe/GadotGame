class_name HudWidgets
extends RefCounted
## Детали интерфейса в духе станции: шрифты, клёпаный щиток, сегментные шкалы, путевой лист, монитор пульса.
## Шрифты — Oswald (узкий, как на советских указателях) и PT Mono (машинка), оба под SIL OFL 1.1 (assets/fonts).

const AMBER := Color(1.0, 0.75, 0.3)
const INK := Color(0.16, 0.13, 0.11)
const PAPER := Color(0.86, 0.82, 0.7)
const STEEL := Color(0.11, 0.11, 0.1, 0.88)
const STEEL_EDGE := Color(0.32, 0.3, 0.26, 0.9)

static var _fonts := {}


## Oswald нужной толщины (переменный шрифт: 200–700).
static func oswald(weight := 500) -> Font:
	var key := "oswald_%d" % weight
	if not _fonts.has(key):
		var base := load("res://assets/fonts/Oswald.ttf") as Font
		if base == null:
			return ThemeDB.fallback_font
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = v
	return _fonts[key]


## Почерк героя (Caveat) — для дневника.
static func hand() -> Font:
	if not _fonts.has("hand"):
		var base := load("res://assets/fonts/Caveat.ttf") as Font
		if base == null:
			return ThemeDB.fallback_font
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
		_fonts["hand"] = v
	return _fonts["hand"]


static func mono() -> Font:
	if not _fonts.has("mono"):
		var f := load("res://assets/fonts/PTMono.ttf") as Font
		_fonts["mono"] = f if f else ThemeDB.fallback_font
	return _fonts["mono"]


## Тема интерфейса: Oswald по умолчанию, чёрная обводка у надписей.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = oswald(400)
	t.default_font_size = 16
	t.set_constant("outline_size", "Label", 5)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	return t


static func label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


## Тёмный стальной щиток с фаской и заклёпками по углам.
class Plate extends PanelContainer:
	func _init(margin := 10.0) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = HudWidgets.STEEL
		st.border_color = HudWidgets.STEEL_EDGE
		st.set_border_width_all(1)
		st.border_width_top = 2
		st.set_corner_radius_all(3)
		st.set_content_margin_all(margin)
		st.content_margin_left = margin + 6
		st.content_margin_right = margin + 6
		st.shadow_color = Color(0, 0, 0, 0.45)
		st.shadow_size = 4
		add_theme_stylebox_override("panel", st)

	func _draw() -> void:
		for p in [Vector2(6, 6), Vector2(size.x - 6, 6), Vector2(6, size.y - 6), Vector2(size.x - 6, size.y - 6)]:
			draw_circle(p, 2.2, Color(0.42, 0.4, 0.35))
			draw_circle(p + Vector2(-0.6, -0.6), 1.0, Color(0.6, 0.58, 0.52))


## Сегментная шкала прибора: горящие деления цветом, погасшие — тускло; на исходе мигает.
class SegBar extends Control:
	var value := 1.0  # 0..1
	var color := Color.WHITE
	var segments := 14
	var warn := 0.25  # ниже — мигает
	var _t := 0.0

	func _init(c: Color, w := 150.0, h := 9.0) -> void:
		color = c
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		v = clampf(v, 0.0, 1.0)
		if absf(v - value) > 0.001:
			value = v
			queue_redraw()

	func _process(delta: float) -> void:
		if value < warn:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var gap := 2.0
		var w := (size.x - gap * (segments - 1)) / segments
		var lit := value * segments
		var blink := value < warn and fmod(_t, 0.8) < 0.4
		for i in segments:
			var r := Rect2(i * (w + gap), 0, w, size.y)
			var on := float(i) < lit
			var c := color if on else Color(color, 0.12)
			if on and float(i) + 1.0 > lit:
				c = Color(color, 0.35 + 0.65 * (lit - float(i)))
			if on and blink:
				c = c.darkened(0.5)
			draw_rect(r, c)
			if on:
				draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.25))


## Монитор пульса вместо полосы страха: чем страшнее, тем чаще и выше удары, линия краснеет.
class Pulse extends Control:
	var fear := 0.0
	var _phase := 0.0
	var _pts: PackedFloat32Array = PackedFloat32Array()

	func _init() -> void:
		custom_minimum_size = Vector2(170, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		var n := int(size.x / 2.0)
		if _pts.size() != n:
			_pts.resize(n)
			_pts.fill(0.0)
		var bpm := lerpf(62.0, 150.0, fear)
		_phase += delta * bpm / 60.0
		# Сдвиг ленты: две точки за кадр.
		var steps := maxi(1, int(delta * 60.0))
		for s in steps:
			for i in n - 1:
				_pts[i] = _pts[i + 1]
			var ph := fmod(_phase + s * 0.01, 1.0)
			var y := 0.0
			if ph < 0.06:
				y = sin(ph / 0.06 * PI) * (0.35 + fear * 0.6)
			elif ph < 0.1:
				y = -sin((ph - 0.06) / 0.04 * PI) * 0.25
			elif ph > 0.3 and ph < 0.42:
				y = sin((ph - 0.3) / 0.12 * PI) * 0.12
			_pts[n - 1] = y + randf_range(-0.02, 0.02) * (1.0 + fear * 2.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.03, 0.75))
		for x in range(0, int(size.x), 10):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.5, 0.25, 0.12))
		var c := Color(0.45, 0.95, 0.5).lerp(Color(1.0, 0.25, 0.15), fear)
		var mid := size.y * 0.55
		var line := PackedVector2Array()
		for i in _pts.size():
			line.append(Vector2(i * 2.0, mid - _pts[i] * size.y * 0.5))
		if line.size() > 1:
			draw_polyline(line, Color(c, 0.35), 3.0)
			draw_polyline(line, c, 1.2)


## Путевой лист обходчика: бумажка с рваным низом и красной печатью смены.
class Slip extends PanelContainer:
	var stamp := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(HudWidgets.PAPER, 0.93)
		st.set_content_margin_all(12)
		st.content_margin_top = 34
		st.content_margin_bottom = 18
		st.shadow_color = Color(0, 0, 0, 0.5)
		st.shadow_size = 6
		st.shadow_offset = Vector2(2, 3)
		add_theme_stylebox_override("panel", st)

	func _draw() -> void:
		# Шапка бланка.
		var f := HudWidgets.oswald(600)
		draw_string(f, Vector2(12, 21), "ПУТЕВОЙ ЛИСТ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(HudWidgets.INK, 0.75))
		draw_line(Vector2(12, 26), Vector2(size.x - 12, 26), Color(HudWidgets.INK, 0.35), 1.0)
		# Рваный низ: тёмные зубцы поверх края.
		var y := size.y - 5.0
		var pts := PackedVector2Array([Vector2(0, y)])
		var x := 0.0
		var k := 0
		while x < size.x:
			x = minf(x + 7.0, size.x)
			pts.append(Vector2(x, y + (5.0 if k % 2 == 0 else 1.0)))
			k += 1
		pts.append(Vector2(size.x, size.y + 2))
		pts.append(Vector2(0, size.y + 2))
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.05, 1.0))
		# Печать.
		if stamp != "":
			var c := Color(0.7, 0.12, 0.1, 0.75)
			var at := Vector2(size.x - 62, 20)
			draw_set_transform(at, -0.18)
			draw_rect(Rect2(-44, -14, 88, 26), c, false, 2.0)
			draw_string(f, Vector2(-40, 5), stamp, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, c)
			draw_set_transform(Vector2.ZERO)
