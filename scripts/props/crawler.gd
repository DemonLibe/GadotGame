class_name Crawler
extends CharacterBody3D
## Ползун — бледное существо из темноты (с третьей ночи). Почти слепое: видит вблизи
## и видит свет фонаря, зато слышит шаги, бег, выстрелы. Бродит, идёт на шум, гонится.
## От того, кто сидит в шкафу и не дышит, уходит ни с чем.
## Два попадания из пистолета — и он рассыпается.

const ATTACK_RANGE := 1.4
const DAMAGE := 25.0
const SIGHT_DARK := 4.0     # видит обходчика без фонаря
const SIGHT_LIT := 16.0     # видит фонарь
const LOSE_TIME := 6.0
const LAYER := 16  # слой для пуль

var player: Player
var level: Level
var speed := 2.2
var hp := 2
var state := "wander"  # wander / investigate / chase
var _dead := false
var _cooldown := 0.0
var _think := 0.0
var _goal := Vector3.ZERO
var _wait := 0.0
var _unseen := 0.0
var _anim: AnimationPlayer
var _body: Node3D
var _hiss: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("day_objects")
	add_to_group("creatures")
	collision_layer = LAYER
	collision_mask = 1 | Geo.WALL_LAYER
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 0.9
	shape.shape = cap
	shape.rotation.x = PI / 2
	shape.position.y = 0.4
	add_child(shape)

	# Модель: Alien Bug Animated (CDmir, CC0) в рост собаки, бледная. Смотрит в +Z — разворачиваем.
	var skin := ProcTex.model_skin("res://models/alien_bug/bug_albedo.png", Color(0.85, 0.82, 0.76), 0.4)
	skin.rim_enabled = true
	skin.rim = 0.6
	_body = Geo.model(self, "res://models/alien_bug/alien-bug.glb", skin, Vector3.ZERO, Basis(Vector3.UP, PI).scaled(Vector3.ONE * 1.9))
	_anim = Geo.model_anim(_body, ["Idle", "Run"])
	_anim.play("Idle")
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = Sfx.hiss()
	_hiss.unit_size = 4.0
	add_child(_hiss)
	Game.noise_made.connect(_on_noise)
	_goal = global_position
	_wait = randf_range(0.5, 2.0)


## Слух: шаги, бег, выстрел, вдох в шкафу.
func _on_noise(pos: Vector3, radius: float) -> void:
	if _dead or state == "chase":
		return
	if global_position.distance_to(pos) > radius:
		return
	state = "investigate"
	_goal = pos
	_wait = 0.0
	if randf() < 0.5:
		_hiss.play()


func _physics_process(delta: float) -> void:
	if _dead or player == null:
		return
	_cooldown -= delta
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	_think -= delta
	if _think <= 0.0:
		_think = 0.2
		_perceive()
	var to := player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var target := player.global_position if state == "chase" else _goal
	var s := speed
	match state:
		"wander":
			s *= 0.45
		"investigate":
			s *= 0.8
	# Свет его не убивает, но заставляет ползти медленнее.
	if player.is_lighting(global_position + Vector3(0, 0.5, 0)):
		s *= 0.45
		if randf() < 0.01:
			_hiss.play()
	var v := Vector3.ZERO
	var go := target - global_position
	go.y = 0.0
	if _wait > 0.0:
		_wait -= delta
	elif go.length() > (ATTACK_RANGE * 0.8 if state == "chase" else 0.6):
		v = go.normalized() * s
		look_at(global_position + go, Vector3.UP)
	else:
		_arrived()
	velocity.x = v.x
	velocity.z = v.z
	move_and_slide()
	# Бег, пока ползёт; удар не прерываем.
	var moving := v.length() > 0.1
	if not _anim.current_animation.begins_with("Attack"):
		_anim.play("Run" if moving else "Idle", 0.2)
		_anim.speed_scale = clampf(v.length() / 2.0, 0.6, 1.6) if moving else 1.0
	if state == "chase" and dist < ATTACK_RANGE and _cooldown <= 0.0:
		_cooldown = 1.3
		_anim.speed_scale = 1.0
		_anim.play("Attack_000" if randf() < 0.5 else "Attack_001", 0.1)
		if player.hiding:
			player.exit_hide()  # вытащил из шкафа
		player.take_damage(DAMAGE)
		Game.add_fear(15.0)
		Game.play_ui(Sfx.sting(), -6.0)


## Видит ли он обходчика.
func _perceive() -> void:
	if player.global_position.y > Level.FLOOR_Y + 5.0:
		if state == "chase":
			_lose()
		return
	var eye := global_position + Vector3(0, 0.5, 0)
	var dist := eye.distance_to(player.global_position + Vector3(0, 1.0, 0))
	var sees := false
	if player.hiding:
		# В шкафу выдаёт только фонарь сквозь щели или дыхание вплотную.
		if player.has_light() and dist < 8.0:
			sees = true
		elif dist < 2.5 and not player.holding_breath and randf() < 0.25:
			sees = true
	else:
		var r := SIGHT_LIT if player.has_light() else SIGHT_DARK
		if player.crouching and not player.has_light():
			r *= 0.6
		sees = dist < r and _clear(eye, player.camera.global_position)
	if sees:
		if state != "chase":
			_hiss.play()
			Game.add_fear(10.0)
			Game.say_once("crawler_first", "Что это?! Оно ползёт ко мне!")
		state = "chase"
		_unseen = 0.0
		_goal = player.global_position
	elif state == "chase":
		_unseen += 0.2
		if not player.hiding:
			_goal = player.global_position
		if _unseen > LOSE_TIME or (player.hiding and _unseen > 1.0):
			_lose()


func _lose() -> void:
	state = "investigate"
	_wait = 0.0
	Game.say_once("crawler_lost", "Оно... потеряло меня? Не шевелиться.", Game.THOUGHT, 3.0)


func _arrived() -> void:
	# Пришёл на шум или к точке обхода — постоять, принюхаться, выбрать новую цель.
	_wait = randf_range(2.0, 4.5)
	state = "wander"
	_goal = _wander_point()


func _wander_point() -> Vector3:
	var p := global_position
	if level == null:
		return p
	var axis := level.axis_at(p)
	for i in 6:
		var q := p + axis * randf_range(-10.0, 10.0)
		q.y = p.y
		if level.is_walkable(q):
			return q
	return p


func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | Geo.WALL_LAYER)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Попадание пули.
func hit() -> void:
	if _dead:
		return
	hp -= 1
	state = "chase"
	_unseen = 0.0
	_hiss.play()
	velocity = -global_transform.basis.z * -3.0
	if hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	collision_layer = 0
	Achievements.unlock("hunter")
	_anim.pause()
	var dust := ProcTex.fire(40, 0.9)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.1, 0.1, 0.1, 0.9))
	grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	dust.color_ramp = grad
	(dust.mesh.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.4
	dust.position.y = 0.4
	dust.one_shot = true
	add_child(dust)
	dust.emitting = true
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3(2.3, 0.1, 2.3), 0.5)
	tw.tween_interval(1.0)
	tw.tween_callback(queue_free)
