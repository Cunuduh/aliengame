extends Node
class_name BulletPatterns

static func spawn_spiral_bullet_pattern(
	combatant: Combatant,
	num_bullets: int, 
	spiral_turns: int, 
	bullet_speed: float, 
	bullet_gap: float = 0.05, 
	initial_angle_offset: float = 0.0,
	spawn_radius: float = 0.0,
	clockwise: bool = true,
	spiral_arms: int = 1
) -> void:
	if num_bullets <= 0 or spiral_arms <= 0:
		return
	
	var bullets_spawned: int = 0
	var angle_increment: float = (2.0 * PI * spiral_turns) / num_bullets
	var arm_angle_offset: float = (2.0 * PI) / spiral_arms
	
	if not clockwise:
		angle_increment = -angle_increment
	
	while bullets_spawned < num_bullets:
		if combatant.stats.health <= 0:
			return
		for arm in range(spiral_arms):
			if bullets_spawned >= num_bullets:
				return
			var arm_offset: float = arm * arm_angle_offset
			var current_angle: float = initial_angle_offset + arm_offset + (angle_increment * bullets_spawned)
			var spawn_offset: Vector2 = Vector2(cos(current_angle), sin(current_angle)) * spawn_radius
			var bullet_position: Vector2 = combatant.global_position + spawn_offset
			var bullet_transform: Transform2D = Transform2D().rotated(current_angle)
			bullet_transform.origin = bullet_position
			var bullet_index: int = BulletPool.get_bullet()
			BulletPool.fire_bullet(bullet_index, bullet_transform, bullet_speed, "")
		bullets_spawned += spiral_arms
		if bullet_gap > 0.0:
			await combatant.get_tree().create_timer(bullet_gap).timeout
		else:
			await combatant.get_tree().process_frame

static func spawn_bullet_circle(combatant: Combatant, num_bullets: int, bullet_speed: float) -> void:
	var angle_step := (2.0 * PI) / num_bullets
	var current_angle := 0.0
	for i in range(num_bullets):
		var bullet_index := BulletPool.get_bullet()
		var bullet_transform := Transform2D().rotated(current_angle)
		bullet_transform.origin = combatant.global_position
		BulletPool.fire_bullet(bullet_index, bullet_transform, bullet_speed)
		current_angle += angle_step

static func spawn_offset_bullet_circles(
	combatant: Combatant,
	num_bullets_per_ring: int,
	num_rings: int,
	bullet_speed: float,
	bullet_gap: float = 0.1,
	initial_angle_offset: float = 0.0
) -> void:
	if num_bullets_per_ring <= 0 or num_rings <= 0:
		return
	var angle_step := (2.0 * PI) / num_bullets_per_ring
	var offset_per_ring := angle_step * 0.5
	for ring in range(num_rings):
		if combatant.stats.health <= 0:
			return
		var ring_angle_offset := initial_angle_offset + (ring * offset_per_ring)
		for bullet in range(num_bullets_per_ring):
			var bullet_angle := ring_angle_offset + (bullet * angle_step)
			var bullet_index := BulletPool.get_bullet()
			var bullet_transform := Transform2D().rotated(bullet_angle)
			bullet_transform.origin = combatant.global_position
			BulletPool.fire_bullet(bullet_index, bullet_transform, bullet_speed, "")
		if bullet_gap > 0.0:
			await combatant.get_tree().create_timer(bullet_gap).timeout
