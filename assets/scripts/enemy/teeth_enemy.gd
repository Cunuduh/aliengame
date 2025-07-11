extends Enemy

func _attack() -> void:
  if target:
    # First phase - follow target while showing warning animation
    animation_player.play("attack_wait")
    var start_time := Time.get_ticks_msec()
    while Time.get_ticks_msec() - start_time < 2000 and stats.health > 0:
      var direction := (target.global_position - global_position)
      if abs(direction.length()) < 2:
        direction = Vector2.ZERO
      velocity = direction.normalized() * follow_speed * 1.5
      move_and_slide()
      await get_tree().process_frame
    
    if stats.health <= 0:
      return
        
    # Second phase - bite attack with bullet circle
    animation_player.play("attack")
    var attack_time := Time.get_ticks_msec()
    # Keep moving during attack animation
    while Time.get_ticks_msec() - attack_time < animation_player.get_animation("attack").length * 1000 - 200 and stats.health > 0:
      var direction := (target.global_position - global_position)
      if abs(direction.length()) < 2:
        direction = Vector2.ZERO
      velocity = direction.normalized() * follow_speed * 0.75 # Slower movement during attack
      move_and_slide()
      await get_tree().process_frame
      
    spawn_bullet_circle(global_position, 64, 200.0)
    await get_tree().create_timer(0.5).timeout
    animation_player.play("idle")

    state_chart.send_event("attack_complete")

func check_flip() -> void:
  pass

func spawn_bullet_circle(center_position: Vector2, num_bullets: int, bullet_speed: float, bullet_type: String = "") -> void:
  var angle_step := (2.0 * PI) / num_bullets
  var current_angle := 0.0
  for i in range(num_bullets):
    var bullet_index := BulletPool.get_bullet()
    var bullet_transform := Transform2D().rotated(current_angle)
    bullet_transform.origin = center_position
    BulletPool.fire_bullet(bullet_index, bullet_transform, bullet_speed, bullet_type)
    current_angle += angle_step
