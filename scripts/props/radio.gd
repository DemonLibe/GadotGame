class_name RadioSet
extends StaticBody3D
## Рация на столе. Шипит и мигает, пока её не заберут; потом в ней звучит диспетчер.

var dispatcher: Dispatcher
var _led: StandardMaterial3D
var _hiss: AudioStreamPlayer3D
var _t := 0.0


func _ready() -> void:
	var body := ProcTex.flat(Color(0.16, 0.2, 0.15), 0.7, 0.2)
	Geo.box(self, Vector3(0, 0.085, 0), Vector3(0.08, 0.17, 0.04), body, false)
	Geo.cylinder(self, Vector3(0.025, 0.23, 0.0), 0.006, 0.12, ProcTex.flat(Color(0.05, 0.05, 0.05), 0.5))
	Geo.box(self, Vector3(0, 0.11, 0.021), Vector3(0.06, 0.06, 0.004), ProcTex.flat(Color(0.05, 0.05, 0.05), 0.9), false)
	_led = ProcTex.emissive(Color(1.0, 0.2, 0.1), 3.0)
	Geo.sphere(self, Vector3(-0.025, 0.155, 0.02), 0.007, _led)
	Geo.collider_box(self, Vector3(0.14, 0.26, 0.1), Vector3(0, 0.13, 0))
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = Sfx.radio_loop()
	_hiss.volume_db = -12.0
	_hiss.unit_size = 3.0
	add_child(_hiss)
	reset()


## Новая смена — рация снова на столе.
func reset() -> void:
	visible = true
	collision_layer = 1
	if is_inside_tree():
		_hiss.play()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_led.emission_energy_multiplier = 3.0 if fmod(_t, 1.2) < 0.5 else 0.2


func get_prompt(_player) -> String:
	return "E — взять рацию" if visible else ""


func interact(player) -> void:
	if not visible:
		return
	visible = false
	collision_layer = 0
	_hiss.stop()
	player.has_radio = true
	Game.play_at(Sfx.pickup(), global_position, -6.0)
	Game.report("radio")
	if dispatcher:
		dispatcher.briefing(Game.day)
