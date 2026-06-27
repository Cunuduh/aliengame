extends Ability
class_name BasicAbility2

var override_velocity := Vector2.ZERO

func _init() -> void:
	cooldown = 7.5
	name = "basic_ability_2"
	current_state = "cast"
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
	var space_state := player.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(player.global_position, target_pos)
	query.exclude = [player]
	query.collision_mask = 1 << 1
	var result := space_state.intersect_ray(query)
	if result:
		target_pos = result.position - (direction * 0.2)
	var dash_duration := player.global_position.distance_to(target_pos) / dash_speed
	player.invincibility = true
	var tween := player.get_tree().create_tween()
	tween.tween_property(player, "global_position", target_pos, dash_duration)
	player.clear_ghosts()
	for i in player.ghost_count:
		var ghost_index := player.ghost_data.size()
		player.add_ghost(
			player.global_position,
			player.sprite.texture,
			player.sprite.frame,
			player.sprite.hframes,
			player.sprite.vframes,
			player.sprite.flip_h,
			Color(1, 1, 1, 0.5)
		)
		player.fade_ghost(ghost_index, 0.2)
		await player.get_tree().create_timer(dash_duration / player.ghost_count).timeout

	player.invincibility = false
	var idx := player.get_ability_index(self)
	player.state_chart.send_event("end_%s-%d" % [name, idx])