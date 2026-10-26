class_name Stalker
extends Node3D
## «Другой». Стоит на краю луча, дышит за спиной, ждёт за решёткой.
## Исчезает, когда на него смотрят. Пока что — не нападает.

signal vanished(mode: String, seen: bool)

var player: Player
var mode := ""
var _life := 0.0
var _lit := 0.0
var _seen := 0.0


func _ready() -> void:
	visible = false
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.02, 0.02, 0.02)
	skin.roughness = 1.0
	skin.rim_enabled = true
	skin.rim = 0.5
	skin.rim_tint = 0.0
	Geo.capsule(self, Vector3(-0.1, 0.55, 0), 0.075, 1.1, skin)
	Geo.capsule(self, Vector3(0.1, 0.55, 0), 0.075, 1.1, skin)
	var torso := Geo.capsule(self, Vector3(0, 1.4, 0), 0.19, 0.95, skin)
	torso.scale = Vector3(1.15, 1.0, 0.65)
	# Слишком длинные руки — до колен.
	Geo.capsule(self, Vector3(-0.3, 1.05, -0.02), 0.05, 1.25, skin, Basis(Vector3.FORWARD, -0.08))
	Geo.capsule(self, Vector3(0.3, 1.05, -0.02), 0.05, 1.25, skin, Basis(Vector3.FORWARD, 0.08))
	var head := Node3D.new()
	head.position = Vector3(0, 2.02, 0)
	head.rotation.z = 0.35
	add_child(head)
	var skull := Geo.sphere(head, Vector3.ZERO, 0.15, skin)
	skull.scale = Vector3(0.9, 1.2, 0.95)
	var eye := ProcTex.emissive(Color(0.85, 0.82, 0.7), 1.6)
	Geo.sphere(head, Vector3(-0.05, 0.02, -0.13), 0.016, eye)
	Geo.sphere(head, Vector3(0.05, 0.02, -0.13), 0.016, eye)


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


func _vanish(seen: bool) -> void:
	var old := mode
	hide_now()
	vanished.emit(old, seen)
