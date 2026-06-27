extends Node

var battle_scene: BattleScene = null
var _world_nodes: Array = []
var encountered_enemies: Array[Combatant] = []
var _player_original_parent: Node = null # for restoring player to the original scene after battle
var _player_original_global_position: Vector2 = Vector2.ZERO
var dead := false

func start_battle() -> void:
	_player_original_parent = Globals.player.get_parent()
	_player_original_global_position = Globals.player.global_position
	_world_nodes = get_tree().get_nodes_in_group("world")
	for wn: Node in _world_nodes:
		wn.process_mode = Node.PROCESS_MODE_DISABLED
	# get rest of non-world nodes that aren't in player/enemies
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if node not in encountered_enemies:
			_world_nodes.append(node)
			node.process_mode = Node.PROCESS_MODE_DISABLED

	battle_scene = preload("res://assets/scenes/battle_scene.tscn").instantiate() as BattleScene
	get_tree().root.add_child(battle_scene)
	battle_scene.position = Vector2.ZERO

	await battle_scene.start(Globals.player, encountered_enemies)

func cleanup(battle_won: bool) -> void:
	if Globals.player and Globals.player.get_parent() == battle_scene:
		battle_scene.remove_child(Globals.player)

	if battle_won:
		if is_instance_valid(Globals.player) and is_instance_valid(_player_original_parent):
			_player_original_parent.call_deferred("add_child", Globals.player)

			var tween := create_tween()
			tween.tween_property(Globals.player, "global_position", _player_original_global_position, 0.5)

			await battle_scene.fade_out()
			battle_scene.queue_free()
			battle_scene = null

			for wn: Node in _world_nodes:
				wn.process_mode = Node.PROCESS_MODE_INHERIT
			_world_nodes.clear()
	else:
		if dead:
			return
		dead = true
		var death_scene := preload("res://assets/scenes/death_screen.tscn")
		Globals.player.get_tree().change_scene_to_packed(death_scene)
		BattleManager.encountered_enemies.clear()
		_player_original_parent = null
		battle_scene = null
