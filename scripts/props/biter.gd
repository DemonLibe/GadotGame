class_name Biter
extends CharacterBody3D
## Кусачий паук (седьмая смена): крупнее тех, что на стенах, бегает по полу и бросается на обходчика.
## Фонарь видит издалека, в темноте замечает только вблизи, идёт на шум.
## Одна пуля — и всё. Огня боится: от горелки пятится, а вплотную — сгорает.

const DAMAGE := 10.0
const SPEED := 3.4
const BITE_RANGE := 0.9
const SIGHT_LIT := 14.0
const SIGHT_DARK := 5.0
const LOSE_TIME := 4.0
const SCALE := 0.6

var player: Player
var level: Level
var _chasing := false
var _dead := false
var _cooldown := 0.0
var _think := 0.0
var _unseen := 0.0
var _flee := 0.0
var _goal := Vector3.ZERO
var _anim: AnimationPlayer
var _model: Node3D


func _ready() -> void:
	add_to_group("day_objects")
	add_to_group("biters")
	collision_layer = Crawler.LAYER
	collision_mask = 1 | Geo.WALL_LAYER
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	shape.position.y = 0.3
	add_child(shape)
	# Та же модель, что у пауков на стенах (Low Poly Spider, Wciow и John.d.h, CC-BY-SA 3.0), в два с лишним раза крупнее
	# и с бурым отливом. Смотрит в +Z — разворачиваем.
	var skin := ProcTex.flat(Color(0.16, 0.07, 0.05), 0.5)
	skin.rim_enabled = true
	skin.rim = 0.5
	_model = Geo.model(self, "res://models/spider/spider.glb", skin, Vector3.ZERO, Basis(Vector3.UP, PI).scaled(Vector3.ONE * SCALE))
	_anim = Geo.model_anim(_model, ["Idle", "Walk"])
	_anim.play("Idle")
	_anim.seek(randf())
	Game.noise_made.connect(_on_noise)
	_goal = global_position


func _on_noise(pos: Vector3, radius: float) -> void:
	if _dead or _chasing or global_position.distance_to(pos) > radius:
		return
	_goal = pos


func _physics_process(delta: float) -> void:
	if _dead or player == null:
		return
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	_cooldown -= delta
	_think -= delta
	if _think <= 0.0:
		_think = 0.25
		_perceive()
	var to_p := player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	# Огонь: вплотную — сгорает, рядом — пятится.
	if player.is_burning() and dist < 3.0:
		if dist < 1.6:
			_die()
			return
		_flee = 1.5
	var target := player.global_position if _chasing else _goal
	if level:
		target = level.next_waypoint(global_position, target)
	var s := SPEED if _chasing else SPEED * 0.4
	if _flee > 0.0:
		_flee -= delta
		target = global_position - to_p.normalized() * 3.0
		s = SPEED
	var go := target - global_position
	go.y = 0.0
	var v := Vector3.ZERO
	var stop := BITE_RANGE * 0.7 if _chasing and _flee <= 0.0 else 0.4
	if go.length() > stop:
		v = go.normalized() * s
		look_at(global_position + go, Vector3.UP)
	velocity.x = v.x
	velocity.z = v.z
	move_and_slide()
	var moving := v.length() > 0.1
	if _anim.current_animation != "Attack":
		_anim.play("Walk" if moving else "Idle", 0.1)
		_anim.speed_scale = clampf(v.length(), 1.0, 3.5) if moving else 1.0
	if _chasing and _flee <= 0.0 and dist < BITE_RANGE and _cooldown <= 0.0 and not player.hiding \
			and absf(player.global_position.y - global_position.y) < 1.5:
		_cooldown = 1.1
		_anim.speed_scale = 1.5
		_anim.play("Attack", 0.05)
		player.take_damage(DAMAGE)
		Game.add_fear(6.0)
		Game.play_at(Sfx.scuttle(), global_position, 0.0)


func _perceive() -> void:
	if player.global_position.y > Level.FLOOR_Y + 5.0 or player.hiding:
		_chasing = false
		return
	var eye := global_position + Vector3(0, 0.3, 0)
	var dist := eye.distance_to(player.global_position)
	var r := SIGHT_LIT if player.has_light() else SIGHT_DARK
	if dist < r and _clear(eye, player.camera.global_position):
		if not _chasing:
			Game.play_at(Sfx.scuttle(), global_position, -2.0)
		_chasing = true
		_unseen = 0.0
	elif _chasing:
		_unseen += 0.25
		if _unseen > LOSE_TIME:
			_chasing = false
			_goal = player.global_position


func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | Geo.WALL_LAYER)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Попадание пули.
func hit() -> void:
	_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	collision_layer = 0
	_anim.speed_scale = 1.0
	_anim.play("Die", 0.05)
	Game.play_at(Sfx.hiss(), global_position, -6.0)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_model, "scale", _model.scale * 0.01, 0.6)
	tw.tween_callback(queue_free)
