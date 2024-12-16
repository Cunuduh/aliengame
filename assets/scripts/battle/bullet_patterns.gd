extends Node
class_name BulletPatterns

func spawn_spiral_bullet_pattern(center_position: Vector2, num_bullets: int, spiral_turns: int, bullet_speed: float, spawn_gap: float = 0.0, bullet_gap: float = 0.0, initial_angle_offset: float = 0.0) -> void:
  var angle_step := (2.0 * PI * spiral_turns) / num_bullets
  var current_angle = initial_angle_offset
  for i in range(num_bullets):
    var bullet_index := BulletPool.get_bullet()
    var bullet_position = center_position
    var bullet_transform := Transform2D().rotated(current_angle)
    bullet_transform.origin = bullet_position
    BulletPool.fire_bullet(bullet_index, bullet_transform, bullet_speed)
    current_angle += angle_step + spawn_gap
    await get_tree().create_timer(bullet_gap).timeout
    if bullet_gap == 0.0:
      await get_tree().process_frame

func spawn_bullet_circle(center_position: Vector2, num_bullets: int, bullet_speed: float) -> void:
  var angle_step := (2.0 * PI) / num_bullets
  var current_angle = 0.0
  for i in range(num_bullets):
    var bullet_index := BulletPool.get_bullet()
    var bullet_transform := Transform2D().rotated(current_angle)
    bullet_transform.origin = center_position
    BulletPool.fire_bullet(bullet_index, bullet_transform, bullet_speed)
    current_angle += angle_step
