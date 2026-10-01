extends Ability
class_name BasicPatch

const HEAL_RATIO := 0.25
const BASE_HEAL := 1

func _init() -> void:
	name = "basic_patch"
	targets_allies = true

func apply_effect(battle: BattleScene, _user: Combatant, target: Combatant) -> void:
	await battle.apply_heal(target, int(target.stats.max_health * HEAL_RATIO) + BASE_HEAL)
	await battle.get_tree().create_timer(0.8).timeout
