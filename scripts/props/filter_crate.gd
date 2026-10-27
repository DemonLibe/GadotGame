class_name FilterCrate
extends StaticBody3D
## Ящик с запасом: фильтры и (редко) батарейки. Каждый день содержимое раскладывается заново.

var filters := 0
var batteries := 0
var _filter_meshes: Array[Node3D] = []
var _battery_meshes: Array[Node3D] = []


func _ready() -> void:
	var wood := ProcTex.flat(Color(0.32, 0.23, 0.14), 0.9)
	Geo.box(self, Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.5), wood, false)
	Geo.box(self, Vector3(-0.335, 0.25, 0), Vector3(0.03, 0.5, 0.5), wood, false)
	Geo.box(self, Vector3(0.335, 0.25, 0), Vector3(0.03, 0.5, 0.5), wood, false)
	Geo.box(self, Vector3(0, 0.25, -0.235), Vector3(0.7, 0.5, 0.03), wood, false)
	Geo.box(self, Vector3(0, 0.25, 0.235), Vector3(0.7, 0.5, 0.03), wood, false)
	var white := ProcTex.flat(Color(0.88, 0.88, 0.82), 0.95)
	for i in 3:
		_filter_meshes.append(Geo.box(self, Vector3(-0.22 + i * 0.16, 0.22, -0.05), Vector3(0.13, 0.24, 0.3), white, false))
	var cell := ProcTex.flat(Color(0.15, 0.15, 0.15), 0.5, 0.3)
	for i in 2:
		_battery_meshes.append(Geo.box(self, Vector3(0.24, 0.16, -0.12 + i * 0.12), Vector3(0.06, 0.12, 0.06), cell, false))
	Geo.label(self, Vector3(0, 0.3, 0.252), "ЗАПАС", 0, 26, Color(0.9, 0.85, 0.7), true)
	Geo.collider_box(self, Vector3(0.7, 0.5, 0.5), Vector3(0, 0.25, 0))
	_refresh()


func set_contents(f: int, b: int) -> void:
	filters = f
	batteries = b
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	for i in _filter_meshes.size():
		_filter_meshes[i].visible = i < filters
	for i in _battery_meshes.size():
		_battery_meshes[i].visible = i < batteries


func get_prompt(_player) -> String:
	if filters <= 0 and batteries <= 0:
		return "Ящик — пусто"
	var parts: PackedStringArray = []
	if filters > 0:
		parts.append("фильтры: %d" % filters)
	if batteries > 0:
		parts.append("батарейки: %d" % batteries)
	return "E — забрать (%s)" % ", ".join(parts)


func interact(player) -> void:
	var took_f := mini(filters, Player.MAX_FILTERS - player.filters)
	var took_b := mini(batteries, Player.MAX_BATTERIES - player.batteries)
	if took_f + took_b <= 0:
		if filters + batteries > 0:
			Game.say("Больше не унесу.")
		return
	filters -= took_f
	batteries -= took_b
	player.filters += took_f
	player.batteries += took_b
	if took_b > 0:
		Game.report("gear:battery", took_b)
	_refresh()
	Game.play_at(Sfx.pickup(), global_position, -6.0)
