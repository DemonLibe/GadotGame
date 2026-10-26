class_name Crawler
extends CharacterBody3D
## Ползун — бледное существо из темноты (с третьей ночи). Ползёт к обходчику,
## в луче фонаря замедляется и шипит. Два попадания из пистолета — и он рассыпается.

const ATTACK_RANGE := 1.4
const DAMAGE := 25.0
const NOTICE_RANGE := 22.0
const LAYER := 16  # слой для пуль

var player: Player
var speed := 2.2
var hp := 2
var _dead := false
var _chasing := false
var _cooldown := 0.0
var _t := 0.0
var _legs: Array[Node3D] = []
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

	var skin := ProcTex.flat(Color(0.72, 0.7, 0.66), 0.4)
	skin.rim_enabled = true
	skin.rim = 0.6
	_body = Node3D.new()
	add_child(_body)
	var torso := Geo.capsule(_body, Vector3(0, 0.45, 0), 0.17, 0.95, skin, Basis(Vector3.RIGHT, PI / 2))
	torso.scale = Vector3(1.0, 1.0, 0.75)
	var head := Geo.sphere(_body, Vector3(0, 0.42, -0.6), 0.14, skin)
	head.scale = Vector3(0.8, 0.9, 1.3)
	var mouth := ProcTex.flat(Color(0.05, 0.02, 0.02), 1.0)
	Geo.box(_body, Vector3(0, 0.36, -0.75), Vector3(0.12, 0.05, 0.04), mouth, false)
	# Четыре длинные коленчатые лапы.
	for z in [-0.3, 0.3]:
		for side in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(float(side) * 0.15, 0.5, float(z))
			_body.add_child(hip)
			var upper := Geo.cylinder(hip, Vector3(float(side) * 0.22, 0.12, 0), 0.03, 0.5, skin, Basis(Vector3.FORWARD, -float(side) * 1.1))
			upper.name = "upper"
			Geo.cylinder(hip, Vector3(float(side) * 0.48, -0.15, 0), 0.025, 0.6, skin, Basis(Vector3.FORWARD, float(side) * 0.35))
			_legs.append(hip)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = Sfx.hiss()
	_hiss.unit_size = 4.0
	add_child(_hiss)


func _physics_process(delta: float) -> void:
	if _dead or player == null:
		return
	_t += delta
	_cooldown -= delta
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	var to := player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if not _chasing and dist < NOTICE_RANGE and player.global_position.y < Level.FLOOR_Y + 5.0:
		_chasing = true
		_hiss.play()
		Game.add_fear(10.0)
		Game.say_once("crawler_first", "Что это?! Оно ползёт ко мне!")
	var v := Vector3.ZERO
	if _chasing and dist > ATTACK_RANGE * 0.8:
		var s := speed
		# Свет его не убивает, но заставляет ползти медленнее.
		if player.is_lighting(global_position + Vector3(0, 0.5, 0)):
			s *= 0.45
			if randf() < 0.01:
				_hiss.play()
		v = to / dist * s
		look_at(global_position + to, Vector3.UP)
	velocity.x = v.x
	velocity.z = v.z
	move_and_slide()
	# Лапы перебирают.
	var moving := v.length() > 0.1
	for i in _legs.size():
		_legs[i].rotation.x = sin(_t * 12.0 + i * 1.6) * 0.5 if moving else 0.0
	_body.position.y = absf(sin(_t * 12.0)) * 0.04 if moving else 0.0
	if _chasing and dist < ATTACK_RANGE and _cooldown <= 0.0:
		_cooldown = 1.3
		player.take_damage(DAMAGE)
		Game.add_fear(15.0)
		Game.play_ui(Sfx.sting(), -6.0)


## Попадание пули.
func hit() -> void:
	if _dead:
		return
	hp -= 1
	_chasing = true
	_hiss.play()
	velocity = -global_transform.basis.z * -3.0
	if hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	collision_layer = 0
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
	tw.tween_property(_body, "scale", Vector3(1.2, 0.05, 1.2), 0.5)
	tw.tween_interval(1.0)
	tw.tween_callback(queue_free)
