extends PlayerBase
class_name Player

var _attack_charge: float
var _ghost_sprites: Array[Sprite2D] = []
var _ghost_count = 5
func _ready() -> void:
  super._ready()
  _attack_charge = speed
  combatant_name = "Player"
  for i in _ghost_count:
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
    _ghost_sprites.append(ghost)
    ghost.visible = false

func _pre_attack() -> void:
  _attack_charge = speed
  animation_player.play("attack_transition")
  await animation_player.animation_finished
  animation_player.play("attack_wait")
  # wait for key release
  while Input.is_action_pressed("attack"):
    _attack_charge += 70 * get_process_delta_time()
    await get_tree().process_frame
  attack()

func attack() -> void:
  state_chart.send_event("end_attack")
  animation_player.play("attack_action")
  var projectile: Sprite2D = preload("res://assets/scenes/player_attack_projectile.tscn").instantiate()
  Globals.current_battle_scene.add_child(projectile)
  projectile.global_position = global_position
  projectile.launch(closest_enemy_position, min(floori(_attack_charge), speed * 2))
  await get_tree().create_timer(animation_player.get_animation("attack_action").length).timeout
  animation_player.play("battle_stance")

func _pre_ability_1() -> void:
  ability_1()

func ability_1() -> void:
  pass

func _pre_ability_2() -> void:
  var override_velocity := Vector2.ZERO
  if velocity.length() == 0:
    var direction := closest_enemy_position.direction_to(global_position)
    var snapped_angle := roundi(direction.angle() / PI * 4) * PI / 4
    override_velocity = Vector2(cos(snapped_angle), sin(snapped_angle)) * direction.length()
  ability_2(override_velocity)

func ability_2(override_velocity: Vector2 = Vector2.ZERO) -> void:
  if state_chart.get_node("Root/Battling/Attack/Active").active and not Input.is_action_pressed("attack"):
    state_chart.send_event("end_attack")

  var dash_distance := 150.0
  var dash_speed := 750.0
  var direction := velocity.normalized() if override_velocity == Vector2.ZERO else override_velocity.normalized()
  var target_pos := global_position + (direction * dash_distance)

  var space_state = get_world_2d().direct_space_state
  var query = PhysicsRayQueryParameters2D.create(global_position, target_pos) 
  query.exclude = [self]
  query.collision_mask = 1 << 1
  var result = space_state.intersect_ray(query)
  
  if result:
    target_pos = result.position - (direction * 0.2)
  var dash_duration := global_position.distance_to(target_pos) / dash_speed
  invincibility = true
  var tween = get_tree().create_tween()
  tween.tween_property(self, "global_position", target_pos, dash_duration)

  for i in _ghost_count:
    var ghost := _ghost_sprites[i]
    ghost.visible = true
    ghost.texture = sprite.texture
    ghost.hframes = sprite.hframes
    ghost.vframes = sprite.vframes
    ghost.frame = sprite.frame
    ghost.flip_h = sprite.flip_h
    ghost.modulate = Color(1, 1, 1, 0.5)
    ghost.position = global_position
    var ghost_tween = get_tree().create_tween()
    ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
    ghost_tween.tween_callback(func(): ghost.visible = false)
    await get_tree().create_timer(dash_duration / _ghost_count).timeout

  invincibility = false
  state_chart.send_event("end_ability_2")

func _exit_ability_2() -> void:
  animation_player.play("battle_stance")
  state_chart.send_event("end_ability_2")
