class_name Spider
extends Node3D
## Безобидный паук. Ползает по стене, удирает от огня и время от времени плетёт новую паутину.
## Существо пауки чуют раньше человека: разбегаются — значит, оно рядом.

var main  # Main — для spawn_small_web()
var player: Player
var wall_x := 0.0
var normal := Vector3.RIGHT  # нормаль стены, на которой сидит паук
var home_z := -60.0
var range_z := 6.0
var floor_y := -15.0

var _target := Vector3.ZERO
var _wait := 0.0
var _weave := 40.0
var _webs_made := 0
var _anim: AnimationPlayer
var _scan := 0.0
var _alarm := 0.0       # чует существо — удирает
var _flee_from := Vector3.ZERO


func _ready() -> void:
	add_to_group("day_objects")
	add_to_group("spiders")
	global_position = Vector3(wall_x, floor_y + randf_range(0.6, 2.6), home_z)
	# Модель: Alien Bug Animated (CDmir, CC0), уменьшенная до паука. Смотрит в +Z — разворачиваем.
	var skin := ProcTex.model_skin("res://models/alien_bug/bug_albedo.png", Color(0.2, 0.17, 0.15), 0.55)
	var model := Geo.model(self, "res://models/alien_bug/alien-bug.glb", skin, Vector3.ZERO, Basis(Vector3.UP, PI).scaled(Vector3.ONE * 0.38))
	_anim = Geo.model_anim(model, ["Idle", "Run"])
	_anim.play("Idle")
	# Невидимая «мишень» для луча взаимодействия (слой 2).
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	_weave = randf_range(30.0, 70.0)
	_pick_target()
	_orient(Vector3.UP)


func get_prompt(_player) -> String:
	return "Паук. Безобидный — только плетёт паутину"


func _pick_target() -> void:
	_target = Vector3(wall_x, floor_y + randf_range(0.4, 2.9), home_z + randf_range(-range_z, range_z))


func _orient(dir: Vector3) -> void:
	var d := dir - normal * dir.dot(normal)
	if d.length() < 0.01:
		return
	global_transform.basis = Basis.looking_at(d.normalized(), normal)


## Разбежаться: что-то идёт со стороны from.
func alarm(from: Vector3) -> void:
	if _alarm <= 0.0 and randf() < 0.5:
		Game.play_at(Sfx.scuttle(), global_position, -8.0)
	_alarm = 4.0
	_flee_from = from


func _process(delta: float) -> void:
	var speed := 0.35
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		for n in get_tree().get_nodes_in_group("creatures"):
			var c := n as Node3D
			if c and c.global_position.distance_to(global_position) < 15.0:
				alarm(c.global_position)
				if player and player.global_position.distance_to(global_position) < 10.0:
					Game.say_once("spiders_run", "Пауки... разбегаются. Все разом. Что-то идёт.", Game.THOUGHT, 3.5)
				break
	if _alarm > 0.0:
		_alarm -= delta
		var dir := signf(global_position.z - _flee_from.z)
		if dir == 0.0:
			dir = 1.0
		_target = Vector3(wall_x, clampf(global_position.y + 0.3, floor_y + 0.4, floor_y + 2.9), global_position.z + dir * 2.0)
		_wait = 0.0
		speed = 2.0
	if player and player.is_burning() and player.global_position.distance_to(global_position) < 3.5:
		var away := signf(global_position.z - player.global_position.z)
		if away == 0.0:
			away = 1.0
		var z := clampf(global_position.z + away * 3.0, home_z - range_z * 2.0, home_z + range_z * 2.0)
		_target = Vector3(wall_x, global_position.y, z)
		_wait = 0.0
		speed = 1.6
		Game.say_once("spider_flee", "Боится огня. Хоть кто-то здесь боится меня.")

	var moving := false
	if _wait > 0.0:
		_wait -= delta
	else:
		var to := _target - global_position
		var dist := to.length()
		if dist < 0.05:
			_wait = randf_range(1.5, 6.0)
			_pick_target()
		else:
			global_position += to / dist * minf(speed * delta, dist)
			_orient(to)
			moving = true
	if _anim.current_animation != "Attack_000":
		_anim.play("Run" if moving else "Idle", 0.15)
		_anim.speed_scale = clampf(speed * 2.0, 1.0, 3.0) if moving else 1.0

	_weave -= delta
	if _weave <= 0.0:
		_weave = randf_range(45.0, 90.0)
		if _webs_made < 2 and main:
			_webs_made += 1
			_anim.play("Attack_000", 0.1)  # выпускает нить
			main.spawn_small_web(global_position + normal * 0.5, 1.0)
