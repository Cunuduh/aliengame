extends Combatant
class_name PartyMember

const TRAIL_GAP := 44.0
const TRAIL_SAMPLE := 0.01
const TRAIL_MAX := 2048
const TRAIL_COMPACT_THRESHOLD := 256
const MOVE_SPEED_EPSILON := 4.0
const STOP_GRACE := 0.1
const FACING_BIAS := 1.25
const RUN_ANIM_SCALE := 1.5
const WALK_ANIMS := {0: "walk_right", 1: "walk_left", 2: "walk_up", 3: "walk_down"}

var leader: Node2D
var _prev_health := -1
var _facing := 3
var _facing_vertical := true
var _posed := -1
var _still := 0.0
var _trail: PackedVector2Array = PackedVector2Array()
var _pace: PackedFloat32Array = PackedFloat32Array()
var _boost: PackedFloat32Array = PackedFloat32Array()
var _trail_head := 0
var _last_head := Vector2.INF

func _ready() -> void:
	add_to_group("party")
	_pose(_facing)
	_prev_health = stats.health
	stats.stat_changed.connect(_check_dissolve)

func face(point: Vector2) -> void:
	sprite.flip_h = global_position.x > point.x

func follow(new_leader: Node2D, snap: bool = true) -> void:
	leader = new_leader
	_reset_trail()
	if is_instance_valid(leader):
		if snap:
			global_position = leader.global_position
		_trail.push_back(global_position)
		_pace.push_back(0.0)
		_boost.push_back(1.0)

func stop_following() -> void:
	leader = null
	_reset_trail()
	if is_instance_valid(animation_player):
		animation_player.speed_scale = 1.0

func _reset_trail() -> void:
	_trail = PackedVector2Array()
	_pace = PackedFloat32Array()
	_boost = PackedFloat32Array()
	_trail_head = 0
	_last_head = Vector2.INF

func _process(delta: float) -> void:
	if in_battle or not is_instance_valid(leader) or delta <= 0.0:
		return
	var head := leader.global_position
	var head_speed := 0.0
	if _last_head.is_finite():
		head_speed = _last_head.distance_to(head) / delta
	_last_head = head
	var head_boost := 1.0
	if leader.has_method("run_multiplier"):
		head_boost = float(leader.run_multiplier())
	if _trail.is_empty():
		_trail.push_back(head)
		_pace.push_back(0.0)
		_boost.push_back(1.0)
	else:
		var sample_distance := _trail[_trail.size() - 1].distance_to(head)
		if head_speed > 0.0 and sample_distance >= TRAIL_SAMPLE:
			_trail.push_back(head)
			_pace.push_back(head_speed)
			_boost.push_back(head_boost)
			while _active_trail_size() > TRAIL_MAX:
				_drop_first_trail_point()
	var before := _trail[_trail_head]
	_advance(_stretch_speed() * delta)
	var exact := _trail[_trail_head]
	_compact_trail()
	global_position = exact
	_play_walk(exact - before, delta)

func _stretch_speed() -> float:
	return _pace[_trail_head + 1] if _active_trail_size() > 1 else 0.0

func run_multiplier() -> float:
	return _boost[_trail_head + 1] if _active_trail_size() > 1 else 1.0

func _advance(step: float) -> void:
	if _active_trail_size() < 2:
		return
	step = minf(step, _arc_length() - TRAIL_GAP)
	if step <= 0.0:
		return
	while _active_trail_size() > 1:
		var seg := _trail[_trail_head].distance_to(_trail[_trail_head + 1])
		if seg > step:
			_trail[_trail_head] = _trail[_trail_head].lerp(_trail[_trail_head + 1], step / seg)
			return
		step -= seg
		_drop_first_trail_point()

func _arc_length() -> float:
	var total := 0.0
	for i: int in range(_trail_head, _trail.size() - 1):
		total += _trail[i].distance_to(_trail[i + 1])
	return total

func _active_trail_size() -> int:
	return _trail.size() - _trail_head

func _drop_first_trail_point() -> void:
	if _active_trail_size() < 2:
		return
	_trail_head += 1

func _compact_trail() -> void:
	if _trail_head < TRAIL_COMPACT_THRESHOLD:
		return
	_trail = _trail.slice(_trail_head)
	_pace = _pace.slice(_trail_head)
	_boost = _boost.slice(_trail_head)
	_trail_head = 0

func _play_walk(motion: Vector2, delta: float) -> void:
	if delta <= 0.0 or motion.length() / delta < MOVE_SPEED_EPSILON:
		_still += delta
		if _still >= STOP_GRACE:
			_pose(_facing)
		return
	_still = 0.0
	_facing = _facing_for(motion)
	var anim: String = WALK_ANIMS[_facing]
	if not is_instance_valid(animation_player) or not animation_player.has_animation(anim):
		_pose(_facing)
		return
	animation_player.speed_scale = RUN_ANIM_SCALE if run_multiplier() > 1.0 else 1.0
	_posed = -1
	if String(animation_player.current_animation) != anim:
		animation_player.play(anim)
	elif not animation_player.is_playing():
		animation_player.play()

func _pose(facing: int) -> void:
	if is_instance_valid(animation_player):
		animation_player.speed_scale = 1.0
	if _posed == facing:
		return
	_posed = facing
	pose_idle(facing)

func _facing_for(motion: Vector2) -> int:
	var ax := absf(motion.x)
	var ay := absf(motion.y)
	if _facing_vertical and ax > ay * FACING_BIAS:
		_facing_vertical = false
	elif not _facing_vertical and ay > ax * FACING_BIAS:
		_facing_vertical = true
	var dir := Vector2.RIGHT
	if _facing_vertical:
		dir = Vector2.DOWN if motion.y > 0.0 else Vector2.UP
	elif motion.x <= 0.0:
		dir = Vector2.LEFT
	var idx: int = VEC_TO_INT[dir]
	return idx

func _check_dissolve(stat: CharacterStats.StatType, value: int) -> void:
	if stat != CharacterStats.StatType.HEALTH:
		return
	var prev := _prev_health
	_prev_health = value
	if value >= prev:
		return
	if value > 0:
		await _play_damaged(false)
		return
	await _play_damaged(true)
	dissolve()

func _play_damaged(fatal: bool) -> void:
	if is_instance_valid(animation_player) and animation_player.has_animation("damaged"):
		animation_player.play("damaged")
		await animation_player.animation_finished
		if not fatal:
			if in_battle:
				if animation_player.has_animation("idle_battle"):
					animation_player.play("idle_battle")
			else:
				_posed = -1
				_pose(_facing)
		return
	await play_hurt(fatal)

func revive() -> void:
	super()
	visible = true
	if is_instance_valid(sprite) and sprite.material:
		sprite.material.set_shader_parameter("progress", 0.0)
	_posed = -1
	_still = 0.0
	_pose(_facing)

func dissolve() -> void:
	animation_player.stop()
	if sprite.material:
		var tween := get_tree().create_tween()
		tween.tween_method(func(x: float) -> void: sprite.material.set_shader_parameter("progress", x), 0.25, 1.0, 1.0)
		await tween.finished
	visible = false
