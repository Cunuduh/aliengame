extends Ability
class_name TripleDown

const HITS := 3
const HIT_DAMAGE := 15

func _init() -> void:
	name = "triple_down"
	en_cost = 0
	hp_cost_ratio = 0.25

func calculate_damage(_battle: BattleScene, _user: Combatant, _target: Combatant) -> int:
	return HIT_DAMAGE

func apply_effect(battle: BattleScene, user: Combatant, target: Combatant) -> void:
	var total := 0
	for i: int in range(HITS):
		if not is_instance_valid(target) or not target.is_alive():
			break
		await battle.spawn_hit_effect(user.hit_type, target)
		battle.apply_damage(user, target, HIT_DAMAGE, true)
		total += battle.last_damage
		battle.set_message(tr("* %s took %d damage!") % [target.combatant_name, total] + battle.damage_suffix() + battle.ko_suffix())
		await battle.get_tree().create_timer(0.15).timeout
	await battle.get_tree().create_timer(0.6).timeout
