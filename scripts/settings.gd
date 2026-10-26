extends Node
## Настройки игрока (автозагрузка Settings): мышь, звук, изображение.
## Хранятся отдельно от прогресса, в user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"mouse_sens": 1.0,    # множитель чувствительности мыши
	"invert_y": false,
	"fov": 72.0,
	"master": 0.8,        # громкость 0..1
	"voice": 1.0,         # голос диспетчера и рация
	"ambience": 1.0,      # гул подземелья
	"brightness": 1.0,
	"grain": true,        # плёночное зерно
	"fullscreen": false,
}
const BUSES := ["Voice", "Ambience"]

## Не записывать на диск (смоук-тест).
var persist := true
var _values := DEFAULTS.duplicate()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	_load()
	_apply(true)


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key == "fullscreen")
	_save()
	changed.emit()


func reset() -> void:
	var was_full: bool = _values["fullscreen"]
	_values = DEFAULTS.duplicate()
	_apply(was_full)
	_save()
	changed.emit()


## Подключает постобработку к настройкам яркости и зерна; отключается сама, когда узел уходит из дерева.
func bind_postfx(owner_node: Node, mat: ShaderMaterial) -> void:
	var update := func():
		mat.set_shader_parameter("brightness", float(get_value("brightness")))
		mat.set_shader_parameter("grain", 0.035 if get_value("grain") else 0.0)
	update.call()
	changed.connect(update)
	owner_node.tree_exiting.connect(func(): changed.disconnect(update))


func _apply(window: bool) -> void:
	_set_volume("Master", float(_values["master"]))
	_set_volume("Voice", float(_values["voice"]))
	_set_volume("Ambience", float(_values["ambience"]))
	if window and DisplayServer.get_name() != "headless":
		var full: bool = _values["fullscreen"]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)


func _set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, linear < 0.01)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.01)))


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in DEFAULTS:
		var v: Variant = cf.get_value("settings", k, DEFAULTS[k])
		if typeof(v) == typeof(DEFAULTS[k]) or (v is int and DEFAULTS[k] is float):
			_values[k] = type_convert(v, typeof(DEFAULTS[k]))
	# В браузере полноэкранный режим включается только по нажатию, при запуске — всегда окно.
	if OS.has_feature("web"):
		_values["fullscreen"] = false


func _save() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	for k in _values:
		cf.set_value("settings", k, _values[k])
	cf.save(PATH)
