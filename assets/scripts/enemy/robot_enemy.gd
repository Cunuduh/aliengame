extends Enemy

func _attack() -> void:
  if target:
    await get_tree().create_timer(0.5).timeout
    if stats.health <= 0:
      return
    var bullet_index := BulletPool.get_bullet()
    var speed := 200.0
    var predicted_pos := predict_intercept_position(speed)
    var direction := (predicted_pos - global_position).normalized()
    
    var bullet_transform := Transform2D().rotated(direction.angle())
    bullet_transform.origin = global_position
    BulletPool.fire_bullet(bullet_index, bullet_transform, speed)
    animation_player.play("attack")
    await animation_player.animation_finished
    animation_player.play("idle")

  await get_tree().create_timer(1.0).timeout
  movement_switch_timer = movement_switch_interval - 1.0
  state_chart.send_event("attack_complete")