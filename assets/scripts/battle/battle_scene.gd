extends Control
class_name BattleScene


const BATTLE_UI := preload("res://assets/scenes/battle_ui.tscn")
const HIT_EFFECT := preload("res://assets/scenes/hit_effect.tscn")
const COMBATANT_INFO := preload("res://assets/scenes/combatant_info.tscn")
const LINK_STEP := 0.25
const EN_MAX := 32
const EN_START := 0
const EN_FIGHT_GAIN := 4
const EN_LINK_BONUS := 2
const EN_PASS_GAIN := 8
const NAV_REPEAT_DELAY := 0.35
const NAV_REPEAT_RATE := 0.07
const OUTLINE_QUEUE_COLOR := Color("#0bfdc5")
const OUTLINE_TARGET_COLOR := Color(1.0, 0.0, 0.0)
const OUTLINE_ALLY_TARGET_COLOR := Color(1.0, 1.0, 1.0)
const OUTLINE_TURN_COLOR := Color(1.0, 1.0, 1.0)
const OUTLINE_TURN_FADE := 0.5
const BUFF_STAGE_TEX: Array[Texture2D] = [
	preload("res://assets/sprites/ui/battle/buff_stage_1.png"),
	preload("res://assets/sprites/ui/battle/buff_stage_2.png"),
	preload("res://assets/sprites/ui/battle/buff_stage_3.png"),
]
const STAGE_CHEVRON_COLORS: Dictionary = {
	CharacterStats.StatType.ATTACK: Color(1.0, 0.2, 0.2),
	CharacterStats.StatType.DEFENSE: Color(0.3, 0.6, 1.0),
	CharacterStats.StatType.AGILITY: Color(0.3, 1.0, 0.3),
}
const STAGE_STAT_NAMES: Dictionary = {
	CharacterStats.StatType.ATTACK: "attack",
	CharacterStats.StatType.DEFENSE: "defense",
	CharacterStats.StatType.AGILITY: "agility",
}
const MENU := ["FIGHT", "ABILITY", "ITEM", "TURN", "CHECK"]

const SLOT_LAYOUTS := {
	1: [3],
	2: [2, 4],
	3: [1, 3, 5],
	4: [1, 2, 4, 5],
	5: [1, 2, 3, 4, 5],
}

var cora: Combatant
var party: Array[Combatant] = []
var enemies: Array[Combatant]
var ui: BattleUI
var _flavour := tr("* You're surrounded!")
var _active_member: Combatant

var _turn_order: Array[Combatant] = []
var _preview_highlight: Combatant
var _turn_acted: Array[Combatant] = []
var _link := 0
var _link_boost := 0
var _pending_fight_en := 0
var _en := EN_START
var _actor_outlined: Combatant
var _actor_outline_color := Color.WHITE
var _target_outlined: Combatant
var _combatant_infos: Array[HBoxContainer] = []
var _cache_hits: Array[Combatant] = []
var _queued_actions: Dictionary = {}
var _damage_mults: Dictionary = {}
var _mult_spent := false
var last_damage := 0
var last_factor := 1.0
var last_ko := ""
var _enemy_plans: Dictionary = {}
var _check_choices: Array[Combatant] = []
var _ally_choices: Array[Combatant] = []
var _item_choices: Array[Item] = []
var _queueing := false
var _reordering := false
signal _reorder_done(confirmed: bool)

# selection state
signal _choice_made(index: int)
var _selecting := false
var _nav_hold := 0.0
var _select_index := 0
var _select_count := 0
var _on_change := Callable()
var _menu_memory: Dictionary = {}

func start(battle_party: Array[Combatant], battle_enemies: Array[Combatant]) -> void:
	party = battle_party
	cora = party[0]
	enemies = BattleManager.encountered_enemies
	for member: Combatant in party:
		_reparent(member)
	for enemy: Combatant in battle_enemies:
		_reparent(enemy)
	for combatant: Combatant in party + enemies:
		if is_instance_valid(combatant):
			combatant.stats.reset_stages()

	_build_ui()
	$Border.modulate = Color(1, 1, 1, 1)
	_set_background_modulation(Color(0, 0, 0, 0))
	await get_tree().process_frame
	ui.refresh_card()
	_update_en()
	_turn_order = _build_turn_order()
	_refresh_turn_preview()

	for combatant: Combatant in party + enemies:
		if is_instance_valid(combatant):
			combatant.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.5).timeout
	for combatant: Combatant in party + enemies:
		if is_instance_valid(combatant):
			combatant.process_mode = Node.PROCESS_MODE_INHERIT

	var bg := get_tree().create_tween()
	bg.tween_method(_set_background_modulation, Color(0, 0, 0, 0), Color(1, 1, 1, 1), 0.75)
	await _slide_in_combatants(battle_enemies)
	await ui.slide_in()
	_run_battle()

func _build_ui() -> void:
	ui = BATTLE_UI.instantiate()
	add_child(ui)
	ui.setup(party, EN_MAX, _en)
	ui.turn_track.sort_children.connect(_on_turn_sorted)

func _reparent(combatant: Combatant) -> void:
	if not is_instance_valid(combatant):
		return
	var parent := combatant.get_parent()
	if is_instance_valid(parent):
		parent.remove_child(combatant)
	call_deferred("add_child", combatant)

func fade_out() -> void:
	_selecting = false
	_clear_outlines()
	if is_instance_valid(ui):
		ui.visible = false
	$Border.modulate = Color(0, 0, 0, 0)
	var tween := get_tree().create_tween()
	tween.tween_method(_set_background_modulation, Color(1, 1, 1, 1), Color(0, 0, 0, 0), 0.75)
	await tween.finished

func _set_background_modulation(colour: Color) -> void:
	$Background.material.set_shader_parameter("colour_modulation", colour)

func _run_battle() -> void:
	set_message(_flavour)
	while true:
		_turn_order = _build_turn_order()
		_plan_enemy_turns()
		var actions: Dictionary = {}
		while true:
			actions = await _party_queue_phase(actions)
			ui.hide_menu()
			if await _confirm_actions(actions):
				break
			for m: Combatant in living_party():
				return_to_idle(m)

		ui.hide_menu()
		_refresh_turn_preview()
		_turn_acted.clear()
		_link = 0
		var prev_ally := false
		var has_prev := false
		await ui.turn_track.sort_children
		for combatant: Combatant in _turn_order.duplicate():
			_link_boost = 0
			if not is_instance_valid(combatant) or not combatant.is_alive():
				_mark_turn_broken(combatant)
				_link = 0
				continue
			var is_ally := party.has(combatant)
			ui.point_turn_caret(combatant)
			await combatant.on_turn_start(self)
			if not combatant.is_alive():
				_mark_turn_broken(combatant)
				_link = 0
				if _party_wiped():
					await _defeat()
					return
				continue
			if has_prev and is_ally != prev_ally:
				_link = 0
			_flash_actor_outline(combatant, OUTLINE_TURN_COLOR, OUTLINE_TURN_FADE)
			while _cache_hits.has(combatant):
				_cache_hits.erase(combatant)
				_link_boost += 1
			_mult_spent = false
			if is_ally:
				await _execute_queued(combatant, actions.get(combatant, {"type": "pass"}))
			else:
				await (combatant as Enemy).execute_plan(self, _enemy_plans.get(combatant, {}))
				_link += 1
			_settle_damage_mult(combatant)
			prev_ally = is_ally
			has_prev = true
			_mark_turn_taken(combatant)
			await ui.wait_hp_tween()
			if enemies.is_empty():
				await _victory()
				return
			if _party_wiped():
				await _defeat()
				return
			await get_tree().create_timer(0.25).timeout
		_set_actor_outline(null)
		set_message(_flavour)

func living_party() -> Array[Combatant]:
	var alive: Array[Combatant] = []
	for m: Combatant in party:
		if is_instance_valid(m) and m.is_alive():
			alive.append(m)
	return alive

func living_enemies() -> Array[Combatant]:
	var alive: Array[Combatant] = []
	for e: Combatant in enemies:
		if is_instance_valid(e) and e.is_alive():
			alive.append(e)
	return alive

func _party_wiped() -> bool:
	return living_party().is_empty()

func _memory_for(combatant: Combatant) -> Dictionary:
	if not _menu_memory.has(combatant):
		_menu_memory[combatant] = {}
	return _menu_memory[combatant]

func _party_queue_phase(initial: Dictionary = {}) -> Dictionary:
	ui.hide_turn_caret()
	_queueing = true
	var actions := initial
	_queued_actions = actions
	var order: Array[Combatant] = []
	for combatant: Combatant in _turn_order:
		if party.has(combatant) and is_instance_valid(combatant) and combatant.is_alive():
			order.append(combatant)
	# A fresh round starts at the first member; re-entering from a cancelled confirm
	# resumes at the last, reading as a single step back out of the review. The
	# per-member block below then refunds that member's EN as it's landed on.
	var i := maxi(0, order.size() - 1) if not actions.is_empty() else 0
	while i < order.size():
		var member := order[i]
		_active_member = member
		focus_card(member)
		_set_actor_outline(member, OUTLINE_QUEUE_COLOR)
		if actions.has(member):
			var prev: Dictionary = actions[member]
			if prev.has("en_delta"):
				_en = clampi(_en - prev["en_delta"], 0, EN_MAX)
				_update_en()
			if prev.has("item"):
				Inventory.add(prev["item"])
			actions.erase(member)
		_refresh_turn_preview(member)
		var action := await _queue_member(member)
		if action.get("type", "pass") == "back":
			if i > 0:
				i -= 1
			continue
		actions[member] = action
		_refresh_turn_preview(member)
		i += 1
	_queueing = false
	_clear_combatant_info()
	_set_actor_outline(null)
	return actions

func _queue_member(member: Combatant) -> Dictionary:
	var mem := _memory_for(member)
	return_to_idle(member)
	while true:
		var action := await _choose(MENU.size(), _highlight_menu_item, mem.get("menu", 0))
		if action == -1:
			ui.reset_menu_opacity()
			return {"type": "back"}
		ui.dim_menu_except(action)
		mem["menu"] = action
		match action:
			0:  # FIGHT
				var idx := await _choose_enemy(mem.get("enemy", 0))
				if idx == -1:
					continue
				mem["enemy"] = idx
				member.on_queue_attack(self)
				return {"type": "fight", "target": enemies[idx]}
			1:  # ABILITY
				if member.abilities.is_empty():
					set_message(tr("* You have no abilities."))
					await _wait_confirm()
					set_message(_flavour)
					continue
				var ability_idx := await _choose(member.abilities.size(), _highlight_ability, mem.get("ability", 0))
				if ability_idx == -1:
					_preview_en(0)
					continue
				mem["ability"] = ability_idx
				var ability: Ability = member.abilities[ability_idx]
				if not ability.affordable(member, _en):
					_preview_en(0)
					set_message(tr("* Not enough HP.") if ability.hp_cost_ratio > 0.0 else tr("* Not enough EN."))
					await _wait_confirm()
					set_message(_flavour)
					continue
				var target: Combatant
				if ability.targets_all:
					target = _first_living_enemy()
					if target == null:
						_preview_en(0)
						continue
				elif ability.targets_self:
					target = member
				elif ability.targets_allies:
					var ally_idx := await _choose_ally(mem.get("ally", 0))
					if ally_idx == -1:
						_preview_en(0)
						continue
					mem["ally"] = ally_idx
					target = _ally_choices[ally_idx]
				else:
					var target_idx := await _choose_enemy(mem.get("enemy", 0))
					if target_idx == -1:
						_preview_en(0)
						continue
					mem["enemy"] = target_idx
					target = enemies[target_idx]
				var before_en := _en
				_preview_en(0)
				_en = clampi(_en - ability.en_cost, 0, EN_MAX)
				_update_en()
				ability.on_queue(self, member)
				return {"type": "ability", "target": target, "ability": ability, "en_delta": _en - before_en}
			2:  # ITEM
				_item_choices = Inventory.entries()
				if _item_choices.is_empty():
					set_message(tr("* You have no items."))
					await _wait_confirm()
					set_message(_flavour)
					continue
				var item_idx := await _choose(_item_choices.size(), _highlight_item, mem.get("item", 0))
				if item_idx == -1:
					_preview_en(0)
					continue
				mem["item"] = item_idx
				var item: Item = _item_choices[item_idx]
				var item_target: Combatant = member
				if item.targets_allies:
					var item_ally_idx := await _choose_ally(mem.get("ally", 0))
					if item_ally_idx == -1:
						_preview_en(0)
						continue
					mem["ally"] = item_ally_idx
					item_target = _ally_choices[item_ally_idx]
				_preview_en(0)
				Inventory.remove(item)
				item.on_queue(self, member)
				return {"type": "item", "target": item_target, "item": item}
			3:  # TURN
				var sub := await _turn_menu(mem.get("turn", 0))
				_preview_en(0)
				if sub >= 0:
					mem["turn"] = sub
				if sub == 0:  # Pass Turn
					var before_en := _en
					gain_en(EN_PASS_GAIN)
					return {"type": "pass", "en_delta": _en - before_en}
				elif sub == 1:  # Change Order
					await _change_order()
			4:  # CHECK
				await _check_enemies(mem)
			_:
				pass
	return {"type": "pass"}

func _execute_queued(member: Combatant, action: Dictionary) -> void:
	focus_card(member)
	match action.get("type", "pass"):
		"fight":
			var target: Combatant = action["target"]
			if not is_instance_valid(target) or not target.is_alive():
				target = _first_living_enemy()
			if target == null:
				return
			_pending_fight_en = EN_FIGHT_GAIN + EN_LINK_BONUS * (_link + _link_boost)
			await member.attack(self, target)
			_pending_fight_en = 0
			_link += 1
		"ability":
			var ability: Ability = action["ability"]
			var target: Combatant = action["target"]
			if not is_instance_valid(target) or not target.is_alive():
				target = member if ability.targets_allies or ability.targets_self else _first_living_enemy()
			if target == null:
				return
			await ability.use_in_battle(self, member, target)
			_link += 1
		"item":
			var item: Item = action["item"]
			var target: Combatant = action["target"]
			if not is_instance_valid(target) or not target.is_alive():
				target = member
			await item.use_in_battle(self, member, target)
			_link += 1
		_:  # pass / wait the round out
			set_message(tr("* %s holds their turn.") % member.combatant_name)
			await get_tree().create_timer(0.5).timeout

func _set_actor_outline(combatant: Combatant, color: Color = Color.WHITE) -> void:
	if is_instance_valid(_actor_outlined) and _actor_outlined != combatant:
		_actor_outlined.clear_outline()
	_actor_outlined = combatant
	_actor_outline_color = color
	if is_instance_valid(combatant):
		combatant.set_outline(color)

func _set_target_outline(combatant: Combatant, color: Color = OUTLINE_TARGET_COLOR) -> void:
	if is_instance_valid(_target_outlined) and _target_outlined != combatant:
		if _target_outlined == _actor_outlined:
			_target_outlined.set_outline(_actor_outline_color)
		else:
			_target_outlined.clear_outline()
	_target_outlined = combatant
	if is_instance_valid(combatant):
		combatant.set_outline(color)

func _flash_actor_outline(combatant: Combatant, color: Color, duration: float) -> void:
	_set_actor_outline(combatant, color)
	if is_instance_valid(combatant):
		combatant.fade_outline(duration)
	_actor_outlined = null

func _clear_outlines() -> void:
	_set_actor_outline(null)
	_set_target_outline(null)
	for combatant: Combatant in party + enemies:
		if is_instance_valid(combatant):
			combatant.clear_outline()

func _first_living_enemy() -> Combatant:
	for e: Combatant in enemies:
		if is_instance_valid(e) and e.is_alive():
			return e
	return null

# --- Turn order -------------------------------------------------------------

func _build_turn_order() -> Array[Combatant]:
	var combatants: Array[Combatant] = []
	for m: Combatant in party:
		if is_instance_valid(m) and m.is_alive():
			combatants.append(m)
	for e: Combatant in enemies:
		if is_instance_valid(e) and e.is_alive():
			combatants.append(e)
	combatants.sort_custom(_compare_turn)
	return combatants

func _compare_turn(a: Combatant, b: Combatant) -> bool:
	if a.stats.effective_agility() != b.stats.effective_agility():
		return a.stats.effective_agility() > b.stats.effective_agility()
	var a_ally := party.has(a)
	var b_ally := party.has(b)
	if a_ally != b_ally:
		return a_ally
	return _side_index(a) < _side_index(b)

func _side_index(c: Combatant) -> int:
	if party.has(c):
		return party.find(c)
	return enemies.find(c)

# --- Enemy intent -----------------------------------------------------------

func _plan_enemy_turns() -> void:
	_enemy_plans.clear()
	for e: Combatant in enemies:
		if is_instance_valid(e) and e.is_alive():
			_enemy_plans[e] = (e as Enemy).plan_turn(self)

func _plan_label(enemy: Combatant) -> String:
	if not _enemy_plans.has(enemy):
		return "-"
	return (enemy as Enemy).plan_move_name(_enemy_plans[enemy])

func _plan_target(enemy: Combatant) -> Combatant:
	if not _enemy_plans.has(enemy):
		return null
	return (_enemy_plans[enemy] as Dictionary).get("target", null)

# --- Turn order preview / reorder -------------------------------------------

func _refresh_turn_preview(highlight: Combatant = null) -> void:
	if not is_instance_valid(ui):
		return
	_preview_highlight = highlight
	ui.turn_track.show_order(_turn_order, party, highlight, _link_bonus_map())

func _link_bonus_map() -> Dictionary:
	var bonus: Dictionary = {}
	for target: Combatant in _cache_hits:
		bonus[target] = int(bonus.get(target, 0)) + 1
	for member: Combatant in _queued_actions:
		var action: Dictionary = _queued_actions[member]
		if action.get("type", "") != "ability":
			continue
		var ability: Ability = action.get("ability")
		if not is_instance_valid(ability) or ability.link_bonus <= 0:
			continue
		var target: Combatant = action.get("target")
		if not is_instance_valid(target) or not target.is_alive():
			continue
		if _turn_order.find(target) <= _turn_order.find(member):
			continue
		bonus[target] = int(bonus.get(target, 0)) + ability.link_bonus
	return bonus

func _mark_turn_taken(combatant: Combatant) -> void:
	if not is_instance_valid(combatant):
		return
	if not _turn_acted.has(combatant):
		_turn_acted.append(combatant)
	ui.turn_track.mark_taken(combatant)

func _mark_turn_broken(combatant: Combatant) -> void:
	ui.turn_track.mark_broken(combatant)

func _change_order() -> void:
	if _turn_order.size() <= 1:
		return
	var snapshot := _turn_order.duplicate()
	_reordering = true
	ui.set_caret_rotated(true)
	_refresh_reorder_preview()
	var confirmed: bool = await _reorder_done
	_reordering = false
	_clear_combatant_info()
	ui.set_caret_rotated(false)
	ui.hide_caret()
	if not confirmed:
		_turn_order = snapshot
	_refresh_turn_preview(_active_member)

func _on_turn_sorted() -> void:
	if _reordering:
		ui.point_caret_at_turn(_active_member)

func _refresh_reorder_preview() -> void:
	_refresh_turn_preview(_active_member)
	_show_combatant_info()

func _field_corner(combatant: Combatant) -> Vector2:
	var corner := combatant.global_position
	if is_instance_valid(combatant.sprite):
		var rect := combatant.sprite.get_rect()
		corner += combatant.sprite.position + Vector2(rect.end.x, rect.position.y)
	return corner

func _show_combatant_info() -> void:
	_clear_combatant_info()
	for i: int in range(_turn_order.size()):
		var combatant := _turn_order[i]
		if not is_instance_valid(combatant) or not combatant.is_alive():
			continue
		_spawn_combatant_info(combatant, i)

func _show_combatant_info_for(combatant: Combatant) -> void:
	_clear_combatant_info()
	if not is_instance_valid(combatant):
		return
	var idx := _turn_order.find(combatant)
	if idx == -1:
		return
	_spawn_combatant_info(combatant, idx)

func _spawn_combatant_info(combatant: Combatant, turn_index: int) -> void:
	var stat_order: Array = [
		CharacterStats.StatType.ATTACK,
		CharacterStats.StatType.DEFENSE,
		CharacterStats.StatType.AGILITY,
	]
	var buff_node_names := ["Buff", "Buff2", "Buff3"]
	var info: HBoxContainer = COMBATANT_INFO.instantiate()
	var number: Label = info.get_node("TurnNumber")
	number.text = str(turn_index + 1)
	for j: int in range(stat_order.size()):
		var rect: TextureRect = info.get_node(buff_node_names[j])
		var stage := combatant.stats.get_stage(stat_order[j])
		if stage == 0:
			rect.visible = false
			continue
		var tier := clampi(absi(stage), 1, CharacterStats.STAGE_MAX) - 1
		rect.texture = BUFF_STAGE_TEX[tier]
		rect.flip_v = stage < 0
		rect.modulate = STAGE_CHEVRON_COLORS[stat_order[j]]
	info.z_index = 100
	add_child(info)
	info.global_position = _field_corner(combatant) - Vector2(6.0, 0.0)
	_combatant_infos.append(info)

func _clear_combatant_info() -> void:
	for info: HBoxContainer in _combatant_infos:
		if is_instance_valid(info):
			info.queue_free()
	_combatant_infos.clear()

func _confirm_actions(actions: Dictionary) -> bool:
	var rows: Array[Combatant] = []
	for c: Combatant in _turn_order:
		if is_instance_valid(c) and c.is_alive():
			rows.append(c)
	if rows.is_empty():
		return true
	var idx := await _choose(rows.size(), _highlight_confirm.bind(rows, actions))
	_set_target_outline(null)
	set_message(_flavour)
	return idx != -1

func _highlight_confirm(idx: int, rows: Array[Combatant], actions: Dictionary) -> void:
	var hovered := rows[idx]
	_set_target_outline(hovered, OUTLINE_QUEUE_COLOR if party.has(hovered) else OUTLINE_TARGET_COLOR)
	var lines: Array[String] = []
	var labels: Array[Dictionary] = []
	for c: Combatant in rows:
		lines.append("   %s" % c.combatant_name)
		if party.has(c):
			labels.append({"text": _action_label(actions.get(c, {})), "dim": false})
		else:
			labels.append({"text": _plan_label(c), "dim": true})
	var footer := tr("%s: begin   %s: cancel") % [Settings.key_name("interact"), Settings.key_name("cancel")]
	ui.show_list(lines, idx, [], labels, "ACTION", footer, 9)

func _action_label(action: Dictionary) -> String:
	match action.get("type", "pass"):
		"fight":
			return tr("Fight")
		"ability":
			return (action["ability"] as Ability).name.capitalize()
		"item":
			return (action["item"] as Item).name.capitalize()
		_:
			return tr("Pass")

func _turn_menu(start := 0) -> int:
	return await _choose(2, _highlight_turn, start)

func _victory() -> void:
	ui.hide_turn_caret()
	set_message(tr("* You won!"))
	await _wait_confirm()
	await BattleManager.cleanup(true)
	if is_instance_valid(cora) and cora is Cora:
		(cora as Cora).finish_battle()

func _defeat() -> void:
	ui.hide_turn_caret()
	set_message(tr("* You lost..."))
	await get_tree().create_timer(1.0).timeout
	await BattleManager.cleanup(false)

# --- Combat services ----------------------------------------------------------

func compute_damage(attacker: Combatant, defender: Combatant) -> int:
	return maxi(1, attacker.stats.effective_attack() - defender.stats.effective_defense())

func return_to_idle(combatant: Combatant) -> void:
	if is_instance_valid(combatant):
		_play_first(combatant.animation_player, ["idle_battle", "idle"])

func apply_damage(attacker: Combatant, defender: Combatant, damage_override: int = -1, silent := false) -> bool:
	var damage := compute_damage(attacker, defender) if damage_override < 0 else damage_override
	var factor := 1.0
	if _link + _link_boost > 0:
		factor *= 1.0 + LINK_STEP * (_link + _link_boost)
	var armed: Dictionary = _damage_mults.get(attacker, {})
	if armed.get("armed", false):
		factor *= float(armed["mult"])
		_mult_spent = true
	if factor != 1.0:
		damage = maxi(1, int(damage * factor))
	last_damage = damage
	last_factor = factor
	focus_card(defender)
	defender.stats.health -= damage
	defender.knockback()
	ui.refresh_card()
	if _pending_fight_en > 0 and party.has(attacker):
		gain_en(_pending_fight_en)
		_pending_fight_en = 0
	var killed := not defender.is_alive()
	last_ko = defender.ko_message() if killed else ""
	if not silent:
		set_message(tr("* %s took %d damage!") % [defender.combatant_name, damage] + damage_suffix() + ko_suffix())
	if killed and _turn_order.has(defender) and not _turn_acted.has(defender):
		_mark_turn_broken(defender)
	return killed

func damage_suffix() -> String:
	return "" if last_factor == 1.0 else " (x%.2f)" % last_factor

func ko_suffix() -> String:
	return "" if last_ko == "" else "\n" + last_ko

func pay_hp_cost(user: Combatant, amount: int) -> void:
	if amount <= 0 or not is_instance_valid(user):
		return
	focus_card(user)
	user.stats.health -= amount
	ui.refresh_card()
	set_message(tr("* %s spends %d HP!") % [user.combatant_name, amount])
	await get_tree().create_timer(0.5).timeout

func queue_damage_multiplier(user: Combatant, mult: float) -> void:
	if not is_instance_valid(user):
		return
	_damage_mults[user] = {"mult": mult, "armed": false}

func _settle_damage_mult(combatant: Combatant) -> void:
	if not _damage_mults.has(combatant):
		return
	if _mult_spent:
		_damage_mults.erase(combatant)
	else:
		(_damage_mults[combatant] as Dictionary)["armed"] = true

func apply_heal(target: Combatant, amount: int) -> void:
	if not is_instance_valid(target):
		return
	focus_card(target)
	await spawn_hit_effect("heal", target)
	target.stats.health += amount
	ui.refresh_card()
	set_message(tr("* %s recovered %d HP!") % [target.combatant_name, amount])

func apply_stage(target: Combatant, stat: CharacterStats.StatType, delta: int) -> void:
	if not is_instance_valid(target):
		return
	var before := target.stats.get_stage(stat)
	var after := target.stats.modify_stage(stat, delta)
	var stat_name: String = STAGE_STAT_NAMES[stat]
	var subs := {"name": target.combatant_name, "stat": tr(stat_name)}
	if after == before:
		var tmpl := "* {name}'s {stat} won't go any higher!" if delta > 0 else "* {name}'s {stat} won't go any lower!"
		set_message(tr(tmpl).format(subs))
	else:
		await spawn_hit_effect("buff" if delta > 0 else "debuff", target, STAGE_CHEVRON_COLORS[stat])
		var msg := tr("* {name}'s {stat} rose!" if delta > 0 else "* {name}'s {stat} fell!").format(subs)
		if stat == CharacterStats.StatType.AGILITY:
			msg += " " + tr("It applies next round.")
		set_message(msg)

func queue_cache_hit(target: Combatant) -> void:
	if not is_instance_valid(target):
		return
	_cache_hits.append(target)
	set_message(tr("* %s's next Link runs a step deeper!") % target.combatant_name)

func spawn_hit_effect(hit_type: String, target: Combatant, tint: Color = Color.WHITE) -> void:
	if hit_type == "" or not is_instance_valid(target):
		return
	var fx: HitEffect = HIT_EFFECT.instantiate()
	fx.z_index = 100
	fx.modulate = tint
	add_child(fx)
	await fx.play_hit_effect(hit_type, target)
	fx.queue_free()

func play_and_wait(ap: AnimationPlayer, anim: String, fallback: float) -> void:
	await play_and_wait_first(ap, [anim], fallback)

func play_and_wait_first(ap: AnimationPlayer, candidates: Array, fallback: float) -> void:
	if not is_instance_valid(ap):
		return
	for anim: String in candidates:
		if not ap.has_animation(anim):
			continue
		var clip := ap.get_animation(anim)
		ap.play(anim)
		if clip.loop_mode == Animation.LoopMode.LOOP_NONE and clip.length > 0.0:
			await ap.animation_finished
		else:
			await get_tree().create_timer(fallback).timeout
		return

func set_message(text: String) -> void:
	if is_instance_valid(ui):
		ui.set_message(text)

func gain_en(amount: int) -> void:
	var overflow := maxi(0, _en + amount - EN_MAX)
	_en = clampi(_en + amount, 0, EN_MAX)
	_update_en()
	if overflow > 0 and is_instance_valid(ui):
		ui.spill_en(overflow)

func _update_en() -> void:
	if is_instance_valid(ui):
		ui.update_en(_en)

func _preview_en(delta: int) -> void:
	if is_instance_valid(ui):
		ui.preview_en(_en, clampi(_en + delta, 0, EN_MAX))

func focus_card(member: Combatant) -> void:
	if not is_instance_valid(ui):
		return
	if is_instance_valid(member) and party.has(member):
		ui.focus_card(member)
	ui.refresh_card()

# --- Selection ----------------------------------------------------------------

func _choose(count: int, on_change: Callable, start := 0) -> int:
	if count <= 0:
		return -1
	_select_count = count
	_select_index = start if start >= 0 and start < count else 0
	_on_change = on_change
	_selecting = true
	if _on_change.is_valid():
		_on_change.call(_select_index)
	var result: int = await _choice_made
	_selecting = false
	ui.hide_caret()
	return result

func _wait_confirm() -> void:
	ui.hide_caret()
	_select_count = 1
	_on_change = Callable()
	_selecting = true
	await _choice_made
	_selecting = false

func _choose_enemy(start := 0) -> int:
	if enemies.is_empty():
		return -1
	var idx := await _choose(enemies.size(), _highlight_enemy, start)
	_set_target_outline(null)
	_clear_combatant_info()
	ui.hide_caret()
	if idx == -1:
		set_message(_flavour)
	return idx

func _choose_ally(start := 0) -> int:
	_ally_choices = living_party()
	if _ally_choices.is_empty():
		return -1
	var idx := await _choose(_ally_choices.size(), _highlight_ally, start)
	_set_target_outline(null)
	_clear_combatant_info()
	ui.hide_caret()
	if idx == -1:
		set_message(_flavour)
	return idx

func _check_enemies(mem: Dictionary) -> void:
	var idx: int = mem.get("check", 0)
	while true:
		_check_choices = []
		for e: Combatant in enemies:
			if is_instance_valid(e) and e.is_alive():
				_check_choices.append(e)
		if _check_choices.is_empty():
			break
		idx = await _choose(_check_choices.size(), _highlight_check, clampi(idx, 0, _check_choices.size() - 1))
		if idx == -1:
			break
		mem["check"] = idx
		await _check_detail(_check_choices[idx])
	_check_choices = []
	_set_target_outline(null)
	_clear_combatant_info()
	ui.hide_caret()
	_set_actor_outline(_active_member, OUTLINE_QUEUE_COLOR)
	set_message(_flavour)

func _check_detail(enemy: Combatant) -> void:
	var plan: Dictionary = _enemy_plans.get(enemy, {})
	var plan_target: Combatant = plan.get("target", null)
	var move := (enemy as Enemy).plan_move_name(plan)
	var lines: Array[String] = []
	lines.append("   %s  %d/%d" % [enemy.combatant_name, enemy.stats.health, enemy.stats.max_health])
	lines.append("   " + tr("ATK %d   DEF %d   AGI %d") % [
		enemy.stats.effective_attack(),
		enemy.stats.effective_defense(),
		enemy.stats.effective_agility(),
	])
	if is_instance_valid(plan_target):
		lines.append("   %s: %s > %s" % [tr("Plan"), move, plan_target.combatant_name])
	else:
		lines.append("   %s: %s" % [tr("Plan"), move])
	lines.append("   %s" % tr("Moves"))
	for move_name: String in (enemy as Enemy).move_names():
		lines.append("     %s" % move_name)
	var footer := tr("%s: back") % Settings.key_name("cancel")
	ui.hide_caret()
	await _choose(lines.size(), func(i: int) -> void: ui.show_list(lines, i, [], [], "", footer, 9))
	ui.hide_caret()

func _move_selection(dir: int) -> void:
	_select_index = (_select_index + dir + _select_count) % _select_count
	if _on_change.is_valid():
		_on_change.call(_select_index)

func _process(delta: float) -> void:
	if not _selecting or _select_count <= 1:
		_nav_hold = 0.0
		return
	var dir := 0
	if Input.is_action_pressed("up"):
		dir = -1
	elif Input.is_action_pressed("down"):
		dir = 1
	if dir == 0:
		_nav_hold = 0.0
		return
	_nav_hold += delta
	if _nav_hold < NAV_REPEAT_DELAY:
		return
	_nav_hold -= NAV_REPEAT_RATE
	_move_selection(dir)

func _unhandled_input(event: InputEvent) -> void:
	if _reordering:
		var idx := _turn_order.find(_active_member)
		if event.is_action_pressed("right") and idx >= 0 and idx < _turn_order.size() - 1:
			_turn_order[idx] = _turn_order[idx + 1]
			_turn_order[idx + 1] = _active_member
			_refresh_reorder_preview()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("left") and idx > 0:
			var earlier := _turn_order[idx - 1]
			if not (enemies.has(earlier) and earlier.stats.effective_agility() > _active_member.stats.effective_agility()):
				_turn_order[idx] = earlier
				_turn_order[idx - 1] = _active_member
				_refresh_reorder_preview()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			_reorder_done.emit(true)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("cancel"):
			_reorder_done.emit(false)
			get_viewport().set_input_as_handled()
		return
	if _queueing:
		if event.is_action_pressed("show_turn_order"):
			_show_combatant_info()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_released("show_turn_order"):
			_clear_combatant_info()
			if _selecting and _on_change.is_valid():
				_on_change.call(_select_index)
			get_viewport().set_input_as_handled()
			return
	if not _selecting:
		return
	if event.is_action_pressed("up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_choice_made.emit(_select_index)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		_choice_made.emit(-1)
		get_viewport().set_input_as_handled()

# --- Menu highlights ----------------------------------------------------------

func _highlight_menu_item(idx: int) -> void:
	ui.highlight_menu(idx)
	set_message(_flavour)

func _highlight_turn(idx: int) -> void:
	var lines: Array[String] = ["   %s" % tr("Pass Turn"), "   %s" % tr("Change Order")]
	_preview_en(EN_PASS_GAIN if idx == 0 else 0)
	ui.show_list(lines, idx)

func _highlight_ability(idx: int) -> void:
	var abilities := _active_member.abilities
	var lines: Array[String] = []
	var costs: Array[Dictionary] = []
	var hp_costed := 0
	for ability: Ability in abilities:
		if ability.hp_cost_ratio > 0.0:
			hp_costed += 1
	for i in range(abilities.size()):
		var line := "   %s" % abilities[i].name.capitalize()
		var dim: bool = not abilities[i].affordable(_active_member, _en)
		if dim:
			line = "[color=#777777]%s[/color]" % line
		lines.append(line)
		costs.append({"text": abilities[i].cost_label(_active_member), "dim": dim})
	var legend := "EN"
	if hp_costed == abilities.size():
		legend = "HP"
	elif hp_costed > 0:
		legend = "COST"
	var hovered := abilities[idx]
	_preview_en(-hovered.en_cost if hovered.hp_cost_ratio <= 0.0 and hovered.en_cost <= _en else 0)
	ui.show_list(lines, idx, [], costs, legend)

func _highlight_item(idx: int) -> void:
	var lines: Array[String] = []
	var counts: Array[Dictionary] = []
	for it: Item in _item_choices:
		lines.append("   %s" % it.name.capitalize())
		counts.append({"text": "x%d" % Inventory.count(it), "dim": false})
	_preview_en(_item_choices[idx].en_restore)
	ui.show_list(lines, idx, [], counts, "")

func _highlight_enemy(idx: int) -> void:
	_set_target_outline(enemies[idx])
	_show_combatant_info_for(enemies[idx])
	var lines: Array[String] = []
	for e: Combatant in enemies:
		lines.append("   %s" % e.combatant_name)
	ui.show_list(lines, idx, enemies)

func _highlight_check(idx: int) -> void:
	var enemy := _check_choices[idx]
	_set_target_outline(enemy)
	_set_actor_outline(_plan_target(enemy), OUTLINE_ALLY_TARGET_COLOR)
	_show_combatant_info_for(enemy)
	var lines: Array[String] = []
	var labels: Array[Dictionary] = []
	for e: Combatant in _check_choices:
		lines.append("   %s" % e.combatant_name)
		labels.append({"text": _plan_label(e), "dim": false})
	var footer := tr("%s: inspect   %s: back") % [Settings.key_name("interact"), Settings.key_name("cancel")]
	ui.show_list(lines, idx, [], labels, "PLAN", footer, 5)

func _highlight_ally(idx: int) -> void:
	_set_target_outline(_ally_choices[idx], OUTLINE_ALLY_TARGET_COLOR)
	_show_combatant_info_for(_ally_choices[idx])
	var lines: Array[String] = []
	for a: Combatant in _ally_choices:
		lines.append("   %s" % a.combatant_name)
	ui.show_list(lines, idx, _ally_choices)

# --- Field entrances ----------------------------------------------------------

func _slide_in_combatants(battle_enemies: Array[Combatant]) -> void:
	var tween := get_tree().create_tween().set_parallel(true)
	var ally_pos := _marker_pos("Ally1")

	var party_layout: Array = SLOT_LAYOUTS.get(clampi(party.size(), 1, 5), [1, 2, 3, 4, 5])
	for i in range(party.size()):
		var member := party[i]
		if not is_instance_valid(member):
			continue
		var member_marker: int = party_layout[i] if i < party_layout.size() else (i + 1)
		member.z_index = 1
		member.sprite.flip_h = false
		_play_first(member.animation_player, ["idle_battle", "idle_battle_right", "idle"])
		tween.tween_property(member, "global_position", _marker_pos("Ally%d" % member_marker), 0.75) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var layout: Array = SLOT_LAYOUTS.get(clampi(battle_enemies.size(), 1, 5), [1, 2, 3, 4, 5])
	for i in range(battle_enemies.size()):
		var enemy := battle_enemies[i]
		if not is_instance_valid(enemy):
			continue
		var marker_index: int = layout[i] if i < layout.size() else (i + 1)
		var target := _marker_pos("Enemy%d" % marker_index)
		enemy.z_index = 69
		enemy.sprite.flip_h = target.x > ally_pos.x
		_play_first(enemy.animation_player, ["idle"])
		tween.tween_property(enemy, "global_position", target, 0.75) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished

func _marker_pos(marker_name: String) -> Vector2:
	var marker := get_node_or_null(NodePath(marker_name)) as Marker2D
	if is_instance_valid(marker):
		return marker.global_position
	return get_viewport_rect().size * 0.5

func _play_first(ap: AnimationPlayer, candidates: Array) -> void:
	if not is_instance_valid(ap):
		return
	for anim: String in candidates:
		if ap.has_animation(anim):
			ap.play(anim)
			return
