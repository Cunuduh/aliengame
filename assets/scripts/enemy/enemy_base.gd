extends Combatant
class_name Enemy

var target: Combatant
@export var ability_chance := 0.5
@onready var dissolve_particles: GPUParticles2D = $DissolveParticles
func _ready() -> void:
	add_to_group("enemy")
	animation_player.play("idle")
	collision_mask = 1 << 1
	stats.stat_changed.connect(_check_dissolve)
	target = Globals.cora

func plan_turn(battle: BattleScene) -> Dictionary:
	var turn_target := choose_target(battle.living_party())
	if turn_target == null:
		return {"type": "pass"}
	var usable: Array[Ability] = []
	for ability: Ability in abilities:
		if not ability.targets_allies:
			usable.append(ability)
	if not usable.is_empty() and randf() < ability_chance:
		return {"type": "ability", "ability": usable[randi() % usable.size()], "target": turn_target}
	return {"type": "fight", "target": turn_target}

func execute_plan(battle: BattleScene, plan: Dictionary) -> void:
	var turn_target: Combatant = plan.get("target", null)
	if not is_instance_valid(turn_target) or not turn_target.is_alive():
		var living := battle.living_party()
		turn_target = living[0] if not living.is_empty() else null
	if turn_target == null:
		return
	battle.focus_card(turn_target)
	match String(plan.get("type", "fight")):
		"ability":
			await (plan["ability"] as Ability).use_in_battle(battle, self, turn_target)
		"pass":
			battle.set_message(tr("* %s holds their turn.") % combatant_name)
			await battle.get_tree().create_timer(0.5).timeout
		_:
			await attack(battle, turn_target)

func plan_move_name(plan: Dictionary) -> String:
	match String(plan.get("type", "fight")):
		"ability":
			return (plan["ability"] as Ability).name.capitalize()
		"pass":
			return tr("Wait")
		_:
			return tr("Attack")

func move_names() -> Array[String]:
	var names: Array[String] = [tr("Attack")]
	for ability: Ability in abilities:
		names.append(ability.name.capitalize())
	return names

func choose_target(targets: Array[Combatant]) -> Combatant:
	if targets.is_empty():
		return null
	return targets[randi() % targets.size()]

func face(point: Vector2) -> void:
	sprite.flip_h = global_position.x > point.x

func check_flip() -> void:
	if target:
		face(target.global_position)

func _check_dissolve(stat: CharacterStats.StatType, value: int) -> void:
	var current_animation := animation_player.current_animation
	if not current_animation:
		current_animation = "idle"
	if animation_player.get_animation(current_animation).loop_mode == Animation.LoopMode.LOOP_NONE:
		current_animation = "idle"
	if stat == CharacterStats.StatType.HEALTH:
		if value <= 0:
			animation_player.play("hurt")
			await animation_player.animation_finished
			dissolve()
		else:
			animation_player.play("hurt")
			await animation_player.animation_finished
			animation_player.play(current_animation)

func dissolve() -> void:
	BattleManager.encountered_enemies.erase(self)
	set_collision_layer_value(3, false)
	animation_player.stop()
	dissolve_particles.emitting = true
	var tween := get_tree().create_tween()
	tween.tween_method(func(x: float) -> void: sprite.material.set_shader_parameter("progress", x), 0.25, 1.0, 2.0)
	await tween.finished
	await dissolve_particles.finished
	process_mode = Node.PROCESS_MODE_DISABLED
