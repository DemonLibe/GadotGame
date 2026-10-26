class_name Hud
extends CanvasLayer
## Интерфейс: поручения, инвентарь, батарея, подсказки, мысли героя, затемнение, виньетка страха.

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
var _slot_names: Array = []
var _hotbar_state := ""
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

	_tasks = RichTextLabel.new()
	_tasks.bbcode_enabled = true
	_tasks.fit_content = true
	_tasks.scroll_active = false
	_tasks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tasks.add_theme_font_size_override("normal_font_size", 17)
	_tasks.add_theme_font_size_override("bold_font_size", 17)
	_tasks.add_theme_constant_override("outline_size", 5)
	_tasks.add_theme_color_override("font_outline_color", Color.BLACK)
	_place(_tasks, 0, 0, 0, 0, 24, 20, 640, 320)
	_ingame.add_child(_tasks)

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

	Game.tasks_changed.connect(_refresh_tasks)
	Game.message.connect(_on_message)


## Панель инвентаря внизу по центру: по слоту на предмет.
func setup_hotbar(names: Array) -> void:
	_slot_names = names
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(bar, 0, 1, 1, 1, 0, -92, 0, -24)
	_ingame.add_child(bar)
	for i in names.size():
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.5)
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.15)
		style.set_corner_radius_all(4)
		style.content_margin_left = 10
		style.content_margin_right = 10
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(124, 60)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		panel.add_child(label)
		bar.add_child(panel)
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


func set_hotbar(selected: int, counts: Array) -> void:
	var state := "%d %s" % [selected, str(counts)]
	if state == _hotbar_state:
		return
	_hotbar_state = state
	for i in _slots.size():
		var n: int = counts[i]
		var text := "%d  %s" % [i + 1, _slot_names[i]]
		if i >= 2:
			text += "\n× %d" % n
		_slot_labels[i].text = text
		_slot_labels[i].modulate.a = 1.0 if n > 0 else 0.35
		_slot_styles[i].border_color = AMBER if i == selected else Color(1, 1, 1, 0.15)
		_slot_styles[i].bg_color = Color(0.25, 0.17, 0.05, 0.6) if i == selected else Color(0, 0, 0, 0.5)


func set_fear(value: float) -> void:
	_vignette_mat.set_shader_parameter("fear", value)


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
	while _queue.size() > 3:
		_queue.pop_front()


func _refresh_tasks() -> void:
	var lines: PackedStringArray = ["[b]СМЕНА %d — ПОРУЧЕНИЯ[/b]" % Game.day]
	for t in Game.tasks:
		var text := str(t["text"])
		if int(t["target"]) > 1:
			text += " (%d/%d)" % [int(t["progress"]), int(t["target"])]
		if t["done"]:
			lines.append("[color=#7a9a7a][s]%s[/s][/color]" % text)
		else:
			lines.append("• " + text)
	_tasks.text = "\n".join(lines)


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
