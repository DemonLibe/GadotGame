class_name Hud
extends CanvasLayer
## Интерфейс: поручения, батарея, подсказки, мысли героя, затемнение, виньетка страха.

const HELP := "WASD — идти    Shift — бежать\nE — действие (удерживать: зарядка, замена фильтра)\nЛКМ — горелка (жечь паутину)\nF — фонарь    H — подсказка    Esc — освободить курсор"

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

var _root: Control
var _vignette_mat: ShaderMaterial
var _prompt: Label
var _hold: ProgressBar
var _tasks: RichTextLabel
var _battery: ProgressBar
var _battery_fill: StyleBoxFlat
var _battery_label: Label
var _filters: Label
var _subtitle: Label
var _help: Label
var _fade: ColorRect
var _title: Label
var _title_sub: Label
var _queue: Array = []
var _sub_left := 0.0
var _help_left := 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var vig := ColorRect.new()
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	vig.material = _vignette_mat
	_add_full(vig)

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.45)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(dot, 0.5, 0.5, 0.5, 0.5, -2, -2, 2, 2)
	_root.add_child(dot)

	_prompt = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_prompt, 0, 0.5, 1, 0.5, 0, 40, 0, 72)

	_hold = ProgressBar.new()
	_hold.show_percentage = false
	_hold.max_value = 1.0
	_hold.visible = false
	_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_hold, 0.5, 0.5, 0.5, 0.5, -90, 80, 90, 88)
	_root.add_child(_hold)

	_tasks = RichTextLabel.new()
	_tasks.bbcode_enabled = true
	_tasks.fit_content = true
	_tasks.scroll_active = false
	_tasks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tasks.add_theme_font_size_override("normal_font_size", 17)
	_tasks.add_theme_constant_override("outline_size", 5)
	_tasks.add_theme_color_override("font_outline_color", Color.BLACK)
	_place(_tasks, 0, 0, 0, 0, 24, 20, 640, 320)
	_root.add_child(_tasks)

	_filters = _make_label(18, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_filters, 1, 1, 1, 1, -300, -108, -24, -84)
	_battery_label = _make_label(18, HORIZONTAL_ALIGNMENT_RIGHT)
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
	_root.add_child(_battery)

	_help = _make_label(16, HORIZONTAL_ALIGNMENT_LEFT)
	_help.text = HELP
	_help.modulate.a = 0.0
	_place(_help, 0, 1, 0, 1, 24, -130, 700, -20)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_add_full(_fade)

	_subtitle = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(_subtitle, 0, 1, 1, 1, 140, -200, -140, -140)

	_title = _make_label(56, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_title, 0, 0.5, 1, 0.5, 0, -130, 0, -50)
	_title_sub = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_title_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_title_sub, 0, 0.5, 1, 0.5, 160, -30, -160, 200)
	_title.modulate.a = 0.0
	_title_sub.modulate.a = 0.0

	Game.tasks_changed.connect(_refresh_tasks)
	Game.message.connect(_on_message)


func _process(delta: float) -> void:
	_sub_left -= delta
	if _sub_left <= 0.0 and not _queue.is_empty():
		var m: Array = _queue.pop_front()
		_subtitle.text = m[0]
		_subtitle.add_theme_color_override("font_color", m[1])
		_sub_left = m[2]
	_subtitle.modulate.a = clampf(_sub_left * 2.0, 0.0, 1.0)

	if Input.is_action_just_pressed("help"):
		_help_left = 10.0 if _help_left <= 0.0 else 0.0
	_help_left -= delta
	_help.modulate.a = clampf(_help_left, 0.0, 1.0)


# --- API ---------------------------------------------------------------------

func set_prompt(text: String) -> void:
	_prompt.text = text


func set_hold(progress: float) -> void:
	_hold.visible = progress >= 0.0
	_hold.value = maxf(progress, 0.0)


func set_battery(value: float, on: bool) -> void:
	_battery.value = value
	_battery_label.text = "ФОНАРЬ %d%%%s" % [int(ceil(value)), "" if on else " (выкл.)"]
	_battery_fill.bg_color = Color(0.9, 0.2, 0.15).lerp(Color(0.95, 0.85, 0.4), clampf(value / 40.0, 0.0, 1.0))


func set_filters(count: int, max_count: int) -> void:
	_filters.text = "ФИЛЬТРЫ %d/%d" % [count, max_count]


func set_fear(value: float) -> void:
	_vignette_mat.set_shader_parameter("fear", value)


func set_black() -> void:
	_fade.color.a = 1.0


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


func show_help(time: float) -> void:
	_help_left = time


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


func _make_label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	_root.add_child(l)
	return l


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
