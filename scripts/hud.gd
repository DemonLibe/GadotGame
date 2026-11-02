class_name Hud
extends CanvasLayer

signal newspaper_closed
signal diary_closed
## Интерфейс: поручения, шкала страха, выносливость, инвентарь с моделями предметов,
## батарея, подсказки, мысли героя, затемнение, виньетка страха.

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float fear = 0.0;
uniform float air = 0.0;  // удушье: темнеет в глазах, края сжимаются в такт дыханию
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.6, 1.0));
	float pulse = 0.5 + 0.5 * sin(TIME * (2.0 + fear * 5.0));
	float breath = 0.5 + 0.5 * sin(TIME * 1.6);
	float edge = smoothstep(0.35 - fear * 0.25 - air * (0.3 + breath * 0.08), 1.0, d);
	float a = clamp(edge * (0.55 + fear * 0.45 + pulse * fear * 0.2 + air * 0.6), 0.0, 1.0);
	COLOR = vec4(0.12 * fear * (1.0 - air), 0.0, 0.0, a);
}
"""
const AMBER := Color(1.0, 0.75, 0.3)
const TEXT := Color(0.86, 0.84, 0.78)
const DIM := Color(0.6, 0.58, 0.54)

var _root: Control
var _ingame: Control
var _vignette_mat: ShaderMaterial
var _prompt: Label
var _prompt_key: PanelContainer
var _prompt_key_label: Label
var _hold: ProgressBar
var _tasks: RichTextLabel
var _slip: HudWidgets.Slip
var _location: Label
var _pulse: HudWidgets.Pulse
var _item_name: Label
var _item_t := 0.0
var _last_selected := -2
var _battery: HudWidgets.SegBar
var _battery_label: Label
var _slots: Array[PanelContainer] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _slot_labels: Array[Label] = []
const ICON_SIZE := 0.3  # наибольший размер модели в иконке слота, м
var _slot_icons: Array[Node3D] = []
var _hotbar_state := ""
var _stamina_bar: HudWidgets.SegBar
var _health_bar: HudWidgets.SegBar
var _map: MapView
var _note_panel: PanelContainer
var _note_title: Label
var _note_scroll: ScrollContainer
var _note_text: Label
var _reading := false
var _paper: PanelContainer
var _paper_head: Label
var _paper_body: Label
var _paper_cap: Label
var _status: Label
var _diary: PanelContainer
var _diary_title: Label
var _diary_body: Label
var _diary_foot: Label
var _diary_scrawl: Control
var _diary_cry: Label
var _diary_pages: Array = []
var _diary_i := -1
var _money: Label
var _coin: Label
var _coin_t := 0.0
var _shop: ShopPanel
var _flash: ColorRect
var _photo: PanelContainer
var _photo_tex: TextureRect
var _photo_t := 0.0
var _toast: Label
var _toast_t := 0.0
var _scream: Label
var _paper_open := false
var player: Player
var _subtitle: Label
var _subtitle_box: PanelContainer
var _air_bar: HudWidgets.SegBar
var _air_label: Label
var _health_label: Label
var _tasks_full := false
var _tasks_shown_full := false
var _slot_counts: Array[Label] = []
var _fade: ColorRect
var _title: Label
var _title_sub: Label
var _queue: Array = []
var _sub_left := 0.0


func _ready() -> void:
	layer = 10
	_root = _full_control()
	_root.theme = HudWidgets.theme()
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

	# Подсказка под прицелом: клавиша — «клавишей», текст — рядом.
	var prompt_row := CenterContainer.new()
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(prompt_row, 0, 0.5, 1, 0.5, 0, 30, 0, 66)
	_ingame.add_child(prompt_row)
	var prompt_box := HBoxContainer.new()
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.add_theme_constant_override("separation", 8)
	prompt_row.add_child(prompt_box)
	_prompt_key = PanelContainer.new()
	_prompt_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var keycap := StyleBoxFlat.new()
	keycap.bg_color = Color(0.85, 0.82, 0.72)
	keycap.border_color = Color(0.4, 0.38, 0.33)
	keycap.border_width_bottom = 3
	keycap.set_corner_radius_all(3)
	keycap.content_margin_left = 7
	keycap.content_margin_right = 7
	_prompt_key.add_theme_stylebox_override("panel", keycap)
	_prompt_key_label = HudWidgets.label("E", 16, Color(0.1, 0.09, 0.08), HudWidgets.oswald(600))
	_prompt_key_label.add_theme_constant_override("outline_size", 0)
	_prompt_key.add_child(_prompt_key_label)
	prompt_box.add_child(_prompt_key)
	_prompt = HudWidgets.label("", 18, TEXT)
	prompt_box.add_child(_prompt)

	_hold = ProgressBar.new()
	_hold.show_percentage = false
	_hold.max_value = 1.0
	_hold.visible = false
	_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold.add_theme_stylebox_override("background", _panel_style(Color(0, 0, 0, 0.6), 0))
	var hold_fill := StyleBoxFlat.new()
	hold_fill.bg_color = AMBER
	_hold.add_theme_stylebox_override("fill", hold_fill)
	_place(_hold, 0.5, 0.5, 0.5, 0.5, -90, 72, 90, 77)
	_ingame.add_child(_hold)

	# Путевой лист — слева сверху: что осталось сделать (Tab — весь лист).
	_slip = HudWidgets.Slip.new()
	_place(_slip, 0, 0, 0, 0, 18, 16, 332, 16)
	_slip.rotation = deg_to_rad(-0.8)
	_ingame.add_child(_slip)
	_tasks = RichTextLabel.new()
	_tasks.bbcode_enabled = true
	_tasks.fit_content = true
	_tasks.scroll_active = false
	_tasks.custom_minimum_size = Vector2(290, 0)
	_tasks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tasks.add_theme_font_override("normal_font", HudWidgets.mono())
	_tasks.add_theme_font_override("bold_font", HudWidgets.mono())
	_tasks.add_theme_font_size_override("normal_font_size", 13)
	_tasks.add_theme_font_size_override("bold_font_size", 13)
	_tasks.add_theme_color_override("default_color", HudWidgets.INK)
	_tasks.add_theme_constant_override("line_separation", 2)
	_slip.add_child(_tasks)

	# Где ты — табличка справа сверху.
	var where := HudWidgets.Plate.new(6)
	where.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_place(where, 1, 0, 1, 0, -18, 16, -18, 16)
	_ingame.add_child(where)
	_location = HudWidgets.label("", 15, AMBER, HudWidgets.oswald(500))
	where.add_child(_location)

	# Приборный щиток — слева снизу: фонарь, воздух, здоровье; над ним — состояние и карманы.
	_status = HudWidgets.label("", 13, DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(_status, 0, 1, 0, 1, 20, -190, 300, -138)
	_ingame.add_child(_status)
	var vit := HudWidgets.Plate.new(8)
	vit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place(vit, 0, 1, 0, 1, 16, -16, 16, -16)
	_ingame.add_child(vit)
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 3)
	vit.add_child(vbox)
	var row := _vital_row(vbox, "ФОНАРЬ", Color(1.0, 0.82, 0.35))
	_battery_label = row[0]
	_battery = row[1]
	row = _vital_row(vbox, "ВОЗДУХ", Color(0.5, 0.82, 0.95))
	_air_label = row[0]
	_air_bar = row[1]
	row = _vital_row(vbox, "ЗДОРОВЬЕ", Color(0.9, 0.25, 0.2))
	_health_label = row[0]
	_health_bar = row[1]

	# Деньги — справа снизу, над ними — «+40 ₽ · поручение».
	var purse := HudWidgets.Plate.new(6)
	purse.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	purse.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place(purse, 1, 1, 1, 1, -16, -16, -16, -16)
	_ingame.add_child(purse)
	_money = HudWidgets.label("", 18, TEXT, HudWidgets.oswald(500))
	purse.add_child(_money)
	_coin = _make_label(_ingame, 15, HORIZONTAL_ALIGNMENT_RIGHT)
	_coin.add_theme_color_override("font_color", AMBER)
	_place(_coin, 1, 1, 1, 1, -520, -84, -22, -60)
	_coin.modulate.a = 0.0
	Meta.changed.connect(_refresh_money)
	Meta.earned.connect(func(amount: int, reason: String):
		_coin.text = "+%d ₽ · %s" % [amount, reason]
		_coin_t = 3.0
		Game.play_ui(Sfx.pickup(), -16.0))
	_refresh_money()

	# Пульс вместо шкалы страха — сверху по центру.
	var monitor := HudWidgets.Plate.new(5)
	_place(monitor, 0.5, 0, 0.5, 0, -110, 12, 110, 12)
	_ingame.add_child(monitor)
	var mrow := HBoxContainer.new()
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mrow.add_theme_constant_override("separation", 8)
	monitor.add_child(mrow)
	mrow.add_child(HudWidgets.label("ПУЛЬС", 12, Color(0.55, 0.85, 0.55), HudWidgets.oswald(500)))
	_pulse = HudWidgets.Pulse.new()
	mrow.add_child(_pulse)
	# Карта в руках — бумажная схема справа.
	_map = MapView.new()
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.visible = false
	_place(_map, 1, 0.5, 1, 0.5, -400, -250, -40, 250)
	_ingame.add_child(_map)
	# Выносливость — тонкая шкала над инвентарём; название предмета в руках — над ней.
	_stamina_bar = HudWidgets.SegBar.new(Color(0.85, 0.85, 0.78), 280.0, 4.0)
	_stamina_bar.segments = 28
	_stamina_bar.warn = 0.0
	_place(_stamina_bar, 0.5, 1, 0.5, 1, -140, -94, 140, -90)
	_ingame.add_child(_stamina_bar)
	_item_name = _make_label(_ingame, 15, HORIZONTAL_ALIGNMENT_CENTER)
	_item_name.add_theme_color_override("font_color", AMBER)
	_place(_item_name, 0, 1, 1, 1, 0, -120, 0, -98)
	_item_name.modulate.a = 0.0

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_add_full(_fade)

	# Субтитры — над инвентарём, на тёмной подложке по ширине текста.
	var sub_row := CenterContainer.new()
	sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(sub_row, 0, 1, 1, 1, 0, -210, 0, -104)
	_root.add_child(sub_row)
	_subtitle_box = PanelContainer.new()
	_subtitle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_box.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.6), 8))
	_subtitle_box.size_flags_vertical = Control.SIZE_SHRINK_END
	sub_row.add_child(_subtitle_box)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 19)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_box.add_child(_subtitle)

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
	_place(_note_panel, 0.5, 0.5, 0.5, 0.5, -360, -300, 360, 300)
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
	# Длинные записки прокручиваются колесом мыши или W / S.
	_note_scroll = ScrollContainer.new()
	_note_scroll.custom_minimum_size = Vector2(660, 440)
	_note_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nbox.add_child(_note_scroll)
	_note_text = Label.new()
	_note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_text.custom_minimum_size = Vector2(640, 0)
	_note_text.add_theme_font_size_override("font_size", 17)
	_note_text.add_theme_color_override("font_color", Color(0.15, 0.13, 0.12))
	_note_scroll.add_child(_note_text)
	var hint := Label.new()
	hint.text = "колесо мыши / W, S — листать        E / Esc — убрать"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
	nbox.add_child(hint)

	_build_newspaper()
	_build_diary()
	_build_photo()
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

	# Плашка «Достижение получено» справа сверху.
	_toast = _make_label(_root, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_toast.add_theme_color_override("font_color", AMBER)
	_place(_toast, 1, 0, 1, 0, -520, 70, -24, 130)
	_toast.modulate.a = 0.0
	Achievements.unlocked.connect(func(_id, title): show_toast("ДОСТИЖЕНИЕ\n" + title))

	Game.tasks_changed.connect(_refresh_tasks)
	Game.message.connect(_on_message)


## Панель инвентаря внизу по центру: в каждом слоте — вращающаяся модель предмета.
func setup_hotbar(player: Player, with_icons := true) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(bar, 0, 1, 1, 1, 0, -82, 0, -18)
	_ingame.add_child(bar)
	for i in Player.ITEMS.size():
		var item: String = Player.ITEMS[i]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.5)
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.15)
		style.set_corner_radius_all(4)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(76, 62)
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
		vp.size = Vector2i(76, 62)
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
		# Модель вписывается в кадр сама: крутится вокруг своего центра.
		var pivot := Node3D.new()
		pivot.rotation = Vector3(0.35, 0.9, 0)
		vp.add_child(pivot)
		var model := player.make_model(item)
		pivot.add_child(model)
		var box := Geo.mesh_bounds(model)
		var k := ICON_SIZE / maxf(box.get_longest_axis_size(), 0.001)
		model.scale = Vector3.ONE * k
		model.position = -box.get_center() * k
		_slot_icons.append(pivot)
		# Номер клавиши и количество поверх картинки.
		var label := Label.new()
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		# Количество — в правом нижнем углу.
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_font_size_override("font_size", 12)
		count.add_theme_constant_override("outline_size", 4)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_color_override("font_color", AMBER)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(count)
		_slot_counts.append(count)
		_slots.append(panel)
		_slot_styles.append(style)
		_slot_labels.append(label)


func _process(delta: float) -> void:
	_sub_left -= delta
	if _sub_left <= 0.0 and not _queue.is_empty():
		var m: Array = _queue.pop_front()
		_subtitle.text = _wrap(str(m[0]), 70)
		_subtitle.add_theme_color_override("font_color", m[1])
		_sub_left = m[2]
	_subtitle_box.modulate.a = clampf(_sub_left * 2.0, 0.0, 1.0)
	_tasks_full = Input.is_action_pressed("tasks")
	if _tasks_full != _tasks_shown_full:
		_refresh_tasks()
	_toast_t -= delta
	_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.5)
	_coin_t -= delta
	_coin.modulate.a = clampf(_coin_t, 0.0, 1.0)
	_item_t -= delta
	_item_name.modulate.a = clampf(_item_t * 2.0, 0.0, 1.0)
	_photo_t -= delta
	_photo.modulate.a = clampf(_photo_t, 0.0, 1.0)
	_photo.visible = _photo_t > 0.0
	if _diary_scrawl.is_visible_in_tree():
		# Последняя запись дрожит, будто её пишут прямо сейчас.
		_diary_cry.rotation = deg_to_rad(-4.0 + randf_range(-0.6, 0.6))
		_diary_cry.pivot_offset = _diary_cry.size / 2.0
		_diary_cry.position = (_diary_scrawl.size - _diary_cry.size) / 2.0 + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	for m in _slot_icons:
		m.rotate_y(delta * 0.6)


# --- API ---------------------------------------------------------------------

## Показать / скрыть игровой интерфейс (в меню он не нужен).
func set_ingame(value: bool) -> void:
	_ingame.visible = value


func set_prompt(text: String) -> void:
	# «E — …» и «Удерживай E — …»: клавишу — на клавишу, остальное — текстом.
	var key := ""
	var rest := text
	for pre in ["Удерживай E — ", "удерживай E — ", "E — "]:
		if text.begins_with(pre):
			key = "E"
			rest = ("держать: " if pre.to_lower().begins_with("удерж") else "") + text.substr(pre.length())
			break
	_prompt_key.visible = key != ""
	_prompt.text = rest


func set_hold(progress: float) -> void:
	_hold.visible = progress >= 0.0
	_hold.value = maxf(progress, 0.0)


func set_battery(value: float, on: bool) -> void:
	_battery.set_value(value / 100.0)
	_battery.modulate.a = 1.0 if on else 0.45
	_battery_label.text = "%d%%%s" % [int(ceil(value)), "" if on else " · выкл"]


func set_hotbar(selected: int, counts: Array, ammo: int) -> void:
	var state := "%d %s %d" % [selected, str(counts), ammo]
	if state == _hotbar_state:
		return
	_hotbar_state = state
	for i in _slots.size():
		var n: int = counts[i]
		_slot_labels[i].text = " %d" % (i + 1)
		if i < _slot_counts.size():
			var c := ""
			if Player.ITEMS[i] == "filter" or Player.ITEMS[i] == "battery" or (Player.ITEMS[i] == "canister" and n > 1):
				c = "×%d " % n
			elif Player.ITEMS[i] == "pistol" and n > 0:
				c = "%d пт " % ammo
			_slot_counts[i].text = c
			_slot_counts[i].modulate.a = 1.0 if n > 0 else 0.35
		_slot_icons[i].visible = n > 0
		_slot_labels[i].modulate.a = 1.0 if n > 0 else 0.35
		_slot_styles[i].border_color = AMBER if i == selected else HudWidgets.STEEL_EDGE
		_slot_styles[i].bg_color = Color(0.28, 0.19, 0.06, 0.85) if i == selected else HudWidgets.STEEL
	if selected != _last_selected:
		_last_selected = selected
		if selected >= 0:
			_item_name.text = str(Player.ITEM_NAMES[selected]).to_upper()
			_item_t = 1.6


func set_fear(value: float) -> void:
	_vignette_mat.set_shader_parameter("fear", value)
	_pulse.fear = value


func set_health(value: float) -> void:
	_health_bar.set_value(value)
	_health_label.text = "%d" % int(ceil(value * 100.0))


func set_air(value: float) -> void:
	_air_bar.set_value(value)
	_air_label.text = "%d%%" % int(ceil(value * 100.0))
	_vignette_mat.set_shader_parameter("air", clampf(1.0 - value / 0.35, 0.0, 1.0))


func set_map_visible(value: bool) -> void:
	if _map.visible != value:
		_map.visible = value


## Карта читает уровень и открытые сегодня участки.
func setup_map(level: Level, who: Node3D) -> void:
	_map.level = level
	_map.player = who


func update_map(limit_z: float, branches: Array, rooms: Array) -> void:
	_map.limit_z = limit_z
	_map.open_branches = branches
	_map.open_rooms = rooms


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


var _loot := 0


func _refresh_money() -> void:
	_money.text = _rub(Meta.money) + ("   ·   в мешке на " + _rub(_loot) if _loot > 0 else "")


## 127720 → «127 720 ₽».
static func _rub(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = " " + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return ("-" if n < 0 else "") + t + out + " ₽"


## Находки из старой линии при себе: платят, когда вынесешь их на станцию.
func set_loot(amount: int) -> void:
	_loot = amount
	_refresh_money()


## Шкафчик снабжения: пока открыт, обходчик стоит, мышь свободна.
func open_shop(who: Player) -> void:
	if _shop == null:
		_shop = ShopPanel.new()
		_place(_shop, 0.5, 0.5, 0.5, 0.5, -350, -300, 350, 300)
		_root.add_child(_shop)
		_shop.closed.connect(close_shop)
	who.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_shop.open(who)


func close_shop() -> void:
	if _shop == null or not _shop.visible:
		return
	_shop.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Пауза, чтобы та же E не открыла шкафчик снова.
	await get_tree().create_timer(0.25).timeout
	if _shop.player:
		_shop.player.input_locked = false


func is_shop_open() -> bool:
	return _shop != null and _shop.visible


## Вспышка фотоаппарата и снимок-«полароид» в углу экрана.
func _build_photo() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_flash)
	_photo = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.92, 0.9, 0.84)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 34
	st.shadow_color = Color(0, 0, 0, 0.6)
	st.shadow_size = 10
	_photo.add_theme_stylebox_override("panel", st)
	_place(_photo, 1.0, 1.0, 1.0, 1.0, -330, -450, -40, -220)
	_photo.rotation = deg_to_rad(3.0)
	_photo.visible = false
	_root.add_child(_photo)
	_photo_tex = TextureRect.new()
	_photo_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Снимок старой камерой: выцветший, зернистый, с тёмными краями.
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 sepia = vec3(l * 1.15, l * 1.02, l * 0.82);
	float v = 1.0 - smoothstep(0.35, 0.8, length(UV - 0.5));
	float n = fract(sin(dot(UV * 700.0, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(sepia * mix(0.45, 1.25, v) + (n - 0.5) * 0.08, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_photo_tex.material = mat
	_photo.add_child(_photo_tex)


func camera_flash() -> void:
	_flash.color.a = 0.95


func show_photo(img: Image) -> void:
	_photo_tex.texture = ImageTexture.create_from_image(img)
	_photo_t = 6.0
	_photo.visible = true


func set_map_marks(marks: Array) -> void:
	_map.marks = marks


## Дневник обходчика (концовка 2): по странице на смену. Последняя — каракули и символы.
func _build_diary() -> void:
	_diary = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.83, 0.8, 0.69)
	st.set_content_margin_all(34)
	st.border_width_left = 10
	st.border_color = Color(0.35, 0.2, 0.15)
	st.shadow_color = Color(0, 0, 0, 0.7)
	st.shadow_size = 16
	_diary.add_theme_stylebox_override("panel", st)
	_place(_diary, 0.5, 0.5, 0.5, 0.5, -370, -290, 370, 290)
	_diary.rotation = deg_to_rad(0.8)
	_diary.visible = false
	_root.add_child(_diary)
	var ink := Color(0.13, 0.16, 0.36)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_diary.add_child(box)
	_diary_title = _paper_label("", 28, ink, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_diary_title)
	_diary_body = _paper_label("", 18, ink, HORIZONTAL_ALIGNMENT_LEFT)
	_diary_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diary_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_diary_body)
	_diary_foot = _paper_label("", 13, Color(ink, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(_diary_foot)
	# Каракули поверх страницы.
	_diary_scrawl = Control.new()
	_diary_scrawl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diary_scrawl.clip_contents = true
	_diary_scrawl.draw.connect(_draw_scrawl)
	_diary.add_child(_diary_scrawl)
	_diary_cry = _paper_label("Я НЕ ДОЛЖЕН БЫЛ ВЫЖИТЬ", 44, Color(0.42, 0.04, 0.02), HORIZONTAL_ALIGNMENT_CENTER)
	_diary_cry.autowrap_mode = TextServer.AUTOWRAP_OFF
	_diary_scrawl.add_child(_diary_cry)


func show_diary(pages: Array) -> void:
	_diary_pages = pages
	_diary_i = 0
	_show_diary_page()
	_diary.visible = true


func _show_diary_page() -> void:
	var page: Array = _diary_pages[_diary_i]
	var scrawl := page.size() > 2
	_diary_title.text = page[0]
	_diary_body.text = page[1]
	_diary_scrawl.visible = scrawl
	_diary_scrawl.queue_redraw()
	var last := _diary_i == _diary_pages.size() - 1
	_diary_foot.text = "%d / %d     E — %s" % [_diary_i + 1, _diary_pages.size(), "закрыть" if last else "дальше"]
	if scrawl:
		Game.play_ui(Sfx.whisper(), -4.0)
		Game.play_ui(Sfx.sting(), -8.0)


## E на странице дневника: дальше, а с последней — закрыть.
func next_diary_page() -> void:
	if not _diary.visible:
		return
	_diary_i += 1
	Game.play_ui(Sfx.click(), -10.0)
	if _diary_i < _diary_pages.size():
		_show_diary_page()
		return
	_diary.visible = false
	diary_closed.emit()


## Последняя запись: символы, перевёрнутые и зеркальные буквы, восьмёрки и каракули поверх всего.
func _draw_scrawl() -> void:
	var c := _diary_scrawl
	var font := c.get_theme_default_font()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var glyphs := "ЖЩЪЫЭЮЯΨΩΔΣλψωжыъфщ#ЁЬЧ"
	var ink := Color(0.13, 0.16, 0.36)
	var blood := Color(0.42, 0.04, 0.02)
	for i in 70:
		var s := ""
		for k in rng.randi_range(1, 4):
			s += glyphs[rng.randi_range(0, glyphs.length() - 1)]
		var pos := Vector2(rng.randf_range(10.0, c.size.x - 40.0), rng.randf_range(50.0, c.size.y - 20.0))
		var flip := -1.0 if rng.randf() < 0.4 else 1.0
		c.draw_set_transform(pos, rng.randf_range(-0.9, 0.9), Vector2(flip * rng.randf_range(0.8, 1.5), rng.randf_range(0.8, 1.3)))
		var col := ink if rng.randf() < 0.7 else blood
		c.draw_string(font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, rng.randi_range(14, 34), Color(col, rng.randf_range(0.45, 0.9)))
	# Строки восьмёрок, будто кто-то считал.
	for row in 3:
		c.draw_set_transform(Vector2(20.0, 70.0 + row * 150.0), rng.randf_range(-0.05, 0.05), Vector2.ONE)
		c.draw_string(font, Vector2.ZERO, "8 8 8 8 8 8 8 8 8 8 8 8 8 8", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(ink, 0.35))
	c.draw_set_transform(Vector2.ZERO)
	# Каракули: рваные линии, нажим то сильнее, то слабее.
	for i in 16:
		var pts := PackedVector2Array()
		var p := Vector2(rng.randf_range(0.0, c.size.x), rng.randf_range(40.0, c.size.y))
		for k in rng.randi_range(10, 28):
			pts.append(p)
			p += Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-14.0, 14.0))
		c.draw_polyline(pts, Color(ink if i % 3 else blood, rng.randf_range(0.4, 0.8)), rng.randf_range(1.0, 2.6))


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
	"C": ["ТОННЕЛЬ ЗА СТАНЦИЕЙ «ТИХАЯ» ЗАМУРОВАН ИЗНУТРИ", "фото: решётка, 323-й метр",
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
	_note_scroll.scroll_vertical = 0
	_note_panel.visible = true
	_reading = true
	if player:
		player.input_locked = true


func _input(event: InputEvent) -> void:
	if _diary.visible and (event.is_action_pressed("interact") or event.is_action_pressed("burn") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		next_diary_page()
		return
	if _paper_open and (event.is_action_pressed("interact") or event.is_action_pressed("burn") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close_newspaper()
		return
	if not _reading:
		return
	var wheel := event as InputEventMouseButton
	if wheel and wheel.pressed and (wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN or wheel.button_index == MOUSE_BUTTON_WHEEL_UP):
		_note_scroll.scroll_vertical += 60 if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN else -60
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_back") or event.is_action_pressed("move_forward"):
		_note_scroll.scroll_vertical += 80 if event.is_action_pressed("move_back") else -80
		get_viewport().set_input_as_handled()
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


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_t = 4.0
	Game.play_ui(Sfx.pickup(), -4.0)


func set_status(text: String) -> void:
	_status.text = text
	_status.visible = text != ""


func set_stamina(value: float, exhausted: bool) -> void:
	_stamina_bar.set_value(value)
	_stamina_bar.modulate.a = 0.0 if value >= 0.999 else 1.0
	_stamina_bar.color = Color(0.95, 0.4, 0.25) if exhausted else Color(0.85, 0.85, 0.78)


## Где обходчик: «ТОННЕЛЬ · ПК 3», «СТАРАЯ ЛИНИЯ»…
func set_location(text: String) -> void:
	_location.text = text


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
	_tasks_shown_full = _tasks_full
	var open := 0
	for t in Game.tasks:
		if not t["done"]:
			open += 1
	_slip.stamp = "СМЕНА № %d" % Game.day
	_slip.queue_redraw()
	var faded := Color(HudWidgets.INK, 0.45).to_html()
	var lines: PackedStringArray = []
	var shown := 0
	var hidden := 0
	for t in Game.tasks:
		var text := str(t["text"])
		if int(t["target"]) > 1:
			text += " [%d/%d]" % [int(t["progress"]), int(t["target"])]
		if t["done"]:
			if _tasks_full:
				lines.append("[color=#%s][s]— %s[/s][/color]" % [faded, text])
			continue
		if not _tasks_full and shown >= 5:
			hidden += 1
			continue
		lines.append("— " + text)
		shown += 1
	if open == 0:
		lines.append("Всё сделано. Доложить.")
	if hidden > 0:
		lines.append("[color=#%s]…ещё %d (Tab)[/color]" % [faded, hidden])
	lines.append("[font_size=11][color=#%s]записки %d/%d%s[/color][/font_size]" % [faded, Game.notes_count(), Game.NOTES_TOTAL,
		"" if _tasks_full else " · Tab — весь лист"])
	_tasks.text = "\n".join(lines)


## Полупрозрачная тёмная плашка.
func _panel_style(bg: Color, margin: float) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(4)
	st.set_content_margin_all(margin)
	return st


## Строка прибора: название слева, значение справа, сегментная шкала под ними. Возвращает [значение, шкала].
func _vital_row(parent: Control, title: String, color: Color) -> Array:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(head)
	var name_l := HudWidgets.label(title, 12, DIM, HudWidgets.oswald(500))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	var val := HudWidgets.label("", 13, color, HudWidgets.oswald(600))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(val)
	var bar := HudWidgets.SegBar.new(color, 168.0, 8.0)
	parent.add_child(bar)
	return [val, bar]


## Перенос субтитра по словам (ширина подложки — по тексту).
static func _wrap(text: String, width: int) -> String:
	var out: PackedStringArray = []
	var line := ""
	for w in text.split(" "):
		if line.length() + w.length() + 1 > width and line != "":
			out.append(line)
			line = w
		else:
			line = w if line == "" else line + " " + w
	out.append(line)
	return "\n".join(out)


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
