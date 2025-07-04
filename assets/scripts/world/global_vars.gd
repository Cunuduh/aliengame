extends Node
class_name GlobalVars

var battle_background: Texture2D
var player: Combatant
var encountered_enemies: Array[Combatant] = []
var original_environment: Node
var original_environment_children: Array[CanvasItem]
var current_battle_scene: BattleScene
var dead := false

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
