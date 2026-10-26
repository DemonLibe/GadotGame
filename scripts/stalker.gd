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
var _anim: AnimationPlayer
var _head: BoneAttachment3D
var _eyes: Node3D

const IDLE := "SkeletonArmature|Skeleton_Idle"
const EYES := Vector3(0, 0.14, -0.2)  # глазницы относительно кости головы


func _ready() -> void:
	visible = false
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.02, 0.02, 0.02)
	skin.roughness = 1.0
	skin.rim_enabled = true
	skin.rim = 0.5
	skin.rim_tint = 0.0
	# Модель: Skeleton из LowPoly Animated Monsters (Quaternius, CC0) — чёрный, вытянутый,
	# ростом выше человека. Смотрит в +Z — разворачиваем.
	var model := Geo.model(self, "res://models/quaternius/Skeleton.fbx", skin, Vector3.ZERO, Basis(Vector3.UP, PI).scaled(Vector3(0.36, 0.44, 0.36)))
	_anim = Geo.model_anim(model, [IDLE])
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


func _vanish(seen: bool) -> void:
	var old := mode
	hide_now()
	vanished.emit(old, seen)
