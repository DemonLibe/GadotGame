class_name Double
extends Node3D
## Двойник (4–5 и 7 смены): далеко в тоннеле стоит обходчик в каске и светит налобником прямо в глаза.
## Подойдёшь ближе — фонарь гаснет, и там никого. Только каска на полу.

const VANISH_DIST := 15.0
const LIFE := 14.0

var player: Player
var _life := LIFE
var _lamp: SpotLight3D
var _gone := false


func _ready() -> void:
	add_to_group("day_objects")
	# Силуэт: тёмная роба, голова, жёлтая каска. В слепящем луче видно только очертания.
	var cloth := ProcTex.flat(Color(0.05, 0.05, 0.05), 1.0)
	var body := Geo.capsule(self, Vector3(0, 0.95, 0), 0.25, 1.3, cloth)
	body.scale.x = 1.3
	Geo.sphere(self, Vector3(0, 1.72, 0), 0.13, cloth)
	var helmet := Geo.sphere(self, Vector3(0, 1.78, 0), 0.16, ProcTex.flat(Color(0.75, 0.6, 0.1), 0.5))
	(helmet.mesh as SphereMesh).is_hemisphere = true
	Geo.capsule(self, Vector3(-0.32, 1.0, 0), 0.07, 0.75, cloth)
	Geo.capsule(self, Vector3(0.32, 1.0, 0), 0.07, 0.75, cloth)
	Geo.sphere(self, Vector3(0, 1.8, -0.15), 0.035, ProcTex.emissive(Color(1.0, 0.95, 0.8), 6.0))
	_lamp = SpotLight3D.new()
	_lamp.position = Vector3(0, 1.8, -0.18)
	_lamp.light_color = Color(1.0, 0.95, 0.85)
	_lamp.light_energy = 6.0
	_lamp.spot_range = 30.0
	_lamp.spot_angle = 18.0
	_lamp.shadow_enabled = false
	add_child(_lamp)


func _process(delta: float) -> void:
	if _gone or player == null:
		return
	# Смотрит и светит на обходчика.
	var p := player.global_position
	look_at(Vector3(p.x, global_position.y, p.z), Vector3.UP)
	_lamp.look_at(player.camera.global_position, Vector3.UP)
	_life -= delta
	if global_position.distance_to(p) < VANISH_DIST or _life <= 0.0:
		_vanish()


func _vanish() -> void:
	_gone = true
	Game.play_at(Sfx.click(), global_position + Vector3(0, 1.8, 0), 2.0)
	# Каска остаётся на полу — там, где он стоял.
	var helmet := Geo.sphere(get_parent(), Vector3(global_position.x, Level.FLOOR_Y, global_position.z), 0.16, ProcTex.flat(Color(0.75, 0.6, 0.1), 0.5))
	(helmet.mesh as SphereMesh).is_hemisphere = true
	helmet.rotation = Vector3(0.5, randf() * TAU, 0.3)
	helmet.add_to_group("day_objects")
	if player.global_position.distance_to(global_position) < 25.0:
		Game.add_fear(15.0)
		Game.say_once("double", "Его фонарь погас — и никого. Только каска. Жёлтая. Как моя.", Game.THOUGHT, 4.5)
	queue_free()
