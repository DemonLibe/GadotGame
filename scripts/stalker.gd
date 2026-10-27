class_name Stalker
extends Node3D
## «Другой». Стоит на краю луча, дышит за спиной, ждёт за решёткой.
## Исчезает, когда на него смотрят. С третьей смены — охотится: идёт на шум и на свет,
## гонится, пока видит, ищет там, где потерял. От него спасает шкаф: кто спрятался, того он не найдёт —
## постоит и уйдёт. Ворчит, пока ищет, ревёт, когда заметил.

signal vanished(mode: String, seen: bool)
## Охота кончилась тем, что он поймал обходчика.
signal caught

## Охота по сменам: каждый раз агрессивнее.
##   walk / run — скорость, когда ищет и когда видит; length — сколько длится охота;
##   search — сколько ищет на месте, где потерял; sight — видит без фонаря / с фонарём;
##   light — что делает, когда на него светят: "flee" уходит, "slow" замедляется, "ignore" — ничего;
const HUNT := {
	3: {"walk": 1.4, "run": 2.6, "length": 45.0, "search": 8.0, "sight": [6.0, 18.0], "light": "flee", "hear": 1.0},
	4: {"walk": 1.9, "run": 3.5, "length": 70.0, "search": 14.0, "sight": [8.0, 22.0], "light": "slow", "hear": 1.3},
	5: {"walk": 2.4, "run": 4.5, "length": 100.0, "search": 22.0, "sight": [10.0, 26.0], "light": "ignore", "hear": 1.6},
	7: {"walk": 2.7, "run": 4.8, "length": 110.0, "search": 26.0, "sight": [11.0, 28.0], "light": "ignore", "hear": 1.8},
}
const CATCH_RANGE := 1.2
## Сколько он ищет того, кто спрятался в шкаф, прежде чем уйти.
const HIDE_VANISH := 3.0

var player: Player
var level: Level
var mode := ""
var _life := 0.0
var _lit := 0.0
var _seen := 0.0
var _anim: AnimationPlayer
# Охота.
var _cfg: Dictionary = {}
var _goal := Vector3.ZERO
var _chasing := false
var _unseen := 0.0
var _search := 0.0
var _lit_hunt := 0.0
var _player_hid := false  # за эту охоту обходчик прятался в шкафу
var _hidden_t := 0.0
var _growl_t := 0.0
var _voice: AudioStreamPlayer3D

const IDLE := "Idle"
const RUN := "Run"
const ATTACK := "Attack"
const SCALE := 0.6
## Скример: середина морды над полом и с какого расстояния он влезает в кадр целиком.
const EYE_HEIGHT := 1.65
const SCREAM_DIST := 1.3
const LURE := Vector3(0, 2.1, -0.4)  # огонёк приманки (модель повёрнута лицом в -Z узла)
const FEET := 1.37  # начало модели — в тазу, ступни на 2.29 ниже (×SCALE): поднимаем на пол


func _ready() -> void:
	visible = false
	Game.noise_made.connect(_on_noise)
	# Модель: Angler Man (piacenti, CC-BY 3.0) — человек с головой рыбы-удильщика.
	# Анимации (ожидание, бег, удар) сделаны для игры. Смотрит в +Z — разворачиваем.
	var model := Geo.model(self, "res://models/angler/angler.glb", null, Vector3(0, FEET, 0), Basis(Vector3.UP, PI).scaled(Vector3.ONE * SCALE))
	var skin := ProcTex.model_skin("res://models/angler/angler_albedo.png", Color(0.55, 0.5, 0.5), 0.9)
	skin.rim_enabled = true
	skin.rim = 0.4
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		# Поверхности: тело, глаза, кончик приманки. В GL Compatibility скиннинговая модель
		# с разными материалами на поверхностях перестаёт освещаться точечными светильниками —
		# поэтому тело целиком в одном материале, а светящиеся глаза и приманка — во второй
		# копии той же модели (чуть раздутой), где тело невидимо.
		var m := mi as MeshInstance3D
		m.material_override = skin
		if m.mesh.get_surface_count() < 3:
			continue
		var glow_mesh := m.duplicate() as MeshInstance3D
		glow_mesh.material_override = null
		glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow_mesh.set_surface_override_material(0, _hidden())
		glow_mesh.set_surface_override_material(1, _glow(Color(0.62, 0.6, 0.46)))
		glow_mesh.set_surface_override_material(2, _glow(Color(1.0, 0.78, 0.45)))
		m.add_sibling(glow_mesh)
	# Приманка светит: тёплый огонёк над головой — видно издалека, в темноте он сам выдаёт себя.
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.35)
	glow.light_energy = 0.8
	glow.omni_range = 2.5
	glow.shadow_enabled = false
	glow.position = LURE
	add_child(glow)
	# Голос: слышно издалека — по нему понятно, откуда он идёт.
	_voice = AudioStreamPlayer3D.new()
	_voice.position = Vector3(0, 1.8, 0)
	_voice.unit_size = 9.0
	_voice.volume_db = 2.0
	add_child(_voice)
	_anim = Geo.model_anim(model, [IDLE, RUN])
	_anim.play(IDLE)
	_anim.seek(randf() * 2.0)


## Светится сам, без освещения; grow — чтобы не мерцал поверх той же поверхности тела.
static func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.grow = true
	m.grow_amount = 0.01
	return m


static func _hidden() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0)
	return m


## mode: "sighting" — далеко в луче, "behind" — за спиной, "watch" — наблюдает, "nest" — финал.
func appear(pos: Vector3, new_mode: String, life: float) -> void:
	global_position = pos
	mode = new_mode
	_life = life
	_lit = 0.0
	_seen = 0.0
	visible = true
	_face_player()


func hide_now() -> void:
	visible = false
	if _voice:
		_voice.stop()
	mode = ""
	if is_in_group("creatures"):
		remove_from_group("creatures")
	_anim.play(IDLE)
	_anim.speed_scale = 1.0


## Охота: появиться в pos и искать обходчика. day — номер смены (3–5), от него зависит злость.
func hunt(pos: Vector3, day: int) -> void:
	_cfg = HUNT[day] if HUNT.has(day) else HUNT[clampi(day, 3, 5)]
	appear(pos, "hunt", float(_cfg["length"]))
	add_to_group("creatures")  # пауки разбегаются и от него
	_goal = player.global_position
	_chasing = false
	_unseen = 0.0
	_search = float(_cfg["search"])
	_lit_hunt = 0.0
	_player_hid = false
	_hidden_t = 0.0
	_growl_t = randf_range(1.0, 2.5)
	_anim.play(RUN)
	_say(Sfx.stalker_roar())


## Шум: если услышал — идёт туда.
func _on_noise(pos: Vector3, radius: float) -> void:
	if mode != "hunt" or _chasing:
		return
	if global_position.distance_to(pos) <= radius * float(_cfg["hear"]):
		_goal = pos
		_search = float(_cfg["search"])


func _say(stream: AudioStream) -> void:
	_voice.stream = stream
	_voice.pitch_scale = randf_range(0.9, 1.05)
	_voice.play()


func is_chasing() -> bool:
	return mode == "hunt" and _chasing


func player_hid_during_hunt() -> bool:
	return _player_hid


func _face_player() -> void:
	if player == null:
		return
	var p := player.global_position
	p.y = global_position.y
	if global_position.distance_to(p) > 0.2:
		look_at(p, Vector3.UP)


func _process(delta: float) -> void:
	if not visible or player == null:
		return
	if mode == "hunt":
		_hunt_update(delta)
		return
	_face_player()
	_life -= delta
	var head := global_position + Vector3(0, 1.7, 0)
	var dist := player.global_position.distance_to(global_position)
	match mode:
		"sighting", "watch":
			if player.is_lighting(head):
				_lit += delta
			if mode == "sighting":
				global_position += global_transform.basis.z * 0.25 * delta  # медленно пятится в темноту
			if _lit > 0.3:
				_vanish(true)
			elif dist < 8.0 or _life <= 0.0:
				_vanish(false)
		"behind":
			if player.is_looking_at(head, 0.8):
				_seen += delta
			if _seen > 0.1:
				_vanish(true)
			elif _life <= 0.0:
				_vanish(false)


func _hunt_update(delta: float) -> void:
	_life -= delta
	var head := global_position + Vector3(0, 1.7, 0)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	# Спрятался в шкаф — не найдёт: постоит, поищет и уйдёт.
	if player.hiding:
		_player_hid = true
		_chasing = false
		_hidden_t += delta
		if _hidden_t > HIDE_VANISH:
			_vanish(false)
			return
	else:
		_hidden_t = 0.0
	_growl_t -= delta
	if _growl_t <= 0.0:
		_growl_t = randf_range(3.0, 6.0)
		if not _voice.playing:
			_say(Sfx.stalker_growl())
	# Свет: в третью смену он уходит из луча, в четвёртую — вязнет, в пятую — не замечает.
	var lit := player.is_lighting(head)
	var speed_k := 1.0
	if lit:
		_lit_hunt += delta
		match str(_cfg["light"]):
			"flee":
				if _lit_hunt > 0.6:
					_vanish(true)
					return
			"slow":
				speed_k = 0.5
	else:
		_lit_hunt = maxf(0.0, _lit_hunt - delta)
	# Видит ли.
	var sees := false
	if not player.hiding:
		var sight: Array = _cfg["sight"]
		var r: float = sight[1] if player.has_light() else sight[0]
		if player.crouching and not player.has_light():
			r *= 0.6
		sees = dist < r and player.is_looking_at(head, -1.0)
	if sees:
		if not _chasing:
			_say(Sfx.stalker_roar())
			Game.add_fear(15.0)
		_chasing = true
		_unseen = 0.0
		_goal = player.global_position
	elif _chasing:
		_unseen += delta
		if not player.hiding and _unseen < 1.5:
			_goal = player.global_position  # ещё слышит, куда побежал
		if _unseen > 3.0:
			_chasing = false
			_search = float(_cfg["search"])
	# Поймал.
	if dist < CATCH_RANGE and not player.hiding:
		_catch()
		return
	# Шаг к цели по проходам (через развилку, если цель в другой штольне).
	var target := _goal
	if level:
		target = level.next_waypoint(global_position, _goal)
	var go := target - global_position
	go.y = 0.0
	var speed := float(_cfg["run"] if _chasing else _cfg["walk"]) * speed_k
	if go.length() > 0.3:
		var step := go.normalized() * minf(speed * delta, go.length())
		var next := global_position + step
		if level == null or level.is_walkable(next) or not level.is_walkable(global_position):
			global_position = next
		else:
			var axis := level.axis_at(global_position)
			global_position += axis * signf(step.dot(axis)) * step.length()
		look_at(global_position + go.normalized(), Vector3.UP)
		_anim.play(RUN, 0.2)
		_anim.speed_scale = clampf(speed / 3.0, 0.6, 1.5)
	else:
		# Пришёл туда, где слышал или видел, — стоит, принюхивается, бродит рядом.
		_anim.play(IDLE, 0.3)
		_anim.speed_scale = 1.0
		_search -= delta
		if _search <= 0.0 and not _chasing:
			_vanish(false)
			return
		if level and randf() < delta * 0.5:
			var axis := level.axis_at(global_position)
			var q := global_position + axis * randf_range(-6.0, 6.0)
			if level.is_walkable(q):
				_goal = q
	if _life <= 0.0 and not _chasing:
		_vanish(false)


func _catch() -> void:
	_anim.speed_scale = 1.0
	_anim.play(ATTACK, 0.05)
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	mode = "caught"
	Game.play_ui(Sfx.sting(), 4.0)
	_say(Sfx.stalker_roar())
	caught.emit()


func _vanish(seen: bool) -> void:
	var old := mode
	hide_now()
	vanished.emit(old, seen)
