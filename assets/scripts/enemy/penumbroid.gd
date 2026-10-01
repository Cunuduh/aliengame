extends Enemy

func _ready() -> void:
	super()
	hit_type = "bite"

func attack(battle: BattleScene, attack_target: Combatant) -> void:
	if not is_instance_valid(attack_target):
		return
	battle.set_message(tr("* %s bites %s!") % [combatant_name, attack_target.combatant_name])
	await battle.get_tree().create_timer(0.4).timeout
	_play_attack_anim()
	await battle.get_tree().create_timer(0.8).timeout
	await battle.spawn_hit_effect(hit_type, attack_target)
	var killed := battle.apply_damage(self, attack_target)
	await battle.get_tree().create_timer(1.4 if killed else 0.6).timeout
	face(attack_target.global_position)
	battle.return_to_idle(self)

func _play_attack_anim() -> void:
	if not is_instance_valid(animation_player):
		return
	animation_player.play("attack")