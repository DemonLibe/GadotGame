class_name Note
extends StaticBody3D
## Записка прежнего обходчика. По ним складывается история тоннеля.

var note_id := ""
var title := ""
var text := ""
var hud: Hud


func _ready() -> void:
	add_to_group("day_objects")
	var paper := ProcTex.flat(Color(0.82, 0.78, 0.64), 1.0)
	var sheet := Geo.box(self, Vector3(0, 0.003, 0), Vector3(0.21, 0.005, 0.29), paper, false)
	sheet.rotation.y = randf_range(-0.4, 0.4)
	for i in 6:
		Geo.box(sheet, Vector3(0, 0.003, -0.1 + i * 0.035), Vector3(0.15, 0.001, 0.006), ProcTex.flat(Color(0.25, 0.22, 0.2), 1.0), false)
	Geo.collider_box(self, Vector3(0.3, 0.1, 0.35), Vector3(0, 0.05, 0))


func get_prompt(_player) -> String:
	return "E — прочитать записку"


func interact(_player) -> void:
	Game.notes_read[note_id] = true
	Game.tasks_changed.emit()
	if hud:
		hud.show_note(title, text)
