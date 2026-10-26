class_name Player
extends CharacterBody3D
## Обходчик: ходьба от первого лица, фонарь с батареей, горелка для паутины, взаимодействие.

signal footstep

const WALK_SPEED := 2.6
const RUN_SPEED := 4.4
const GRAVITY := 12.0
const MOUSE_SENS := 0.0022
const MAX_FILTERS := 3
const DRAIN_PER_SEC := 100.0 / 300.0  # полный заряд — 5 минут
const REACH := 2.4
const STEP_LENGTH := 1.25
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
var input_locked := false
var drain_mult := 1.0

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D

var _ray: RayCast3D
var _flame: CPUParticles3D
var _torch_light: OmniLight3D
var _flame_sound: AudioStreamPlayer
var _step_sound: AudioStreamPlayer
var _click_sound: AudioStreamPlayer
var _target = null  # интерактивный объект под прицелом (утиная типизация)
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
	collision_mask = 1
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
	camera.fov = 72.0
	camera.near = 0.03
	camera.current = true
	head.add_child(camera)

	# Фонарь живёт отдельно от камеры и догоняет её с небольшой инерцией.
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
	if Main.is_web_renderer():
		flashlight.add_child(_make_beam())

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -REACH)
	_ray.collision_mask = 3
	_ray.collide_with_areas = true
	camera.add_child(_ray)

	# Горелка в правой руке.
	var torch := Node3D.new()
	torch.position = Vector3(0.26, -0.24, -0.45)
	camera.add_child(torch)
	Geo.cylinder(torch, Vector3(0, 0, 0.1), 0.025, 0.25, ProcTex.flat(Color(0.4, 0.4, 0.42), 0.4, 0.9), Basis(Vector3.RIGHT, PI / 2))
	Geo.cylinder(torch, Vector3(0, -0.05, 0.25), 0.045, 0.16, ProcTex.flat(Color(0.6, 0.1, 0.08), 0.6, 0.3))
	_flame = ProcTex.fire(48, 0.35)
	_flame.direction = Vector3(0, 0, -1)
	_flame.spread = 10.0
	_flame.initial_velocity_min = 2.0
	_flame.initial_velocity_max = 3.2
	_flame.gravity = Vector3(0, 1.0, 0)
	_flame.position = Vector3(0, 0, -0.05)
	torch.add_child(_flame)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.55, 0.2)
	_torch_light.omni_range = 5.0
	_torch_light.light_energy = 0.0
	_torch_light.position = Vector3(0, 0, -0.4)
	torch.add_child(_torch_light)

	_flame_sound = _sound(Sfx.flame(), -10.0)
	_step_sound = _sound(Sfx.step(), -14.0)
	_click_sound = _sound(Sfx.click(), -6.0)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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


func _sound(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not input_locked:
		rotate_y(-motion.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENS, -1.45, 1.45)
		head.rotation.x = _pitch
		return
	var button := event as InputEventMouseButton
	if button and button.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var input := Vector2.ZERO
	if not input_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	velocity.x = move_toward(velocity.x, dir.x * speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 20.0 * delta)
	move_and_slide()

	# Покачивание головы и шаги.
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.4:
		_step_acc += delta * hspeed
		_bob += delta * hspeed * PI / STEP_LENGTH
		_bob_amp = move_toward(_bob_amp, 1.0, delta * 4.0)
		if _step_acc >= STEP_LENGTH:
			_step_acc = 0.0
			_step_sound.pitch_scale = randf_range(0.85, 1.1)
			_step_sound.play()
			footstep.emit()
	else:
		_bob_amp = move_toward(_bob_amp, 0.0, delta * 4.0)
	var shake := pow(Game.fear / 100.0, 2.0) * 0.02
	camera.position = Vector3(cos(_bob) * 0.025, absf(sin(_bob)) * 0.04, 0) * _bob_amp \
		+ Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("flashlight") and not input_locked:
		flashlight_on = not flashlight_on
		_click_sound.play()
	_update_battery(delta)
	_sync_flashlight(delta)
	_update_burner(delta)
	_update_interaction(delta)
	if hud:
		hud.set_battery(battery, flashlight_on)
		hud.set_filters(filters, MAX_FILTERS)


func _update_battery(delta: float) -> void:
	if flashlight_on and battery > 0.0:
		battery = maxf(0.0, battery - DRAIN_PER_SEC * drain_mult * delta)
		if battery <= 0.0 and not _empty_warned:
			_empty_warned = true
			Game.say("Фонарь сел. Нужно к зарядке... быстро.")
	if battery > 5.0:
		_empty_warned = false
	var energy := 4.0 * clampf(battery / 30.0, 0.25, 1.0)
	if battery < 15.0 and randf() < 0.04:
		_flicker = maxf(_flicker, randf_range(0.05, 0.2))
	if _flicker > 0.0:
		_flicker -= delta
		if randf() < 0.5:
			energy *= randf_range(0.0, 0.2)
	flashlight.visible = flashlight_on and battery > 0.0
	flashlight.light_energy = energy


func _sync_flashlight(delta: float) -> void:
	flashlight.global_position = camera.global_position + camera.global_transform.basis * Vector3(0.15, -0.12, 0.0)
	var from := flashlight.global_transform.basis.get_rotation_quaternion()
	var to := camera.global_transform.basis.get_rotation_quaternion()
	flashlight.global_transform.basis = Basis(from.slerp(to, clampf(delta * 12.0, 0.0, 1.0)))


func _update_burner(delta: float) -> void:
	var want := Input.is_action_pressed("burn") and not input_locked
	if want != _burning:
		_burning = want
		_flame.emitting = want
		if want:
			_flame_sound.play()
		else:
			_flame_sound.stop()
	_torch_light.light_energy = randf_range(2.2, 3.0) if _burning else 0.0
	if _burning and _target != null and is_instance_valid(_target) and _target.has_method("burn"):
		_target.burn(delta * 0.85)


func _update_interaction(delta: float) -> void:
	var t = null
	if _ray.is_colliding():
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
		if _target.has_method("hold_interact"):
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

func is_burning() -> bool:
	return _burning


func has_light() -> bool:
	return (flashlight_on and battery > 0.0) or _burning


func flicker(time: float) -> void:
	_flicker = maxf(_flicker, time)


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
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
