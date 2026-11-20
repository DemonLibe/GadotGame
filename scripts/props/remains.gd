class_name Remains
extends Node3D
## Останки прежнего обходчика: скелет из частей Dungeon Debris — Skull and Bones (Paul Wortmann, CC0),
## обрывки робы, каска, фонарь, сапоги — у каждого скелета набор и поза свои (зерно — от места, где он лежит).
## pose: "lying" — лежит на полу, "sitting" — сидит, привалившись спиной к стене.
## Голова — к -Z узла; сидящий смотрит в +Z, а стена — позади него, у -Z.

const DIR := "res://models/bones/"
const K := 0.4  # части в наборе крупные — уменьшаем до человеческого роста

var pose := "lying"
var rng := RandomNumberGenerator.new()
var _skull: MeshInstance3D
var _skull_basis := Basis.IDENTITY
var _bone: Material
var _cloth: Material


func _ready() -> void:
	add_to_group("day_objects")
	rng.seed = hash(Vector3(snappedf(position.x, 0.1), snappedf(position.y, 0.1), snappedf(position.z, 0.1)))
	_bone = ProcTex.model_skin(DIR + "bone_albedo.png", Color(0.74, 0.7, 0.6), 0.85)
	# Роба истлела: серо-зелёная ткань, мятая, темнее, чем была.
	_cloth = ProcTex.item("cloth", Color(0.36, 0.38, 0.32), 6.0, 0.95)
	if pose == "sitting":
		_build_sitting()
	else:
		_build_lying()
	_scatter()


# --- Лежит ---------------------------------------------------------------------

func _build_lying() -> void:
	var skull_mat := ProcTex.model_skin(DIR + "skull_albedo.png", Color(0.78, 0.74, 0.64), 0.8)
	var flat := Basis(Vector3.RIGHT, -PI / 2.0)  # части в наборе стоят «как в теле» — кладём на спину
	# Таз и ноги.
	_part(self, "pelvis_2_001", _bone, Vector3(0, 0.09, 0.06), Basis(Vector3.UP, rng.randf_range(-0.14, 0.14)) * flat)
	var kinds := ["straight", "apart", "bent"]
	var bent_taken := false
	var ends: Array[Vector3] = []
	for s: float in [1.0, -1.0]:
		var kind: String = kinds[rng.randi_range(0, 2)]
		if kind == "bent" and bent_taken:
			kind = "apart"
		bent_taken = bent_taken or kind == "bent"
		var pos := Vector3(s * 0.1, 0, 0.42)
		var yaw := s * 0.1
		match kind:
			"apart":
				pos = Vector3(s * 0.2, 0, 0.43)
				yaw = s * rng.randf_range(0.28, 0.5)
			"bent":
				pos = Vector3(s * 0.4, 0, 0.22)
				yaw = s * rng.randf_range(1.0, 1.3)
		yaw += rng.randf_range(-0.07, 0.07)
		_part(self, "leg_2_001", _bone, pos, Basis(Vector3.UP, yaw), s < 0.0)
		ends.append(pos + Vector3(sin(yaw), 0, cos(yaw)) * 0.3)
	# Верх: рёбра, позвоночник, череп, руки — вокруг таза чуть повёрнуты, спина не прямая.
	var torso := Node3D.new()
	torso.position = Vector3(0, 0.02, 0.0)
	torso.rotation.y = rng.randf_range(-0.24, 0.24)
	add_child(torso)
	_torso_parts(torso, skull_mat, flat, false)
	var gear_side := 1.0 if rng.randf() < 0.5 else -1.0
	_rags(0.0, 0.1, 0.5)
	_gear(ends, Vector3(0, 0, -0.66), gear_side)


## Рёбра, позвоночник, череп (и руки, если они лежат на торсе).
func _torso_parts(torso: Node3D, skull_mat: Material, flat: Basis, upright: bool) -> void:
	_part(torso, "spine_2_001", _bone, Vector3(0, 0.08, -0.3), Basis(Vector3.BACK, PI / 2.0))
	# Грудная клетка осела: плоше, чем была, и повёрнута.
	var rib := _part(torso, "ribcage_2_001", _bone, Vector3(rng.randf_range(-0.03, 0.03), 0.0, -0.42),
		Basis(Vector3.FORWARD, rng.randf_range(-0.16, 0.16)) * Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)))
	if not upright:
		rib.scale = Vector3(K, K * 0.78, K)
	# Череп: чаще на месте, но повёрнут; иногда скатился в сторону.
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var roll := rng.randf_range(-0.5, 0.5)
	var pos := Vector3(0, 0.11, -0.66)
	if not upright and rng.randf() < 0.4:
		pos += Vector3(side * rng.randf_range(0.14, 0.3), -0.01, rng.randf_range(-0.12, 0.1))
		roll = side * rng.randf_range(0.8, 1.4)
	_skull_basis = Basis(Vector3.UP, rng.randf_range(-0.7, 0.7)) * Basis(Vector3.FORWARD, roll) * flat
	_skull = _part(torso, "skull_1_001", skull_mat, pos, _skull_basis)
	if upright:
		return
	# Руки: вдоль тела, поперёк груди, раскинуты или над головой — не одинаково.
	var arm_kinds := ["side", "chest", "out", "up", "side"]
	var chest_taken := false
	for s: float in [1.0, -1.0]:
		var kind: String = arm_kinds[rng.randi_range(0, arm_kinds.size() - 1)]
		if kind == "chest" and chest_taken:
			kind = "side"
		chest_taken = chest_taken or kind == "chest"
		var apos := Vector3(s * 0.24, 0, -0.32)
		var ayaw := -s * 0.15
		match kind:
			"chest":
				apos = Vector3(s * 0.05, 0.2, -0.42)
				ayaw = -s * rng.randf_range(1.1, 1.4)
			"out":
				apos = Vector3(s * 0.5, 0, -0.5)
				ayaw = -s * rng.randf_range(1.2, 1.6)
			"up":
				apos = Vector3(s * 0.3, 0, -0.9)
				ayaw = -s * rng.randf_range(0.0, 0.3)
		_part(torso, "arm_2_001", _bone, apos, Basis(Vector3.UP, ayaw + rng.randf_range(-0.1, 0.1)), s < 0.0)


# --- Сидит ---------------------------------------------------------------------

func _build_sitting() -> void:
	var skull_mat := ProcTex.model_skin(DIR + "skull_albedo.png", Color(0.78, 0.74, 0.64), 0.8)
	var flat := Basis(Vector3.RIGHT, -PI / 2.0)
	_part(self, "pelvis_2_001", _bone, Vector3(0, 0.09, 0.04), Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)) * flat)
	# Ноги вытянуты вперёд, одно колено может уйти в сторону.
	var ends: Array[Vector3] = []
	var has_bent := rng.randf() < 0.6
	var bent_side := 1.0 if rng.randf() < 0.5 else -1.0
	for s: float in [1.0, -1.0]:
		var pos := Vector3(s * 0.14, 0, 0.4)
		var yaw := s * rng.randf_range(0.08, 0.3)
		if has_bent and s == bent_side:
			pos = Vector3(s * 0.34, 0, 0.26)
			yaw = s * rng.randf_range(0.8, 1.1)
		_part(self, "leg_2_001", _bone, pos, Basis(Vector3.UP, yaw), s < 0.0)
		ends.append(pos + Vector3(sin(yaw), 0, cos(yaw)) * 0.3)
	# Торс прислонён к стене: откинут назад или осел вперёд.
	var lean := deg_to_rad(rng.randf_range(72.0, 86.0)) if rng.randf() < 0.6 else deg_to_rad(rng.randf_range(42.0, 62.0))
	var torso := Node3D.new()
	torso.position = Vector3(0, 0.07, -0.02)
	torso.rotation = Vector3(lean, rng.randf_range(-0.12, 0.12), rng.randf_range(-0.15, 0.15))
	add_child(torso)
	_torso_parts(torso, skull_mat, flat, true)
	# Осевший вперёд — голова висит на груди.
	if lean < deg_to_rad(65.0):
		_skull.basis = Basis(Vector3.RIGHT, 0.5) * _skull.basis
	# Руки лежат на полу по бокам или на коленях.
	for s: float in [1.0, -1.0]:
		var apos := Vector3(s * 0.3, 0.03, 0.12)
		var ayaw := s * rng.randf_range(0.0, 0.25)
		if rng.randf() < 0.4:
			apos = Vector3(s * 0.2, 0.1, 0.22)  # на бедре
			ayaw = s * 0.1
		_part(self, "arm_2_001", _bone, apos, Basis(Vector3.UP, ayaw), s < 0.0)
	_rags(0.1, 0.0, 0.4)
	_gear(ends, Vector3(0, 0.0, 0.0), 1.0 if rng.randf() < 0.5 else -1.0)


# --- Роба, вещи, разброс -----------------------------------------------------------

## Лохмотья: рваные кусочки ткани вокруг и под костями (две накладывающиеся пластины на кусок), один — на бедре.
func _rags(cx: float, cz: float, spread: float) -> void:
	var count := rng.randi_range(5, 8)
	for i in count:
		var p := Vector3(cx + rng.randf_range(-spread, spread), 0.012 + i * 0.002, cz + rng.randf_range(-0.2 - spread, 0.4))
		var yaw := rng.randf() * TAU
		var w := rng.randf_range(0.09, 0.22)
		var d := rng.randf_range(0.07, 0.17)
		Geo.box(self, p, Vector3(w, 0.012, d), _cloth, false, Basis(Vector3.UP, yaw))
		Geo.box(self, p + Vector3(rng.randf_range(-0.05, 0.05), 0.004, rng.randf_range(-0.05, 0.05)), Vector3(w * 0.6, 0.012, d * 1.3), _cloth, false,
			Basis(Vector3.UP, yaw + rng.randf_range(0.5, 1.2)))
	# Кусок робы лежит поперёк бедра, провисая по кости.
	var drape := Geo.box(self, Vector3(rng.randf_range(0.05, 0.2), 0.1, 0.34), Vector3(0.22, 0.012, 0.14), _cloth, false,
		Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)) * Basis(Vector3.FORWARD, rng.randf_range(-0.25, 0.25)))
	drape.name = "Drape"


## Вещи рядом: каска (почти всегда), фонарь, сапоги, вещмешок — у каждого свой набор.
func _gear(feet: Array[Vector3], head_at: Vector3, side: float) -> void:
	# Каска — недалеко от головы, иногда вверх дном.
	var flipped := rng.randf() < 0.35
	var helmet := Geo.sphere(self, head_at + Vector3(side * rng.randf_range(0.3, 0.6), 0.0, rng.randf_range(-0.25, 0.3)), 0.16,
		ProcTex.item("paint_yellow", Color(0.52, 0.48, 0.34), 5.0))
	(helmet.mesh as SphereMesh).is_hemisphere = true
	helmet.rotation = Vector3(PI if flipped else rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	if flipped:
		helmet.position.y = 0.13
	# Фонарь: корпус и линза, лежит боком.
	if rng.randf() < 0.75:
		var at := Vector3(-side * rng.randf_range(0.35, 0.6), 0.04, rng.randf_range(-0.3, 0.4))
		var yaw := rng.randf() * TAU
		var b := Basis(Vector3.UP, yaw)
		var steel := ProcTex.item("dark_steel", Color.WHITE, 8.0)
		Geo.cylinder(self, at, 0.03, 0.17, steel, b * Basis(Vector3.RIGHT, PI / 2.0))
		Geo.cylinder(self, at + b * Vector3(0, 0, -0.1), 0.04, 0.05, steel, b * Basis(Vector3.RIGHT, PI / 2.0))
		Geo.cylinder(self, at + b * Vector3(0, 0, -0.126), 0.034, 0.006, ProcTex.flat(Color(0.5, 0.52, 0.5), 0.1, 0.0), b * Basis(Vector3.RIGHT, PI / 2.0))
	# Сапоги — на концах ног, стоят носками в стороны.
	if rng.randf() < 0.8:
		for i in feet.size():
			var s := 1.0 if i == 0 else -1.0
			var boot_yaw := s * rng.randf_range(0.0, 0.7)
			var boot := Geo.box(self, feet[i] + Vector3(0, 0.04, 0.06), Vector3(0.1, 0.08, 0.26), ProcTex.item("leather", Color(0.55, 0.5, 0.45), 6.0), false,
				Basis(Vector3.UP, boot_yaw) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15)))
			boot.name = "Boot%d" % i
	# Вещмешок у стены или рядом — у части.
	if rng.randf() < 0.4:
		Geo.box(self, Vector3(side * rng.randf_range(0.55, 0.8), 0.07, rng.randf_range(-0.2, 0.5)), Vector3(0.3, 0.14, 0.38),
			ProcTex.item("canvas", Color(0.6, 0.6, 0.5), 4.0), false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, rng.randf_range(-0.1, 0.1)))


## Кости растащило: пара кучек поменьше вокруг (мыши, сквозняк, кто-то ходил).
func _scatter() -> void:
	for i in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.55, 1.0)
		var frag := _part(self, "bone_pile_2_001", _bone, Vector3(cos(a) * r, 0.0, sin(a) * r * 1.2), Basis(Vector3.UP, rng.randf() * TAU))
		var k := rng.randf_range(0.14, 0.26)
		frag.scale = Vector3.ONE * K * k


# --- Пока не смотришь -------------------------------------------------------
## С третьей смены кости иногда поворачиваются — пока обходчик стоит к ним спиной. Медленно, без звука.
## Когда он обернётся — череп смотрит на него. Лежащий поворачивается целиком, сидящий — только головой.
var _player: Player
var _turned := false
var _noticed := false


func _process(delta: float) -> void:
	if Game.day < 3 or _noticed:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var to := _player.global_position - global_position
	to.y = 0.0
	if to.length() > 9.0:
		return
	var head := global_position + Vector3(0, 0.4, 0)
	var seen := _player.is_looking_at(head, 0.35)
	if not _turned:
		if not seen and to.length() < 6.0 and randf() < delta * 0.25:
			_turned = true
			if pose == "sitting" and _skull != null:
				# Голова поворачивается к обходчику (в осях узла), тело остаётся у стены.
				var local := global_transform.basis.inverse() * to
				_skull.basis = Basis(Vector3.UP, clampf(atan2(local.x, local.z) + PI, -1.3, 1.3)) * _skull.basis
			else:
				# Голова — к обходчику (скелет лежит головой к -Z).
				rotation.y = atan2(-to.x, -to.z) + randf_range(-0.15, 0.15)
	elif seen:
		_noticed = true
		Game.add_fear(10.0)
		Game.play_at(Sfx.creak(), head, -12.0)
		Game.say_once("remains_turned", "Кости лежали иначе. Я помню. Теперь череп смотрит на меня.")


## Часть скелета (.obj из набора): масштаб K, mirror — зеркально по X (левая рука из правой).
static func _part(parent: Node3D, name: String, mat: Material, pos: Vector3, basis: Basis, mirror := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = load(DIR + name + ".obj")
	mi.material_override = mat
	mi.position = pos
	mi.basis = basis
	mi.scale = Vector3(-K if mirror else K, K, K)
	parent.add_child(mi)
	return mi


## Куча костей (для гнезда за решёткой и «декораций» в проходах).
static func bone_pile(parent: Node3D, pos: Vector3, yaw: float, size := 1.0) -> MeshInstance3D:
	var mat := ProcTex.model_skin(DIR + "bone_albedo.png", Color(0.7, 0.66, 0.56), 0.85)
	var mi := _part(parent, "bone_pile_2_001", mat, pos, Basis(Vector3.UP, yaw))
	mi.scale = Vector3.ONE * K * size
	return mi
