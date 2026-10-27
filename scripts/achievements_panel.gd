class_name AchievementsPanel
extends VBoxContainer
## Экран достижений (главное меню и пауза), как в лаунчерах: сверху общий прогресс,
## фильтр «все / получены / не получены», ниже карточки со значком, описанием, датой
## или полоской прогресса, в конце — коллекция находок.

signal closed

const AMBER := Color(1.0, 0.75, 0.3)
const TEXT := Color(0.85, 0.83, 0.78)
const DIM := Color(0.55, 0.53, 0.5)
const CARD := Color(0.07, 0.065, 0.06, 0.88)
const CARD_GOT := Color(0.13, 0.1, 0.06, 0.92)

var _summary: Label
var _bar: ProgressBar
var _list: VBoxContainer
var _finds: GridContainer
var _finds_title: Label
var _scroll: ScrollContainer
var _filter := "all"
var _tabs: Array[Button] = []
var _back: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(780, 0)

	var title := Label.new()
	title.text = "ДОСТИЖЕНИЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", AMBER)
	add_child(title)

	# Общий прогресс: «получено 7 из 18 · 39 %» и полоска.
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_font_size_override("font_size", 16)
	_summary.add_theme_color_override("font_color", TEXT)
	add_child(_summary)
	_bar = _progress_bar(8.0)
	add_child(_bar)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	for t in [["all", "Все"], ["got", "Получены"], ["locked", "Не получены"]]:
		var b := _button(str(t[1]), _set_filter.bind(str(t[0])), 16)
		b.toggle_mode = true
		_tabs.append(b)
		b.set_meta("filter", t[0])
		tabs.add_child(b)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(780, 440)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	_scroll.add_child(inner)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	inner.add_child(_list)
	_finds_title = Label.new()
	_finds_title.add_theme_font_size_override("font_size", 15)
	_finds_title.add_theme_color_override("font_color", AMBER)
	inner.add_child(_spacer(8))
	inner.add_child(_finds_title)
	_finds = GridContainer.new()
	_finds.columns = 4
	_finds.add_theme_constant_override("h_separation", 6)
	_finds.add_theme_constant_override("v_separation", 6)
	inner.add_child(_finds)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bottom)
	_back = _button("Назад", func(): closed.emit(), 22)
	bottom.add_child(_back)
	visible = false


func open() -> void:
	visible = true
	_set_filter(_filter)
	_scroll.scroll_vertical = 0
	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("move_back") or event.is_action_pressed("move_forward"):
		_scroll.scroll_vertical += 90 if event.is_action_pressed("move_back") else -90


func _set_filter(f: String) -> void:
	_filter = f
	for b in _tabs:
		b.set_pressed_no_signal(b.get_meta("filter") == f)
		b.add_theme_color_override("font_color", AMBER if b.button_pressed else TEXT)
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	for c in _finds.get_children():
		c.queue_free()
	var all: Array = Achievements.entries()
	var got := 0
	for e in all:
		if e["got"]:
			got += 1
	_summary.text = "Получено %d из %d  ·  %d%%" % [got, all.size(), roundi(100.0 * got / maxf(all.size(), 1))]
	_bar.value = 100.0 * got / maxf(all.size(), 1)
	# Сначала полученные (свежие выше), потом начатые (по проценту), потом прочие, скрытые — в конце.
	all.sort_custom(func(a, b): return _rank(a) > _rank(b))
	for e in all:
		if _filter == "got" and not e["got"]:
			continue
		if _filter == "locked" and e["got"]:
			continue
		_list.add_child(_card(e))
	var finds: Array = Achievements.find_entries()
	var found := 0
	for f in finds:
		if f["got"]:
			found += 1
		_finds.add_child(_find_tile(f))
	_finds_title.text = "НАХОДКИ  ·  %d из %d" % [found, finds.size()]


static func _rank(e: Dictionary) -> float:
	if e["got"]:
		return 2.0e10 + float(e["date"])
	if e["hidden"]:
		return 0.0
	var p: Array = e["progress"]
	if not p.is_empty() and int(p[0]) > 0:
		return 1.0 + float(p[0]) / float(p[1])
	return 0.5


func _card(e: Dictionary) -> Control:
	var got: bool = e["got"]
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = CARD_GOT if got else CARD
	st.set_corner_radius_all(6)
	st.content_margin_left = 12
	st.content_margin_right = 14
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	st.border_width_left = 4
	st.border_color = AMBER if got else Color(1, 1, 1, 0.06)
	panel.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var icon := AchievementIcon.new()
	icon.icon = e["icon"]
	icon.unlocked = got
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var t := Label.new()
	t.text = e["title"]
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", TEXT if got else Color(0.72, 0.7, 0.66))
	col.add_child(t)
	var d := Label.new()
	d.text = e["text"]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 14)
	d.add_theme_color_override("font_color", DIM)
	col.add_child(d)
	var p: Array = e["progress"]
	if not p.is_empty():
		var prow := HBoxContainer.new()
		prow.add_theme_constant_override("separation", 10)
		col.add_child(prow)
		var bar := _progress_bar(5.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.value = 100.0 * float(p[0]) / maxf(float(p[1]), 1.0)
		prow.add_child(bar)
		var n := Label.new()
		n.text = "%d / %d" % [p[0], p[1]]
		n.add_theme_font_size_override("font_size", 13)
		n.add_theme_color_override("font_color", DIM)
		prow.add_child(n)
	var right := Label.new()
	right.custom_minimum_size = Vector2(110, 0)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_font_size_override("font_size", 13)
	if got:
		right.text = "Получено\n" + _date(int(e["date"]))
		right.add_theme_color_override("font_color", AMBER)
	else:
		right.text = ""
	row.add_child(right)
	return panel


func _find_tile(f: Dictionary) -> Control:
	var got: bool = f["got"]
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = CARD_GOT if got else CARD
	st.set_corner_radius_all(6)
	st.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(186, 0)
	panel.tooltip_text = f["text"]
	var col := VBoxContainer.new()
	panel.add_child(col)
	var t := Label.new()
	t.text = f["title"]
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", TEXT if got else DIM)
	col.add_child(t)
	var d := Label.new()
	d.text = f["text"]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 12)
	d.add_theme_color_override("font_color", DIM)
	col.add_child(d)
	return panel


static func _date(unix: int) -> String:
	if unix <= 0:
		return ""
	var dt := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system()["bias"]) * 60)
	return "%02d.%02d.%d" % [dt["day"], dt["month"], dt["year"]]


func _progress_bar(height: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _button(text: String, action: Callable, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.add_theme_color_override("font_pressed_color", AMBER)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.75, 0.3, 0.12)
	hover.set_corner_radius_all(4)
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(action)
	return b
