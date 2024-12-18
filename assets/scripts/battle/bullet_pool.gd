extends MultiMeshInstance2D

const COLOUR_OFF := Color(0, 0, 0, 0)
const SHAPE := preload("res://assets/resources/bullet_generic.tres")
const SPRITE_FRAMES := preload("res://assets/resources/friendliness_pellet.tres")
const BULLET_LIFETIME := 10.0

var lock_rotation := true

var pool_size := 1 << 12
var _index := 0

var positions := PackedVector2Array()
var directions := PackedVector2Array()
var speeds := PackedFloat32Array()
var lifetimes := PackedFloat32Array()
var frames := PackedFloat32Array()
var visibilities := PackedByteArray()

var query: PhysicsShapeQueryParameters2D
var collision_result: Array[Dictionary]

var frame_width: float
var frame_height: float
var frames_per_row: int
var frame_count: int
var texture_width: float
var texture_height: float
var animation_speed: float

@onready var direct_space_state := get_world_2d().direct_space_state

func _ready() -> void:
  z_index = 100

  positions.resize(pool_size)
  directions.resize(pool_size)
  speeds.resize(pool_size)
  lifetimes.resize(pool_size)
  frames.resize(pool_size)
  visibilities.resize(pool_size)

  query = PhysicsShapeQueryParameters2D.new()
  query.collide_with_bodies = true
  query.collision_mask = 1 + (1 << 1)
  query.shape = SHAPE

  var atlas_texture: Texture2D = SPRITE_FRAMES.get_frame_texture(&"default", 0).atlas

  frame_width = SPRITE_FRAMES.get_frame_texture(&"default", 0).region.size.x
  frame_height = SPRITE_FRAMES.get_frame_texture(&"default", 0).region.size.y
  animation_speed = SPRITE_FRAMES.get_animation_speed(&"default")
  frame_count = SPRITE_FRAMES.get_frame_count(&"default")
  texture_width = atlas_texture.get_width()
  texture_height = atlas_texture.get_height()
  frames_per_row = int(texture_width / frame_width)

  var multi_mesh := MultiMesh.new()
  var quad_mesh := QuadMesh.new()
  quad_mesh.size = Vector2(frame_width, frame_height)
  multi_mesh.mesh = quad_mesh
  
  multi_mesh.transform_format = MultiMesh.TRANSFORM_2D
  multi_mesh.use_custom_data = true
  multi_mesh.instance_count = pool_size
  
  self.multimesh = multi_mesh
  texture = atlas_texture

  var shader_material := ShaderMaterial.new()
  shader_material.shader = preload("res://assets/shaders/uv_offset.gdshader")
  shader_material.set_shader_parameter("texture_width", texture_width)
  shader_material.set_shader_parameter("texture_height", texture_height)
  shader_material.set_shader_parameter("frame_width", frame_width)
  shader_material.set_shader_parameter("frame_height", frame_height)
  material = shader_material

func get_bullet() -> int:
  var bullet_index := _index
  _index = wrapi(_index + 1, 0, pool_size - 1)
  return bullet_index

func fire_bullet(index: int, new_global_transform: Transform2D, speed: float) -> void:
  positions[index] = new_global_transform.origin
  directions[index] = new_global_transform.x
  speeds[index] = speed
  lifetimes[index] = 0.0
  frames[index] = 0.0
  visibilities[index] = 1

func _process(delta: float) -> void:
  for i in range(pool_size):
    if visibilities[i] == 1:
      positions[i] += directions[i] * speeds[i] * delta
      lifetimes[i] += delta
      query.transform.x = Vector2.RIGHT if lock_rotation else directions[i]
      query.transform.y = Vector2.UP if lock_rotation else directions[i].orthogonal()
      query.transform.origin = positions[i]
      frames[i] = fmod(frames[i] + delta * animation_speed, frame_count)

      collision_result = direct_space_state.intersect_shape(query, 1)
      if collision_result and collision_result[0]["collider"].is_in_group("player") and not collision_result[0]["collider"].invincibility:
        var player: PlayerBase = collision_result[0]["collider"]
        player.collision_count += 1
        player.stats.health += 1 if player.heal_from_damage else -1
      if lifetimes[i] > BULLET_LIFETIME or collision_result:
        visibilities[i] = 0
        multimesh.set_instance_custom_data(i, COLOUR_OFF)
        continue

      multimesh.set_instance_transform_2d(i, query.transform)
      var frame_index := int(frames[i])
      var uv_x := (frame_index % frames_per_row) * frame_width / texture_width
      var uv_y := (frame_index / frames_per_row) * frame_height / texture_height
      multimesh.set_instance_custom_data(i, Color(uv_x, uv_y, 1.0, 0.0))

func clear_bullets() -> void:
  for i in range(pool_size):
    if visibilities[i] == 1:
      visibilities[i] = 0
      multimesh.set_instance_custom_data(i, COLOUR_OFF)
