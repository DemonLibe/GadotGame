class_name ProcTex
extends RefCounted
## Процедурные материалы и текстуры: бетон, паутина, огонь.

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
