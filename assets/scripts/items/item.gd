extends Resource
class_name Item

var name := ""
var description := ""
var targets_allies := false
var en_restore := 0

func on_queue(_battle: BattleScene, user: Combatant) -> void:
	var ap := user.animation_player
	if not is_instance_valid(ap):
		return
	if ap.has_animation("item_loop"):
		ap.play("item_loop")

func use_in_battle(battle: BattleScene, user: Combatant, target: Combatant) -> void:
	battle.set_message(tr("* %s uses %s!") % [user.combatant_name, name.capitalize()])
	await battle.get_tree().create_timer(0.4).timeout
	await battle.play_and_wait_first(user.animation_player,
		["item_cast", "spell_cast", "idle_battle"], 0.4)
	await apply_effect(battle, user, target)
	battle.return_to_idle(user)

func apply_effect(_battle: BattleScene, _user: Combatant, _target: Combatant) -> void:
	pass

func use_in_overworld(_target: Combatant) -> bool:
	return false
