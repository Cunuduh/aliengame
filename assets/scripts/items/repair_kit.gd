extends Item
class_name RepairKit

const HEAL_AMOUNT := 30

func _init() -> void:
	name = "repair kit"
	description = "Restores %d HP to one ally." % HEAL_AMOUNT
	targets_allies = true

func apply_effect(battle: BattleScene, _user: Combatant, target: Combatant) -> void:
	await battle.apply_heal(target, HEAL_AMOUNT)
	await battle.get_tree().create_timer(0.8).timeout

func use_in_overworld(target: Combatant) -> bool:
	if target.stats.health >= target.stats.max_health:
		return false
	target.stats.health = mini(target.stats.health + HEAL_AMOUNT, target.stats.max_health)
	return true
