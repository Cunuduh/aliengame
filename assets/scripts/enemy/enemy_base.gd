extends Combatant
class_name Enemy

@export var dissolve_particles: GPUParticles2D

var target: Combatant

var orbit_speed := PI / 2.0
@export var follow_speed := 60.0
@export var desired_distance := 140.0
@export var attack_interval := 5.0
var attack_timer := 0.0

var random_offset := 0.0
var orbit_angle := 0.0

var prediction_time := 1.5
@export var blocking_weight := 0.3

var current_speed := follow_speed

var orbit_direction := 1

var perceived_target_position := Vector2.ZERO
var perceived_target_velocity := Vector2.ZERO
const PERCEPTION_DELAY := 0.5

@export var movement_switch_interval := 5.0  # Time between movement type switches

var movement_switch_timer := movement_switch_interval

func _ready() -> void:
  add_to_group("enemy")
  desired_distance += randi() % 20
  attack_interval += randf() * 2.0
  animation_player.play("idle")
  collision_mask = 1 << 1
  stats.stat_changed.connect(_check_dissolve)

  random_offset = randf() * 2.0 * PI
  orbit_direction = 1 if randf() > 0.5 else -1
  target = Globals.player
  perceived_target_position = target.global_position
  perceived_target_velocity = target.velocity
func check_flip() -> void:
  if target:
    sprite.flip_h = global_position.x > target.global_position.x
func _process(delta: float) -> void:
  check_flip()
  if target and target.in_battle and stats.health > 0:
    update_perceived_player_info(delta)

    movement_switch_timer += delta
    attack_timer += delta

    if attack_timer >= attack_interval:
      state_chart.send_event("attack_interval")
      state_chart.send_event("stop_movement")
      attack_timer = 0.0

    if movement_switch_timer >= movement_switch_interval:
      if randf() < blocking_weight:
        state_chart.send_event("to_blocking")
      else:
        state_chart.send_event("to_orbiting")
      movement_switch_timer = 0.0

func update_perceived_player_info(delta: float) -> void:
  var target_position = target.global_position
  var target_velocity = target.velocity

  perceived_target_position = perceived_target_position.lerp(target_position, delta / PERCEPTION_DELAY)
  perceived_target_velocity = perceived_target_velocity.lerp(target_velocity, delta / PERCEPTION_DELAY)

func orbiting_movement(delta: float) -> void:
  var player_speed := perceived_target_velocity.length()
  var adjusted_orbit_speed := orbit_speed * (1 + player_speed / 100)
  orbit_angle += adjusted_orbit_speed * delta * orbit_direction

  var orbit_position := perceived_target_position + Vector2(cos(orbit_angle + random_offset), sin(orbit_angle + random_offset)) * desired_distance

  move_towards_position(orbit_position, delta)

func blocking_movement(delta: float) -> void:
  var predicted_player_pos := perceived_target_position + perceived_target_velocity * prediction_time
  var to_predicted_pos := predicted_player_pos - perceived_target_position

  var blocking_pos := perceived_target_position + to_predicted_pos.normalized() * desired_distance

  move_towards_position(blocking_pos, delta)

func move_towards_position(target_position: Vector2, delta: float) -> void:
  if stats.health <= 0:
    return
  var distance_to_target := global_position.distance_to(target_position)

  if distance_to_target > 10.0:
    var direction := (target_position - global_position).normalized()
    direction = snap_to_45_degrees(direction)

    current_speed = lerp(current_speed, follow_speed, delta * 2)
    velocity = direction * current_speed
  else:
    velocity = Vector2.ZERO

  move_and_slide()

func snap_to_45_degrees(vector: Vector2) -> Vector2:
  var angle := vector.angle()
  var snapped_angle := roundi(angle / (PI / 4)) * (PI / 4)
  return Vector2(cos(snapped_angle), sin(snapped_angle)) * vector.length()
func predict_target_position(time_ahead: float) -> Vector2:
  if !target:
    return Vector2.ZERO
  return target.global_position + (target.velocity * time_ahead)

func _get_intercept_time(shooter_pos: Vector2, target_pos: Vector2, target_vel: Vector2, projectile_speed: float) -> float:
  var r = target_pos - shooter_pos
  var a = target_vel.dot(target_vel) - projectile_speed * projectile_speed
  var b = 2.0 * r.dot(target_vel)
  var c = r.dot(r)
  var det = b * b - 4.0 * a * c
  if abs(a) < 0.0001 or det < 0.0:
    return r.length() / projectile_speed
  var sqrt_det = sqrt(det)
  var t1 = (-b + sqrt_det) / (2.0 * a)
  var t2 = (-b - sqrt_det) / (2.0 * a)
  var t = t1 if t1 > 0.0 else t2
  if t < 0.0:
    return r.length() / projectile_speed
  return t

func predict_intercept_position(projectile_speed: float) -> Vector2:
  if not target:
    return Vector2.ZERO
  var t = _get_intercept_time(global_position, target.global_position, target.velocity, projectile_speed)
  return target.global_position + target.velocity * t

func _attack() -> void:
  if target:
    for i in range(3):
      await get_tree().create_timer(0.1).timeout
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

  movement_switch_timer = movement_switch_interval - 1.0
  state_chart.send_event("attack_complete")

func _on_orbiting_state_processing(delta: float) -> void:
  orbiting_movement(delta)

func _on_blocking_state_processing(delta: float) -> void:
  blocking_movement(delta)

func _on_attacking_state_entered() -> void:
  _attack()

func _check_dissolve(stat: CharacterStats.StatType, value: int):
  var current_animation = animation_player.current_animation
  # if current animation is not looping, play idle instead
  if animation_player.get_animation(current_animation).loop_mode == Animation.LoopMode.LOOP_NONE:
    current_animation = "idle"
  if stat == CharacterStats.StatType.HEALTH:
    if value <= 0:
      dissolve()
    else:
      animation_player.play("damaged")
      await animation_player.animation_finished
      animation_player.play(current_animation)

func dissolve() -> void:
  Globals.encountered_enemies.erase(self)
  set_collision_layer_value(3, false)
  dissolve_particles.one_shot = true
  dissolve_particles.emitting = true
  animation_player.stop()
  var tween = get_tree().create_tween()
  tween.tween_method(func(x): sprite.material.set_shader_parameter("progress", x), 0.0, 1.0, 1.0)
  await tween.finished
  await dissolve_particles.finished
  process_mode = Node.PROCESS_MODE_DISABLED
