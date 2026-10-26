class_name Vent
extends StaticBody3D
## Вентиляционный блок на стене. Забитый фильтр меняется на новый (удерживать E).

const REPLACE_TIME := 2.0

var vent_name := "В-1"
var dirty := false
var _progress := 0.0
var _filter_mat: StandardMaterial3D
var _lamp_mat: StandardMaterial3D
var _dust: CPUParticles3D


func _ready() -> void:
	Geo.box(self, Vector3(0, 0, 0.12), Vector3(0.9, 0.9, 0.24), ProcTex.flat(Color(0.28, 0.31, 0.3), 0.55, 0.6), false)
	_filter_mat = ProcTex.flat(Color.WHITE, 0.95)
	Geo.box(self, Vector3(0, 0, 0.245), Vector3(0.76, 0.76, 0.01), _filter_mat, false)
	var slat := ProcTex.flat(Color(0.2, 0.21, 0.21), 0.5, 0.7)
	for i in 7:
		Geo.box(self, Vector3(0, -0.33 + i * 0.11, 0.265), Vector3(0.8, 0.035, 0.03), slat, false)
	_lamp_mat = ProcTex.emissive(Color.RED, 2.0)
	Geo.sphere(self, Vector3(0.36, 0.38, 0.25), 0.025, _lamp_mat)
	Geo.label(self, Vector3(0, 0.56, 0.245), vent_name, 0, 36, Color(0.9, 0.85, 0.6), true)
	Geo.collider_box(self, Vector3(0.9, 0.9, 0.3), Vector3(0, 0, 0.15))

	# Пыль из забитой решётки — видна только в луче фонаря.
	_dust = CPUParticles3D.new()
	_dust.amount = 12
	_dust.lifetime = 3.0
	_dust.position = Vector3(0, 0, 0.3)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.35, 0.35, 0.02)
	_dust.direction = Vector3(0, 0, 1)
	_dust.spread = 30.0
	_dust.initial_velocity_min = 0.05
	_dust.initial_velocity_max = 0.2
	_dust.gravity = Vector3(0, -0.15, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	var m := ProcTex.flat(Color(0.6, 0.55, 0.5), 1.0)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	_dust.mesh = q
	add_child(_dust)
	set_dirty(dirty)


func set_dirty(value: bool) -> void:
	dirty = value
	_progress = 0.0
	if not is_node_ready():
		return
	_filter_mat.albedo_color = Color(0.2, 0.17, 0.13) if dirty else Color(0.9, 0.9, 0.85)
	var c := Color(1.0, 0.15, 0.1) if dirty else Color(0.2, 1.0, 0.3)
	_lamp_mat.albedo_color = c
	_lamp_mat.emission = c
	_dust.emitting = dirty


func get_prompt(player) -> String:
	if not dirty:
		return "Вентиляция %s — фильтр чистый" % vent_name
	if player.filters <= 0:
		return "Вентиляция %s — фильтр забит. Нужен новый фильтр" % vent_name
	if player.held() != "filter":
		return "Вентиляция %s — возьми фильтр в руки (клавиша 3)" % vent_name
	return "Удерживай E — заменить фильтр в %s" % vent_name


func hold_interact(player, delta: float) -> float:
	if not dirty or player.filters <= 0 or player.held() != "filter":
		return -1.0
	_progress += delta / REPLACE_TIME
	if _progress >= 1.0:
		set_dirty(false)
		player.filters -= 1
		Game.play_at(Sfx.clank(), global_position, -4.0)
		Game.report("filters")
		return -1.0
	return _progress


func hold_cancel() -> void:
	_progress = 0.0
