class_name StoreDoor
extends StaticBody3D
## Служебка старой линии: кирпичная стена с аркой и ржавая решётчатая калитка на замке.
## Открывается ключом с биркой «С-N» (ключ лежит где-то в этой же линии). Внутри — полезное.
## Стоит на границе клеток: локальная +Z смотрит из коридора в служебку.

var number := 1
var opened := false
var _gate: Node3D
var _block: CollisionShape3D


func _ready() -> void:
	add_to_group("day_objects")
	if ResourceLoader.exists(ProcTex.KIT + "models/06_old_line/oldline_arch_passage.glb"):
		ProcTex.kit_model(self, "06_old_line/oldline_arch_passage")
		var door := ProcTex.kit_model(self, "06_old_line/iron_grate_door")
		_gate = door.find_child("Gate", true, false) as Node3D
	else:
		var rust := ProcTex.flat(Color(0.3, 0.17, 0.1), 0.85, 0.5)
		_gate = Node3D.new()
		_gate.position = Vector3(-0.75, 0, 0)
		add_child(_gate)
		for k in 8:
			Geo.box(_gate, Vector3(0.1 + k * 0.19, 1.2, 0), Vector3(0.03, 2.4, 0.03), rust, false)
	Geo.label(self, Vector3(0, 2.2, -0.27), "СЛУЖЕБНАЯ С-%d" % number, 180.0, 36, Color(0.85, 0.82, 0.7), true, 0.003)
	# Невидимая преграда в проёме — она же ловит взгляд для подсказки.
	_block = CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.6, 2.4, 0.3)
	_block.shape = b
	_block.position = Vector3(0, 1.2, 0)
	add_child(_block)


func get_prompt(player) -> String:
	if opened:
		return ""
	if player.keys.has(number):
		return "E — отпереть служебку «С-%d»" % number
	return "Служебка «С-%d» — заперто. Ключ где-то в старой линии" % number


func interact(player) -> void:
	if opened:
		return
	if not player.keys.has(number):
		Game.play_at(Sfx.clank(), global_position + Vector3(0, 1.0, 0), -8.0)
		Game.say_once("store_locked_%d" % number, "Заперто. На решётке бирка «С-%d». Ключ должен быть где-то здесь — у таких же, как я." % number, Game.THOUGHT, 4.0)
		return
	Game.play_at(Sfx.unlock(), global_position + Vector3(0, 1.0, 0), 0.0)
	open()
	Game.play_at(Sfx.creak(), global_position + Vector3(0, 1.2, 0), -2.0)
	Game.make_noise(global_position, 9.0)
	Game.say_once("store_open", "Ржавый замок поддался. Скрип — на всю линию...", Game.THOUGHT, 3.0)


func open() -> void:
	opened = true
	_block.disabled = true
	collision_layer = 0
	if _gate:
		var tw := create_tween()
		tw.tween_property(_gate, "rotation:y", _gate.rotation.y - 1.9, 1.2).set_ease(Tween.EASE_OUT)
