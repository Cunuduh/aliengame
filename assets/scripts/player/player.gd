extends Combatant
class_name Player

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
var _battle_facing_direction := Vector2.RIGHT

var speed := 70
var collision_count := 0
var ability_cooldowns: Array[float]

var ghost_sprites: Array[Sprite2D] = []
var ghost_count = 5

func _ready() -> void:
  soul.visible = false
  collision_mask = 1

  overworld_query.shape = overworld_collision.shape
  enemy_search_query.shape = enemy_search_area
  overworld_query.collision_mask = 1 << 2
  enemy_search_query.collision_mask = 1 << 2

  Globals.player = self

  for i in ghost_count:
    var ghost := Sprite2D.new()
    ghost.top_level = true
    ghost.texture = sprite.texture
    ghost.hframes = sprite.hframes
    ghost.vframes = sprite.vframes
    ghost.frame = sprite.frame
    ghost.flip_h = sprite.flip_h
    ghost.modulate = Color(1, 1, 1, 0.5)
    ghost.position = global_position
    add_child.call_deferred(ghost)
    ghost_sprites.append(ghost)
    ghost.visible = false
  var chilling_node: CompoundState = state_chart.get_node("Root/Chilling")
  chilling_node.state_processing.connect(_on_chilling_state_processing)
  chilling_node.state_input.connect(_on_chilling_state_input)
  var idling_node: AtomicState = state_chart.get_node("Root/Chilling/Idling")
  idling_node.state_entered.connect(_on_idling_state_entered)
  idling_node.state_exited.connect(_on_idling_state_exited)
  idling_node.state_input.connect(_on_idling_state_input)
  var walking_node: AtomicState = state_chart.get_node("Root/Chilling/Walking")
  walking_node.state_entered.connect(_on_walking_state_entered)
  walking_node.state_processing.connect(_on_walking_state_processing)
  walking_node.state_input.connect(_on_walking_state_input)
  var battling_node: ParallelState = state_chart.get_node("Root/Battling")
  battling_node.state_entered.connect(_on_battling_state_entered)
  battling_node.state_processing.connect(_on_battling_state_processing)
  battling_node.state_exited.connect(_on_battling_state_exited)
  battling_node.state_input.connect(_on_battling_state_input)
  var movement_node: CompoundState = state_chart.get_node("Root/Battling/Movement")
  movement_node.get_node("Idling").state_entered.connect(_on_battle_movement_idling_entered)
  movement_node.get_node("Walking").state_entered.connect(_on_battle_movement_walking_entered)

  ability_cooldowns.resize(abilities.size())
  ability_cooldowns.fill(0.0)

  for i in range(abilities.size()):
    _create_ability_states(abilities[i], i)

func _create_ability_states(ability: Ability, index: int) -> void:
  var ability_node_name = ability.name.to_pascal_case() + "-%d" % index

  var use_event := StringName("use_%s-%d" % [ability.name, index])
  var end_event := StringName("end_%s-%d" % [ability.name, index])
  state_chart._valid_event_names.append(use_event)
  state_chart._valid_event_names.append(end_event)

  var battling_node: ParallelState = state_chart.get_node("Root/Battling")
  var ability_node = CompoundState.new()
  ability_node.name = ability_node_name
  battling_node.add_child(ability_node)

  var available_node = AtomicState.new()
  available_node.name = "Available"
  ability_node.add_child(available_node)
  ability_node.initial_state = "Available"
  ability_node._initial_state = available_node

  var on_use_node = Transition.new()
  on_use_node.name = "On%sUse" % ability_node_name
  on_use_node.event = use_event
  on_use_node.to = "../../Active"
  available_node.add_child(on_use_node)

  var active_node = AtomicState.new()
  active_node.name = "Active"
  ability_node.add_child(active_node)
  active_node.state_entered.connect(func(): _execute_ability(index))
  active_node.state_exited.connect(func(): 
    if in_battle:
      match _battle_facing_direction:
        Vector2.LEFT:
          animation_player.play("idle_battle_left")
        Vector2.RIGHT:
          animation_player.play("idle_battle_right")
    else:
      animation_player.play("idle")
  )

  var end_node = Transition.new()
  end_node.name = "End%s" % ability_node_name
  end_node.event = end_event
  end_node.to = "../../Cooldown"
  active_node.add_child(end_node)

  var cooldown_node = AtomicState.new()
  cooldown_node.name = "Cooldown"
  ability_node.add_child(cooldown_node)

  var refresh_node = Transition.new()
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
        Globals.encountered_enemies.append(result["collider"])

    if Globals.encountered_enemies.size() > 0:
      state_chart.send_event("enemy_collision")

func set_ability_cooldown(_discard: float, cooldown: float, index: int) -> void:
  ability_cooldowns[index] = cooldown

func _on_chilling_state_processing(_delta: float) -> void:
  process_collisions()

func _on_chilling_state_input(event: InputEvent) -> void:
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
    animation_player.seek(0.125*_last_input, true)

func _on_idling_state_exited() -> void:
  animation_player.play()

func _on_idling_state_input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed and stats.health > 0:
    for action in ACTION_TO_VEC.keys():
      if event.is_action_pressed(action):
        state_chart.send_event("walk")
        break

func _on_walking_state_entered() -> void:
  _input_queue.clear()
  for action in ACTION_TO_VEC.keys():
    if Input.is_action_pressed(action):
      var vec: Vector2 = ACTION_TO_VEC[action]
      _input_queue.append(vec)

func _on_walking_state_processing(_delta: float) -> void:
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
  
  input_vector = _handle_movement()
  if input_vector == Vector2.ZERO:
    _last_anim_vec = Vector2.ZERO
    state_chart.send_event("idle")
  
  if input_vector in VEC_TO_INT and _last_input != VEC_TO_INT[input_vector]:
    _last_input = VEC_TO_INT[input_vector]

func _on_walking_state_input(event: InputEvent) -> void:
  if event is InputEventKey and stats.health > 0:
    var action := event.as_text().to_lower()
    var vector: Vector2 = ACTION_TO_VEC[action]
    if event.is_action_pressed(action):
      if -vector in _input_queue:
        _input_queue.erase(-vector)
      if not vector in _input_queue:
        _input_queue.append(vector)
    elif event.is_action_released(action) and vector in _input_queue:
      _input_queue.erase(vector)
      var opp := -vector
      for act2 in ACTION_TO_VEC.keys():
        if ACTION_TO_VEC[act2] == opp and Input.is_action_pressed(act2) and not opp in _input_queue:
          _input_queue.append(opp)

func _handle_movement() -> Vector2:
  input_vector = Vector2.ZERO
  for direction in _input_queue:
    input_vector += direction
  velocity = input_vector * speed
  move_and_slide()
  return input_vector

func _get_square_input_vector(left: String, right: String, up: String, down: String) -> Vector2:
  var x := int(Input.is_action_pressed(right)) - int(Input.is_action_pressed(left))
  var y := int(Input.is_action_pressed(down)) - int(Input.is_action_pressed(up))
  return Vector2(x, y)

func _update_battle_facing_direction() -> void:
  if Globals.encountered_enemies.size() == 0:
    return

  var avg_pos := Vector2.ZERO
  for enemy in Globals.encountered_enemies:
    avg_pos += enemy.global_position
  avg_pos /= Globals.encountered_enemies.size()
  closest_enemy_position = avg_pos
  var old_dir := _battle_facing_direction

  var direction_to_enemies := (avg_pos - global_position).normalized()
  if abs(direction_to_enemies.x) > abs(direction_to_enemies.y):
    _battle_facing_direction = Vector2.RIGHT if direction_to_enemies.x > 0 else Vector2.LEFT
  else:
    _battle_facing_direction = Vector2.DOWN if direction_to_enemies.y > 0 else Vector2.UP
  if old_dir != _battle_facing_direction:
    _update_battle_idle_animation()
    _update_battle_walk_animation()

func _handle_battle_movement() -> Vector2:
  input_vector = _get_square_input_vector("left", "right", "up", "down")
  velocity = input_vector * speed
  move_and_slide()
  _update_battle_facing_direction()
  if input_vector != Vector2.ZERO and input_vector != _last_battle_input_vector:
    _update_battle_walk_animation()
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
  _last_battle_input_vector = Vector2.ZERO
  
  BattleManager.start_battle(self, Globals.encountered_enemies)

func _on_battling_state_processing(_delta: float) -> void:
  if Globals.encountered_enemies.size() == 0:
    state_chart.send_event("battle_finished")
    return
  if stats.health <= 0:
    state_chart.send_event("battle_finished")
    return

  input_vector = _handle_battle_movement()
  if input_vector == Vector2.ZERO:
    state_chart.send_event("battle_idle")
  else:
    state_chart.send_event("battle_walk")

func _on_battling_state_input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed:
    for action in ["left", "right", "up", "down"]:
      if event.is_action_pressed(action):
        if input_vector == Vector2.ZERO:
          state_chart.send_event("battle_walk")
        break
    if event.is_action_pressed("slow"):
      speed = 35
    elif event.is_action_released("slow"):
      speed = 70
    for i in range(abilities.size()):
      if ability_cooldowns[i] == 0:
        var action_name := "attack" if i == 0 else "ability_%d" % (i)
        if event.is_action_pressed(action_name):
          state_chart.send_event("use_%s-%d" % [abilities[i].name, i])
          break
  elif event is InputEventKey and event.is_action_released("slow"):
    speed = 70

func _on_battling_state_exited() -> void:
  in_battle = false
  speed = 70

  sprite.flip_h = false
  sprite.top_level = false
  sprite.modulate = Color(1, 1, 1, 1)
  sprite.position = Vector2.ZERO

  soul.visible = false
  battle_collision.set_deferred("disabled", true)
  if stats.health <= 0:
    BulletPool.clear_bullets()
    Globals.die()
    BattleManager.cleanup(false)
  else:
    BattleManager.cleanup(true)
  overworld_collision.set_deferred("disabled", false)
  overworld_query.collision_mask = 1 << 2
  enemy_search_query.collision_mask = 1 << 2
  collision_mask = 1
  
  ability_cooldowns.fill(0.0)

func _execute_ability(index: int) -> void:
  # ignore warnings about redundant await because the ability functions might be async
  if index >= 0 and index < abilities.size():
    var ability = abilities[index]
    await ability.pre_execute(self)
    await ability.execute(self)
    await ability.exit(self)
    ability_cooldowns[index] = ability.cooldown

func get_ability_cooldown(index: int) -> float:
  return ability_cooldowns[index]

func get_ability_index(ability: Ability) -> int:
  return abilities.find(ability)

func _on_battle_movement_idling_entered() -> void:
  _update_battle_idle_animation()

func _update_battle_idle_animation() -> void:
  if input_vector != Vector2.ZERO:
    return
  match _battle_facing_direction:
    Vector2.LEFT:
      animation_player.play("idle_battle_left")
    Vector2.RIGHT:
      animation_player.play("idle_battle_right")
    _:
      animation_player.play("idle_battle_right")

func _on_battle_movement_walking_entered() -> void:
  _update_battle_walk_animation()

func _update_battle_walk_animation() -> void:
  if input_vector == Vector2.ZERO:
    return
  var anim_name = "battle_%s_walk_%s" % [
    "left" if _battle_facing_direction == Vector2.LEFT else "right",
    "left" if input_vector.x < 0 else "right"
  ]
  animation_player.play(anim_name)
