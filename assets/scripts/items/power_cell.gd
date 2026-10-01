extends Item
class_name PowerCell

const EN_RESTORE := 30

func _init() -> void:
	name = "power cell"
	description = "Restores %d EN to the party's pool." % EN_RESTORE
	en_restore = EN_RESTORE

func apply_effect(battle: BattleScene, _user: Combatant, _target: Combatant) -> void:
	battle.gain_en(EN_RESTORE)
	battle.set_message(tr("* The party recovers %d EN!") % EN_RESTORE)
	await battle.get_tree().create_timer(0.8).timeout
