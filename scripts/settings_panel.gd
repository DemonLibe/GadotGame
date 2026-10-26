class_name SettingsPanel
extends VBoxContainer
## Экран настроек: общий для главного меню и паузы. Значения сразу применяются и сохраняются.

signal closed

const AMBER := Color(1.0, 0.75, 0.3)
const TEXT := Color(0.85, 0.83, 0.78)
const DIM := Color(0.62, 0.6, 0.56)

var _rows: Dictionary = {}  # ключ настройки → элемент управления
var _back: Button


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(560, 0)
	_heading("Управление")
	_slider("mouse_sens", "Чувствительность мыши", 0.2, 3.0, 0.05, func(v): return "%.2f×" % v)
	_check("invert_y", "Инвертировать по вертикали")
	_heading("Звук")
	_slider("master", "Общая громкость", 0.0, 1.0, 0.05, _percent)
	_slider("voice", "Голос диспетчера", 0.0, 1.0, 0.05, _percent)
	_slider("ambience", "Гул подземелья", 0.0, 1.0, 0.05, _percent)
	_heading("Изображение")
	_slider("fov", "Поле зрения", 55.0, 100.0, 1.0, func(v): return "%d°" % int(v))
	_slider("brightness", "Яркость", 0.6, 1.6, 0.05, _percent)
	_check("grain", "Плёночное зерно")
	_check("fullscreen", "Во весь экран")

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	add_child(_spacer(10))
	add_child(bar)
	bar.add_child(_button("Сбросить", _on_reset))
	_back = _button("Назад", func(): closed.emit())
	bar.add_child(_back)
	Settings.changed.connect(_refresh)
	_refresh()


## Показывает панель и ставит фокус, чтобы меню работало и с клавиатуры.
func open() -> void:
	visible = true
	_refresh()
	var first: Control = _rows["mouse_sens"]
	first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _on_reset() -> void:
	Settings.reset()


func _refresh() -> void:
	for key in _rows:
		var c: Control = _rows[key]
		if c is HSlider:
			(c as HSlider).set_value_no_signal(float(Settings.get_value(key)))
			c.get_meta("update").call()
		elif c is CheckBox:
			(c as CheckBox).set_pressed_no_signal(bool(Settings.get_value(key)))


static func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func _heading(text: String) -> void:
	add_child(_spacer(6))
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", AMBER)
	add_child(l)


func _slider(key: String, text: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var name_label := _row_label(text)
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(200, 20)
	s.focus_mode = Control.FOCUS_ALL
	_style_slider(s)
	row.add_child(s)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(64, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", DIM)
	row.add_child(value_label)
	var update := func(): value_label.text = fmt.call(s.value)
	s.set_meta("update", update)
	s.value_changed.connect(func(v: float):
		update.call()
		Settings.set_value(key, v))
	s.focus_entered.connect(func(): name_label.add_theme_color_override("font_color", AMBER))
	s.focus_exited.connect(func(): name_label.add_theme_color_override("font_color", TEXT))
	_rows[key] = s


func _check(key: String, text: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_ALL
	c.add_theme_font_size_override("font_size", 20)
	c.add_theme_color_override("font_color", TEXT)
	c.add_theme_color_override("font_hover_color", AMBER)
	c.add_theme_color_override("font_focus_color", AMBER)
	c.add_theme_color_override("font_pressed_color", TEXT)
	c.add_theme_color_override("font_hover_pressed_color", AMBER)
	c.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	c.add_theme_icon_override("unchecked", _box_icon(TEXT, false))
	c.add_theme_icon_override("checked", _box_icon(AMBER, true))
	c.toggled.connect(func(on: bool): Settings.set_value(key, on))
	add_child(c)
	_rows[key] = c


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(270, 0)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", TEXT)
	return l


func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.set_corner_radius_all(2)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(AMBER, 0.7)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	knob.fill(Color(0, 0, 0, 0))
	for y in 14:
		for x in 14:
			if Vector2(x - 6.5, y - 6.5).length() <= 6.5:
				knob.set_pixel(x, y, TEXT)
	var hot := knob.duplicate() as Image
	for y in 14:
		for x in 14:
			if hot.get_pixel(x, y).a > 0.0:
				hot.set_pixel(x, y, AMBER)
	s.add_theme_icon_override("grabber", ImageTexture.create_from_image(knob))
	s.add_theme_icon_override("grabber_highlight", ImageTexture.create_from_image(hot))


## Квадратик флажка: рамка, у включённого — с заливкой.
static func _box_icon(color: Color, filled: bool) -> ImageTexture:
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var edge := x < 2 or y < 2 or x >= n - 2 or y >= n - 2
			var inner := x >= 5 and y >= 5 and x < n - 5 and y < n - 5
			if edge or (filled and inner):
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.75, 0.3, 0.12)
	hover.set_corner_radius_all(4)
	hover.content_margin_left = 14
	hover.content_margin_right = 14
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(action)
	return b


static func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
