extends Combatant
class_name PlayerBase

@export var overworld_collision: CollisionShape2D
@export var battle_collision: CollisionShape2D
@export var enemy_search_area: Shape2D
@export var soul: Sprite2D

var heal_from_damage := false
var invincibility := false
var overworld_query := PhysicsShapeQueryParameters2D.new()
var enemy_search_query := PhysicsShapeQueryParameters2D.new()
@onready var direct_space_state := get_world_2d().direct_space_state

var closest_enemy_position := Vector2.ZERO

var speed := 70
var attack_cooldown := 0.0
var ability_1_cooldown := 0.0
var ability_2_cooldown := 0.0
var collision_count := 0
func _ready() -> void:
  soul.visible = false
  collision_mask = 1

  overworld_query.shape = overworld_collision.shape
  enemy_search_query.shape = enemy_search_area
  overworld_query.collision_mask = 1 << 2
  enemy_search_query.collision_mask = 1 << 2

  Globals.player = self

  state_chart.get_node("Root/Chilling").state_processing.connect(_on_chilling_state_processing)
  state_chart.get_node("Root/Chilling/Idling").state_entered.connect(_on_idling_state_entered)
  state_chart.get_node("Root/Chilling/Idling").state_exited.connect(_on_idling_state_exited)
  state_chart.get_node("Root/Chilling/Idling").state_processing.connect(_on_idling_state_processing)
  state_chart.get_node("Root/Chilling/Walking").state_processing.connect(_on_walking_state_processing)
  state_chart.get_node("Root/Battling").state_entered.connect(_on_battling_state_entered)
  state_chart.get_node("Root/Battling").state_processing.connect(_on_battling_state_processing)
  state_chart.get_node("Root/Battling").state_exited.connect(_on_battling_state_exited)

  state_chart.get_node("Root/Battling/Attack/Active").state_entered.connect(_pre_attack)
  state_chart.get_node("Root/Battling/Ability1/Active").state_entered.connect(_pre_ability_1)
  state_chart.get_node("Root/Battling/Ability2/Active").state_entered.connect(_pre_ability_2)
  state_chart.get_node("Root/Battling/Attack/Active").state_exited.connect(func(): animation_player.play("battle_stance"))
  state_chart.get_node("Root/Battling/Ability1/Active").state_exited.connect(func(): animation_player.play("battle_stance"))
  state_chart.get_node("Root/Battling/Ability2/Active").state_exited.connect(func(): animation_player.play("battle_stance"))

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

func set_attack_cooldown(_discard: float, value: float) -> void:
  attack_cooldown = value

func set_ability_1_cooldown(_discard: float, value: float) -> void:
  ability_1_cooldown = value

func set_ability_2_cooldown(_discard: float, value: float) -> void:
  ability_2_cooldown = value

func _on_chilling_state_processing(_delta: float) -> void:
  process_collisions()

func _on_idling_state_entered() -> void:
  if stats.health > 0:
    animation_player.play("battle_stance")

func _on_idling_state_exited() -> void:
  animation_player.play()

func _on_idling_state_processing(_delta: float) -> void:
  if Input.get_vector("left", "right", "up", "down") != Vector2.ZERO and stats.health > 0:
    state_chart.send_event("walk")

func _on_walking_state_processing(_delta: float) -> void:
  if stats.health <= 0:
    return
  _handle_movement()
  _flip_player_sprite()
  if Input.get_vector("left", "right", "up", "down") == Vector2.ZERO:
    state_chart.send_event("idle")

func _handle_movement() -> Vector2:
  var input_vector := Input.get_vector("left", "right", "up", "down")
  velocity = input_vector * speed
  move_and_slide()
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

  set_ability_1_cooldown(0, 0)
  set_ability_2_cooldown(0, 0)
  set_attack_cooldown(0, 0)

func _on_battling_state_processing(_delta: float) -> void:
  if Globals.encountered_enemies.size() == 0:
    state_chart.send_event("battle_finished")
    return
  if stats.health <= 0:
    state_chart.send_event("battle_finished")
    return

  _handle_movement()
  _flip_player_sprite()
  closest_enemy_position = Globals.encountered_enemies.front().global_position

  for enemy in Globals.encountered_enemies:
    if global_position.distance_to(enemy.global_position) < global_position.distance_to(closest_enemy_position):
      closest_enemy_position = enemy.global_position

  if Input.is_action_just_pressed("slow"):
    speed = 35
  elif Input.is_action_just_released("slow"):
    speed = 70

  if attack_cooldown == 0:
    if Input.is_action_pressed("attack"):
      state_chart.send_event("attack")
  
  if ability_1_cooldown == 0:
    if Input.is_action_just_pressed("ability_1"):
      state_chart.send_event("ability_1")

  if ability_2_cooldown == 0:
    if Input.is_action_just_pressed("ability_2"):
      state_chart.send_event("ability_2")
  
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
    animation_player.play("death")
    BulletPool.clear_bullets()
    Globals.die()
  overworld_collision.set_deferred("disabled", false)
  overworld_query.collision_mask = 1 << 2
  enemy_search_query.collision_mask = 1 << 2
  collision_mask = 1

# Override methods

func _pre_attack() -> void:
  pass

func attack() -> void:
  pass

func _exit_attack() -> void:
  pass

func _pre_ability_1() -> void:
  pass

func ability_1() -> void:
  pass

func _exit_ability_1() -> void:
  pass

func _pre_ability_2() -> void:
  pass

func ability_2() -> void:
  pass

func _exit_ability_2() -> void:
  pass
