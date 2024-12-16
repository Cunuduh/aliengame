extends Node
class_name GlobalVars

var battle_background: Texture2D
var player: Combatant
var encountered_enemies: Array[Combatant] = []
var original_environment: Lobby
var original_environment_children: Array[CanvasItem]
var current_battle_scene: BattleScene
var levels_completed := 0
  
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

func generate_enemies():
  match levels_completed:
    0:
      var enemy: Enemy = preload("res://assets/scenes/robot_enemy.tscn").instantiate()
      enemy.visible = true
      enemy.global_position = Vector2(20+(randi() % 480-20), 20+(randi() % 270-20))
      encountered_enemies.append(enemy)
      original_environment.add_child(enemy)
    1:
      for i in range(3):
        var enemy: Enemy = preload("res://assets/scenes/robot_enemy.tscn").instantiate()
        enemy.visible = true
        enemy.global_position = Vector2(20+(randi() % 480-20), 20+(randi() % 270-20))
        encountered_enemies.append(enemy)
        original_environment.add_child(enemy)
    2:
      for i in range(2):
        var enemy: Enemy = preload("res://assets/scenes/robot_enemy.tscn").instantiate()
        enemy.visible = true
        enemy.global_position = Vector2(20+(randi() % 480-20), 20+(randi() % 270-20))
        encountered_enemies.append(enemy)
        original_environment.add_child(enemy)
      for i in range(2):
        var enemy: Enemy = preload("res://assets/scenes/horned_enemy.tscn").instantiate()
        enemy.visible = true
        enemy.global_position = Vector2(20+(randi() % 480-20), 20+(randi() % 270-20))
        encountered_enemies.append(enemy)
        original_environment.add_child(enemy)
