class_name TesterMenu
extends CanvasLayer
## ВРЕМЕННО: меню тестировщика (F9). Смены, концовки, телепорты, выдача вещей.
## Удалить: файл + 4 строки с TesterMenu в main.gd.

var main: Node
var _panel: PanelContainer
var _god := false


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.position = Vector2(40, 30)
	add_child(_panel)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.92)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_label(box, "МЕНЮ ТЕСТИРОВЩИКА (F9 — закрыть)")
	_label(box, "Смена (сверху)")
	var row := HBoxContainer.new()
	box.add_child(row)
	for d in range(1, 8):
		_btn(row, str(d), func(): _shift(d, false))
	_label(box, "Смена (сразу внизу)")
	row = HBoxContainer.new()
	box.add_child(row)
	for d in range(1, 8):
		_btn(row, str(d), func(): _shift(d, true))
	_label(box, "Концовки")
	row = HBoxContainer.new()
	box.add_child(row)
	_btn(row, "1 Обвал/газета", func(): _ending(1))
	_btn(row, "2 Метро", func(): _ending(2))
	_btn(row, "3 Решётка", func(): _ending(3))
	_btn(row, "Выбраться → смена 6", func(): _ending(4))
	_label(box, "Телепорт")
	row = HBoxContainer.new()
	box.add_child(row)
	_btn(row, "Станция", func(): _tp(Main.SPAWN))
	_btn(row, "Низ шахты", func(): _tp(Main.BOTTOM_SPAWN))
	_btn(row, "Пролом", func(): _tp(Vector3(0, Level.FLOOR_Y + 0.1, Level.OLD_BREACH_Z)))
	_btn(row, "Решётка", func(): _tp(Vector3(0, Level.FLOOR_Y + 0.1, Level.GRATE_Z + 3.0)))
	_btn(row, "Метро", func(): _tp(Vector3(0, Level.FLOOR_Y + 0.1, Level.METRO_Z1 + 6.0)))
	_label(box, "Помощь")
	row = HBoxContainer.new()
	box.add_child(row)
	_btn(row, "Бессмертие", func(): _god = not _god)
	_btn(row, "Вещи", _gear)
	_btn(row, "Все записки", _notes)
	_btn(row, "Закрыть задания", _tasks)


func _label(p: Node, t: String) -> void:
	var l := Label.new()
	l.text = t
	p.add_child(l)


func _btn(p: Node, t: String, f: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.pressed.connect(f)
	p.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		if _panel.visible:
			_close()
		elif main.state == "playing":
			_open()


func _process(_d: float) -> void:
	if _god and main.player:
		main.player.health = main.player.HEALTH_MAX


func _open() -> void:
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close() -> void:
	_panel.visible = false
	get_tree().paused = false
	main._grace = 1.5
	main._uncaptured = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _shift(d: int, below: bool) -> void:
	_close()
	main.busy = false
	main.collapsing = false
	main.start_day(d, below)


func _ending(n: int) -> void:
	_close()
	main.busy = false
	main.collapsing = false
	match n:
		1:
			await main.start_day(Game.FINAL_DAY)
			main.busy = false
			main.collapsing = true
			main._final_scene()
		2:
			await main.start_day(Game.LAST_DAY)
			main.busy = false
			main.ending_metro()
		3:
			await main.start_day(Game.FINAL_DAY)
			main.busy = false
			main.collapsing = true
			main._ending_seal()
		4:
			await main.start_day(Game.FINAL_DAY)
			main.busy = false
			main.collapsing = true
			main._ending_climb()


func _tp(pos: Vector3) -> void:
	_close()
	main.player.global_position = pos


func _gear() -> void:
	var p: Player = main.player
	p.has_radio = true
	p.has_pistol = true
	p.ammo = 30
	p.batteries = 9
	p.canisters = 5
	p.filters = 5
	p.fuses = 3
	p.bolts = 10
	p.relays = 5


func _notes() -> void:
	for k in main.NOTES:
		Game.notes_read[k] = true


func _tasks() -> void:
	for t in Game.tasks:
		Game.report(t["kind"], int(t["target"]))
