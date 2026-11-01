class_name Listener
extends CharacterBody3D
## Слушатель — житель старой линии. Высокий, из одних костей, без глаз: свет ему безразличен.
## Стоит неподвижно и слушает. Первый звук — поворачивает голову и щёлкает,
## второй, пока он настороже, — бросается туда, откуда услышал. Медленно и пригнувшись мимо пройти можно,
## бегом — нет. Громкий звук (бег, прыжок, ручка динамо, болт) — бросается сразу. Болт уводит его в сторону. Пули его не берут — только злят.

const DAMAGE := 40.0
const SPEED := 6.2
const HIT_RANGE := 1.3
const ALERT_TIME := 2.5     # сколько он настороже после первого звука
const HEAR_MULT := 1.3      # слышит чуть дальше ползуна
const TOUCH := 1.0          # вплотную чувствует и без звука
const LOUD := 10.0          # громкий звук (бег, прыжок, ручка, болт, выстрел) — бросается сразу

var player: Player
var level: Level
var state := "listen"  # listen / alert / charge / search
var _alert := 0.0
var _goal := Vector3.ZERO
var _search := 0.0
var _cooldown := 0.0
var _t := 0.0
var _body: Node3D
var _head: Node3D
var _click: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("day_objects")
	add_to_group("creatures")
	collision_layer = Crawler.LAYER
	collision_mask = 1 | Geo.WALL_LAYER
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 2.2
	shape.shape = cap
	shape.position.y = 1.1
	add_child(shape)
	_build()
	_click = AudioStreamPlayer3D.new()
	_click.stream = Sfx.tick()
	_click.unit_size = 5.0
	_click.pitch_scale = 0.6
	add_child(_click)
	Game.noise_made.connect(_on_noise)
	_t = randf() * 10.0


## Скелет из частей Dungeon Debris (как у останков), только стоймя, вытянутый и с длинными руками.
func _build() -> void:
	var bone := ProcTex.model_skin(Remains.DIR + "bone_albedo.png", Color(0.55, 0.52, 0.47), 0.85)
	bone.rim_enabled = true
	bone.rim = 0.4
	var skull_mat := ProcTex.model_skin(Remains.DIR + "skull_albedo.png", Color(0.6, 0.56, 0.5), 0.8)
	_body = Node3D.new()
	add_child(_body)
	# Части лежат вдоль Z (голова к -Z, лицом вверх) — поворот на 90° по X ставит их стоймя лицом к +Z.
	var lying := Node3D.new()
	lying.rotation.x = PI / 2
	lying.scale = Vector3.ONE * 1.45
	lying.position.y = 1.15
	_body.add_child(lying)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.1, -0.6)
	lying.add_child(_head)
	Remains._part(_head, "skull_1_001", skull_mat, Vector3(0, 0.03, -0.06), Vector3(-PI / 2, 0, 0))
	Remains._part(lying, "spine_2_001", bone, Vector3(0, 0.08, -0.3), Vector3(0, 0, PI / 2))
	Remains._part(lying, "ribcage_2_001", bone, Vector3(0, 0.02, -0.42), Vector3.ZERO)
	for s in [-1.0, 1.0]:
		var arm := Remains._part(lying, "arm_2_001", bone, Vector3(s * 0.26, 0.02, -0.12), Vector3(0, -s * 0.08, 0), s < 0.0)
		arm.scale.z *= 1.6  # руки до колен
		var leg := Remains._part(lying, "leg_2_001", bone, Vector3(s * 0.11, 0, 0.42), Vector3(0, s * 0.05, 0), s < 0.0)
		leg.scale.z *= 1.15
	Remains._part(lying, "pelvis_2_001", bone, Vector3(0, 0.09, 0.06), Vector3(-PI / 2, 0, 0))


## Слух — единственное, что у него есть.
func _on_noise(pos: Vector3, radius: float) -> void:
	if level and not level.same_floor(global_position, pos):
		return
	if global_position.distance_to(pos) > radius * HEAR_MULT:
		return
	_heard(pos, radius)


func _heard(pos: Vector3, radius: float) -> void:
	if radius >= LOUD:
		_charge(pos)
		return
	match state:
		"listen", "search":
			state = "alert"
			_alert = ALERT_TIME
			_goal = pos
			_click.play()
			_face(pos)
			if global_position.distance_to(player.global_position) < 14.0:
				Game.say_once("listener_alert", "Щёлкает... Повернул голову. Он меня слышит. Не шуметь.", Game.THOUGHT, 3.5)
		"alert", "charge":
			_charge(pos)


func _charge(pos: Vector3) -> void:
	if state != "charge":
		Game.play_at(Sfx.scream(), global_position + Vector3(0, 2.0, 0), -4.0)
		Game.add_fear(12.0)
	state = "charge"
	_goal = pos


## Пуля его не берёт — только выдаёт стрелка.
func hit() -> void:
	_charge(player.global_position)


func _face(pos: Vector3) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length() > 0.1:
		rotation.y = atan2(to.x, to.z)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	_cooldown -= delta
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	var v := Vector3.ZERO
	match state:
		"listen":
			# Покачивается и медленно водит головой.
			_head.rotation.y = sin(_t * 0.4) * 0.5
			_body.rotation.x = 0.0
		"alert":
			_alert -= delta
			_head.rotation.y = move_toward(_head.rotation.y, 0.0, delta * 3.0)
			_head.rotation.z = sin(_t * 9.0) * 0.08
			if _alert <= 0.0:
				state = "listen"
		"charge", "search":
			var target := level.next_waypoint(global_position, _goal) if level else _goal
			var go := target - global_position
			go.y = 0.0
			var left := _goal - global_position
			left.y = 0.0
			if state == "charge":
				_body.rotation.x = 0.35
				if left.length() > 0.5 and go.length() > 0.05:
					v = go.normalized() * SPEED
					rotation.y = atan2(go.x, go.z)
				else:
					state = "search"
					_search = 3.0
			else:
				_body.rotation.x = 0.1
				_search -= delta
				_head.rotation.y = sin(_t * 3.0) * 0.7
				if _search <= 0.0:
					state = "listen"
	velocity.x = v.x
	velocity.z = v.z
	move_and_slide()
	# Вплотную он чувствует и тишину.
	var to_p := player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	if state == "listen" and dist < TOUCH:
		_charge(player.global_position)
	if (state == "charge" or state == "search") and dist < HIT_RANGE and _cooldown <= 0.0 \
			and absf(player.global_position.y - global_position.y) < 1.5:
		_cooldown = 1.6
		player.take_damage(DAMAGE)
		Game.add_fear(20.0)
		Game.play_ui(Sfx.sting(), -4.0)
		state = "search"
		_search = 2.0
		_goal = player.global_position
