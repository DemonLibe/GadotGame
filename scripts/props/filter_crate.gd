class_name FilterCrate
extends StaticBody3D
## Ящик с запасными фильтрами. Каждый день фильтры раскладываются заново.

var count := 0
var _filters: Array[Node3D] = []


func _ready() -> void:
	var wood := ProcTex.flat(Color(0.32, 0.23, 0.14), 0.9)
	Geo.box(self, Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.5), wood, false)
	Geo.box(self, Vector3(-0.335, 0.25, 0), Vector3(0.03, 0.5, 0.5), wood, false)
	Geo.box(self, Vector3(0.335, 0.25, 0), Vector3(0.03, 0.5, 0.5), wood, false)
	Geo.box(self, Vector3(0, 0.25, -0.235), Vector3(0.7, 0.5, 0.03), wood, false)
	Geo.box(self, Vector3(0, 0.25, 0.235), Vector3(0.7, 0.5, 0.03), wood, false)
	var white := ProcTex.flat(Color(0.88, 0.88, 0.82), 0.95)
	for i in 3:
		_filters.append(Geo.box(self, Vector3(-0.2 + i * 0.2, 0.22, 0), Vector3(0.16, 0.24, 0.4), white, false))
	Geo.label(self, Vector3(0, 0.3, 0.252), "ФИЛЬТРЫ", 0, 26, Color(0.9, 0.85, 0.7), true)
	Geo.collider_box(self, Vector3(0.7, 0.5, 0.5), Vector3(0, 0.25, 0))
	set_count(count)


func set_count(n: int) -> void:
	count = n
	if not is_node_ready():
		return
	for i in _filters.size():
		_filters[i].visible = i < count


func get_prompt(_player) -> String:
	if count <= 0:
		return "Ящик для фильтров — пусто"
	return "E — взять фильтр (в ящике: %d)" % count


func interact(player) -> void:
	if count <= 0:
		return
	if player.filters >= Player.MAX_FILTERS:
		Game.say("Больше не унесу.")
		return
	set_count(count - 1)
	player.filters += 1
	Game.play_at(Sfx.pickup(), global_position, -6.0)
