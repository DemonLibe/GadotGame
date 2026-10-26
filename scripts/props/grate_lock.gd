class_name GrateLock
extends StaticBody3D
## Засов решётки на правой стене (последняя смена). Кто прочитал все записки,
## тот поймёт: решётку можно запереть изнутри — и остаться.

var main  # Main


func _ready() -> void:
	add_to_group("day_objects")
	var rust := ProcTex.flat(Color(0.35, 0.2, 0.12), 0.8, 0.5)
	Geo.box(self, Vector3(0, 0, 0.04), Vector3(0.1, 0.3, 0.08), rust, false)
	Geo.box(self, Vector3(-0.12, 0, 0.1), Vector3(0.3, 0.04, 0.04), rust, false)
	Geo.box(self, Vector3(-0.25, -0.05, 0.1), Vector3(0.03, 0.1, 0.03), rust, false)
	Geo.collider_box(self, Vector3(0.5, 0.4, 0.25), Vector3(-0.1, 0, 0.1))


func _available(player) -> bool:
	return main != null and main.collapsing and Game.notes_count() >= Game.NOTES_TOTAL \
		and player.global_position.z < Level.GRATE_Z


func get_prompt(player) -> String:
	if _available(player):
		return "E — закрыть решётку и запереть изнутри"
	return "Ржавый засов решётки"


func interact(player) -> void:
	if not _available(player):
		return
	Game.seal_requested.emit()
