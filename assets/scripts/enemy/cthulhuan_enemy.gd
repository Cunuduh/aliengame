extends Enemy

func _attack() -> void:
  if target:
    await get_tree().create_timer(0.5).timeout
    if stats.health <= 0:
      return
    animation_player.play("attack")
    await spawn_spiral_bullet_pattern(12800, 4, 50.0, 0.025)
    animation_player.play("idle")

  movement_switch_timer = movement_switch_interval - 1.0
  state_chart.send_event("attack_complete")

func spawn_spiral_bullet_pattern(num_bullets: int, spiral_turns: int, bullet_speed: float, spawn_gap: float = 0.0, bullet_gap: float = 0.0, initial_angle_offset: float = 0.0) -> void:
  var angle_step := (2.0 * PI * spiral_turns) / num_bullets
  var current_angle = initial_angle_offset
  for i in range(num_bullets):
    if stats.health <= 0:
      return
    var bullet_index := BulletPool.get_bullet()
    var bullet_position = global_position
    var bullet_transform := Transform2D().rotated(current_angle)
    bullet_transform.origin = bullet_position
    BulletPool.fire_bullet(bullet_index, bullet_transform, bullet_speed)
    current_angle += angle_step + spawn_gap
    await get_tree().create_timer(bullet_gap).timeout
    if bullet_gap == 0.0:
      await get_tree().process_frame
