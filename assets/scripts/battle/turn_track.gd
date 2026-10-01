extends HBoxContainer
class_name TurnTrack

const LINK_PANEL := preload("res://assets/scenes/link_panel.tscn")
const LINK_PANEL_ENEMY_TEX := preload("res://assets/sprites/ui/battle/link_panel_enemy.png")
const LINK_MARGIN := 2.0
const ALLY_TEX := preload("res://assets/sprites/ui/battle/turn_ally.png")
const ENEMY_TEX := preload("res://assets/sprites/ui/battle/turn_enemy.png")
const SELECT_TEX := preload("res://assets/sprites/ui/battle/turn_select.png")
const ALLY_BROKEN_TEX := preload("res://assets/sprites/ui/battle/turn_ally_broken.png")
const ENEMY_BROKEN_TEX := preload("res://assets/sprites/ui/battle/turn_enemy_broken.png")
const ALLY_LINK_TEX: Array[Texture2D] = [
	preload("res://assets/sprites/ui/battle/turn_ally_link_1.png"),
	preload("res://assets/sprites/ui/battle/turn_ally_link_2.png"),
	preload("res://assets/sprites/ui/battle/turn_ally_link_3.png"),
	preload("res://assets/sprites/ui/battle/turn_ally_link_4.png"),
	preload("res://assets/sprites/ui/battle/turn_ally_link_5.png"),
]
const ALLY_LINK_SELECT_TEX: Array[Texture2D] = [
	preload("res://assets/sprites/ui/battle/turn_ally_link_select_1.png"),
	preload("res://assets/sprites/ui/battle/turn_ally_link_select_2.png"),
	preload("res://assets/sprites/ui/battle/turn_ally_link_select_3.png"),
	preload("res://assets/sprites/ui/battle/turn_ally_link_select_4.png"),
	preload("res://assets/sprites/ui/battle/turn_ally_link_select_5.png"),
]
const ENEMY_LINK_TEX: Array[Texture2D] = [
	preload("res://assets/sprites/ui/battle/turn_enemy_link_1.png"),
	preload("res://assets/sprites/ui/battle/turn_enemy_link_2.png"),
	preload("res://assets/sprites/ui/battle/turn_enemy_link_3.png"),
	preload("res://assets/sprites/ui/battle/turn_enemy_link_4.png"),
	preload("res://assets/sprites/ui/battle/turn_enemy_link_5.png"),
]

var panel_parent: Node
var _order: Array[Combatant] = []
var _allies: Array[Combatant] = []
var _highlight: Combatant
var _icons: Array[TextureRect] = []
var _panels: Array[NinePatchRect] = []
var _link_bonus: Dictionary = {}

func _ready() -> void:
	sort_children.connect(rebuild_links)

func show_order(order: Array[Combatant], allies: Array[Combatant], highlight: Combatant = null, link_bonus: Dictionary = {}) -> void:
	_order = order
	_allies = allies
	_highlight = highlight
	_link_bonus = link_bonus
	for icon: TextureRect in _icons:
		if is_instance_valid(icon):
			remove_child(icon)
			icon.queue_free()
	_icons.clear()
	for combatant: Combatant in _order:
		var tex := _base_tex(combatant)
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = tex.get_size()
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.z_index = 1
		add_child(icon)
		_icons.append(icon)

func mark_taken(combatant: Combatant) -> void:
	var idx := _order.find(combatant)
	if idx >= 0 and idx < _icons.size() and is_instance_valid(_icons[idx]):
		_icons[idx].modulate.a = 0.25

func mark_broken(combatant: Combatant) -> void:
	var idx := _order.find(combatant)
	if idx >= 0 and idx < _icons.size() and is_instance_valid(_icons[idx]):
		_icons[idx].texture = ALLY_BROKEN_TEX if _allies.has(combatant) else ENEMY_BROKEN_TEX
		_icons[idx].modulate.a = 0.25
	rebuild_links()

func icon_rect(combatant: Combatant) -> Rect2:
	var idx := _order.find(combatant)
	if idx < 0 or idx >= _icons.size() or not is_instance_valid(_icons[idx]):
		return Rect2()
	return Rect2(_icons[idx].global_position, _icons[idx].size)

func rebuild_links() -> void:
	for link: NinePatchRect in _panels:
		if is_instance_valid(link):
			link.queue_free()
	_panels.clear()
	var n := mini(_order.size(), _icons.size())
	for k: int in range(n):
		if is_instance_valid(_icons[k]):
			_icons[k].texture = _base_tex(_order[k])
	var i := 0
	while i < n:
		if not is_instance_valid(_icons[i]) or _link_broken(i):
			i += 1
			continue
		var side := _allies.has(_order[i])
		var j := i
		while j + 1 < n and is_instance_valid(_icons[j + 1]) and not _link_broken(j + 1) and _allies.has(_order[j + 1]) == side:
			j += 1
		if j > i:
			_spawn_link_panel(_icons[i], _icons[j], side)
		for k: int in range(i, j + 1):
			_apply_link_tex(k, side, k - i + int(_link_bonus.get(_order[k], 0)))
		i = j + 1

func _base_tex(combatant: Combatant) -> Texture2D:
	if not is_instance_valid(combatant) or not combatant.is_alive():
		return ALLY_BROKEN_TEX if _allies.has(combatant) else ENEMY_BROKEN_TEX
	if combatant == _highlight:
		return SELECT_TEX
	return ALLY_TEX if _allies.has(combatant) else ENEMY_TEX

func _apply_link_tex(k: int, is_ally: bool, depth: int) -> void:
	if depth <= 0:
		return
	var d := clampi(depth - 1, 0, 4)
	if is_ally and _order[k] == _highlight:
		_icons[k].texture = ALLY_LINK_SELECT_TEX[d]
	elif is_ally:
		_icons[k].texture = ALLY_LINK_TEX[d]
	else:
		_icons[k].texture = ENEMY_LINK_TEX[d]

func _link_broken(i: int) -> bool:
	var c := _order[i]
	return not is_instance_valid(c) or not c.is_alive()

func _spawn_link_panel(first: TextureRect, last: TextureRect, is_ally: bool) -> void:
	if not is_instance_valid(panel_parent):
		return
	var left := first.global_position.x - LINK_MARGIN
	var top := first.global_position.y - LINK_MARGIN
	var right := last.global_position.x + last.size.x + LINK_MARGIN
	var panel: NinePatchRect = LINK_PANEL.instantiate()
	panel.position = Vector2(left, top)
	panel.size = Vector2(right - left, first.size.y + LINK_MARGIN * 2.0)
	if not is_ally:
		panel.texture = LINK_PANEL_ENEMY_TEX
	panel_parent.add_child(panel)
	_panels.append(panel)
