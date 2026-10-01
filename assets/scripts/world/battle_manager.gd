extends Node

var battle_scene: BattleScene = null
var _world_nodes: Array = []
var encountered_enemies: Array[Combatant] = []
var party: Array[Combatant] = []
var _cora_original_parent: Node = null # for restoring Cora to the original scene after battle
var _cora_original_global_position: Vector2 = Vector2.ZERO
var _member_original_global_positions: Dictionary = {}
var dead := false

func start_battle() -> void:
	_cora_original_parent = Globals.cora.get_parent()
	_cora_original_global_position = Globals.cora.global_position
	_world_nodes = get_tree().get_nodes_in_group("world")
	for wn: Node in _world_nodes:
		wn.process_mode = Node.PROCESS_MODE_DISABLED
	# get rest of non-world nodes that aren't in cora/enemies
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if node not in encountered_enemies:
			_world_nodes.append(node)
			node.process_mode = Node.PROCESS_MODE_DISABLED

	party = [Globals.cora]
	for member: Combatant in Party.members():
		party.append(member)

	_member_original_global_positions.clear()
	for member: PartyMember in Party.followers:
		if is_instance_valid(member):
			_member_original_global_positions[member] = member.global_position
	Party.enter_battle()

	battle_scene = preload("res://assets/scenes/battle_scene.tscn").instantiate() as BattleScene
	get_tree().root.add_child(battle_scene)
	battle_scene.position = Vector2.ZERO

	await battle_scene.start(party, encountered_enemies)

func revive_party() -> void:
	if is_instance_valid(Globals.cora):
		Globals.cora.revive()
	for member: PartyMember in Party.followers:
		if is_instance_valid(member):
			member.revive()

func cleanup(battle_won: bool) -> void:
	party.clear()
	if Globals.cora and Globals.cora.get_parent() == battle_scene:
		battle_scene.remove_child(Globals.cora)
	for member: PartyMember in Party.followers:
		if is_instance_valid(member) and member.get_parent() == battle_scene:
			battle_scene.remove_child(member)

	if battle_won:
		if is_instance_valid(Globals.cora) and is_instance_valid(_cora_original_parent):
			_cora_original_parent.call_deferred("add_child", Globals.cora)
			for member: PartyMember in Party.followers:
				if is_instance_valid(member):
					_cora_original_parent.call_deferred("add_child", member)

			var tween := create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(Globals.cora, "global_position", _cora_original_global_position, 0.5)
			for member: PartyMember in Party.followers:
				if is_instance_valid(member) and _member_original_global_positions.has(member):
					tween.tween_property(member, "global_position", _member_original_global_positions[member], 0.5)

			await battle_scene.fade_out()
			battle_scene.queue_free()
			battle_scene = null
			revive_party()

			for wn: Node in _world_nodes:
				wn.process_mode = Node.PROCESS_MODE_INHERIT
			_world_nodes.clear()
			Party.leave_battle()
			_member_original_global_positions.clear()
	else:
		if dead:
			return
		dead = true
		var death_scene := preload("res://assets/scenes/death_screen.tscn")
		Globals.cora.get_tree().change_scene_to_packed(death_scene)
		BattleManager.encountered_enemies.clear()
		_cora_original_parent = null
		battle_scene = null
