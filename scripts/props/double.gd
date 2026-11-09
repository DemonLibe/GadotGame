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
	# Силуэт: тёмная роба, жёлтая каска. В слепящем луче видно только очертания.
	var cloth := ProcTex.flat(Color(0.05, 0.05, 0.05), 1.0)
	var head_y := 1.72
	if ResourceLoader.exists(WORKER):
		head_y = _build_worker()
	else:
		var body := Geo.capsule(self, Vector3(0, 0.95, 0), 0.25, 1.3, cloth)
		body.scale.x = 1.3
		Geo.sphere(self, Vector3(0, 1.72, 0), 0.13, cloth)
		Geo.capsule(self, Vector3(-0.32, 1.0, 0), 0.07, 0.75, cloth)
		Geo.capsule(self, Vector3(0.32, 1.0, 0), 0.07, 0.75, cloth)
	var helmet := Geo.sphere(self, Vector3(0, head_y + 0.06, 0), 0.16, ProcTex.flat(Color(0.75, 0.6, 0.1), 0.5))
	(helmet.mesh as SphereMesh).is_hemisphere = true
	Geo.sphere(self, Vector3(0, head_y + 0.08, -0.15), 0.035, ProcTex.emissive(Color(1.0, 0.95, 0.8), 6.0))
	_lamp = SpotLight3D.new()
	_lamp.position = Vector3(0, head_y + 0.08, -0.18)
	_lamp.light_color = Color(1.0, 0.95, 0.85)
	_lamp.light_energy = 6.0
	_lamp.spot_range = 30.0
	_lamp.spot_angle = 18.0
	_lamp.shadow_enabled = false
	add_child(_lamp)


## Фигура человека (Universal Base Characters, Quaternius, CC0) в тёмной робе, руки опущены.
## Модель без анимаций, в позе «Т» — руки опускаем поворотом костей. Возвращает высоту головы.
const WORKER := "res://models/worker/worker.gltf"
const HEIGHT := 1.78


func _build_worker() -> float:
	var m := (load(WORKER) as PackedScene).instantiate() as Node3D
	m.rotation.y = PI  # лицом к -Z узла: узел смотрит на обходчика через look_at
	add_child(m)
	var skin := ProcTex.model_skin("res://models/worker/worker_albedo.png", Color(0.16, 0.16, 0.15), 0.95)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = skin
	var sk := m.find_children("*", "Skeleton3D", true, false)
	if not sk.is_empty():
		var skel := sk[0] as Skeleton3D
		# Поворот в осях модели (вокруг оси «спина—грудь»), пересчитанный в локальные оси кости.
		for side in [["upperarm_l", -1.0], ["upperarm_r", 1.0]]:
			var b := skel.find_bone(side[0])
			if b < 0:
				continue
			var pg := skel.get_bone_global_pose(skel.get_bone_parent(b)).basis.get_rotation_quaternion()
			var turn := Quaternion(Vector3.BACK, deg_to_rad(ARM_DOWN) * float(side[1]))
			skel.set_bone_pose_rotation(b, pg.inverse() * turn * pg * skel.get_bone_pose_rotation(b))
	var box := Geo.mesh_bounds(m)
	var k := HEIGHT / maxf(box.size.y, 0.001)
	m.scale = Vector3.ONE * k
	m.position.y = -box.position.y * k
	return HEIGHT - 0.1


const ARM_DOWN := 70.0


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
