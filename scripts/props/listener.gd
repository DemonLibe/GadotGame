class_name Listener
extends CharacterBody3D
## Слушатель — житель старой линии. Без глаз: свет ему безразличен.
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
var _unstuck := Unstuck.new()  # обход углов и колонн, чтобы не тёрся о стену
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
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)
	_build()
	_click = AudioStreamPlayer3D.new()
	_click.stream = Sfx.tick()
	_click.unit_size = 5.0
	_click.pitch_scale = 0.6
	add_child(_click)
	Game.noise_made.connect(_on_noise)
	_t = randf() * 10.0


## Модель: Blind Hunter (Mophs, CC-BY-SA 3.0/4.0) — безглазая тварь с пастью во всю голову.
## Бледнее оригинала: под землёй сто лет без света. Смотрит в +Z.
const MODEL := "res://models/listener/listener.obj"
const SKIN := "res://models/listener/listener_albedo.png"
const SCALE := 0.5
const YAW := 0.0  # поворот модели, чтобы пасть смотрела в +Z узла


func _build() -> void:
	var skin := ProcTex.model_skin(SKIN, Color(0.95, 0.85, 0.8), 0.6)
	skin.rim_enabled = true
	skin.rim = 0.35
	_body = Node3D.new()
	add_child(_body)
	_head = Node3D.new()  # поворачивается целиком — «вслушивается»
	_body.add_child(_head)
	var mi := MeshInstance3D.new()
	mi.mesh = load(MODEL)
	mi.material_override = skin
	mi.scale = Vector3.ONE * SCALE
	mi.rotation.y = YAW
	_head.add_child(mi)


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
			_head.rotation.y = sin(_t * 0.4) * 0.25
			_body.rotation.x = 0.0
		"alert":
			_alert -= delta
			_head.rotation.y = move_toward(_head.rotation.y, 0.0, delta * 3.0)
			_head.rotation.z = sin(_t * 9.0) * 0.03
			if _alert <= 0.0:
				state = "listen"
		"charge", "search":
			var target := level.next_waypoint(global_position, _goal) if level else _goal
			var go := target - global_position
			go.y = 0.0
			var left := _goal - global_position
			left.y = 0.0
			if state == "charge":
				_body.rotation.x = 0.12
				if left.length() > 0.5 and go.length() > 0.05:
					v = go.normalized() * SPEED
					rotation.y = atan2(go.x, go.z)
				else:
					state = "search"
					_search = 3.0
			else:
				_body.rotation.x = 0.04
				_search -= delta
				_head.rotation.y = sin(_t * 3.0) * 0.4
				if _search <= 0.0:
					state = "listen"
	v = _unstuck.steer(v, delta)
	velocity.x = v.x
	velocity.z = v.z
	move_and_slide()
	_unstuck.check(self, v, delta)
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
