extends Enemy

func _attack() -> void:
	if target:
		velocity = Vector2.ZERO
		current_speed = 0.0
		
		await get_tree().create_timer(0.5).timeout
		if stats.health <= 0:
			return
		animation_player.play("attack")
		await BulletPatterns.spawn_offset_bullet_circles(
			self,      # combatant
			16,         # num_bullets_per_ring
			128,         # num_rings
			30.0,     # bullet_speed
			0.25,      # bullet_gap (time between rings)
			0.0        # initial_angle_offset
		)
		animation_player.play("idle")
		
		current_speed = follow_speed

	movement_switch_timer = movement_switch_interval - 1.0
	state_chart.send_event("attack_complete")


