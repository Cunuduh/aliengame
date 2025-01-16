extends Combatant
class_name Player

@export var animation_tree: AnimationTree
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

var speed := 85
var collision_count := 0
var ability_cooldowns: Array[float]

var ghost_sprites: Array[Sprite2D] = []
var ghost_count = 5

var animation_state_machine: AnimationNodeStateMachinePlayback
func _ready() -> void:
  animation_tree.active = true
  animation_state_machine = animation_tree.get("parameters/playback")
  animation_state_machine.start("idle")
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
  state_chart.get_node("Root/Chilling").state_processing.connect(_on_chilling_state_processing)
  state_chart.get_node("Root/Chilling/Idling").state_entered.connect(_on_idling_state_entered)
  state_chart.get_node("Root/Chilling/Idling").state_processing.connect(_on_idling_state_processing)
  state_chart.get_node("Root/Chilling/Walking").state_processing.connect(_on_walking_state_processing)
  state_chart.get_node("Root/Battling").state_entered.connect(_on_battling_state_entered)
  state_chart.get_node("Root/Battling").state_processing.connect(_on_battling_state_processing)
  state_chart.get_node("Root/Battling").state_exited.connect(_on_battling_state_exited)

  ability_cooldowns.resize(abilities.size())
  ability_cooldowns.fill(0.0)

  for i in range(abilities.size()):
    _create_ability_states(abilities[i], i)

func _create_ability_states(ability: Ability, index: int) -> void:
  var ability_node_name = ability.name.to_pascal_case()

  var use_event := StringName("use_%s" % ability.name)
  var end_event := StringName("end_%s" % ability.name)
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
  active_node.state_exited.connect(func(): animation_state_machine.travel("idle"))

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

func _on_idling_state_entered() -> void:
  if stats.health > 0:
    animation_state_machine.travel("idle")

func _on_idling_state_processing(_delta: float) -> void:
  if Input.get_vector("left", "right", "up", "down") != Vector2.ZERO and stats.health > 0:
    state_chart.send_event("walk")

func _on_walking_state_processing(delta: float) -> void:
  if stats.health <= 0:
    return
  if _handle_movement() == Vector2.ZERO:
    state_chart.send_event("idle")

func _handle_movement() -> Vector2:
  var input_vector = Input.get_vector("left", "right", "up", "down")
  velocity = input_vector * speed
  move_and_slide()
  var node = animation_state_machine.get_current_node()
  if input_vector.x < 0:
    if node != "walk_left_loop":
      animation_state_machine.travel("walk_left_loop")
  elif input_vector.x > 0 or (input_vector.y != 0 and node != "walk_left_loop"):
    if node != "walk_right_loop":
      animation_state_machine.travel("walk_right_loop")
  return input_vector

func _get_square_input_vector(left: String, right: String, up: String, down: String) -> Vector2:
  var x := int(Input.is_action_pressed(right)) - int(Input.is_action_pressed(left))
  var y := int(Input.is_action_pressed(down)) - int(Input.is_action_pressed(up))
  return Vector2(x, y)

func _flip_player_sprite() -> void:
  if Globals.encountered_enemies.size():
    if sprite.global_position.x < closest_enemy_position.x:
      sprite.flip_h = false
    else:
      sprite.flip_h = true

func _on_battling_state_entered() -> void:
  in_battle = true
  sprite.modulate = Color(1, 1, 1, 0.5)
  soul.visible = true
  overworld_collision.set_deferred("disabled", true)
  battle_collision.set_deferred("disabled", false)
  overworld_query.collision_mask = 0
  enemy_search_query.collision_mask = 0
  collision_mask = 1 << 1

func _on_battling_state_processing(_delta: float) -> void:
  if Globals.encountered_enemies.size() == 0:
    state_chart.send_event("battle_finished")
    return
  if stats.health <= 0:
    state_chart.send_event("battle_finished")
    return

  _handle_movement()
  closest_enemy_position = Globals.encountered_enemies.front().global_position

  for enemy in Globals.encountered_enemies:
    if global_position.distance_to(enemy.global_position) < global_position.distance_to(closest_enemy_position):
      closest_enemy_position = enemy.global_position

  if Input.is_action_just_pressed("slow"):
    speed = 35
  elif Input.is_action_just_released("slow"):
    speed = 70

  if ability_cooldowns[0] == 0:
    if Input.is_action_just_pressed("attack"):
      state_chart.send_event("use_%s" % abilities[0].name)
  
  if ability_cooldowns[1] == 0:
    if Input.is_action_just_pressed("ability_1"):
      state_chart.send_event("use_%s" % abilities[1].name)

  if ability_cooldowns[2] == 0:
    if Input.is_action_just_pressed("ability_2"):
      state_chart.send_event("use_%s" % abilities[2].name)
  
  if ability_cooldowns.size() > 3 and ability_cooldowns[3] == 0:
    if Input.is_action_just_pressed("ability_3"):
      state_chart.send_event("use_%s" % abilities[3].name)
  
  if ability_cooldowns.size() > 4 and ability_cooldowns[4] == 0:
    if Input.is_action_just_pressed("ability_4"):
      state_chart.send_event("use_%s" % abilities[4].name)
  
func _on_battling_state_exited() -> void:
  in_battle = false
  speed = 70

  sprite.flip_h = false
  sprite.top_level = false
  sprite.modulate = Color(1, 1, 1, 1)
  sprite.position = Vector2.ZERO

  soul.visible = false
  battle_collision.set_deferred("disabled", true)
  if stats.health > 0:
    Globals.deconstruct_battle_scene()
  else:
    BulletPool.clear_bullets()
    Globals.die()
  overworld_collision.set_deferred("disabled", false)
  overworld_query.collision_mask = 1 << 2
  enemy_search_query.collision_mask = 1 << 2
  collision_mask = 1

func _execute_ability(index: int) -> void:
  if index >= 0 and index < abilities.size():
    var ability = abilities[index]
    await ability.pre_execute(self)
    await ability.execute(self)
    await ability.exit(self)
    ability_cooldowns[index] = ability.cooldown

func get_ability_cooldown(index: int) -> float:
  return ability_cooldowns[index]
