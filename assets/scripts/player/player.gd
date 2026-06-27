extends Combatant
class_name Player

signal battle_facing_direction_changed(new_direction: Vector2)

const VEC_TO_INT := {
	Vector2.RIGHT: 0,
	Vector2.LEFT: 1,
	Vector2.UP: 2,
	Vector2.DOWN: 3
}
const ACTION_TO_VEC := {
	"right": Vector2.RIGHT,
	"left": Vector2.LEFT,
	"up": Vector2.UP,
	"down": Vector2.DOWN,
}

@export var overworld_collision: CollisionShape2D
@export var battle_collision: CollisionShape2D
@export var enemy_search_area: Shape2D
@export var soul: Sprite2D
@export var abilities: Array[Ability] = []

var heal_from_damage := false
var invincibility := false
var overworld_query := PhysicsShapeQueryParameters2D.new()
var enemy_search_query := PhysicsShapeQueryParameters2D.new()
@onready var direct_space_state := get_world_2d().direct_space_state

var closest_enemy_position := Vector2.ZERO
var _last_anim_vec := Vector2.ZERO
var _last_input := 0
var _input_queue: Array[Vector2] = []
var input_vector := Vector2.ZERO
var _last_battle_input_vector := Vector2.ZERO
var battle_facing_direction := Vector2.RIGHT
var locked_animation := false

var speed := 60.0
var collision_count := 0
var ability_cooldowns: Array[float]

var ghost_count := 10
var ghost_data: Array[Dictionary] = []

func _ready() -> void:
	Input.set_use_accumulated_input(false)
	soul.visible = false
	collision_mask = 1

	overworld_query.shape = overworld_collision.shape
	enemy_search_query.shape = enemy_search_area
	overworld_query.collision_mask = 1 << 2
	enemy_search_query.collision_mask = 1 << 2

	Globals.player = self

	var chilling_node: CompoundState = state_chart.get_node("Root/Chilling")
	chilling_node.state_processing.connect(_on_chilling_state_processing)
	chilling_node.state_unhandled_input.connect(_on_chilling_state_unhandled_input)
	var idling_node: AtomicState = state_chart.get_node("Root/Chilling/Idling")
	idling_node.state_entered.connect(_on_idling_state_entered)
	idling_node.state_exited.connect(_on_idling_state_exited)
	idling_node.state_unhandled_input.connect(_on_idling_state_unhandled_input)
	var walking_node: AtomicState = state_chart.get_node("Root/Chilling/Walking")
	walking_node.state_entered.connect(_on_walking_state_entered)
	walking_node.state_processing.connect(_on_walking_state_processing)
	walking_node.state_unhandled_input.connect(_on_walking_state_unhandled_input)
	var battling_node: ParallelState = state_chart.get_node("Root/Battling")
	battling_node.state_entered.connect(_on_battling_state_entered)
	battling_node.state_processing.connect(_on_battling_state_processing)
	battling_node.state_exited.connect(_on_battling_state_exited)
	battling_node.state_unhandled_input.connect(_on_battling_state_unhandled_input)
	var movement_node: CompoundState = state_chart.get_node("Root/Battling/Movement")
	movement_node.get_node("Idling").state_entered.connect(_on_battle_movement_idling_entered)
	movement_node.get_node("Walking").state_entered.connect(_on_battle_movement_walking_entered)

	ability_cooldowns.resize(abilities.size())
	ability_cooldowns.fill(0.0)

	for i in range(abilities.size()):
		_create_ability_states(abilities[i], i)

func _draw() -> void:
	draw_set_transform_matrix(Transform2D())
	for ghost in ghost_data:
		if ghost.visible:
			var texture: Texture2D = ghost.texture
			var src_rect := Rect2()

			if ghost.hframes > 1 or ghost.vframes > 1:
				var frame_width: float = texture.get_width() / float(ghost.hframes)
				var frame_height: float = texture.get_height() / float(ghost.vframes)
				var frame_x: float = (ghost.frame % ghost.hframes) * frame_width
				var frame_y: float = (ghost.frame / ghost.hframes) * frame_height
				src_rect = Rect2(frame_x, frame_y, frame_width, frame_height)
			else:
				src_rect = Rect2(Vector2.ZERO, texture.get_size())

			var local_pos := to_local(ghost.position)

			var draw_transform := Transform2D()
			if ghost.flip_h:
				draw_transform = draw_transform.scaled(Vector2(-1, 1))
				local_pos.x = -local_pos.x
			draw_transform.origin = local_pos

			draw_set_transform_matrix(draw_transform)
			draw_texture_rect_region(texture, Rect2(-src_rect.size * 0.5, src_rect.size), src_rect, ghost.modulate)

func add_ghost(ghost_position: Vector2, texture: Texture2D, frame: int, hframes: int, vframes: int, flip_h: bool, ghost_modulate: Color) -> void:
	ghost_data.append({
		"position": ghost_position,
		"texture": texture,
		"frame": frame,
		"hframes": hframes,
		"vframes": vframes,
		"flip_h": flip_h,
		"modulate": ghost_modulate,
		"visible": true
	})
	queue_redraw()

func clear_ghosts() -> void:
	ghost_data.clear()
	queue_redraw()

func fade_ghost(index: int, duration: float) -> void:
	if index < 0 or index >= ghost_data.size():
		return

	var tween := get_tree().create_tween()
	tween.tween_method(
		func(alpha: float) -> void:
			if index < ghost_data.size():
				ghost_data[index].modulate.a = alpha
				queue_redraw(),
		ghost_data[index].modulate.a,
		0.0,
		duration
	)
	tween.tween_callback(
		func() -> void:
			if index < ghost_data.size():
				ghost_data[index].visible = false
				queue_redraw()
	)


func _create_ability_states(ability: Ability, index: int) -> void:
	var ability_node_name := ability.name.to_pascal_case() + "-%d" % index

	var use_event := StringName("use_%s-%d" % [ability.name, index])
	var end_event := StringName("end_%s-%d" % [ability.name, index])
	state_chart._valid_event_names.append(use_event)
	state_chart._valid_event_names.append(end_event)

	var battling_node: ParallelState = state_chart.get_node("Root/Battling")
	var ability_node := CompoundState.new()
	ability_node.name = ability_node_name
	battling_node.add_child(ability_node)

	var available_node := AtomicState.new()
	available_node.name = "Available"
	ability_node.add_child(available_node)
	ability_node.initial_state = "Available"
	ability_node._initial_state = available_node

	var on_use_node := Transition.new()
	on_use_node.name = "On%sUse" % ability_node_name
	on_use_node.event = use_event
	on_use_node.to = "../../Active"
	available_node.add_child(on_use_node)

	var active_node := AtomicState.new()
	active_node.name = "Active"
	ability_node.add_child(active_node)
	active_node.state_entered.connect(func() -> void:
		_execute_ability(index)
		battle_facing_direction_changed.connect(ability.update_current_anim.bind(self))
	)
	active_node.state_exited.connect(func() -> void:
		if battle_facing_direction_changed.is_connected(ability.update_current_anim.bind(self)):
			battle_facing_direction_changed.disconnect(ability.update_current_anim.bind(self))
		if in_battle:
			_update_battle_sprite()
		else:
			animation_player.play("idle")
	)

	var end_node := Transition.new()
	end_node.name = "End%s" % ability_node_name
	end_node.event = end_event
	end_node.to = "../../Cooldown"
	active_node.add_child(end_node)

	var cooldown_node := AtomicState.new()
	cooldown_node.name = "Cooldown"
	ability_node.add_child(cooldown_node)

	var refresh_node := Transition.new()
	refresh_node.name = "Refresh"
	refresh_node.to = "../../Available"
	refresh_node.delay_in_seconds = str(ability.cooldown)
	cooldown_node.add_child(refresh_node)
	cooldown_node.transition_pending.connect(set_ability_cooldown.bind(index))

	ability_node._state_init()
	battling_node._sub_states.append(ability_node)

func start_invincibility() -> void:
	invincibility = true
	await get_tree().create_timer(0.5).timeout
	invincibility = false

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
			state_chart.send_event("enemy_collision")

func set_ability_cooldown(_discard: float, cooldown: float, index: int) -> void:
	ability_cooldowns[index] = cooldown

func _on_chilling_state_processing(_delta: float) -> void:
	process_collisions()

func _on_chilling_state_unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and stats.health > 0:
		var action := event.as_text().to_lower()
		if action in ACTION_TO_VEC.keys():
			if event.is_action_pressed(action) and state_chart.get_node("Root/Chilling/Idling").active:
				state_chart.send_event("walk")

func _on_idling_state_entered() -> void:
	_input_queue.clear()
	if stats.health > 0:
		animation_player.play("idle")
		animation_player.pause()
		animation_player.seek(0, true)
		animation_player.seek(0.25*_last_input, true)

func _on_idling_state_exited() -> void:
	animation_player.play()

func _on_idling_state_unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and stats.health > 0:
		for action: String in ACTION_TO_VEC.keys():
			if event.is_action_pressed(action):
				state_chart.send_event("walk")
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
	var animation_vector := Vector2.ZERO

	if _input_queue.size() > 0:
		animation_vector = _input_queue.front()
		if -animation_vector in _input_queue:
			animation_vector = -animation_vector

	if animation_vector != Vector2.ZERO:
		_last_anim_vec = animation_vector

	match _last_anim_vec:
		Vector2.RIGHT:
			animation_player.play("walk_right")
		Vector2.LEFT:
			animation_player.play("walk_left")
		Vector2.UP:
			animation_player.play("walk_up")
		Vector2.DOWN:
			animation_player.play("walk_down")

	input_vector = _handle_movement(delta)
	if input_vector == Vector2.ZERO:
		_last_anim_vec = Vector2.ZERO
		state_chart.send_event("idle")

	if input_vector in VEC_TO_INT and _last_input != VEC_TO_INT[input_vector]:
		_last_input = VEC_TO_INT[input_vector]

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

func _handle_movement(delta: float) -> Vector2:
	input_vector = Vector2.ZERO
	for direction in _input_queue:
		input_vector += direction
	velocity = input_vector * speed
	var predicted_collision := move_and_collide(velocity * delta, true)
	if predicted_collision:
		velocity = velocity.slide(predicted_collision.get_normal()).normalized() * speed
	move_and_slide()
	return input_vector

func _get_square_input_vector(left: String, right: String, up: String, down: String) -> Vector2:
	var x := int(Input.is_action_pressed(right)) - int(Input.is_action_pressed(left))
	var y := int(Input.is_action_pressed(down)) - int(Input.is_action_pressed(up))
	return Vector2(x, y)

func _update_battle_facing_direction() -> void:
	if BattleManager.encountered_enemies.size() == 0:
		return

	var closest_enemy: Combatant = BattleManager.encountered_enemies[0]
	var closest_distance := global_position.distance_squared_to(closest_enemy.global_position)

	for enemy: Combatant in BattleManager.encountered_enemies:
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance

	closest_enemy_position = closest_enemy.global_position
	var old_dir := battle_facing_direction

	var direction_to_enemy := (closest_enemy_position - global_position).normalized()
	battle_facing_direction = Vector2.RIGHT if direction_to_enemy.x > 0 else Vector2.LEFT
	if old_dir != battle_facing_direction:
		battle_facing_direction_changed.emit(battle_facing_direction)
		if not locked_animation:
			_update_battle_sprite()

func _update_battle_sprite() -> void:
	if not in_battle:
		return
	if input_vector == Vector2.ZERO:
		match battle_facing_direction:
			Vector2.LEFT:
				animation_player.play("idle_battle_left")
			Vector2.RIGHT:
				animation_player.play("idle_battle_right")
			_:
				animation_player.play("idle_battle_right")
	else:
		var anim_name := "battle_%s_walk_%s" % [
			"left" if battle_facing_direction == Vector2.LEFT else "right",
			"left" if input_vector.x < 0 else "right"
		]
		animation_player.play(anim_name)

func _handle_battle_movement(delta: float) -> Vector2:
	input_vector = Vector2.ZERO
	for direction in _input_queue:
		input_vector += direction
	velocity = input_vector * speed
	var predicted_collision := move_and_collide(velocity * delta, true)
	if predicted_collision:
		velocity = velocity.slide(predicted_collision.get_normal()).normalized() * speed
	move_and_slide()
	_update_battle_facing_direction()
	if input_vector != _last_battle_input_vector and not locked_animation:
		_update_battle_sprite()
	_last_battle_input_vector = input_vector
	return input_vector

func _on_battling_state_entered() -> void:
	in_battle = true
	sprite.modulate = Color(1, 1, 1, 0.5)
	soul.visible = true
	overworld_collision.set_deferred("disabled", true)
	battle_collision.set_deferred("disabled", false)
	overworld_query.collision_mask = 0
	enemy_search_query.collision_mask = 0
	collision_mask = 1 << 1
	_input_queue.clear()
	for action: String in ACTION_TO_VEC.keys():
		if Input.is_action_pressed(action):
			var vec: Vector2 = ACTION_TO_VEC[action]
			_input_queue.append(vec)
	_last_battle_input_vector = Vector2.ZERO
	speed = 60.0
	BattleManager.start_battle()

func _on_battling_state_processing(delta: float) -> void:
	if BattleManager.encountered_enemies.size() == 0:
		state_chart.send_event("battle_finished")
		return
	if stats.health <= 0:
		state_chart.send_event("battle_finished")
		return

	input_vector = _handle_battle_movement(delta)
	if input_vector == Vector2.ZERO:
		state_chart.send_event("battle_idle")
	else:
		state_chart.send_event("battle_walk")

func _on_battling_state_unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and stats.health > 0:
		var action := event.as_text().to_lower()
		if action in ACTION_TO_VEC.keys():
			var vector: Vector2 = ACTION_TO_VEC[action]
			if event.is_action_pressed(action):
				if -vector in _input_queue:
					_input_queue.erase(-vector)
				if not vector in _input_queue:
					_input_queue.append(vector)
				if input_vector == Vector2.ZERO:
					state_chart.send_event("battle_walk")
			elif event.is_action_released(action) and vector in _input_queue:
				_input_queue.erase(vector)
				var opp := -vector
				for act2: String in ACTION_TO_VEC.keys():
					if ACTION_TO_VEC[act2] == opp and Input.is_action_pressed(act2) and not opp in _input_queue:
						_input_queue.append(opp)
		elif event.pressed:
			if event.is_action_pressed("slow"):
				speed = 30.0
			elif event.is_action_released("slow"):
				speed = 60.0
			for i in range(abilities.size()):
				if ability_cooldowns[i] == 0:
					var action_name := "attack" if i == 0 else "ability_%d" % (i)
					if event.is_action_pressed(action_name):
						state_chart.send_event("use_%s-%d" % [abilities[i].name, i])
						break

func _on_battling_state_exited() -> void:
	in_battle = false
	speed = 60.0

	sprite.flip_h = false
	sprite.top_level = false
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.position = Vector2.ZERO

	soul.visible = false
	battle_collision.set_deferred("disabled", true)
	if stats.health <= 0:
		BulletPool.clear_bullets()
		await BattleManager.cleanup(false)
	else:
		await BattleManager.cleanup(true)
	overworld_collision.set_deferred("disabled", false)
	overworld_query.collision_mask = 1 << 2
	enemy_search_query.collision_mask = 1 << 2
	collision_mask = 1
	
	ability_cooldowns.fill(0.0)

func _execute_ability(index: int) -> void:
	# ignore warnings about redundant await because the ability functions might be async
	if index >= 0 and index < abilities.size():
		var ability := abilities[index]
		await ability.pre_execute(self)
		await ability.execute(self)
		await ability.exit(self)
		ability_cooldowns[index] = ability.cooldown
		_update_battle_sprite()

func get_ability_cooldown(index: int) -> float:
	return ability_cooldowns[index]

func get_ability_index(ability: Ability) -> int:
	return abilities.find(ability)

func _on_battle_movement_idling_entered() -> void:
	if not locked_animation:
		_update_battle_sprite()

func _on_battle_movement_walking_entered() -> void:
	if not locked_animation:
		_update_battle_sprite()
