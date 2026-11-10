class_name Trolley
extends StaticBody3D
## Ручная дрезина на путях основного тоннеля. Быстро — но рычаг лязгает на весь тоннель, и качать его надо самому:
## выдохся — катишься по инерции. Через паутину и ограждение не проедет. Стоит за вагонеткой, у ПК 5.

const HOME_Z := -176.0       # где стоит в начале смены (дальше вагонетки — путь к станции занят ею)
const MAX_SPEED := 9.0
const ACCEL := 2.6
const FRICTION := 1.1
const BRAKE := 5.0
const PUMP_STAMINA := 9.0    # расход выносливости в секунду, пока качаешь

var main  # Main
var speed := 0.0             # вдоль z: минус — вглубь
var rider = null
var _lever: Node3D
var _phase := 0.0
var _clack := 0.0
var _noise := 0.0
var _roll: AudioStreamPlayer3D


func _ready() -> void:
	var steel := ProcTex.flat(Color(0.28, 0.27, 0.26), 0.6, 0.7)
	var rust := ProcTex.flat(Color(0.36, 0.21, 0.13), 0.85, 0.4)
	var wood := ProcTex.flat(Color(0.27, 0.2, 0.13), 0.9)
	Geo.box(self, Vector3(0, 0.36, 0), Vector3(1.3, 0.1, 2.0), wood, false)
	for sx in [-0.6, 0.6]:
		Geo.box(self, Vector3(sx, 0.27, 0), Vector3(0.08, 0.12, 2.0), rust, false)
		for sz in [-0.65, 0.65]:
			Geo.cylinder(self, Vector3(sx, 0.2, sz), 0.2, 0.07, steel, Basis(Vector3.FORWARD, PI / 2))
	# Стойка и коромысло рычага.
	Geo.box(self, Vector3(0, 0.85, 0), Vector3(0.1, 0.9, 0.1), rust, false)
	_lever = Node3D.new()
	_lever.position = Vector3(0, 1.28, 0)
	add_child(_lever)
	Geo.box(_lever, Vector3.ZERO, Vector3(0.06, 0.06, 1.5), steel, false)
	for sz in [-0.75, 0.75]:
		Geo.box(_lever, Vector3(0, 0, sz), Vector3(0.5, 0.05, 0.05), steel, false)
	Geo.label(self, Vector3(0.66, 0.3, 0), "ДР-2", 90, 26, Color(0.85, 0.8, 0.6), true, 0.003)
	Geo.collider_box(self, Vector3(1.3, 0.42, 2.0), Vector3(0, 0.21, 0))
	_roll = AudioStreamPlayer3D.new()
	_roll.stream = Sfx.pump()
	_roll.unit_size = 6.0
	_roll.volume_db = -60.0
	_roll.position = Vector3(0, 0.3, 0)
	add_child(_roll)
	_roll.play()


func reset() -> void:
	position = Vector3(Level.TUN_CX, Level.FLOOR_Y, HOME_Z)
	speed = 0.0
	rider = null


func get_prompt(player) -> String:
	if player.riding == self:
		if absf(speed) > 1.5:
			return "W / S — качать рычаг · S против хода — тормоз"
		return "E — сойти · W / S — качать рычаг (лязг слышно далеко)"
	return "Дрезина — E: встать на площадку"


func interact(player) -> void:
	if player.riding == self:
		if absf(speed) > 1.5:
			return
		player.riding = null
		rider = null
		player.global_position = global_position + Vector3(-1.05, 0.05, 0)
		return
	if player.hiding or player.climbing:
		return
	player.riding = self
	rider = player
	Game.say_once("trolley", "Ручная дрезина. Быстрее, чем пешком, — и слышно её, наверное, до самой решётки.", Game.THOUGHT, 4.5)


## Сесть на место обходчика: пока он на площадке — рычаг его руками. push: +1 — по взгляду, -1 — назад.
func pump(push: float, look_z: float, delta: float, can_pump: bool) -> void:
	if push == 0.0 or not can_pump:
		return
	var want := signf(look_z) * push   # куда по z хочет ехать
	if speed != 0.0 and signf(speed) != want:
		speed = move_toward(speed, 0.0, BRAKE * delta)
	else:
		speed = clampf(speed + want * ACCEL * delta, -MAX_SPEED, MAX_SPEED)


func _physics_process(delta: float) -> void:
	if rider != null and (not is_instance_valid(rider) or rider.riding != self):
		rider = null
	speed = move_toward(speed, 0.0, FRICTION * delta * (1.0 if rider != null else 2.5))
	var k := absf(speed) / MAX_SPEED
	_roll.volume_db = lerpf(-60.0, -4.0, clampf(k * 2.0, 0.0, 1.0))
	_roll.pitch_scale = lerpf(0.6, 1.3, k)
	if speed == 0.0:
		return
	var z := position.z + speed * delta
	# Границы: дальше стоянки к станции путь занят вагонеткой; вглубь — ограждение смены или решётка.
	var deep := maxf(main.day_limit() + 3.5, Level.GRATE_Z + 3.5) if main else Level.GRATE_Z + 3.5
	if z > HOME_Z or z < deep:
		z = clampf(z, deep, HOME_Z)
		_stop("")
	# Паутина поперёк пути.
	for n in get_tree().get_nodes_in_group("webs"):
		var w := n as Web
		if w and w.blocking and not w.is_dead() and absf(w.global_position.x - Level.TUN_CX) < 1.0:
			var dz := w.global_position.z - z
			if absf(dz) < 2.2 and signf(dz) == signf(speed):
				z = w.global_position.z - signf(speed) * 2.2
				_stop("Паутина поперёк пути. Дрезина в неё не пойдёт — жечь.")
	position.z = z
	_phase += absf(speed) * delta * 1.6
	_lever.rotation.x = sin(_phase) * 0.35
	# Стыки рельсов и лязг рычага — слышно тем дальше, чем быстрее.
	_clack -= absf(speed) * delta
	if _clack <= 0.0:
		_clack = 4.0
		Game.play_at(Sfx.clank(), global_position + Vector3(0, 0.2, 0), lerpf(-16.0, -6.0, k))
	_noise -= delta
	if _noise <= 0.0:
		_noise = 0.7
		Game.make_noise(global_position, lerpf(9.0, 26.0, k))


func _stop(why: String) -> void:
	if absf(speed) > 3.0:
		Game.play_at(Sfx.clank(), global_position + Vector3(0, 0.3, 0), 0.0)
		Game.make_noise(global_position, 20.0)
		if rider != null:
			rider.take_damage(absf(speed) * 0.8)
	speed = 0.0
	if why != "" and rider != null:
		Game.say(why, Game.THOUGHT, 3.5)
