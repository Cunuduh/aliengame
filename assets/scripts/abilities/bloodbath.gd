extends Ability
class_name Bloodbath

const DAMAGE := 100

func _init() -> void:
	name = "bloodbath"
	en_cost = 0
	hp_cost_ratio = 1.0
	targets_all = true

func calculate_damage(_battle: BattleScene, _user: Combatant, _target: Combatant) -> int:
	return DAMAGE

func apply_effect(battle: BattleScene, user: Combatant, _target: Combatant) -> void:
	for enemy: Combatant in battle.living_enemies():
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		await battle.spawn_hit_effect(user.hit_type, enemy)
		battle.apply_damage(user, enemy, DAMAGE)
		await battle.get_tree().create_timer(0.35).timeout
	await battle.get_tree().create_timer(0.6).timeout
