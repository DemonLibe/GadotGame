class_name Player
extends CharacterBody3D
## Обходчик: ходьба, бег с выносливостью, прыжок, подъём по лестнице,
## инвентарь (в руках один предмет или ничего), налобный фонарь с батареей, горелка, рация, взаимодействие.

signal footstep
signal died

const WALK_SPEED := 2.6
const CROUCH_SPEED := 1.3
const HEAD_STAND := 1.62
const HEAD_CROUCH := 1.0
## Насколько далеко слышно (м): шаг, бег, шаг вприсядку, приземление, выстрел, ступенька.
const NOISE_WALK := 7.0
const NOISE_RUN := 18.0
const NOISE_CROUCH := 2.0
const NOISE_LAND := 10.0
const NOISE_SHOT := 45.0
const NOISE_RUNG := 6.0
const BREATH_DRAIN := 18.0
const RUN_SPEED := 4.2
const CLIMB_SPEED := 0.85               # 100 м лестницы — около двух минут
const GRAVITY := 12.0
const MOUSE_SENS := 0.0022
const MAX_FILTERS := 3
const MAX_BATTERIES := 2
const DRAIN_PER_SEC := 100.0 / 300.0    # полный заряд — 5 минут
## Ручка динамо (R): процентов в секунду (с находкой «аккумулятор» — быстрее) и сколько метров слышно треск.
const CRANK_RATE := 0.9
const CRANK_RATE_CELL := 1.2
const NOISE_CRANK := 12.0
const NOISE_CRANK_CELL := 8.0
const NOISE_CRANK_HIDDEN := 4.0
## Болты: сколько влезает в карман и сколько при себе в начале смены.
const MAX_BOLTS := 6
const START_BOLTS := 2
const REACH := 2.4
const STEP_LENGTH := 1.25
const RUNG_STEP := 0.3
const HAND_POS := Vector3(0.24, -0.2, -0.42)
const HEADLAMP_OFFSET := Vector3(0.0, 0.09, -0.06)
const HAND_LAYER := 2  # визуальный слой предметов в руке (их подсвечивает своя лампочка)
const JUMP_VELOCITY := 4.2
const STAMINA_MAX := 100.0
const STAMINA_RUN := 22.0      # расход в секунду при беге
const STAMINA_REGEN := 14.0
const STAMINA_JUMP := 18.0
const STAMINA_DELAY := 0.9     # пауза перед восстановлением

const HEALTH_MAX := 100.0
const SHOT_RANGE := 40.0

## Слоты инвентаря (клавиши 1–7). Фонарь налобный — он не в руках, а включается клавишей F.
const ITEMS := ["burner", "filter", "battery", "radio", "map", "pistol", "canister"]
const ITEM_NAMES := ["Горелка", "Фильтр", "Батарейка", "Рация", "Карта", "Пистолет", "Канистра"]

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float length = 9.0;
uniform float intensity = 0.07;
varying float along;
void vertex() {
	along = VERTEX.y / length + 0.5;  // 0 у фонаря, 1 на дальнем конце
}
void fragment() {
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = vec3(1.0, 0.93, 0.8);
	ALPHA = intensity * (1.0 - along) * edge;
}
"""

var hud: Hud
var battery := 60.0
var flashlight_on := true
var filters := 0
var batteries := 0
var selected := -1  # -1 — руки пусты
var input_locked := false
var drain_mult := 1.0
var upgrade_drain := 1.0      # находка «аккумулятор»
var ran_today := false        # для достижения «Тихоня»
var climbing := false
var crouching := false
var hiding := false          # сидит в шкафу
var holding_breath := false
var canisters := 0
var bolts := 0                # болты в кармане — бросить (G), чтобы отвлечь
var fuses := 0                # запасной предохранитель для щитка
var relays := 0               # ретрансляторы рации, которые надо развесить
var cranking := false         # крутит ручку динамо
var cranked_today := 0.0      # сколько процентов накрутил за смену
var _crank_sound: AudioStreamPlayer
var _crank_noise := 0.0
var speed_mult := 1.0        # вода в штольне замедляет
var climb_mult := 1.0        # в финале по лестнице лезут быстрее
var _hideout = null
var _breath_block := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var extra_shake := 0.0  # тряска камеры от обвала и скримера
var stamina := STAMINA_MAX
var has_radio := false
var has_pistol := false
var ammo := 0
var health := HEALTH_MAX
var _hurt_wait := 0.0
var _shot_cd := 0.0
var _muzzle: OmniLight3D
var dispatcher  # Dispatcher — повторить последнее сообщение по рации
var _exhausted := false
var _stamina_wait := 0.0

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D

var _ray: RayCast3D
var _hand: Node3D
var _models := {}
var _flame: CPUParticles3D
var _torch_light: OmniLight3D
var _flame_sound: AudioStreamPlayer
var _step_sound: AudioStreamPlayer
var _click_sound: AudioStreamPlayer
var _rung_sound: AudioStreamPlayer
var _target = null  # интерактивный объект под прицелом (утиная типизация)
var _ladder = null
var _burning := false
var _bob := 0.0
var _bob_amp := 0.0
var _step_acc := 0.0
var _flicker := 0.0
var _pitch := 0.0
var _empty_warned := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1 | Geo.WALL_LAYER
	floor_snap_length = 0.35

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.875
	add_child(shape)

	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	camera = Camera3D.new()
	_apply_settings()
	Settings.changed.connect(_apply_settings)
	camera.near = 0.03
	camera.current = true
	head.add_child(camera)

	# Луч фонаря живёт отдельно от камеры и догоняет её с небольшой инерцией.
	flashlight = SpotLight3D.new()
	flashlight.top_level = true
	flashlight.light_color = Color(1.0, 0.93, 0.8)
	flashlight.light_energy = 4.0
	flashlight.spot_range = 26.0
	flashlight.spot_angle = 24.0
	flashlight.spot_attenuation = 0.9
	flashlight.shadow_enabled = true
	flashlight.light_volumetric_fog_energy = 1.5
	add_child(flashlight)
	if Main.is_web_renderer() and not Main.debug_flag("nobeam"):
		flashlight.add_child(_make_beam())
	if Main.debug_flag("noshadow"):
		flashlight.shadow_enabled = false
	apply_upgrades()

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -REACH)
	_ray.collision_mask = 3
	_ray.collide_with_areas = true
	camera.add_child(_ray)

	_hand = Node3D.new()
	_hand.position = HAND_POS
	camera.add_child(_hand)
	_build_models()

	_flame_sound = _sound(Sfx.flame(), -10.0)
	_step_sound = _sound(Sfx.step(), -14.0)
	_click_sound = _sound(Sfx.click(), -6.0)
	_rung_sound = _sound(Sfx.rung(), -12.0)
	_crank_sound = _sound(Sfx.crank(), -9.0)
	_show_selected()


# --- Модели в руке -----------------------------------------------------------

func _build_models() -> void:
	for item in ITEMS:
		var m := make_model(item)
		_models[item] = m
		_hand.add_child(m)
		for mi in m.find_children("*", "VisualInstance3D", true, false):
			(mi as VisualInstance3D).layers = 1 | HAND_LAYER
	# Налобный фонарь светит вперёд, а не на руки: слабая подсветка только для предмета в руке
	# (отдельный слой — тоннель от неё светлее не становится).
	var fill := OmniLight3D.new()
	fill.light_cull_mask = HAND_LAYER
	fill.light_color = Color(1.0, 0.9, 0.75)
	fill.light_energy = 0.6
	fill.omni_range = 1.2
	fill.shadow_enabled = false
	fill.position = Vector3(0.0, 0.15, 0.1)
	camera.add_child(fill)
	# Огонь и свет горелки — только у модели в руке.
	var burner: Node3D = _models["burner"]
	_flame = ProcTex.fire(48, 0.35)
	_flame.direction = Vector3(0, 0, -1)
	_flame.spread = 10.0
	_flame.initial_velocity_min = 2.0
	_flame.initial_velocity_max = 3.2
	_flame.gravity = Vector3(0, 1.0, 0)
	_flame.position = Vector3(0, 0, -0.16)
	burner.add_child(_flame)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.55, 0.2)
	_torch_light.omni_range = 5.0
	_torch_light.light_energy = 0.0
	_torch_light.visible = false
	_torch_light.position = Vector3(0, 0, -0.5)
	burner.add_child(_torch_light)
	var pistol: Node3D = _models["pistol"]
	_muzzle = OmniLight3D.new()
	_muzzle.light_color = Color(1.0, 0.8, 0.5)
	_muzzle.omni_range = 6.0
	_muzzle.light_energy = 3.0
	_muzzle.visible = false
	_muzzle.position = Vector3(0, 0.02, -0.15)
	pistol.add_child(_muzzle)


## Модель предмета — для руки и для иконки в инвентаре.
func make_model(item: String) -> Node3D:
	var steel := ProcTex.flat(Color(0.25, 0.25, 0.27), 0.4, 0.8)
	var along := Basis(Vector3.RIGHT, PI / 2)
	var root := Node3D.new()
	match item:
		"burner":
			# Баллончик — пропановый баллон из Containers Pack (loafbrr_1, CC0), сопло — своё.
			Geo.model_fit(root, "res://models/items/propane.glb", ProcTex.model_skin("res://models/items/propane_albedo.png", Color(0.8, 0.75, 0.7), 0.6, 0.3), 0.15, Vector3(0, -0.12, 0.1))
			Geo.cylinder(root, Vector3(0, 0, -0.02), 0.014, 0.25, ProcTex.flat(Color(0.4, 0.4, 0.42), 0.4, 0.9), along)
			Geo.box(root, Vector3(0, -0.02, 0.08), Vector3(0.02, 0.05, 0.03), steel, false)
		"filter":
			Geo.box(root, Vector3(-0.05, 0.02, 0.0), Vector3(0.28, 0.24, 0.03), steel, false)
			Geo.box(root, Vector3(-0.05, 0.02, 0.0), Vector3(0.25, 0.21, 0.05), ProcTex.flat(Color(0.88, 0.88, 0.82), 0.95), false)
			for k in 4:
				Geo.box(root, Vector3(-0.05, -0.06 + k * 0.055, 0.027), Vector3(0.24, 0.01, 0.005), ProcTex.flat(Color(0.7, 0.7, 0.65), 0.95), false)
		"battery":
			# Survival Items (artie31, CC0).
			Geo.model_fit(root, "res://models/items/battery.glb", ProcTex.model_skin("res://models/items/survival_palette.png", Color(0.85, 0.85, 0.85), 0.5, 0.2), 0.12, Vector3(0, -0.06, 0), Basis(Vector3.RIGHT, -PI / 2))
		"map":
			var paper := ProcTex.flat(Color(0.86, 0.82, 0.7), 1.0)
			var left := Geo.box(root, Vector3(-0.07, 0, 0), Vector3(0.14, 0.2, 0.004), paper, false)
			left.rotation.y = 0.25
			var right := Geo.box(root, Vector3(0.07, 0, 0), Vector3(0.14, 0.2, 0.004), paper, false)
			right.rotation.y = -0.25
			var ink := ProcTex.flat(Color(0.25, 0.2, 0.15), 1.0)
			Geo.box(root, Vector3(0.0, 0.0, 0.025), Vector3(0.012, 0.16, 0.002), ink, false)
			Geo.box(root, Vector3(-0.06, -0.03, 0.02), Vector3(0.09, 0.008, 0.002), ink, false)
		"pistol":
			# Pistol (loafbrr_1, CC0): ствол вдоль модели по X — поворачиваем вперёд (-Z), почти точно в прицел,
			# чтобы в руке он был виден сзади, вдоль ствола, а не боком.
			Geo.model_fit(root, "res://models/items/pistol.glb", ProcTex.model_skin("res://models/items/pistol_albedo.png", Color(0.7, 0.7, 0.74), 0.4, 0.7), 0.19, Vector3(-0.06, -0.03, 0.04), Basis(Vector3.UP, PI / 2 + 0.06) * Basis(Vector3.RIGHT, 0.04))
		"canister":
			# Jerry can из Containers Pack (loafbrr_1, CC0).
			Geo.model_fit(root, "res://models/items/jerrycan.glb", ProcTex.model_skin("res://models/items/jerrycan_albedo.png", Color(0.8, 0.7, 0.68), 0.5, 0.3), 0.26, Vector3(0, -0.13, 0))
		"radio":
			# Radio (laleksic, CC0) — переносная станция с антенной.
			Geo.model_fit(root, "res://models/items/radio.glb", ProcTex.model_skin("res://models/items/radio_albedo.png", Color(0.85, 0.85, 0.85), 0.7, 0.1), 0.22, Vector3(-0.04, -0.03, 0), Basis(Vector3.UP, PI - 0.4))
	return root


## Видимый луч для браузерного рендера: прозрачный конус, гаснущий к краям и вдаль.
func _make_beam() -> MeshInstance3D:
	var length := 9.0
	var cone := CylinderMesh.new()
	cone.height = length
	cone.top_radius = tan(deg_to_rad(flashlight.spot_angle)) * length
	cone.bottom_radius = 0.03
	cone.radial_segments = 24
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var shader := Shader.new()
	shader.code = BEAM_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("length", length)
	var beam := MeshInstance3D.new()
	beam.mesh = cone
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Ось цилиндра (Y) разворачиваем вперёд (-Z), узкий конец — у фонаря.
	beam.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0, -length / 2))
	return beam


func _apply_settings() -> void:
	camera.fov = float(Settings.get_value("fov"))


func _sound(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p


# --- Инвентарь ---------------------------------------------------------------

func held() -> String:
	return ITEMS[selected] if selected >= 0 else ""


func count_of(item: String) -> int:
	match item:
		"filter":
			return filters
		"battery":
			return batteries
		"radio":
			return 1 if has_radio else 0
		"pistol":
			return 1 if has_pistol else 0
		"canister":
			return canisters
	return 1


func counts() -> Array:
	var c := []
	for item in ITEMS:
		c.append(count_of(item))
	return c


## Взять предмет в руки; та же клавиша ещё раз — убрать (руки пусты).
func select(index: int) -> void:
	if index < -1 or index >= ITEMS.size():
		return
	if index == selected:
		index = -1
	selected = index
	_hand.position = HAND_POS + Vector3(0, -0.35, 0)
	create_tween().tween_property(_hand, "position", HAND_POS, 0.22).set_ease(Tween.EASE_OUT)
	_click_sound.play()
	_show_selected()


## Взять в руки именно этот предмет ("" — убрать всё из рук).
func hold(item: String) -> void:
	var i := ITEMS.find(item)
	if i != selected:
		select(i)


## Следующий/предыдущий непустой слот (колесо мыши).
func cycle(step: int) -> void:
	var i := selected if selected >= 0 else (-1 if step > 0 else 0)
	for k in ITEMS.size():
		i = posmod(i + step, ITEMS.size())
		if count_of(ITEMS[i]) > 0:
			if i != selected:
				select(i)
			return


## Действие предметом в руке (ЛКМ). Горелка работает, пока кнопка зажата.
func use_item() -> void:
	if cranking:
		return  # руки заняты ручкой
	match held():
		"battery":
			if batteries <= 0:
				return
			if battery >= 99.0:
				Game.say("Фонарь и так заряжен.", Game.SYSTEM, 2.0)
				return
			batteries -= 1
			battery = 100.0
			_empty_warned = false
			Game.play_at(Sfx.clank(), global_position + Vector3(0, 1.4, 0), -12.0)
			Game.say("Новая батарейка. Фонарь заряжен.", Game.SYSTEM, 2.5)
		"filter":
			if filters > 0:
				Game.say("Фильтр ставится в вентблок: подойди и удерживай E.", Game.SYSTEM, 3.0)
		"radio":
			# Всё сделано — доклад и конец смены; иначе диспетчер подскажет, куда идти.
			if has_radio and dispatcher:
				dispatcher.radio_pressed(Game.day)
		"pistol":
			_shoot()


func _show_selected() -> void:
	for key in _models:
		var m: Node3D = _models[key]
		m.visible = key == held() and count_of(key) > 0


## Сброс в начале смены.
func reset_for_day(pos: Vector3, yaw: float, start_battery: float) -> void:
	climbing = false
	_ladder = null
	global_position = pos
	rotation.y = yaw
	_pitch = 0.0
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	battery = start_battery
	flashlight_on = true
	filters = 0
	batteries = 0
	selected = -1
	stamina = STAMINA_MAX
	_exhausted = false
	has_radio = false
	has_pistol = false
	ammo = 0
	health = HEALTH_MAX
	crouching = false
	hiding = false
	holding_breath = false
	_hideout = null
	canisters = 0
	bolts = START_BOLTS
	fuses = 0
	relays = 0
	cranking = false
	cranked_today = 0.0
	_crank_sound.stop()
	speed_mult = 1.0
	climb_mult = 1.0
	ran_today = false
	head.position.y = HEAD_STAND
	apply_upgrades()
	_burning = false
	_flame.emitting = false
	_show_selected()


# --- Ввод --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * float(Settings.get_value("mouse_sens"))
		var dy := -motion.relative.y if Settings.get_value("invert_y") else motion.relative.y
		rotate_y(-motion.relative.x * sens)
		_pitch = clampf(_pitch - dy * sens, -1.45, 1.45)
		head.rotation.x = _pitch
		return
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle(-1)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle(1)


func _physics_process(delta: float) -> void:
	if climbing:
		_climb(delta)
		return
	if hiding:
		_hide_update(delta)
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var input := Vector2.ZERO
	if not input_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	# Бег тратит выносливость; выдохся — бежать нельзя, пока не отдышишься.
	crouching = Input.is_action_pressed("crouch") and not input_locked
	head.position.y = move_toward(head.position.y, HEAD_CROUCH if crouching else HEAD_STAND, delta * 4.0)
	var running := Input.is_action_pressed("run") and input.length() > 0.1 and not _exhausted and not input_locked and not crouching and not cranking
	if running:
		ran_today = true
		stamina = maxf(0.0, stamina - STAMINA_RUN * delta)
		_stamina_wait = STAMINA_DELAY
		if stamina <= 0.0:
			_exhausted = true
			Game.say_once("exhausted", "Дыхание сбилось... Надо отдышаться.")
	else:
		_stamina_wait -= delta
		if _stamina_wait <= 0.0:
			stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
	if _exhausted and stamina >= 30.0:
		_exhausted = false
	if Input.is_action_just_pressed("jump") and not input_locked and not crouching and is_on_floor() and stamina >= STAMINA_JUMP:
		velocity.y = JUMP_VELOCITY
		stamina -= STAMINA_JUMP
		_stamina_wait = STAMINA_DELAY
	var speed := (RUN_SPEED if running else (CROUCH_SPEED if crouching or cranking else WALK_SPEED)) * speed_mult
	velocity.x = move_toward(velocity.x, dir.x * speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 20.0 * delta)
	if not is_on_floor():
		_fall_speed = maxf(_fall_speed, -velocity.y)
	move_and_slide()
	# Приземление слышно.
	if is_on_floor() and not _was_on_floor and _fall_speed > 3.0:
		Game.make_noise(global_position, NOISE_LAND)
	if is_on_floor():
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()

	# Покачивание головы и шаги.
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.4:
		_step_acc += delta * hspeed
		_bob += delta * hspeed * PI / STEP_LENGTH
		_bob_amp = move_toward(_bob_amp, 1.0, delta * 4.0)
		if _step_acc >= STEP_LENGTH:
			_step_acc = 0.0
			_step_sound.pitch_scale = randf_range(0.85, 1.1)
			_step_sound.volume_db = -22.0 if crouching else -14.0
			_step_sound.play()
			footstep.emit()
			var noise := NOISE_CROUCH if crouching else (NOISE_RUN if running else NOISE_WALK)
			if speed_mult < 0.9:
				noise *= 2.0  # по воде хлюпает
			Game.make_noise(global_position, noise)
	else:
		_bob_amp = move_toward(_bob_amp, 0.0, delta * 4.0)
	var shake := pow(Game.fear / Achievements.fear_max(), 2.0) * 0.02 + extra_shake
	camera.position = Vector3(cos(_bob) * 0.025, absf(sin(_bob)) * 0.04, 0) * _bob_amp \
		+ Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0)


# --- Укрытие -----------------------------------------------------------------

func enter_hide(hideout) -> void:
	if hiding or climbing:
		return
	hiding = true
	_hideout = hideout
	crouching = false
	velocity = Vector3.ZERO
	global_position = hideout.inside_pos()
	rotation.y = hideout.facing_yaw()
	_pitch = 0.0
	head.rotation.x = 0.0
	head.position.y = HEAD_STAND
	Game.play_at(Sfx.clank(), global_position + Vector3(0, 1, 0), -14.0)
	Game.say_once("hide", "Тихо. Если оно рядом — задержать дыхание (Space).", Game.THOUGHT, 3.5)


func exit_hide() -> void:
	if not hiding:
		return
	hiding = false
	holding_breath = false
	global_position = _hideout.exit_pos()
	_hideout = null
	Game.play_at(Sfx.clank(), global_position + Vector3(0, 1, 0), -14.0)


func _hide_update(delta: float) -> void:
	velocity = Vector3.ZERO
	_breath_block -= delta
	var want := Input.is_action_pressed("jump") and not input_locked and _breath_block <= 0.0
	holding_breath = want and stamina > 0.0
	if holding_breath:
		stamina = maxf(0.0, stamina - BREATH_DRAIN * delta)
		_stamina_wait = STAMINA_DELAY
		if stamina <= 0.0:
			# Не выдержал — шумный вдох.
			holding_breath = false
			_breath_block = 2.5
			Game.play_at(Sfx.gasp(), global_position + Vector3(0, 1.5, 0), 0.0)
			Game.make_noise(global_position, 7.0)
			Game.say_once("gasp", "Не могу... воздуха...", Game.THOUGHT, 2.0)
	else:
		_stamina_wait -= delta
		if _stamina_wait <= 0.0:
			stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
	camera.position = Vector3.ZERO


# --- Лестница ----------------------------------------------------------------

func start_climb(ladder) -> void:
	if climbing:
		return
	_ladder = ladder
	climbing = true
	velocity = Vector3.ZERO
	var y := global_position.y
	if y > ladder.top_y - 0.5:
		y -= 1.0  # сверху — сразу опускаемся в люк
	global_position = Vector3(ladder.climb_x, clampf(y, ladder.bottom_y, ladder.top_y - 1.2), ladder.climb_z)
	rotation.y = ladder.facing_yaw
	Game.say_once("ladder", "Сто метров вниз. Не смотреть вниз. Просто считать ступеньки.")


func stop_climb(pos: Vector3) -> void:
	climbing = false
	_ladder = null
	global_position = pos
	velocity = Vector3.ZERO


func _climb(delta: float) -> void:
	var up := 0.0
	if not input_locked:
		up = Input.get_axis("move_back", "move_forward")
	var y := global_position.y + up * CLIMB_SPEED * climb_mult * delta
	if up > 0.0 and y >= _ladder.top_y - 1.2:
		stop_climb(_ladder.exit_top)
		return
	if up < 0.0 and y <= _ladder.bottom_y:
		stop_climb(Vector3(global_position.x, _ladder.bottom_y + 0.02, global_position.z + _ladder.away * 0.3))
		return
	global_position.y = y
	velocity = Vector3.ZERO
	if up != 0.0:
		_step_acc += absf(up) * CLIMB_SPEED * climb_mult * delta
		_bob += delta * PI * 1.5
		if _step_acc >= RUNG_STEP:
			_step_acc = 0.0
			_rung_sound.pitch_scale = randf_range(0.9, 1.1)
			_rung_sound.play()
			Game.make_noise(global_position, NOISE_RUNG)
			footstep.emit()
	camera.position = Vector3(sin(_bob) * 0.02, absf(cos(_bob)) * 0.03, 0)


# --- Каждый кадр -------------------------------------------------------------

func _process(delta: float) -> void:
	if not input_locked:
		for i in ITEMS.size():
			if Input.is_action_just_pressed("slot_%d" % (i + 1)):
				select(i)
		if Input.is_action_just_pressed("flashlight"):
			toggle_light()
		if Input.is_action_just_pressed("throw"):
			throw_bolt()
		if Input.is_action_just_pressed("burn") and held() != "burner":
			use_item()
	_show_selected()
	_shot_cd -= delta
	if _muzzle.visible and _shot_cd < 0.3:
		_muzzle.visible = false
	_hurt_wait -= delta
	if _hurt_wait <= 0.0 and health < HEALTH_MAX:
		health = minf(HEALTH_MAX, health + 1.5 * delta)
	_update_crank(delta)
	_update_battery(delta)
	_sync_flashlight(delta)
	_update_burner(delta)
	_update_interaction(delta)
	if hud:
		hud.set_battery(battery, flashlight_on)
		hud.set_hotbar(selected, counts(), ammo)
		hud.set_health(health / HEALTH_MAX)
		hud.set_map_visible(held() == "map" and not input_locked)
		hud.set_stamina(stamina / STAMINA_MAX, _exhausted)
		var st := ""
		if cranking:
			st = "КРУТИШЬ ДИНАМО · треск слышно" + (" (в шкафу — тише)" if hiding else "")
		elif hiding:
			st = "В ШКАФУ · ДЫХАНИЕ ЗАДЕРЖАНО" if holding_breath else "В ШКАФУ · держи Space — не дышать"
		elif crouching:
			st = "ПРИСЕЛ · шаги почти не слышны"
		if canisters > 0:
			st += ("   " if st != "" else "") + "канистр: %d" % canisters
		if bolts > 0:
			st += ("   " if st != "" else "") + "болтов: %d (G)" % bolts
		if fuses > 0:
			st += ("   " if st != "" else "") + "предохранитель"
		if relays > 0:
			st += ("   " if st != "" else "") + "ретрансляторов: %d" % relays
		hud.set_status(st)


## Ручка динамо: пока крутишь — заряд растёт, а не тратится, но треск слышат все, кто рядом.
func _update_crank(delta: float) -> void:
	var want := Input.is_action_pressed("crank") and not input_locked and not climbing and battery < 100.0
	if want != cranking:
		cranking = want
		if cranking:
			_crank_sound.play()
			_crank_noise = 0.0
		else:
			_crank_sound.stop()
	if not cranking:
		return
	var cell := Achievements.has_find("cell")
	var add := (CRANK_RATE_CELL if cell else CRANK_RATE) * delta
	battery = minf(100.0, battery + add)
	cranked_today += add
	_empty_warned = false
	if cranked_today >= 20.0:
		Game.report("crank")
	_crank_noise -= delta
	if _crank_noise <= 0.0:
		_crank_noise = 0.5
		Game.make_noise(global_position, NOISE_CRANK_HIDDEN if hiding else (NOISE_CRANK_CELL if cell else NOISE_CRANK))


func _update_battery(delta: float) -> void:
	var on := flashlight_on and battery > 0.0
	if on and not cranking:
		battery = maxf(0.0, battery - DRAIN_PER_SEC * drain_mult * upgrade_drain * delta)
		if battery <= 0.0 and not _empty_warned:
			_empty_warned = true
			Game.say("Фонарь сел. Батарейка — или крутить ручку (R). Быстро.")
	if on and battery < 20.0:
		Game.say_once("crank_hint", "Фонарь садится. R — крутить ручку динамо. Только треск слышно далеко.", Game.SYSTEM, 5.0)
	var energy := 4.0 * clampf(battery / 30.0, 0.25, 1.0)
	if cranking:
		# Пока крутишь — луч тусклый и пульсирует в такт ручке.
		energy *= 0.35 + 0.25 * absf(sin(Time.get_ticks_msec() * 0.012))
	if battery < 15.0 and randf() < 0.04:
		_flicker = maxf(_flicker, randf_range(0.05, 0.2))
	if _flicker > 0.0:
		_flicker -= delta
		if randf() < 0.5:
			energy *= randf_range(0.0, 0.2)
	flashlight.visible = on and battery > 0.0
	flashlight.light_energy = energy


## Налобный фонарь: над глазами, луч чуть отстаёт от поворота головы.
func _sync_flashlight(delta: float) -> void:
	flashlight.global_position = camera.global_position + camera.global_transform.basis * HEADLAMP_OFFSET
	var from := flashlight.global_transform.basis.get_rotation_quaternion()
	var to := camera.global_transform.basis.get_rotation_quaternion()
	flashlight.global_transform.basis = Basis(from.slerp(to, clampf(delta * 12.0, 0.0, 1.0)))


func _update_burner(delta: float) -> void:
	# Газа мало: горелка зажигается, только когда прицел на паутине.
	var aiming_web: bool = _target != null and is_instance_valid(_target) and _target.has_method("burn")
	if Input.is_action_just_pressed("burn") and held() == "burner" and not aiming_web and not input_locked:
		_click_sound.play()
		Game.say_once("burner_hint", "Газа мало. Горелку зажигаю только у паутины.", Game.THOUGHT, 3.0)
	var want := Input.is_action_pressed("burn") and not input_locked and held() == "burner" and aiming_web and not cranking
	if want != _burning:
		_burning = want
		_flame.emitting = want
		_torch_light.visible = want
		if want:
			_flame_sound.play()
		else:
			_flame_sound.stop()
	_torch_light.light_energy = randf_range(2.2, 3.0) if _burning else 0.0
	if _burning and _target != null and is_instance_valid(_target) and _target.has_method("burn"):
		_target.burn(delta * 0.85)


func _update_interaction(delta: float) -> void:
	var t = null
	if hiding:
		t = _hideout  # изнутри шкафа луч его не видит — выход по E всегда
	elif _ray.is_colliding():
		t = _find_interactable(_ray.get_collider())
	if _target != null and not is_instance_valid(_target):
		_target = null
	if t != _target:
		if _target != null and _target.has_method("hold_cancel"):
			_target.hold_cancel()
		_target = t
	var prompt := ""
	var hold := -1.0
	if _target != null and not input_locked:
		prompt = _target.get_prompt(self)
		if Input.is_action_just_pressed("interact") and _target.has_method("interact"):
			_target.interact(self)
		if _target != null and is_instance_valid(_target) and _target.has_method("hold_interact"):
			if Input.is_action_pressed("interact"):
				hold = _target.hold_interact(self, delta)
			else:
				_target.hold_cancel()
		if _target is Spider:
			Game.say_once("spider_first", "Паук... Говорили, они тут безобидные. Только паутину плетут без конца.")
	if hud:
		hud.set_prompt(prompt)
		hud.set_hold(hold)


func _find_interactable(o: Object) -> Node:
	var n := o as Node
	while n != null and not n.has_method("get_prompt"):
		n = n.get_parent()
	return n


# --- Для других систем -------------------------------------------------------

func _shoot() -> void:
	if not has_pistol or _shot_cd > 0.0 or cranking:
		return
	_shot_cd = 0.45
	if ammo <= 0:
		_click_sound.play()
		Game.say_once("no_ammo", "Пусто. Патроны — в ящиках по тоннелю.", Game.THOUGHT, 3.0)
		return
	ammo -= 1
	Game.play_ui(Sfx.gunshot(), -2.0)
	Game.make_noise(global_position, NOISE_SHOT)
	_muzzle.visible = true
	_pitch = clampf(_pitch + 0.04, -1.45, 1.45)
	head.rotation.x = _pitch
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * SHOT_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | Geo.WALL_LAYER | Crawler.LAYER)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit["collider"].has_method("hit"):
		hit["collider"].hit()


## Бросить болт по взгляду: там, где он звякнет, его и будут искать.
func throw_bolt() -> void:
	if bolts <= 0 or hiding or climbing or cranking:
		if bolts <= 0:
			Game.say_once("no_bolts", "Болтов нет. Они валяются по тоннелю — в коробках у стен.", Game.THOUGHT, 3.0)
		return
	bolts -= 1
	var b := Bolt.new()
	get_tree().current_scene.add_child(b)
	var fwd := -camera.global_transform.basis.z
	b.throw(camera.global_position + fwd * 0.4, fwd)
	Game.say_once("bolt_thrown", "Звякнет — и они пойдут туда. Не ко мне.", Game.THOUGHT, 3.0)


func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	_hurt_wait = 6.0
	flicker(0.4)
	if health <= 0.0:
		died.emit()
	else:
		Game.say_once("hurt", "Оно меня задело... Кровь. Надо держаться света.", Game.THOUGHT, 3.0)


func is_burning() -> bool:
	return _burning


## Свет, который держит страх: только фонарь. Горелка страх не снимает.
func has_light() -> bool:
	return flashlight.visible


## Находки для фонаря: рефлектор — луч длиннее и шире, аккумулятор — садится медленнее.
func apply_upgrades() -> void:
	var lens := Achievements.has_find("lens")
	flashlight.spot_range = 34.0 if lens else 26.0
	flashlight.spot_angle = 29.0 if lens else 24.0
	upgrade_drain = 0.7 if Achievements.has_find("cell") else 1.0


## Налобный фонарь: щелчок — включить или выключить.
func toggle_light() -> void:
	flashlight_on = not flashlight_on
	_click_sound.play()


func flicker(time: float) -> void:
	_flicker = maxf(_flicker, time)


## Отладка: повернуть взгляд (наклон, поворот относительно текущего).
func debug_look(pitch: float, yaw: float) -> void:
	_pitch = pitch
	head.rotation.x = pitch
	rotate_y(yaw)


func forward_flat() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


## Попадает ли точка в луч фонаря (с проверкой препятствий).
func is_lighting(point: Vector3) -> bool:
	if not flashlight.visible:
		return false
	var origin := flashlight.global_position
	var to := point - origin
	if to.length() > flashlight.spot_range:
		return false
	var fwd := -flashlight.global_transform.basis.z
	if fwd.dot(to.normalized()) < cos(deg_to_rad(flashlight.spot_angle)):
		return false
	return _clear_line(origin, point)


func is_looking_at(point: Vector3, min_dot: float) -> bool:
	var to := point - camera.global_position
	if (-camera.global_transform.basis.z).dot(to.normalized()) < min_dot:
		return false
	return _clear_line(camera.global_position, point)


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | Geo.WALL_LAYER)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
