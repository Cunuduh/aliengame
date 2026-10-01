extends Resource
class_name Ability

var cooldown: float = 1.0
var icon: Texture2D
var name: String
var targets_allies := false
var targets_self := false
var targets_all := false

var en_cost := 4
var hp_cost_ratio := 0.0
var link_bonus := 0

func hp_cost(user: Combatant) -> int:
	if hp_cost_ratio <= 0.0:
		return 0
	return maxi(1, ceili(user.stats.max_health * hp_cost_ratio))

func cost_label(user: Combatant) -> String:
	if hp_cost_ratio > 0.0:
		return str(hp_cost(user))
	return str(en_cost)

func affordable(user: Combatant, en: int) -> bool:
	if hp_cost_ratio > 0.0:
		return user.can_pay_hp()
	return en >= en_cost

func calculate_damage(_battle: BattleScene, _user: Combatant, _target: Combatant) -> int:
	return 3

func on_queue(_battle: BattleScene, user: Combatant) -> void:
	var ap := user.animation_player
	if not is_instance_valid(ap):
		return
	if ap.has_animation(name + "_loop"):
		ap.play(name + "_loop")
	elif ap.has_animation("spell_loop"):
		ap.play("spell_loop")

func use_in_battle(battle: BattleScene, user: Combatant, target: Combatant) -> void:
	battle.set_message(tr("* %s uses %s!") % [user.combatant_name, name.capitalize()])
	await battle.get_tree().create_timer(0.4).timeout
	await battle.pay_hp_cost(user, hp_cost(user))
	await battle.play_and_wait_first(user.animation_player,
		[name + "_cast", "spell_cast", "attack", "idle_battle"], 0.4)
	await apply_effect(battle, user, target)
	battle.return_to_idle(user)

func apply_effect(battle: BattleScene, user: Combatant, target: Combatant) -> void:
	var killed := battle.apply_damage(user, target, calculate_damage(battle, user, target))
	await battle.get_tree().create_timer(0.6 if killed else 0.2).timeout
