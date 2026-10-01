extends Ability
class_name Spike

func _init() -> void:
	cooldown = 0.8
	name = "spike"
	en_cost = 25

func calculate_damage(_battle: BattleScene, _user: Combatant, _target: Combatant) -> int:
	return 5
