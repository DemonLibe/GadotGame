class_name Charger
extends StaticBody3D
## Зарядная станция для фонаря. Зелёный огонёк виден издалека в темноте.

const CHARGE_PER_SEC := 12.0

var charger_id := "station"
var _active := 0.0
var _lamp_mat: StandardMaterial3D
var _glow: OmniLight3D
var _hum: AudioStreamPlayer3D


func _ready() -> void:
	Geo.box(self, Vector3(0, 0, 0.1), Vector3(0.5, 0.7, 0.2), ProcTex.flat(Color(0.2, 0.27, 0.22), 0.6, 0.5), false)
	Geo.box(self, Vector3(0, 0.1, 0.205), Vector3(0.3, 0.15, 0.01), ProcTex.flat(Color(0.05, 0.05, 0.05), 0.3), false)
	Geo.box(self, Vector3(0.15, -0.95, 0.05), Vector3(0.03, 1.2, 0.03), ProcTex.flat(Color(0.05, 0.05, 0.05)), false)
	_lamp_mat = ProcTex.emissive(Color(0.2, 1.0, 0.3), 2.0)
	Geo.sphere(self, Vector3(0, -0.15, 0.21), 0.035, _lamp_mat)
	Geo.label(self, Vector3(0, 0.45, 0.205), "ЗАРЯДКА", 0, 30, Color(0.85, 0.9, 0.85))
	Geo.collider_box(self, Vector3(0.5, 0.7, 0.2), Vector3(0, 0, 0.1))
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, -0.15, 0.4)
	_glow.light_color = Color(0.3, 1.0, 0.4)
	_glow.omni_range = 1.6
	_glow.light_energy = 0.3
	_glow.add_to_group("fear_light")
	add_child(_glow)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = Sfx.hum()
	_hum.volume_db = -8.0
	add_child(_hum)


func get_prompt(player) -> String:
	if player.battery >= 99.5:
		return "Зарядная станция — фонарь заряжен"
	return "Удерживай E — зарядить фонарь (%d%%)" % int(player.battery)


func hold_interact(player, delta: float) -> float:
	if player.battery >= 100.0:
		Game.report("charge:" + charger_id)
		return -1.0
	player.battery = minf(100.0, player.battery + CHARGE_PER_SEC * delta)
	_active = 0.15
	if player.battery >= 100.0:
		Game.play_at(Sfx.click(), global_position)
		Game.report("charge:" + charger_id)
	return player.battery / 100.0


func hold_cancel() -> void:
	_active = 0.0


func _process(delta: float) -> void:
	_active -= delta
	var on := _active > 0.0
	if on and not _hum.playing:
		_hum.play()
	elif not on and _hum.playing:
		_hum.stop()
	var c := Color(1.0, 0.8, 0.2) if on else Color(0.2, 1.0, 0.3)
	_lamp_mat.emission = c
	_lamp_mat.albedo_color = c
	_glow.light_color = c
