class_name Hud
extends CanvasLayer

signal newspaper_closed
## Интерфейс: поручения, шкала страха, выносливость, инвентарь с моделями предметов,
## батарея, подсказки, мысли героя, затемнение, виньетка страха.

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float fear = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.6, 1.0));
	float pulse = 0.5 + 0.5 * sin(TIME * (2.0 + fear * 5.0));
	float edge = smoothstep(0.35 - fear * 0.25, 1.0, d);
	float a = clamp(edge * (0.55 + fear * 0.45 + pulse * fear * 0.2), 0.0, 1.0);
	COLOR = vec4(0.12 * fear, 0.0, 0.0, a);
}
"""
const AMBER := Color(1.0, 0.75, 0.3)

var _root: Control
var _ingame: Control
var _vignette_mat: ShaderMaterial
var _prompt: Label
var _hold: ProgressBar
var _tasks: RichTextLabel
var _battery: ProgressBar
var _battery_fill: StyleBoxFlat
var _battery_label: Label
var _slots: Array[PanelContainer] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _slot_labels: Array[Label] = []
var _slot_icons: Array[Node3D] = []
var _hotbar_state := ""
var _fear_bar: ProgressBar
var _fear_fill: StyleBoxFlat
var _stamina_bar: ProgressBar
var _stamina_fill: StyleBoxFlat
var _health_bar: ProgressBar
var _map: MapView
var _note_panel: PanelContainer
var _note_title: Label
var _note_text: Label
var _reading := false
var _paper: PanelContainer
var _paper_head: Label
var _paper_body: Label
var _paper_cap: Label
var _status: Label
var _scream: Label
var _paper_open := false
var player: Player
var _subtitle: Label
var _fade: ColorRect
var _title: Label
var _title_sub: Label
var _queue: Array = []
var _sub_left := 0.0


func _ready() -> void:
	layer = 10
	_root = _full_control()
	add_child(_root)

	var vig := ColorRect.new()
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	vig.material = _vignette_mat
	_add_full(vig)

	_ingame = _full_control()
	_root.add_child(_ingame)

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.45)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(dot, 0.5, 0.5, 0.5, 0.5, -2, -2, 2, 2)
	_ingame.add_child(dot)

	_prompt = _make_label(_ingame, 20, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_prompt, 0, 0.5, 1, 0.5, 0, 40, 0, 72)

	_hold = ProgressBar.new()
	_hold.show_percentage = false
	_hold.max_value = 1.0
	_hold.visible = false
	_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_hold, 0.5, 0.5, 0.5, 0.5, -90, 80, 90, 88)
	_ingame.add_child(_hold)

	# Список дел — на маленьком бумажном планшете с зажимом.
	var board := PanelContainer.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color(0.36, 0.25, 0.15)
	board_style.set_corner_radius_all(6)
	board_style.set_content_margin_all(8)
	board_style.content_margin_top = 18
	board_style.shadow_color = Color(0, 0, 0, 0.5)
	board_style.shadow_size = 6
	board.add_theme_stylebox_override("panel", board_style)
	_place(board, 0, 0, 0, 0, 18, 14, 330, 14)
	board.rotation = deg_to_rad(-1.5)
	_ingame.add_child(board)
	var sheet := PanelContainer.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet_style := StyleBoxFlat.new()
	sheet_style.bg_color = Color(0.88, 0.85, 0.74)
	sheet_style.set_content_margin_all(10)
	sheet.add_theme_stylebox_override("panel", sheet_style)
	board.add_child(sheet)
	var clip := ColorRect.new()
	clip.color = Color(0.55, 0.56, 0.58)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(clip, 0, 0, 0, 0, 140, 8, 200, 24)
	_ingame.add_child(clip)
	_tasks = RichTextLabel.new()
	_tasks.bbcode_enabled = true
	_tasks.fit_content = true
	_tasks.scroll_active = false
	_tasks.custom_minimum_size = Vector2(290, 0)
	_tasks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tasks.add_theme_font_size_override("normal_font_size", 14)
	_tasks.add_theme_font_size_override("bold_font_size", 15)
	_tasks.add_theme_color_override("default_color", Color(0.15, 0.13, 0.12))
	sheet.add_child(_tasks)

	# Состояние: присел, в шкафу, задержал дыхание.
	_status = _make_label(_ingame, 16, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_status, 0, 1, 0, 1, 24, -80, 420, -56)

	_battery_label = _make_label(_ingame, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_battery_label, 1, 1, 1, 1, -300, -80, -24, -56)
	_battery = ProgressBar.new()
	_battery.show_percentage = false
	_battery.max_value = 100.0
	_battery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_battery.add_theme_stylebox_override("background", bg)
	_battery_fill = StyleBoxFlat.new()
	_battery_fill.bg_color = Color(0.95, 0.85, 0.4)
	_battery.add_theme_stylebox_override("fill", _battery_fill)
	_place(_battery, 1, 1, 1, 1, -224, -48, -24, -36)
	_ingame.add_child(_battery)

	# Шкала страха — сверху по центру.
	var fear_label := _make_label(_ingame, 14, HORIZONTAL_ALIGNMENT_CENTER)
	fear_label.text = "СТРАХ"
	fear_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.55))
	_place(fear_label, 0.5, 0, 0.5, 0, -150, 10, 150, 28)
	_fear_bar = _bar(Color(0.55, 0.08, 0.06))
	_fear_fill = _fear_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_place(_fear_bar, 0.5, 0, 0.5, 0, -150, 32, 150, 42)
	_ingame.add_child(_fear_bar)
	_health_bar = _bar(Color(0.75, 0.2, 0.18))
	_place(_health_bar, 0.5, 0, 0.5, 0, -150, 48, 150, 54)
	_ingame.add_child(_health_bar)
	# Карта в руках — бумажная схема справа.
	_map = MapView.new()
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.visible = false
	_place(_map, 1, 0.5, 1, 0.5, -400, -250, -40, 250)
	_ingame.add_child(_map)
	# Выносливость — тонкая полоска над инвентарём.
	_stamina_bar = _bar(Color(0.8, 0.82, 0.75))
	_stamina_fill = _stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_place(_stamina_bar, 0.5, 1, 0.5, 1, -160, -112, 160, -106)
	_ingame.add_child(_stamina_bar)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_add_full(_fade)

	_subtitle = _make_label(_root, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(_subtitle, 0, 1, 1, 1, 140, -230, -140, -150)

	_title = _make_label(_root, 56, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_title, 0, 0.5, 1, 0.5, 0, -130, 0, -50)
	_title_sub = _make_label(_root, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_title_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_title_sub, 0, 0.5, 1, 0.5, 160, -30, -160, 200)
	_title.modulate.a = 0.0
	_title_sub.modulate.a = 0.0

	# Записка во весь экран.
	_note_panel = PanelContainer.new()
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(0.84, 0.8, 0.66)
	ns.set_content_margin_all(28)
	ns.shadow_color = Color(0, 0, 0, 0.6)
	ns.shadow_size = 12
	_note_panel.add_theme_stylebox_override("panel", ns)
	_place(_note_panel, 0.5, 0.5, 0.5, 0.5, -300, -260, 300, 260)
	_note_panel.rotation = deg_to_rad(0.8)
	_note_panel.visible = false
	_root.add_child(_note_panel)
	var nbox := VBoxContainer.new()
	nbox.add_theme_constant_override("separation", 14)
	_note_panel.add_child(nbox)
	_note_title = Label.new()
	_note_title.add_theme_font_size_override("font_size", 22)
	_note_title.add_theme_color_override("font_color", Color(0.2, 0.12, 0.08))
	nbox.add_child(_note_title)
	_note_text = Label.new()
	_note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_text.custom_minimum_size = Vector2(540, 0)
	_note_text.add_theme_font_size_override("font_size", 18)
	_note_text.add_theme_color_override("font_color", Color(0.15, 0.13, 0.12))
	nbox.add_child(_note_text)
	var hint := Label.new()
	hint.text = "E / Esc — убрать"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
	nbox.add_child(hint)

	_build_newspaper()
	_scream = Label.new()
	_scream.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scream.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_scream.add_theme_font_size_override("font_size", 46)
	_scream.add_theme_color_override("font_color", Color(0.85, 0.05, 0.05))
	_scream.add_theme_constant_override("outline_size", 10)
	_scream.add_theme_color_override("font_outline_color", Color.BLACK)
	_place(_scream, 0, 0, 1, 1, 40, 40, -40, -60)
	_scream.visible = false
	_root.add_child(_scream)

	Game.tasks_changed.connect(_refresh_tasks)
	Game.message.connect(_on_message)


## Панель инвентаря внизу по центру: в каждом слоте — вращающаяся модель предмета.
func setup_hotbar(player: Player, with_icons := true) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(bar, 0, 1, 1, 1, 0, -100, 0, -20)
	_ingame.add_child(bar)
	for i in Player.ITEMS.size():
		var item: String = Player.ITEMS[i]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.5)
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.15)
		style.set_corner_radius_all(4)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(96, 76)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", style)
		bar.add_child(panel)
		if not with_icons:
			_slot_icons.append(Node3D.new())
			var plain := Label.new()
			plain.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			plain.add_theme_font_size_override("font_size", 13)
			plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(plain)
			_slots.append(panel)
			_slot_styles.append(style)
			_slot_labels.append(plain)
			plain.text = Player.ITEM_NAMES[i]
			continue
		# Своя маленькая 3D-сцена: камера, свет и модель предмета.
		var holder := SubViewportContainer.new()
		holder.stretch = true
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(holder)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.size = Vector2i(96, 76)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		holder.add_child(vp)
		var cam := Camera3D.new()
		cam.position = Vector3(0, 0.02, 0.55)
		cam.fov = 32.0
		vp.add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.6, 0.6, 0)
		sun.light_energy = 1.6
		vp.add_child(sun)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
		env.environment.ambient_light_energy = 0.6
		vp.add_child(env)
		var model := player.make_model(item)
		model.scale = Vector3.ONE * float(Player.ICON_SCALE[item])
		model.rotation = Vector3(0.35, 0.9, 0)
		vp.add_child(model)
		_slot_icons.append(model)
		# Номер клавиши и количество поверх картинки.
		var label := Label.new()
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		_slots.append(panel)
		_slot_styles.append(style)
		_slot_labels.append(label)


func _process(delta: float) -> void:
	_sub_left -= delta
	if _sub_left <= 0.0 and not _queue.is_empty():
		var m: Array = _queue.pop_front()
		_subtitle.text = m[0]
		_subtitle.add_theme_color_override("font_color", m[1])
		_sub_left = m[2]
	_subtitle.modulate.a = clampf(_sub_left * 2.0, 0.0, 1.0)
	for m in _slot_icons:
		m.rotate_y(delta * 0.6)


# --- API ---------------------------------------------------------------------

## Показать / скрыть игровой интерфейс (в меню он не нужен).
func set_ingame(value: bool) -> void:
	_ingame.visible = value


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_hold(progress: float) -> void:
	_hold.visible = progress >= 0.0
	_hold.value = maxf(progress, 0.0)


func set_battery(value: float, on: bool) -> void:
	_battery.value = value
	_battery_label.text = "ФОНАРЬ %d%%%s" % [int(ceil(value)), "" if on else " (выкл.)"]
	_battery_fill.bg_color = Color(0.9, 0.2, 0.15).lerp(Color(0.95, 0.85, 0.4), clampf(value / 40.0, 0.0, 1.0))


func set_hotbar(selected: int, counts: Array, ammo: int) -> void:
	var state := "%d %s %d" % [selected, str(counts), ammo]
	if state == _hotbar_state:
		return
	_hotbar_state = state
	for i in _slots.size():
		var n: int = counts[i]
		var text := " %d" % (i + 1)
		if Player.ITEMS[i] == "filter" or Player.ITEMS[i] == "battery":
			text += "           × %d" % n
		elif Player.ITEMS[i] == "pistol" and n > 0:
			text += "         пт %d" % ammo
		_slot_labels[i].text = text
		_slot_icons[i].visible = n > 0
		_slot_labels[i].modulate.a = 1.0 if n > 0 else 0.35
		_slot_styles[i].border_color = AMBER if i == selected else Color(1, 1, 1, 0.15)
		_slot_styles[i].bg_color = Color(0.25, 0.17, 0.05, 0.6) if i == selected else Color(0, 0, 0, 0.5)


func set_fear(value: float) -> void:
	_vignette_mat.set_shader_parameter("fear", value)
	_fear_bar.value = value * 100.0
	_fear_fill.bg_color = Color(0.45, 0.08, 0.06).lerp(Color(1.0, 0.15, 0.1), value)


func set_health(value: float) -> void:
	_health_bar.value = value * 100.0
	_health_bar.modulate.a = 0.0 if value >= 0.999 else 1.0


func set_map_visible(value: bool) -> void:
	if _map.visible != value:
		_map.visible = value


## Карта читает уровень и открытые сегодня участки.
func setup_map(level: Level, who: Node3D) -> void:
	_map.level = level
	_map.player = who


func update_map(limit_z: float, branches: Array, rooms: Array, chargers: Array[Vector3]) -> void:
	_map.limit_z = limit_z
	_map.open_branches = branches
	_map.open_rooms = rooms
	_map.chargers = chargers


## Газета в финале: «погиб ещё один обходчик».
func _build_newspaper() -> void:
	_paper = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.86, 0.83, 0.74)
	st.set_content_margin_all(30)
	st.shadow_color = Color(0, 0, 0, 0.7)
	st.shadow_size = 16
	_paper.add_theme_stylebox_override("panel", st)
	_place(_paper, 0.5, 0.5, 0.5, 0.5, -390, -300, 390, 300)
	_paper.rotation = deg_to_rad(-1.2)
	_paper.visible = false
	_root.add_child(_paper)
	var ink := Color(0.12, 0.11, 0.1)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_paper.add_child(box)
	box.add_child(_paper_label("ПОДЗЕМНЫЙ ВЕСТНИК", 44, ink, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_paper_label("ежедневная газета метрополитена   •   № 43   •   цена 5 коп.", 13, Color(ink, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	var rule := ColorRect.new()
	rule.color = ink
	rule.custom_minimum_size = Vector2(0, 3)
	box.add_child(rule)
	_paper_head = _paper_label("", 26, ink, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_paper_head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var photo := ColorRect.new()
	photo.color = Color(0.16, 0.15, 0.14)
	photo.custom_minimum_size = Vector2(230, 230)
	_paper_cap = _paper_label("", 12, Color(0.75, 0.73, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
	_paper_cap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_paper_cap.position = Vector2(30, 200)
	photo.add_child(_paper_cap)
	row.add_child(photo)
	var body := _paper_label("", 15, ink, HORIZONTAL_ALIGNMENT_LEFT)
	_paper_body = body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(450, 0)
	row.add_child(body)
	box.add_child(_paper_label("E — дальше", 13, Color(ink, 0.6), HORIZONTAL_ALIGNMENT_RIGHT))


func _paper_label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if size >= 20:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Три концовки — три разные заметки.
var _newspapers := {
	"A": ["НА ЗАКРЫТОЙ СТАНЦИИ «ТИХАЯ» ПОГИБ ЕЩЁ ОДИН ОБХОДЧИК", "фото: вход в шахту № 3",
		"Вчера ночью на законсервированной станции «Тихая» погиб обходчик — восьмой за сорок лет. "
		+ "Последний доклад по рации поступил в 03:12: «Тоннель рушится, бегу к станции». На записи есть и ответ: «Принял. Стой у станции. Мы идём».\n\n"
		+ "Однако пульт диспетчерской станции «Тихая» отключён от сети с 2001 года. Кто отвечал обходчику пять ночей подряд, установить не удалось.\n\n"
		+ "Тело не найдено. У погибшего осталась дочь семи лет. Объявление о наборе нового обходчика — на странице 6."],
	"B": ["ОБХОДЧИК СТАНЦИИ «ТИХАЯ» ВЫБРАЛСЯ ИЗ-ПОД ЗАВАЛА — И ПРОПАЛ", "фото: журнал смен",
		"Под утро обходчик поднялся по шахте № 3 на поверхность, весь в бетонной пыли. Домой он не вернулся. "
		+ "В журнале смен его рукой сделана последняя запись: «Смена сдана. Восьмой».\n\n"
		+ "Соседи рассказывают, что ночью у его подъезда слышали скрежет — будто по асфальту ползло что-то тяжёлое.\n\n"
		+ "Дочь пропавшего, Маша, каждый вечер ждёт отца у окна. Пульт диспетчерской станции отключён с 2001 года."],
	"C": ["ТОННЕЛЬ ЗА СТАНЦИЕЙ «ТИХАЯ» ЗАМУРОВАН ИЗНУТРИ", "фото: решётка, 232-й метр",
		"Спасатели не смогли открыть решётку в конце тоннеля: она заперта изнутри, на замок обходчика. "
		+ "За решёткой тишина. Обвал прекратился сам.\n\n"
		+ "Впервые за сорок лет датчики станции не фиксируют никакого движения. Набор обходчиков прекращён.\n\n"
		+ "Семье обходчика выплачено жалованье за год вперёд. Говорят, его дочь Маша успешно перенесла операцию и уже начала бегать."],
}


func show_newspaper(variant := "A") -> void:
	var paper: Array = _newspapers.get(variant, _newspapers["A"])
	_paper_head.text = paper[0]
	_paper_cap.text = paper[1]
	_paper_body.text = paper[2]
	_paper.visible = true
	_paper_open = true


func close_newspaper() -> void:
	if not _paper_open:
		return
	_paper_open = false
	_paper.visible = false
	newspaper_closed.emit()


func show_scream(text: String) -> void:
	_scream.text = text
	_scream.visible = true


func hide_scream() -> void:
	_scream.visible = false


func is_reading() -> bool:
	return _reading


func show_note(title: String, text: String) -> void:
	_note_title.text = title
	_note_text.text = text
	_note_panel.visible = true
	_reading = true
	if player:
		player.input_locked = true


func _input(event: InputEvent) -> void:
	if _paper_open and (event.is_action_pressed("interact") or event.is_action_pressed("burn") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close_newspaper()
		return
	if not _reading:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("burn"):
		get_viewport().set_input_as_handled()
		close_note()


func close_note() -> void:
	_note_panel.visible = false
	# Небольшая пауза, чтобы та же клавиша E не открыла записку снова.
	await get_tree().create_timer(0.25).timeout
	_reading = false
	if player:
		player.input_locked = false


func set_status(text: String) -> void:
	_status.text = text


func set_stamina(value: float, exhausted: bool) -> void:
	_stamina_bar.value = value * 100.0
	_stamina_bar.modulate.a = 0.25 if value >= 0.999 else 1.0
	_stamina_fill.bg_color = Color(0.9, 0.35, 0.2) if exhausted else Color(0.8, 0.82, 0.75)


func hide_vignette() -> void:
	for c in _root.get_children():
		if c is ColorRect and (c as ColorRect).material == _vignette_mat:
			c.visible = false


func fade_alpha() -> float:
	return _fade.color.a


func set_black() -> void:
	_fade.color.a = 1.0


func set_clear() -> void:
	_fade.color.a = 0.0


func fade_to(alpha: float, time: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	return tw


## Большой заголовок по центру. hold <= 0 — оставить на экране.
func show_title(title: String, sub: String, hold: float) -> void:
	_title.text = title
	_title_sub.text = sub
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "modulate:a", 1.0, 1.0)
	tw.tween_property(_title_sub, "modulate:a", 1.0, 1.0)
	if hold > 0.0:
		var out := create_tween().set_parallel(true)
		out.tween_property(_title, "modulate:a", 0.0, 1.0).set_delay(hold)
		out.tween_property(_title_sub, "modulate:a", 0.0, 1.0).set_delay(hold)


func hide_title() -> void:
	_title.modulate.a = 0.0
	_title_sub.modulate.a = 0.0


# --- Внутреннее --------------------------------------------------------------

func _on_message(text: String, color: Color, duration: float) -> void:
	_queue.append([text, color, duration])
	while _queue.size() > 8:
		_queue.pop_front()


func _refresh_tasks() -> void:
	var lines: PackedStringArray = ["[b]СМЕНА № %d — СПИСОК ДЕЛ[/b]" % Game.day, ""]
	for t in Game.tasks:
		var text := str(t["text"])
		if int(t["target"]) > 1:
			text += " (%d/%d)" % [int(t["progress"]), int(t["target"])]
		if t["done"]:
			lines.append("[color=#6b6a5e][s]%s[/s][/color]" % text)
		else:
			lines.append("— " + text)
	lines.append("")
	lines.append("[color=#6b5a48]записки: %d из %d[/color]" % [Game.notes_count(), Game.NOTES_TOTAL])
	_tasks.text = "\n".join(lines)


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _make_label(parent: Control, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(l)
	return l


func _full_control() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(c, 0, 0, 1, 1, 0, 0, 0, 0)
	return c


func _add_full(c: ColorRect) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(c, 0, 0, 1, 1, 0, 0, 0, 0)
	_root.add_child(c)


func _place(c: Control, al: float, at: float, ar: float, ab: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b
