extends Node2D

const SHAPE: CircleShape2D = preload("res://assets/resources/bullet_generic.tres")
const SPRITE_FRAMES: SpriteFrames = preload("res://assets/resources/friendliness_pellet.tres")
const BULLET_LIFETIME: float = 10.0
const ANIMATION_NAME: String = "default"
@export var animation_speed: float = 10.0

var bullet_textures: Dictionary = {
  "default": SPRITE_FRAMES
}
var current_bullet_type: String = "default"

var pool_size: int = 1 << 10
var _pool_index: int = 0
var _active_bullets_count: int = 0

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
  z_index = 1000

  speeds.resize(pool_size)
  lifetimes.resize(pool_size)
  bullet_types.resize(pool_size)
  transforms.resize(pool_size)
  _active_bullet_indices.resize(0)
  set_process(true)
  queue_redraw()

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

  transforms[index] = new_global_transform
  speeds[index] = speed
  lifetimes[index] = 0.0

  var final_bullet_type := current_bullet_type
  if bullet_type != "" and bullet_textures.has(bullet_type):
    final_bullet_type = bullet_type
  if bullet_types[index] != final_bullet_type:
    bullet_types[index] = final_bullet_type

  queue_redraw()

func _process(delta: float) -> void:
  if _active_bullets_count <= 0:
    return

  for i in range(_active_bullets_count - 1, -1, -1):
    var bullet_index := _active_bullet_indices[i]
    var tx := transforms[bullet_index]
    var dir := Vector2.RIGHT.rotated(tx.get_rotation())
    tx.origin += dir * speeds[bullet_index] * delta
    transforms[bullet_index] = tx

    lifetimes[bullet_index] += delta
    if lifetimes[bullet_index] > BULLET_LIFETIME:
      deactivate_bullet(bullet_index)
      continue

    _query.transform = tx
    _collision_result = _direct_space_state.intersect_shape(_query, 1)
    if _collision_result.size() > 0:
      var collider = _collision_result[0]["collider"]
      if collider.is_in_group("player"):
        var player_node: Player = collider
        if not player_node.invincibility:
          player_node.stats.health -= 1
          player_node.start_invincibility()
        elif player_node.heal_from_damage:
          player_node.stats.health += 1
        player_node.collision_count += 1
        deactivate_bullet(bullet_index)
        continue
      elif collider.is_in_group("battle"):
        deactivate_bullet(bullet_index)
        continue
  queue_redraw()

func deactivate_bullet(index_to_deactivate: int) -> void:
  if not _active_index_map.has(index_to_deactivate):
    return

  var pos_in_active_list: int = _active_index_map[index_to_deactivate]
  var last_bullet_index := _active_bullet_indices[-1]

  _active_bullet_indices[pos_in_active_list] = last_bullet_index
  _active_index_map[last_bullet_index] = pos_in_active_list

  _active_index_map.erase(index_to_deactivate)
  _active_bullet_indices.resize(_active_bullet_indices.size() - 1)

  _active_bullets_count -= 1

  queue_redraw()

func clear_bullets() -> void:
  var indices_to_clear := _active_index_map.keys()
  for bullet_index in indices_to_clear:
    deactivate_bullet(bullet_index)

  _active_bullet_indices.clear()
  _active_index_map.clear()
  _active_bullets_count = 0
  _pool_index = 0

  queue_redraw()

func _draw() -> void:
  draw_set_transform(Vector2.ZERO)
  for index in _active_bullet_indices:
    var tx: Transform2D = transforms[index]
    draw_set_transform(tx.origin, tx.get_rotation(), tx.get_scale())
    var frames: SpriteFrames = bullet_textures[bullet_types[index]]
    var frame_count: int = frames.get_frame_count(ANIMATION_NAME)
    var frame_idx: int = int(lifetimes[index] * animation_speed) % frame_count
    var tex: Texture2D = frames.get_frame_texture(ANIMATION_NAME, frame_idx)
    var size: Vector2 = tex.get_size()
    draw_texture(tex, -size * 0.5)

  draw_set_transform(Vector2.ZERO)
