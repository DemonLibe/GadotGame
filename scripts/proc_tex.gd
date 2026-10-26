class_name ProcTex
extends RefCounted
## Процедурные материалы и текстуры: тюбинги метро, плитка, гранит, щебень,
## краска, рифлёный металл, бетон, паутина, огонь. Всё рисуется кодом один раз и кешируется.

static var _cache := {}


static func concrete(color: Color, scale := 0.3) -> StandardMaterial3D:
	var key := "concrete_%s_%s" % [color.to_html(), scale]
	if _cache.has(key):
		return _cache[key]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.015
	noise.fractal_octaves = 5
	noise.seed = randi()

	var grad := Gradient.new()
	grad.set_color(0, color.darkened(0.55))
	grad.set_color(1, color.lightened(0.12))

	var albedo := NoiseTexture2D.new()
	albedo.width = 512
	albedo.height = 512
	albedo.seamless = true
	albedo.noise = noise
	albedo.color_ramp = grad

	var normal := NoiseTexture2D.new()
	normal.width = 512
	normal.height = 512
	normal.seamless = true
	normal.as_normal_map = true
	normal.bump_strength = 8.0
	normal.noise = noise

	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo
	m.normal_enabled = true
	m.normal_texture = normal
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	_cache[key] = m
	return m


static func flat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func emissive(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Текстура паутины: радиальные нити + спираль. Несколько вариантов кешируются.
static func web_texture(variant := 0) -> ImageTexture:
	var key := "web_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(s / 2.0, s / 2.0) + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	var spokes := randi_range(11, 16)
	var angles: Array[float] = []
	for i in spokes:
		angles.append(TAU * i / spokes + randf_range(-0.12, 0.12))
	for a in angles:
		_line(img, center, center + Vector2.from_angle(a) * s, Color(0.92, 0.92, 0.95, 0.8))
	var r := 7.0
	while r < s * 0.72:
		for i in spokes:
			var a1 := angles[i]
			var a2 := angles[(i + 1) % spokes]
			if i == spokes - 1:
				a2 += TAU
			var r2 := r + randf_range(-2.0, 2.0)
			if randf() < 0.08:
				continue # рваные участки
			_line(img, center + Vector2.from_angle(a1) * r, center + Vector2.from_angle(a2) * r2, Color(0.88, 0.88, 0.92, 0.6))
		r += randf_range(7.0, 12.0)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	if steps <= 0:
		return
	var w := img.get_width()
	var h := img.get_height()
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var x := int(p.x)
		var y := int(p.y)
		if x < 0 or y < 0 or x >= w or y >= h:
			continue
		var old := img.get_pixel(x, y)
		if old.a < c.a:
			img.set_pixel(x, y, c)


static func soft_dot() -> GradientTexture2D:
	if _cache.has("dot"):
		return _cache["dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_cache["dot"] = t
	return t


## Частицы огня (горелка, горящая паутина). По умолчанию выключены.
static func fire(amount := 32, lifetime := 0.5) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 20.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	grad.set_color(1, Color(0.6, 0.05, 0.0, 0.0))
	grad.add_point(0.35, Color(1.0, 0.5, 0.1, 0.9))
	p.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_dot()
	quad.material = m
	p.mesh = quad
	return p


# --- Текстуры поверхностей ----------------------------------------------------
# Картинки собираются нативными операциями Image (fill_rect / blend_rect),
# а цвет задаётся оттенком материала — так генерация быстрая и в браузере.

## Чугунные тюбинги тоннеля метро: фланцы, рёбра, болты, ржавые потёки.
## Материал рассчитан на UV трубы (одна картинка = один тюбинг).
static func tubbing() -> StandardMaterial3D:
	if _cache.has("tubbing"):
		return _cache["tubbing"]
	var s := 256
	var img := _noise(s, 0.025, 4)
	img.adjust_bcs(0.85, 0.35, 1.0)
	var flange := Color(0.7, 0.7, 0.7)
	img.fill_rect(Rect2i(0, 0, s, 10), flange)
	img.fill_rect(Rect2i(0, s - 10, s, 10), flange)
	img.fill_rect(Rect2i(0, 0, 10, s), flange)
	img.fill_rect(Rect2i(s - 10, 0, 10, s), flange)
	var rib := Color(0.58, 0.58, 0.58)
	img.fill_rect(Rect2i(0, s / 2 - 4, s, 8), rib)
	img.fill_rect(Rect2i(s / 2 - 4, 0, 8, s), rib)
	var bolt := Color(0.1, 0.1, 0.1)
	for i in range(16, s, 32):
		img.fill_rect(Rect2i(i - 3, 2, 6, 6), bolt)
		img.fill_rect(Rect2i(i - 3, s - 8, 6, 6), bolt)
		img.fill_rect(Rect2i(2, i - 3, 6, 6), bolt)
		img.fill_rect(Rect2i(s - 8, i - 3, 6, 6), bolt)
	_streaks(img, 8, Color(0.34, 0.18, 0.07), 110, false)
	return _textured("tubbing", img, Color(0.64, 0.6, 0.55), 0.55, 0.3, 4.0, 0.0)


## Те же тюбинги, но с проекцией в мировых координатах — для развилок (CSG).
static func tubbing_triplanar() -> StandardMaterial3D:
	if _cache.has("tubbing_tri"):
		return _cache["tubbing_tri"]
	var m := tubbing().duplicate() as StandardMaterial3D
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 1.65
	_cache["tubbing_tri"] = m
	return m


## Кафельная плитка станции (кирпичная раскладка, затёртые швы, потёки).
static func tiles() -> StandardMaterial3D:
	if _cache.has("tiles"):
		return _cache["tiles"]
	var s := 256
	var img := _noise(s, 0.05, 3)
	img.adjust_bcs(1.6, 0.2, 1.0)
	var tw := 64
	var th := 32
	var grout := Color(0.33, 0.32, 0.3)
	for row in s / th:
		var off := (row % 2) * (tw / 2)
		for col in range(-1, s / tw + 1):
			var x := col * tw + off
			var shade := Image.create(tw, th, false, Image.FORMAT_RGBA8)
			shade.fill(Color(0.0, 0.0, 0.0, randf_range(0.0, 0.14)))
			img.blend_rect(shade, Rect2i(0, 0, tw, th), Vector2i(x, row * th))
			img.fill_rect(Rect2i(x, row * th, 3, th), grout)
		img.fill_rect(Rect2i(0, row * th, s, 3), grout)
	_streaks(img, 6, Color(0.3, 0.25, 0.15), 140, true)
	return _textured("tiles", img, Color(0.85, 0.83, 0.75), 0.35, 0.0, 2.5, 1.2)


## Гранитные плиты пола станции.
static func granite() -> StandardMaterial3D:
	if _cache.has("granite"):
		return _cache["granite"]
	var s := 256
	var img := _noise(s, 0.12, 2, FastNoiseLite.TYPE_CELLULAR)
	img.adjust_bcs(0.9, 0.5, 1.0)
	for i in range(0, s, 128):
		img.fill_rect(Rect2i(i, 0, 2, s), Color(0.15, 0.15, 0.15))
		img.fill_rect(Rect2i(0, i, s, 2), Color(0.15, 0.15, 0.15))
	return _textured("granite", img, Color(0.55, 0.5, 0.47), 0.5, 0.0, 1.5, 2.0)


## Щебень путевого полотна.
static func ballast() -> StandardMaterial3D:
	if _cache.has("ballast"):
		return _cache["ballast"]
	var img := _noise(256, 0.09, 1, FastNoiseLite.TYPE_CELLULAR)
	img.adjust_bcs(1.0, 0.8, 1.0)
	return _textured("ballast", img, Color(0.42, 0.4, 0.37), 1.0, 0.0, 6.0, 1.2)


## Бетон со швами колец (шахта, камеры развилок).
static func concrete_rings() -> StandardMaterial3D:
	if _cache.has("rings"):
		return _cache["rings"]
	var s := 256
	var img := _noise(s, 0.02, 5)
	img.adjust_bcs(1.0, 0.45, 1.0)
	img.fill_rect(Rect2i(0, 0, s, 4), Color(0.2, 0.2, 0.2))
	img.fill_rect(Rect2i(0, s / 2, s, 3), Color(0.3, 0.3, 0.3))
	_streaks(img, 5, Color(0.2, 0.18, 0.12), 120, true)
	return _textured("rings", img, Color(0.5, 0.49, 0.46), 0.95, 0.0, 3.0, 2.5)


## Облупившаяся краска (стены комнаты с люком).
static func paint(tint: Color, key: String) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var s := 256
	var img := _noise(s, 0.04, 3)
	img.adjust_bcs(1.5, 0.15, 1.0)
	for i in 45:
		var w := randi_range(3, 14)
		var h := randi_range(2, 9)
		img.fill_rect(Rect2i(randi_range(0, s - w), randi_range(0, s - h), w, h), Color(0.45, 0.43, 0.4))
	return _textured(key, img, tint, 0.85, 0.0, 2.0, 1.5)


## Рифлёный стальной лист (крышка люка).
static func plate() -> StandardMaterial3D:
	if _cache.has("plate"):
		return _cache["plate"]
	var s := 256
	var img := _noise(s, 0.06, 3)
	img.adjust_bcs(0.9, 0.3, 1.0)
	for y in range(0, s, 16):
		var off := 8 if (y / 16) % 2 == 1 else 0
		for x in range(0, s, 16):
			img.fill_rect(Rect2i(x + off, y + 6, 8, 3), Color(0.8, 0.8, 0.8))
	return _textured("plate", img, Color(0.45, 0.46, 0.48), 0.45, 0.7, 3.0, 0.8)


static func _noise(size: int, freq: float, octaves := 4, type := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = randi()
	var img := n.get_seamless_image(size, size)
	img.convert(Image.FORMAT_RGBA8)
	return img


## Полосы-потёки, затухающие к концу. vertical = false — вдоль строк картинки.
static func _streaks(img: Image, count: int, c: Color, max_len: int, vertical: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for k in count:
		var thick := randi_range(3, 7)
		var length := randi_range(30, max_len)
		var sw := thick if vertical else length
		var sh := length if vertical else thick
		var streak := Image.create(sw, sh, false, Image.FORMAT_RGBA8)
		for i in length:
			var a := 0.55 * (1.0 - float(i) / length)
			if vertical:
				streak.fill_rect(Rect2i(0, i, thick, 1), Color(c.r, c.g, c.b, a))
			else:
				streak.fill_rect(Rect2i(i, 0, 1, thick), Color(c.r, c.g, c.b, a))
		img.blend_rect(streak, Rect2i(0, 0, sw, sh), Vector2i(randi_range(0, w - sw), randi_range(0, h - sh)))


## world_size > 0 — трипланар в мировых координатах (картинка = world_size метров), иначе UV меша.
static func _textured(key: String, albedo: Image, tint: Color, roughness: float, metallic: float, bump: float, world_size: float) -> StandardMaterial3D:
	var normal := albedo.duplicate() as Image
	normal.bump_map_to_normal_map(bump)
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(albedo)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(normal)
	m.roughness = roughness
	m.metallic = metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if world_size > 0.0:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / world_size
	else:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m
