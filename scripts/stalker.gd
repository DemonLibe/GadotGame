class_name Stalker
extends Node3D
## «Другой». Стоит на краю луча, дышит за спиной, ждёт за решёткой.
## Исчезает, когда на него смотрят. С третьей смены — охотится: идёт на шум и на свет,
## гонится, пока видит, ищет там, где потерял. От него спасает только шкаф и тишина.

signal vanished(mode: String, seen: bool)
## Охота кончилась тем, что он поймал обходчика.
signal caught

## Охота по сменам: каждый раз агрессивнее.
##   walk / run — скорость, когда ищет и когда видит; length — сколько длится охота;
##   search — сколько ищет на месте, где потерял; sight — видит без фонаря / с фонарём;
##   light — что делает, когда на него светят: "flee" уходит, "slow" замедляется, "ignore" — ничего;
##   sniff — шанс в секунду учуять дышащего в шкафу вплотную.
const HUNT := {
	3: {"walk": 1.4, "run": 2.6, "length": 45.0, "search": 8.0, "sight": [6.0, 18.0], "light": "flee", "sniff": 0.25, "hear": 1.0},
	4: {"walk": 1.9, "run": 3.5, "length": 70.0, "search": 14.0, "sight": [8.0, 22.0], "light": "slow", "sniff": 0.45, "hear": 1.3},
	5: {"walk": 2.4, "run": 4.5, "length": 100.0, "search": 22.0, "sight": [10.0, 26.0], "light": "ignore", "sniff": 0.7, "hear": 1.6},
}
const CATCH_RANGE := 1.2

var player: Player
var level: Level
var mode := ""
var _life := 0.0
var _lit := 0.0
var _seen := 0.0
var _anim: AnimationPlayer
var _head: BoneAttachment3D
var _eyes: Node3D
# Охота.
var _cfg: Dictionary = {}
var _goal := Vector3.ZERO
var _chasing := false
var _unseen := 0.0
var _search := 0.0
var _lit_hunt := 0.0
var _player_hid := false  # за эту охоту обходчик прятался в шкафу

const IDLE := "SkeletonArmature|Skeleton_Idle"
const RUN := "SkeletonArmature|Skeleton_Running"
const ATTACK := "SkeletonArmature|Skeleton_Attack"
const EYES := Vector3(0, 0.14, -0.2)  # глазницы относительно кости головы


func _ready() -> void:
	visible = false
	Game.noise_made.connect(_on_noise)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.02, 0.02, 0.02)
	skin.roughness = 1.0
	skin.rim_enabled = true
	skin.rim = 0.5
	skin.rim_tint = 0.0
	# Модель: Skeleton из LowPoly Animated Monsters (Quaternius, CC0) — чёрный, вытянутый,
	# ростом выше человека. Смотрит в +Z — разворачиваем.
	var model := Geo.model(self, "res://models/quaternius/Skeleton.fbx", skin, Vector3.ZERO, Basis(Vector3.UP, PI).scaled(Vector3(0.36, 0.44, 0.36)))
	_anim = Geo.model_anim(model, [IDLE, RUN])
	_anim.play(IDLE)
	_anim.seek(randf() * 2.0)
	# Светящиеся глаза идут за костью головы (сама кость в масштабе модели — к ней не цепляем).
	_head = BoneAttachment3D.new()
	_head.bone_name = "Head"
	model.find_child("Skeleton3D", true, false).add_child(_head)
	_eyes = Node3D.new()
	add_child(_eyes)
	var eye := ProcTex.emissive(Color(0.85, 0.82, 0.7), 1.6)
	Geo.sphere(_eyes, Vector3(-0.12, 0, 0), 0.02, eye)
	Geo.sphere(_eyes, Vector3(0.12, 0, 0), 0.02, eye)


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
	mode = ""
	if is_in_group("creatures"):
		remove_from_group("creatures")
	_anim.play(IDLE)
	_anim.speed_scale = 1.0


## Охота: появиться в pos и искать обходчика. day — номер смены (3–5), от него зависит злость.
func hunt(pos: Vector3, day: int) -> void:
	_cfg = HUNT[clampi(day, 3, 5)]
	appear(pos, "hunt", float(_cfg["length"]))
	add_to_group("creatures")  # пауки разбегаются и от него
	_goal = player.global_position
	_chasing = false
	_unseen = 0.0
	_search = float(_cfg["search"])
	_lit_hunt = 0.0
	_player_hid = false
	_anim.play(RUN)


## Шум: если услышал — идёт туда.
func _on_noise(pos: Vector3, radius: float) -> void:
	if mode != "hunt" or _chasing:
		return
	if global_position.distance_to(pos) <= radius * float(_cfg["hear"]):
		_goal = pos
		_search = float(_cfg["search"])


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
		_eyes.position = to_local(_head.global_position) + EYES
		_hunt_update(delta)
		return
	_face_player()
	_eyes.position = to_local(_head.global_position) + EYES
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
	if player.hiding:
		_player_hid = true
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
	if player.hiding:
		# В шкафу выдаёт фонарь сквозь щели или дыхание вплотную.
		if player.has_light() and dist < 7.0:
			sees = true
		elif dist < 2.0 and not player.holding_breath and randf() < float(_cfg["sniff"]) * delta:
			sees = true
	else:
		var sight: Array = _cfg["sight"]
		var r: float = sight[1] if player.has_light() else sight[0]
		if player.crouching and not player.has_light():
			r *= 0.6
		sees = dist < r and player.is_looking_at(head, -1.0)
	if sees:
		if not _chasing:
			Game.play_at(Sfx.hiss(), head, 0.0)
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
	if dist < CATCH_RANGE and (not player.hiding or sees):
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
	if player.hiding:
		player.exit_hide()  # вытащил из шкафа
	Game.play_ui(Sfx.sting(), 4.0)
	caught.emit()


func _vanish(seen: bool) -> void:
	var old := mode
	hide_now()
	vanished.emit(old, seen)
