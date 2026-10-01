extends PartyMember
class_name Hime

const MORTAL_TURNS := 2
const MORTAL_TINT := Color(1.0, 0.45, 0.5)

var mortal_turns_left := 0

var _collapsed := false

func _ready() -> void:
	super()
	stats.can_go_negative = true
	hit_type = "punch"

func is_alive() -> bool:
	return not _collapsed

func is_mortal() -> bool:
	return not _collapsed and stats.health <= 0

func can_pay_hp() -> bool:
	return not _collapsed and stats.health > 0

func on_turn_start(battle: BattleScene) -> void:
	await battle.get_tree().process_frame
	if not is_mortal():
		return
	if mortal_turns_left > 0:
		mortal_turns_left -= 1
		battle.set_message(tr("* %s is running on fumes... %d turn left.") % [combatant_name, mortal_turns_left + 1])
		await battle.get_tree().create_timer(0.8).timeout
		return
	_collapsed = true
	battle.set_message(ko_message())
	await dissolve()
	await battle.get_tree().create_timer(0.6).timeout

func attack(battle: BattleScene, target: Combatant) -> void:
	if not is_instance_valid(target):
		return
	battle.set_message(tr("* %s punches %s!") % [combatant_name, target.combatant_name])
	await battle.get_tree().create_timer(0.4).timeout
	_play_attack_anim()
	await battle.get_tree().create_timer(0.1).timeout
	await battle.spawn_hit_effect(hit_type, target)
	var killed := battle.apply_damage(self, target)
	await battle.get_tree().create_timer(1.4 if killed else 0.6).timeout
	face(target.global_position)
	battle.return_to_idle(self)

func ko_message() -> String:
	return tr("* %s finally fell over...") % combatant_name

func revive() -> void:
	_collapsed = false
	mortal_turns_left = 0
	sprite.modulate = Color.WHITE
	super()

func _check_dissolve(stat: CharacterStats.StatType, value: int) -> void:
	if stat != CharacterStats.StatType.HEALTH:
		return
	var prev := _prev_health
	_prev_health = value
	if _collapsed:
		return
	if value > 0:
		mortal_turns_left = 0
		sprite.modulate = Color.WHITE
	else:
		if mortal_turns_left <= 0 and value < prev:
			mortal_turns_left = MORTAL_TURNS
		sprite.modulate = MORTAL_TINT
	if value < prev:
		await play_hurt(false)
