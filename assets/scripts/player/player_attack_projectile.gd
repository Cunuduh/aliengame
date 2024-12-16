extends Sprite2D

const SHAPE := preload("res://assets/resources/player_attack_projectile_shape.tres")

var direction := Vector2.ZERO
var image := preload("res://assets/sprites/player/attack_projectile.png").get_image()
var _distance_traveled := 0.0
var _max_distance := 0.0
var _queued_for_deletion := false
var _speed := 250.0
var query := PhysicsShapeQueryParameters2D.new()
@onready var direct_space_state := get_world_2d().direct_space_state

func _init() -> void:
  query.shape = SHAPE
  query.collide_with_bodies = true
  query.collision_mask = 1 << 2
func launch(target: Vector2, dist: int) -> void:
  visible = true
  _max_distance = dist
  
  direction = target - global_position
  rotation = direction.angle()

  $GPUParticles2D.process_material.angle_min = -rotation_degrees
  $GPUParticles2D.process_material.angle_max = -rotation_degrees

  $GPUParticles2D.texture = ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
  if _distance_traveled > _max_distance and not _queued_for_deletion:
    await destroy()
  if visible and not _queued_for_deletion:
    var distance := _speed * delta
    var motion := direction.normalized() * distance
    global_position += motion
    _distance_traveled += distance
    query.transform = global_transform
    var result := direct_space_state.intersect_shape(query, 1)
    if result.size() > 0 and result[0]["collider"].is_in_group("enemy"):
      result[0]["collider"].stats.health -= Globals.player.stats.attack
      await destroy()

func destroy() -> void:
  _queued_for_deletion = true
  var tween = get_tree().create_tween().set_parallel(true)
  tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1)
  tween.tween_property(self, "scale", Vector2(1, 0), 1)
  $GPUParticles2D.emitting = false
  await tween.finished
  visible = false
  queue_free()
