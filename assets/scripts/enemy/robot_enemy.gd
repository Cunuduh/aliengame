extends Enemy

func _attack() -> void:
  if target:
    await get_tree().create_timer(0.5).timeout
    if stats.health <= 0:
      return
    var bullet_index := BulletPool.get_bullet()
    var dist_to_target := global_position.distance_to(target.global_position)
    var time_to_target := dist_to_target / 200.0
    var predicted_pos := predict_target_position(time_to_target)
    var direction := (predicted_pos - global_position).normalized()
    
    var bullet_transform := Transform2D().rotated(direction.angle())
    bullet_transform.origin = global_position
    BulletPool.fire_bullet(bullet_index, bullet_transform, 200.0)
    animation_player.play("attack")
    await animation_player.animation_finished
    animation_player.play("idle")

  await get_tree().create_timer(1.0).timeout
  movement_switch_timer = movement_switch_interval - 1.0
  state_chart.send_event("attack_complete")