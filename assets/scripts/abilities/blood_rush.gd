extends Ability
class_name BloodRush

const DAMAGE_MULT := 2.0

func _init() -> void:
	name = "blood_rush"
	en_cost = 0
	hp_cost_ratio = 0.5
	targets_self = true

func apply_effect(battle: BattleScene, user: Combatant, _target: Combatant) -> void:
	await battle.spawn_hit_effect("buff", user, Color(1.0, 0.2, 0.3))
	battle.queue_damage_multiplier(user, DAMAGE_MULT)
	battle.set_message(tr("* %s's next attack will hit twice as hard!") % user.combatant_name)
	await battle.get_tree().create_timer(0.8).timeout
