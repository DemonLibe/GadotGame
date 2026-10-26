class_name Hatch
extends StaticBody3D
## Люк в полу комнаты. Тяжёлый: открывается удержанием E. Узел стоит на линии шарнира.

const OPEN_TIME := 1.3

var ladder: Ladder
var is_open := false
var _progress := 0.0


func _ready() -> void:
	var plate := ProcTex.plate()
	Geo.box(self, Vector3(0, 0.03, Level.SHAFT_HALF), Vector3(1.86, 0.06, 1.86), plate, false)
	# Ручка и петли.
	var dark := ProcTex.flat(Color(0.15, 0.15, 0.16), 0.5, 0.8)
	Geo.cylinder(self, Vector3(0, 0.09, 1.55), 0.02, 0.4, dark, Basis(Vector3.FORWARD, PI / 2))
	Geo.box(self, Vector3(-0.6, 0.07, 0.05), Vector3(0.2, 0.05, 0.12), dark, false)
	Geo.box(self, Vector3(0.6, 0.07, 0.05), Vector3(0.2, 0.05, 0.12), dark, false)
	Geo.collider_box(self, Vector3(1.86, 0.08, 1.86), Vector3(0, 0.04, Level.SHAFT_HALF))


func set_open(value: bool, animate := false) -> void:
	is_open = value
	_progress = 0.0
	var target := deg_to_rad(-100.0) if value else 0.0
	if animate:
		create_tween().tween_property(self, "rotation:x", target, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		rotation.x = target


func get_prompt(player) -> String:
	if player.climbing:
		return ""
	if is_open:
		return "E — спуститься в шахту"
	return "Удерживай E — открыть люк"


func interact(player) -> void:
	if is_open and ladder:
		ladder.interact(player)


func hold_interact(_player, delta: float) -> float:
	if is_open:
		return -1.0
	_progress += delta / OPEN_TIME
	if _progress >= 1.0:
		set_open(true, true)
		Game.play_at(Sfx.creak(), global_position, 0.0)
		return -1.0
	return _progress


func hold_cancel() -> void:
	_progress = 0.0
