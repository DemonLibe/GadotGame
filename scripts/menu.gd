class_name Menu
extends CanvasLayer
## Экран меню: главное (отдельная сцена main_menu.tscn) и пауза в игре, у обоих — настройки.
## Работает и при остановленной игре.

signal new_game
signal continue_game
signal resume
signal main_menu
signal quit

const CONTROLS := "WASD — идти        Shift — бежать        Мышь — смотреть\n" \
	+ "C / Ctrl — присесть        Space — прыжок, в шкафу — задержать дыхание\n" \
	+ "E — действие (удерживать: люк, генератор, зарядка, фильтр)\n" \
	+ "W / S на лестнице — вверх / вниз\n" \
	+ "1–7 или колесо мыши — предмет в руках (та же клавиша — убрать)\n" \
	+ "ЛКМ — использовать предмет        F — налобный фонарь        Esc — пауза"
const AMBER := Color(1.0, 0.75, 0.3)

var _bg: ColorRect
var _title: Label
var _sub: Label
var _buttons: VBoxContainer
var _controls: Label
var _ach: AchievementsPanel
var _box: VBoxContainer
var _settings: SettingsPanel
var _bg_alpha := 0.6
var _mode := ""
var _saved_day := 1
var _t := 0.0
var _blink := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.8)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)
	_box = box

	_title = _label(box, 84, AMBER)
	_sub = _label(box, 18, Color(0.75, 0.73, 0.68))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	box.add_child(_buttons)
	_controls = _label(box, 17, Color(0.85, 0.83, 0.78))
	_controls.text = CONTROLS

	_settings = SettingsPanel.new()
	_settings.visible = false
	center.add_child(_settings)
	_settings.closed.connect(_close_settings)
	_ach = AchievementsPanel.new()
	center.add_child(_ach)
	_ach.closed.connect(_close_achievements)
	visible = false


func show_main(saved_day: int) -> void:
	_mode = "main"
	_saved_day = saved_day
	visible = true
	_bg.color.a = 0.35
	_title.text = "HOPE LIGHT"
	_sub.text = "Станция «Тихая». Пять смен под землёй.\nСложность одна — высокая."
	_show_box()
	if saved_day > 1:
		_button("Продолжить — смена %d" % saved_day, func(): continue_game.emit())
	_button("Новая игра", func(): new_game.emit())
	_button("Настройки", open_settings)
	_button("Управление", _toggle_controls)
	_button("Достижения", open_achievements)
	if not OS.has_feature("web"):
		_button("Выход", func(): quit.emit())
	_focus_first()


func show_pause() -> void:
	_mode = "pause"
	visible = true
	_bg.color.a = 0.6
	_title.text = "ПАУЗА"
	_sub.text = "Темнота подождёт. Недолго."
	_show_box()
	_button("Продолжить", func(): resume.emit())
	_button("Настройки", open_settings)
	_button("Управление", _toggle_controls)
	_button("Достижения", open_achievements)
	_button("В главное меню", func(): main_menu.emit())
	_focus_first()


## Надпись вместо кнопок, пока строится уровень.
func show_loading() -> void:
	_show_box()
	_sub.text = "Спуск…"


func open_settings() -> void:
	_box.visible = false
	_bg_alpha = _bg.color.a
	_bg.color.a = maxf(_bg_alpha, 0.75)
	_settings.open()


func is_settings_open() -> bool:
	return _settings.visible


func hide_all() -> void:
	_mode = ""
	visible = false
	_settings.visible = false
	_ach.visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	# Заголовок мигает, как старая лампа.
	_t += delta
	_blink -= delta
	if _blink <= 0.0 and randf() < 0.01:
		_blink = randf_range(0.05, 0.25)
	var a := 0.85 + 0.15 * sin(_t * 2.0)
	_title.modulate.a = 0.15 if _blink > 0.0 else a


func _unhandled_input(event: InputEvent) -> void:
	if visible and _mode == "pause" and not _settings.visible and not _ach.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume.emit()


func _toggle_controls() -> void:
	_controls.visible = not _controls.visible


## Экран достижений — вместо кнопок, как настройки.
func open_achievements() -> void:
	_box.visible = false
	_bg_alpha = _bg.color.a
	_bg.color.a = maxf(_bg_alpha, 0.85)
	_ach.open()


func is_achievements_open() -> bool:
	return _ach.visible


func _close_achievements() -> void:
	_ach.visible = false
	_bg.color.a = _bg_alpha
	_box.visible = true
	_focus_first()


func _close_settings() -> void:
	_settings.visible = false
	_bg.color.a = _bg_alpha
	_box.visible = true
	_focus_first()


func _show_box() -> void:
	_settings.visible = false
	_box.visible = true
	_controls.visible = false
	_ach.visible = false
	_clear()


func _focus_first() -> void:
	# Кнопки создаются в этом же кадре, фокус ставим, когда они попадут в дерево.
	await get_tree().process_frame
	for c in _buttons.get_children():
		if not c.is_queued_for_deletion():
			(c as Button).grab_focus()
			return


func _clear() -> void:
	for c in _buttons.get_children():
		c.queue_free()


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78))
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.75, 0.3, 0.12)
	hover.set_corner_radius_all(4)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(action)
	_buttons.add_child(b)


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(l)
	return l
