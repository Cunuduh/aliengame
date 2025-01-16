extends Ability
class_name BasicAbility2

var override_velocity := Vector2.ZERO

func _init():
  cooldown = 7.5
  name = "basic_ability_2"
  icon = preload("res://assets/sprites/ui/battle/player/basic_ability_2_icon.png")

func pre_execute(player: Player) -> void:
  if player.velocity.length() == 0:
    var direction := player.closest_enemy_position.direction_to(player.global_position)
    var snapped_angle := roundi(direction.angle() / PI * 4) * PI / 4
    override_velocity = Vector2(cos(snapped_angle), sin(snapped_angle)) * direction.length()

func execute(player: Player) -> void:
  var dash_distance := 150.0
  var dash_speed := 750.0
  var direction := player.velocity.normalized()
  if player.velocity.length() == 0:
    var snapped_angle := roundi(player.closest_enemy_position.direction_to(player.global_position).angle() / PI * 4) * PI / 4
    direction = Vector2(cos(snapped_angle), sin(snapped_angle))
    
  var target_pos := player.global_position + (direction * dash_distance)
  var space_state = player.get_world_2d().direct_space_state
  var query = PhysicsRayQueryParameters2D.create(player.global_position, target_pos)
  query.exclude = [player]
  query.collision_mask = 1 << 1
  var result = space_state.intersect_ray(query)
  
  if result:
    target_pos = result.position - (direction * 0.2)
  var dash_duration := player.global_position.distance_to(target_pos) / dash_speed
  
  player.invincibility = true
  var tween = player.get_tree().create_tween()
  tween.tween_property(player, "global_position", target_pos, dash_duration)

  for i in player.ghost_count:
    var ghost: Sprite2D = player.ghost_sprites[i]
    ghost.visible = true
    ghost.texture = player.sprite.texture
    ghost.hframes = player.sprite.hframes
    ghost.vframes = player.sprite.vframes
    ghost.frame = player.sprite.frame
    ghost.flip_h = player.sprite.flip_h
    ghost.modulate = Color(1, 1, 1, 0.5)
    ghost.position = player.global_position
    var ghost_tween = player.get_tree().create_tween()
    ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
    ghost_tween.tween_callback(func(): ghost.visible = false)
    await player.get_tree().create_timer(dash_duration / player.ghost_count).timeout

  player.invincibility = false
  player.state_chart.send_event("end_basic_ability_2")