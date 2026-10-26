extends Control
## Заставка перед главным меню: «Vibe Games / made by Sponjik» на чёрном.
## Надпись разгорается, как лампа, держится и гаснет. Любая клавиша или клик — пропустить.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const FADE_IN := 1.2
const HOLD := 2.0
const FADE_OUT := 0.9

var _title: Label
var _sub: Label
var _t := 0.0
var _done := false


func _ready() -> void:
	# В смоук-тесте заставку не ждём: сразу в меню, где начинается прогон.
	if OS.get_cmdline_user_args().has("--smoke"):
		_finish.call_deferred()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = _label("Vibe Games", 72, Color(0.95, 0.78, 0.42))
	box.add_child(_title)
	_sub = _label("made by Sponjik", 26, Color(0.72, 0.7, 0.66))
	box.add_child(_sub)
	_title.modulate.a = 0.0
	_sub.modulate.a = 0.0

	if not Main.debug_flag("nofx"):
		Main.add_postfx(self)
	var hum := AudioStreamPlayer.new()
	hum.stream = Sfx.hum()
	hum.volume_db = -18.0
	add_child(hum)
	hum.play()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _process(delta: float) -> void:
	if _done or _title == null:
		return
	_t += delta
	var a := 1.0
	if _t < FADE_IN:
		# Разгорается рывками, как старая лампа.
		a = _t / FADE_IN
		if sin(_t * 37.0) + sin(_t * 23.0) < -0.9:
			a *= 0.25
	elif _t > FADE_IN + HOLD:
		a = 1.0 - (_t - FADE_IN - HOLD) / FADE_OUT
	_title.modulate.a = clampf(a, 0.0, 1.0)
	_sub.modulate.a = clampf((_t - 0.5) / FADE_IN, 0.0, 1.0) * clampf(a, 0.0, 1.0)
	if _t >= FADE_IN + HOLD + FADE_OUT:
		_finish()


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file(MENU_SCENE)
