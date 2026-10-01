extends Combatant
class_name Cora

const OVERWORLD_MENU := preload("res://assets/scenes/overworld_menu.tscn")
const ACTION_TO_VEC := {
	"right": Vector2.RIGHT,
	"left": Vector2.LEFT,
	"up": Vector2.UP,
	"down": Vector2.DOWN,
}

const RUN_RAMP: Array[Dictionary] = [
	{"after": 0.0, "boost": 0.25},
	{"after": 1.0 / 3.0, "boost": 0.5},
	{"after": 2.0, "boost": 0.75},
]
const RUN_ANIM_SCALE := 1.5
const MOVE_SPEED_EPSILON := 1.0

enum CoraState {
	IDLING,
	WALKING,
	BATTLING,
}

@export var overworld_collision: CollisionShape2D
@export var battle_collision: CollisionShape2D
@export var enemy_search_area: Shape2D
@export var soul: Sprite2D

var overworld_query := PhysicsShapeQueryParameters2D.new()
var enemy_search_query := PhysicsShapeQueryParameters2D.new()
@onready var direct_space_state := get_world_2d().direct_space_state

var closest_enemy_position := Vector2.ZERO
var _last_anim_vec := Vector2.ZERO
var _last_input := 0
var _input_queue: Array[Vector2] = []
var input_vector := Vector2.ZERO

var speed := 60.0
var collision_count := 0
var _battle_prev_health := -1
var _run_held := 0.0
var _state: CoraState = CoraState.IDLING

func _ready() -> void:
	Input.set_use_accumulated_input(false)
	if soul:
		soul.visible = false
	collision_mask = 1

	overworld_query.shape = overworld_collision.shape
	enemy_search_query.shape = enemy_search_area
	overworld_query.collision_mask = 1 << 2
	enemy_search_query.collision_mask = 1 << 2

	Globals.cora = self
	if Globals.pending_spawn.is_finite():
		global_position = Globals.pending_spawn
		Globals.pending_spawn = Vector2.INF
	hit_type = "slap"
	stats.stat_changed.connect(_on_stat_changed)

	Dialogue.started.connect(_on_dialogue_started)
	Dialogue.finished.connect(_on_dialogue_finished)

	_on_idling_state_entered()
	Party.spawn_followers.call_deferred(self)

func _process(delta: float) -> void:
	if _state == CoraState.BATTLING:
		return
	_on_chilling_state_processing(delta)
	if _state == CoraState.WALKING:
		_on_walking_state_processing(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _state == CoraState.BATTLING:
		return
	_on_chilling_state_unhandled_input(event)
	match _state:
		CoraState.IDLING:
			_on_idling_state_unhandled_input(event)
		CoraState.WALKING:
			_on_walking_state_unhandled_input(event)

func _set_state(next_state: CoraState) -> void:
	if next_state == _state:
		return
	match _state:
		CoraState.IDLING:
			_on_idling_state_exited()
		CoraState.BATTLING:
			_on_battling_state_exited()
	_state = next_state
	match _state:
		CoraState.IDLING:
			_on_idling_state_entered()
		CoraState.WALKING:
			_on_walking_state_entered()
		CoraState.BATTLING:
			_on_battling_state_entered()

func finish_battle() -> void:
	if _state == CoraState.BATTLING:
		_set_state(CoraState.IDLING)

func _open_overworld_menu() -> void:
	var menu: OverworldMenu = OVERWORLD_MENU.instantiate()
	get_tree().root.add_child(menu)
	_on_dialogue_started()
	menu.open()
	menu.closed.connect(_on_dialogue_finished)

func _on_dialogue_started() -> void:
	if in_battle:
		return
	velocity = Vector2.ZERO
	_last_anim_vec = Vector2.ZERO
	_set_state(CoraState.IDLING)

func _on_dialogue_finished() -> void:
	if in_battle:
		return
	for action: String in ACTION_TO_VEC.keys():
		if Input.is_action_pressed(action):
			_set_state(CoraState.WALKING)
			return

func attack(battle: BattleScene, target: Combatant) -> void:
	if not is_instance_valid(target):
		return
	battle.set_message(tr("* %s slaps %s!") % [combatant_name, target.combatant_name])
	await battle.get_tree().create_timer(0.4).timeout
	_play_attack_anim()
	await battle.get_tree().create_timer(0.33).timeout
	await battle.spawn_hit_effect(hit_type, target)
	var killed := battle.apply_damage(self, target)
	await battle.get_tree().create_timer(1.4 if killed else 0.6).timeout
	face(target.global_position)
	battle.return_to_idle(self)

func ko_message() -> String:
	return tr("* %s was hurt and beaten...") % combatant_name

func _play_attack_anim() -> void:
	if not is_instance_valid(animation_player):
		return
	animation_player.play("attack_cast")

func process_collisions() -> void:
	overworld_query.transform = global_transform
	enemy_search_query.transform = global_transform
	var overworld_collision_result := direct_space_state.intersect_shape(overworld_query, 1)

	if overworld_collision_result.size() > 0:
		var enemy_search_query_result := direct_space_state.intersect_shape(enemy_search_query)

		for result in enemy_search_query_result:
			if result["collider"].is_in_group("enemy"):
				BattleManager.encountered_enemies.append(result["collider"])

		if BattleManager.encountered_enemies.size() > 0:
			_set_state(CoraState.BATTLING)

func run_multiplier() -> float:
	if not Input.is_action_pressed("run"):
		return 1.0
	var boost := 0.0
	for tier: Dictionary in RUN_RAMP:
		if _run_held >= float(tier["after"]):
			boost = float(tier["boost"])
	return 1.0 + boost

func _on_chilling_state_processing(_delta: float) -> void:
	if not Input.is_action_pressed("run"):
		_run_held = 0.0
	process_collisions()

func _on_chilling_state_unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and stats.health > 0 and not Dialogue.is_active():
		get_viewport().set_input_as_handled()
		_open_overworld_menu()

func _on_idling_state_entered() -> void:
	_run_held = 0.0
	animation_player.speed_scale = 1.0
	_input_queue.clear()
	if stats.health > 0:
		pose_idle(_last_input)

func _on_idling_state_exited() -> void:
	animation_player.play()

func _on_idling_state_unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and stats.health > 0:
		for action: String in ACTION_TO_VEC.keys():
			if event.is_action_pressed(action):
				_set_state(CoraState.WALKING)
				break

func _on_walking_state_entered() -> void:
	_input_queue.clear()
	for action: String in ACTION_TO_VEC.keys():
		if Input.is_action_pressed(action):
			var vec: Vector2 = ACTION_TO_VEC[action]
			_input_queue.append(vec)

func _on_walking_state_processing(delta: float) -> void:
	if stats.health <= 0:
		return
	if Input.is_action_pressed("run"):
		_run_held += delta
	var movement_multiplier := run_multiplier()
	var animation_vector := Vector2.ZERO

	if _input_queue.size() > 0:
		animation_vector = _input_queue.front()
		if -animation_vector in _input_queue:
			animation_vector = -animation_vector

	var actual_motion := _handle_movement(delta, movement_multiplier)
	if input_vector in VEC_TO_INT and _last_input != VEC_TO_INT[input_vector]:
		_last_input = VEC_TO_INT[input_vector]
	var actual_speed := actual_motion.length() / delta if delta > 0.0 else 0.0
	if actual_speed < MOVE_SPEED_EPSILON:
		_run_held = 0.0
		velocity = Vector2.ZERO
		animation_player.speed_scale = 1.0
		_last_anim_vec = Vector2.ZERO
		_set_state(CoraState.IDLING)
		return
	var actual_direction := actual_motion.normalized()
	if actual_direction in VEC_TO_INT:
		animation_vector = actual_direction
		_last_input = VEC_TO_INT[actual_direction]
	if animation_vector != Vector2.ZERO:
		_last_anim_vec = animation_vector

	animation_player.speed_scale = RUN_ANIM_SCALE if movement_multiplier > 1.0 else 1.0
	var walk_animation := ""
	match _last_anim_vec:
		Vector2.RIGHT:
			walk_animation = "walk_right"
		Vector2.LEFT:
			walk_animation = "walk_left"
		Vector2.UP:
			walk_animation = "walk_up"
		Vector2.DOWN:
			walk_animation = "walk_down"
	if not walk_animation.is_empty() and (String(animation_player.current_animation) != walk_animation or not animation_player.is_playing()):
		animation_player.play(walk_animation)

func _on_walking_state_unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and stats.health > 0:
		var action := event.as_text().to_lower()
		if not action in ACTION_TO_VEC.keys():
			return
		var vector: Vector2 = ACTION_TO_VEC[action]
		if event.is_action_pressed(action):
			if -vector in _input_queue:
				_input_queue.erase(-vector)
			if not vector in _input_queue:
				_input_queue.append(vector)
		elif event.is_action_released(action) and vector in _input_queue:
			_input_queue.erase(vector)
			var opp := -vector
			for act2: String in ACTION_TO_VEC.keys():
				if ACTION_TO_VEC[act2] == opp and Input.is_action_pressed(act2) and not opp in _input_queue:
					_input_queue.append(opp)

func _handle_movement(delta: float, movement_multiplier: float) -> Vector2:
	input_vector = Vector2.ZERO
	for direction in _input_queue:
		input_vector += direction
	var before := global_position
	var pace := speed * movement_multiplier
	velocity = input_vector * pace
	var predicted_collision := move_and_collide(velocity * delta, true)
	if predicted_collision:
		velocity = velocity.slide(predicted_collision.get_normal()).normalized() * pace
	move_and_slide()
	return global_position - before

func _on_battling_state_entered() -> void:
	in_battle = true
	_run_held = 0.0
	animation_player.speed_scale = 1.0
	_battle_prev_health = stats.health
	if soul:
		soul.visible = false
	velocity = Vector2.ZERO
	_input_queue.clear()
	overworld_collision.set_deferred("disabled", true)
	if battle_collision:
		battle_collision.set_deferred("disabled", false)
	overworld_query.collision_mask = 0
	enemy_search_query.collision_mask = 0
	collision_mask = 1 << 1
	BattleManager.start_battle()

func _on_stat_changed(stat: CharacterStats.StatType, value: int) -> void:
	if not in_battle or stat != CharacterStats.StatType.HEALTH:
		return
	var prev := _battle_prev_health
	_battle_prev_health = value
	if value >= prev:
		return
	await play_hurt(value <= 0)

func _on_battling_state_exited() -> void:
	in_battle = false
	speed = 60.0
	sprite.flip_h = false
	sprite.top_level = false
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.position = Vector2.ZERO
	if soul:
		soul.visible = false
	if battle_collision:
		battle_collision.set_deferred("disabled", true)
	overworld_collision.set_deferred("disabled", false)
	overworld_query.collision_mask = 1 << 2
	enemy_search_query.collision_mask = 1 << 2
	collision_mask = 1
	_input_queue.clear()
	animation_player.play("idle")
