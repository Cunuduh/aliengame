extends Node

var battle_scene: BattleScene = null
var _world_nodes: Array = []  # cache of world nodes to disable during battle
var _battle_player: Combatant = null  # saved player during battle
var _player_original_parent: Node = null
var _player_original_global_position: Vector2 = Vector2.ZERO

func start_battle(player: Combatant, enemies: Array[Combatant]) -> void:
  _battle_player = player
  _player_original_parent = player.get_parent()
  _player_original_global_position = player.global_position
  _world_nodes = get_tree().get_nodes_in_group("world")
  for wn in _world_nodes:
    wn.process_mode = Node.PROCESS_MODE_DISABLED
  # get rest of non-world nodes that aren't in player/enemies
  for node in get_tree().get_nodes_in_group("enemy"):
    if node not in enemies:
      _world_nodes.append(node)
      node.process_mode = Node.PROCESS_MODE_DISABLED

  battle_scene = preload("res://assets/scenes/battle_scene.tscn").instantiate() as BattleScene
  get_tree().root.add_child(battle_scene)
  battle_scene.position = Vector2.ZERO

  await battle_scene.start(player, enemies)

func cleanup(result) -> void:
  if result and is_instance_valid(_battle_player) and is_instance_valid(_player_original_parent):
    if _battle_player.get_parent() == battle_scene:
      battle_scene.remove_child(_battle_player)
    _player_original_parent.call_deferred("add_child", _battle_player)

    var tween := create_tween()
    tween.tween_property(_battle_player, "global_position", _player_original_global_position, 0.5)

    _battle_player = null
    await battle_scene.fade_out()
    battle_scene.queue_free()
    battle_scene = null

    for wn in _world_nodes:
      wn.process_mode = Node.PROCESS_MODE_INHERIT
    _world_nodes.clear()
