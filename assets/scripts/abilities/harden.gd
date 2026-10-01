extends Ability
class_name Harden

func _init() -> void:
	name = "harden"
	targets_allies = true

func apply_effect(battle: BattleScene, _user: Combatant, target: Combatant) -> void:
	await battle.apply_stage(target, CharacterStats.StatType.DEFENSE, 1)
	await battle.get_tree().create_timer(0.8).timeout
