extends Node2D

const SHAPE: CircleShape2D = preload("res://assets/resources/bullet_generic.tres")
const SPRITE_FRAMES: SpriteFrames = preload("res://assets/resources/friendliness_pellet.tres")
const BULLET_LIFETIME: float = 10.0

var bullet_textures: Dictionary = {
  "default": SPRITE_FRAMES
}
var current_bullet_type: String = "default"

var pool_size: int = 1 << 12 # 4096
var _pool_index: int = 0
var _active_bullets_count: int = 0

var bullet_nodes: Array[AnimatedSprite2D] = []
var speeds: PackedFloat32Array = PackedFloat32Array()
var lifetimes: PackedFloat32Array = PackedFloat32Array()
var bullet_types: PackedStringArray = PackedStringArray()
var transforms: Array[Transform2D] = []

var _active_bullet_indices: PackedInt32Array = PackedInt32Array()
var _active_index_map: Dictionary = {}

var _query: PhysicsShapeQueryParameters2D
var _collision_result: Array[Dictionary]
@onready var _direct_space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state


func _ready() -> void:
  z_index = 100

  bullet_nodes.resize(pool_size)
  speeds.resize(pool_size)
  lifetimes.resize(pool_size)
  bullet_types.resize(pool_size)
  transforms.resize(pool_size)
  _active_bullet_indices.resize(0)

  for i in range(pool_size):
    var bullet := AnimatedSprite2D.new()
    bullet.sprite_frames = bullet_textures[current_bullet_type]
    bullet.visible = false

    var area := Area2D.new()
    area.collision_layer = 0
    area.collision_mask = 0
    var collision := CollisionShape2D.new()
    collision.shape = SHAPE
    area.add_child(collision)
    bullet.add_child(area)

    add_child(bullet)
    bullet_nodes[i] = bullet
    speeds[i] = 0.0
    lifetimes[i] = 0.0
    bullet_types[i] = current_bullet_type
    transforms[i] = Transform2D()

  _query = PhysicsShapeQueryParameters2D.new()
  _query.collide_with_bodies = true
  _query.collide_with_areas = false
  _query.collision_mask = 1 + (1 << 1)
  _query.shape = SHAPE


func set_bullet_type(type: String) -> void:
  if bullet_textures.has(type):
    current_bullet_type = type


func add_bullet_type(type_name: String, frames: SpriteFrames) -> void:
  if not bullet_textures.has(type_name):
    bullet_textures[type_name] = frames


func get_bullet() -> int:
  var start_index := _pool_index

  while _active_index_map.has(_pool_index):
    _pool_index = (_pool_index + 1) % pool_size
    if _pool_index == start_index:
      printerr("bullet pool full, reusing oldest bullet.")
      deactivate_bullet(_pool_index)
      break

  var bullet_index := _pool_index
  _pool_index = (_pool_index + 1) % pool_size

  var active_list_pos := _active_bullet_indices.size()
  _active_bullet_indices.push_back(bullet_index)
  _active_index_map[bullet_index] = active_list_pos
  _active_bullets_count += 1

  return bullet_index


func fire_bullet(index: int, new_global_transform: Transform2D, speed: float, bullet_type: String = "") -> void:
  if not _active_index_map.has(index):
    printerr("attempted to fire inactive bullet index: ", index)
    return

  var bullet := bullet_nodes[index] as AnimatedSprite2D

  bullet.global_transform = new_global_transform
  bullet.visible = true

  speeds[index] = speed
  lifetimes[index] = 0.0
  transforms[index] = new_global_transform

  var final_bullet_type := current_bullet_type
  if bullet_type != "" and bullet_textures.has(bullet_type):
    final_bullet_type = bullet_type

  if bullet_types[index] != final_bullet_type:
    bullet_types[index] = final_bullet_type
    bullet.sprite_frames = bullet_textures[final_bullet_type]

  bullet.play("default")


func _process(delta: float) -> void:
  if _active_bullets_count <= 0:
    return

  for i in range(_active_bullets_count - 1, -1, -1):
    var bullet_index := _active_bullet_indices[i]
    var bullet_sprite := bullet_nodes[bullet_index] as AnimatedSprite2D

    var direction := Vector2.RIGHT.rotated(bullet_sprite.global_rotation)
    bullet_sprite.global_position += direction * speeds[bullet_index] * delta

    lifetimes[bullet_index] += delta

    if lifetimes[bullet_index] > BULLET_LIFETIME:
      deactivate_bullet(bullet_index)
      continue

    _query.transform = bullet_sprite.global_transform
    _collision_result = _direct_space_state.intersect_shape(_query, 1)

    if _collision_result.size() > 0:
      var collider = _collision_result[0]["collider"]
      if collider.is_in_group("player"):
        var player_node: Player = collider
        player_node.stats.health += 1 if player_node.heal_from_damage else -1
        player_node.collision_count += 1
        continue
      elif collider.is_in_group("battle"):
        deactivate_bullet(bullet_index)
        continue


func deactivate_bullet(index_to_deactivate: int) -> void:
  if not _active_index_map.has(index_to_deactivate):
    return

  var bullet := bullet_nodes[index_to_deactivate] as AnimatedSprite2D
  if bullet.visible:
    bullet.visible = false
    bullet.stop()

    var pos_in_active_list: int = _active_index_map[index_to_deactivate]
    var last_bullet_index := _active_bullet_indices[-1]

    _active_bullet_indices[pos_in_active_list] = last_bullet_index
    _active_index_map[last_bullet_index] = pos_in_active_list

    _active_index_map.erase(index_to_deactivate)
    _active_bullet_indices.resize(_active_bullet_indices.size() - 1)

    _active_bullets_count -= 1

func clear_bullets() -> void:
  var indices_to_clear := _active_index_map.keys()
  for bullet_index in indices_to_clear:
    deactivate_bullet(bullet_index)

  _active_bullet_indices.clear()
  _active_index_map.clear()
  _active_bullets_count = 0
  _pool_index = 0


func create_circle_transform_func(center_position: Vector2, num_items: int) -> Callable:
  return func(i: int) -> Transform2D:
    var angle_step := (2.0 * PI) / num_items
    var current_angle := angle_step * i
    var new_transform := Transform2D().rotated(current_angle)
    new_transform.origin = center_position
    return new_transform
