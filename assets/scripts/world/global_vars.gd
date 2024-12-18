extends Node
class_name GlobalVars

var battle_background: Texture2D
var player: Combatant
var encountered_enemies: Array[Combatant] = []
var original_environment: Lobby
var original_environment_children: Array[CanvasItem]
var current_battle_scene: BattleScene
var levels_completed := 0
var dead := false
func construct_battle_scene():
  var battle_scene = preload("res://assets/scenes/battle_scene.tscn").instantiate()
  player.state_chart.send_event("enemy_collision")
  original_environment = player.get_parent()
  generate_enemies()
  for child in original_environment.get_children():
    if child not in [player] + Globals.encountered_enemies and child.name != "StateChartDebugger":
      child.set_process(false)
      child.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
      if child is CanvasItem and child.name != "Background":
        child.visible = false
      original_environment_children.append(child)
  original_environment.call_deferred("add_child", battle_scene)
  battle_scene.set_position(Vector2(0, 0))
  var nodes_to_reparent = [player] + encountered_enemies
  for node in nodes_to_reparent:
    if node.visible:
      node.get_parent().call_deferred("remove_child", node)
      battle_scene.call_deferred("add_child", node)
  current_battle_scene = battle_scene

func deconstruct_battle_scene():
  var battle_scene = current_battle_scene
  for node in battle_scene.get_children():
    if node is Combatant:
      node.get_parent().call_deferred("remove_child", node)
      original_environment.call_deferred("add_child", node)
  for child in original_environment_children:
    if is_instance_valid(child):
      child.set_process(true)
      child.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
      if child is CanvasItem:
        child.visible = true
  original_environment_children.clear()
  original_environment.refresh_package()
  await battle_scene.fade_out()
  battle_scene.queue_free()
  current_battle_scene = null
  levels_completed += 1
  original_environment.levels_cleared.text = str(Globals.levels_completed) + " LEVELS CLEARED"

func die():
  if dead:
    return
  dead = true
  var death_scene := preload("res://assets/scenes/death_screen.tscn").instantiate()
  original_environment.add_child(death_scene)
  player.get_parent().remove_child(player)
  death_scene.add_child(player)
  await current_battle_scene.fade_out()
  current_battle_scene.queue_free()
  encountered_enemies.clear()
  original_environment = null
  original_environment_children.clear()
  levels_completed = 0

func generate_enemies():
  var base_count := 1 + floori(levels_completed / 2.0)
  
  match levels_completed:
    0, 1:
      _spawn_enemies("robot", base_count)
    
    2, 3:
      _spawn_enemies("robot", base_count)
      _spawn_enemies("horned", base_count)
    
    4, 5:
      _spawn_enemies("robot", base_count)
      _spawn_enemies("horned", base_count) 
      _spawn_enemies("cthulhuan", 1)
    6:
      _spawn_enemies("teeth", 1)
    _:
      var robot_count := base_count + 1
      var horned_count := base_count + 2
      var cthulhuan_count := 1 + floori(levels_completed / 4.0)
      
      # Add 5% chance for teeth enemy at round 7+
      var spawn_teeth := levels_completed >= 7 and randf() <= 0.05
      
      if spawn_teeth:
        _spawn_enemies("teeth", 1)
        # Reduce other enemy counts if teeth enemy spawns
        robot_count = ceili(robot_count / 3.0)
        horned_count = ceili(horned_count / 3.0) 
        cthulhuan_count = ceili(cthulhuan_count / 3.0)
      
      _spawn_enemies("robot", robot_count)
      _spawn_enemies("horned", horned_count)
      _spawn_enemies("cthulhuan", cthulhuan_count)

func _spawn_enemies(type: String, count: int) -> void:
  var scene: PackedScene
  match type:
    "robot":
      scene = preload("res://assets/scenes/robot_enemy.tscn")
    "horned":
      scene = preload("res://assets/scenes/horned_enemy.tscn")
    "cthulhuan":
      scene = preload("res://assets/scenes/cthulhuan_enemy.tscn")
    "teeth":
      scene = preload("res://assets/scenes/teeth_enemy.tscn")
  
  const MARGIN := 80.0
  const ARENA_WIDTH := 480.0
  const ARENA_HEIGHT := 270.0
  
  for i in range(count):
    var enemy: Enemy = scene.instantiate()
    enemy.visible = true

    enemy.global_position = Vector2(
      clampf(MARGIN + randf() * (ARENA_WIDTH - 2 * MARGIN), MARGIN, ARENA_WIDTH - MARGIN),
      clampf(MARGIN + randf() * (ARENA_HEIGHT - 2 * MARGIN), MARGIN, ARENA_HEIGHT - MARGIN)
    )
    
    encountered_enemies.append(enemy)
    original_environment.add_child(enemy)
