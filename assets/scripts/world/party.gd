extends Node

const HIME := preload("res://assets/scenes/hime.tscn")

var roster: Array[PackedScene] = [HIME]
var followers: Array[PartyMember] = []

func spawn_followers(leader: Cora) -> void:
	followers.clear()
	var parent := leader.get_parent()
	if not is_instance_valid(parent):
		return
	var ahead: Node2D = leader
	for scene: PackedScene in roster:
		var member := scene.instantiate() as PartyMember
		if member == null:
			continue
		parent.add_child(member)
		member.follow(ahead)
		followers.append(member)
		ahead = member

func members() -> Array[Combatant]:
	var alive: Array[Combatant] = []
	for member: PartyMember in followers:
		if is_instance_valid(member):
			alive.append(member)
	return alive

func enter_battle() -> void:
	for member: PartyMember in followers:
		if is_instance_valid(member):
			member.in_battle = true
			member.stop_following()

func leave_battle() -> void:
	var ahead: Node2D = Globals.cora
	for member: PartyMember in followers:
		if not is_instance_valid(member) or not is_instance_valid(ahead):
			continue
		member.in_battle = false
		member.follow(ahead, false)
		ahead = member
