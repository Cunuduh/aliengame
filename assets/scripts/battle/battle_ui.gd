extends CanvasLayer
class_name BattleUI

const HEALTH_BAR := preload("res://assets/scenes/health_bar.tscn")
const MEMBER_CARD := preload("res://assets/scenes/member_card.tscn")
const MENU_TEX: Array[Texture2D] = [
	preload("res://assets/sprites/ui/battle/party/fight_button.png"),
	preload("res://assets/sprites/ui/battle/party/ability_button.png"),
	preload("res://assets/sprites/ui/battle/party/item_button.png"),
	preload("res://assets/sprites/ui/battle/party/turn_button.png"),
	preload("res://assets/sprites/ui/battle/party/check_button.png"),
]
const MENU_TEX_SELECT: Array[Texture2D] = [
	preload("res://assets/sprites/ui/battle/party/fight_button_select.png"),
	preload("res://assets/sprites/ui/battle/party/ability_button_select.png"),
	preload("res://assets/sprites/ui/battle/party/item_button_select.png"),
	preload("res://assets/sprites/ui/battle/party/turn_button_select.png"),
	preload("res://assets/sprites/ui/battle/party/check_button_select.png"),
]
const MENU_NODES := ["ATTK", "ABIL", "ITEM", "TURN", "CHEK"]

@onready var turn_track: TurnTrack = $TurnOrderContainer
@onready var _menu: VBoxContainer = $ActionContainer
@onready var _message: RichTextLabel = $TextBox/MarginContainer/Text
@onready var _hp_legend: Label = $TextBox/HPLabel
@onready var _scroll_down: TextureRect = $TextBox/ScrollDown
@onready var _card_container: HBoxContainer = $CardContainer
@onready var _en_label: Label = $EnergyValue
@onready var _en_max_label: Label = $EnergyMax
@onready var _en_bar: TextureProgressBar = $EnergyBar
@onready var _en_ghost_bar: TextureProgressBar = $EnergyBarGhost
@onready var _ui_caret: Sprite2D = $UICaret
@onready var _turn_caret: Sprite2D = $TurnCaret
@onready var _en_spills: Array[GPUParticles2D] = [$EnSpill, $EnSpill2, $EnSpill3]

var _menu_buttons: Array[TextureRect] = []
var _cards: Array[MemberCard] = []
var _en_tween: Tween
var _en_pulse: Tween
var _en_ghost_tint := Color.WHITE
var _en_ghost_edge: Control
var _list_bars: Array[TextureProgressBar] = []
var _list_costs: Array[Label] = []
var _ui_slides: Array[Dictionary] = []
var _spill_index := 0

func _ready() -> void:
	for node_name: String in MENU_NODES:
		_menu_buttons.append(get_node("ActionContainer/" + node_name))
	_message.bbcode_enabled = true
	_hp_legend.visible = false
	_scroll_down.visible = false
	_en_ghost_tint = _en_ghost_bar.tint_progress
	MemberCard.add_bar_edge(_en_bar)
	_en_ghost_edge = MemberCard.add_bar_edge(_en_ghost_bar)
	turn_track.panel_parent = self
	_register_slide($UIBackground, Vector2(0, 240))
	_register_slide($E, Vector2(-240, 0))
	_register_slide($N, Vector2(-240, 0))
	_register_slide(_en_label, Vector2(-240, 0))
	_register_slide($SeparatorBar, Vector2(-240, 0))
	_register_slide(_en_max_label, Vector2(-240, 0))
	_register_slide(_en_bar, Vector2(-240, 0))
	_register_slide(_en_ghost_bar, Vector2(-240, 0))
	_register_slide(_menu, Vector2(-240, 0))
	_register_slide($TURN, Vector2(0, -120))
	_register_slide(turn_track, Vector2(0, -120))
	_register_slide(_card_container, Vector2(280, 0))
	_register_slide($TextBox, Vector2(280, 0))

func setup(members: Array[Combatant], en_max: int, en: int) -> void:
	for member: Combatant in members:
		var card: MemberCard = MEMBER_CARD.instantiate()
		_card_container.add_child(card)
		card.setup(member)
		_cards.append(card)
	_en_max_label.text = str(en_max)
	_en_bar.max_value = en_max
	_en_bar.value = en
	_en_ghost_bar.max_value = en_max
	_en_ghost_bar.value = en

func _process(_delta: float) -> void:
	if is_instance_valid(_en_ghost_edge) and is_instance_valid(_en_ghost_bar):
		_en_ghost_edge.modulate.a = _en_ghost_bar.tint_progress.a

func set_message(text: String) -> void:
	if is_instance_valid(_message):
		_message.text = text

# --- Action menu --------------------------------------------------------------

func show_menu() -> void:
	_menu.visible = true

func hide_menu() -> void:
	_menu.visible = false
	reset_menu_opacity()

func reset_menu_opacity() -> void:
	for b: TextureRect in _menu_buttons:
		b.modulate.a = 1.0

func dim_menu_except(idx: int) -> void:
	for i in range(_menu_buttons.size()):
		_menu_buttons[i].modulate.a = 1.0 if i == idx else 0.25

func highlight_menu(idx: int) -> void:
	show_menu()
	for i in range(_menu_buttons.size()):
		_menu_buttons[i].texture = MENU_TEX_SELECT[i] if i == idx else MENU_TEX[i]
		_menu_buttons[i].modulate.a = 1.0
	_caret_at_control(_menu_buttons[idx])

# --- Scrolling list -----------------------------------------------------------

func show_list(lines: Array[String], idx: int, combatants: Array[Combatant] = [], costs: Array[Dictionary] = [], cost_legend := "EN", footer := "", cost_margin_chars := 7) -> void:
	var visible := _visible_list_lines()
	var offset := 1 if (not combatants.is_empty() or (not costs.is_empty() and not cost_legend.is_empty())) else 0
	visible = maxi(1, visible - offset - (1 if not footer.is_empty() else 0))
	var first := clampi(idx - (visible - 1), 0, maxi(0, lines.size() - visible))
	var last := mini(first + visible, lines.size())
	var txt := "\n".repeat(offset)
	for i: int in range(first, last):
		txt += lines[i] + "\n"
	if not footer.is_empty():
		txt += "\n".repeat(maxi(0, visible - (last - first)))
		txt += "[color=#777777]%s[/color]" % footer
	set_message(txt)
	_caret_at_line(idx - first + offset)
	if is_instance_valid(_scroll_down):
		_scroll_down.visible = last < lines.size()
	if not combatants.is_empty():
		_show_list_bars(combatants.slice(first, last))
	elif not costs.is_empty():
		_show_list_costs(costs.slice(first, last), cost_legend, offset, cost_margin_chars)

func _line_height() -> float:
	var font := _message.get_theme_font("normal_font")
	var fsize := _message.get_theme_font_size("normal_font_size")
	return font.get_height(fsize) if font else 14.0

func _visible_list_lines() -> int:
	if not is_instance_valid(_message):
		return 1
	return maxi(1, int(_message.size.y / _line_height()))

func _show_list_bars(combatants: Array[Combatant]) -> void:
	_clear_list_bars()
	if not is_instance_valid(_message):
		return
	var line_height := _line_height()
	var base := _message.global_position
	if is_instance_valid(_hp_legend):
		_hp_legend.text = tr("HP%")
		_hp_legend.visible = true
	for i in range(combatants.size()):
		var combatant := combatants[i]
		if not is_instance_valid(combatant):
			continue
		var bar: TextureProgressBar = HEALTH_BAR.instantiate()
		bar.max_value = combatant.stats.max_health
		bar.value = combatant.stats.health
		var pct: Label = bar.get_node("Percentage")
		pct.text = "%d" % roundi(100.0 * combatant.stats.health / maxf(combatant.stats.max_health, 1.0))
		bar.position = Vector2(base.x + _message.size.x - bar.size.x, base.y + (i + 1) * line_height + (line_height - bar.size.y) * 0.5)
		add_child(bar)
		_list_bars.append(bar)

func _show_list_costs(costs: Array[Dictionary], legend := "EN", row_offset := 1, margin_chars := 7) -> void:
	_clear_list_bars()
	if not is_instance_valid(_message):
		return
	var font := _message.get_theme_font("normal_font")
	var fsize := _message.get_theme_font_size("normal_font_size")
	var line_height: float = font.get_height(fsize) if font else 14.0
	var margin: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x * float(margin_chars) if font else 10.0
	var base := _message.global_position
	if is_instance_valid(_hp_legend):
		_hp_legend.text = tr(legend) if not legend.is_empty() else legend
		_hp_legend.visible = not legend.is_empty()
	for i in range(costs.size()):
		var label := Label.new()
		label.text = str(costs[i]["text"])
		if font:
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", fsize)
		if costs[i]["dim"]:
			label.modulate = Color("#777777")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(_message.size.x - margin, line_height)
		label.position = Vector2(base.x, base.y + (i + row_offset) * line_height)
		add_child(label)
		_list_costs.append(label)

func _clear_list_bars() -> void:
	for bar: TextureProgressBar in _list_bars:
		if is_instance_valid(bar):
			bar.queue_free()
	_list_bars.clear()
	for label: Label in _list_costs:
		if is_instance_valid(label):
			label.queue_free()
	_list_costs.clear()
	if is_instance_valid(_hp_legend):
		_hp_legend.visible = false

# --- Carets -------------------------------------------------------------------

func _caret_at_control(c: Control) -> void:
	if not is_instance_valid(_ui_caret) or not is_instance_valid(c):
		return
	var sz := _ui_caret.texture.get_size()
	var half_y := floorf(c.get_size().y * 0.5)
	_ui_caret.position = Vector2(c.global_position.x - sz.x * 0.5 - 4.0, c.global_position.y + half_y)
	_ui_caret.visible = true

func _caret_at_line(line: int) -> void:
	if not is_instance_valid(_ui_caret) or not is_instance_valid(_message):
		return
	var line_height := _line_height()
	var sz := _ui_caret.texture.get_size()
	var base := _message.global_position
	_ui_caret.position = Vector2(base.x + sz.x * 0.5, base.y + line * line_height + floorf(line_height * 0.5) - 1.0)
	_ui_caret.visible = true

func hide_caret() -> void:
	if is_instance_valid(_ui_caret):
		_ui_caret.visible = false
	if is_instance_valid(_scroll_down):
		_scroll_down.visible = false
	_clear_list_bars()

func set_caret_rotated(rotated: bool) -> void:
	_ui_caret.rotation = deg_to_rad(-90.0) if rotated else 0.0

func point_caret_at_turn(combatant: Combatant) -> void:
	_place_caret_at_turn(_ui_caret, combatant)

func point_turn_caret(combatant: Combatant) -> void:
	_place_caret_at_turn(_turn_caret, combatant)

func hide_turn_caret() -> void:
	if is_instance_valid(_turn_caret):
		_turn_caret.visible = false

func _place_caret_at_turn(caret: Sprite2D, combatant: Combatant) -> void:
	if not is_instance_valid(caret):
		return
	var rect := turn_track.icon_rect(combatant)
	if rect.size == Vector2.ZERO:
		return
	var sz := caret.texture.get_size()
	var center := rect.position + rect.size * 0.5
	caret.position = Vector2(center.x - 1.0, center.y + rect.size.y * 0.5 + maxf(sz.x, sz.y) * 0.5 + 2.0)
	caret.visible = true

# --- HP card ------------------------------------------------------------------

func focus_card(member: Combatant) -> void:
	if not is_instance_valid(member):
		return
	for card: MemberCard in _cards:
		card.set_focused(card.member == member)

func refresh_card() -> void:
	for card: MemberCard in _cards:
		card.refresh()

func wait_hp_tween() -> void:
	for card: MemberCard in _cards:
		await card.wait_tween()

# --- EN bar -------------------------------------------------------------------

func update_en(value: int) -> void:
	if is_instance_valid(_en_label):
		_en_label.text = str(value)
	if is_instance_valid(_en_bar) and is_instance_valid(_en_ghost_bar):
		_en_tween = MemberCard.ghost_update(_en_bar, _en_ghost_bar, float(value), _en_tween)

func spill_en(overflow: int) -> void:
	if overflow <= 0:
		return
	while _en_bar.value < _en_bar.max_value and _en_tween != null and _en_tween.is_valid() and _en_tween.is_running():
		await get_tree().process_frame
	if _en_bar.value < _en_bar.max_value:
		return
	var emitter: GPUParticles2D = null
	for candidate: GPUParticles2D in _en_spills:
		if is_instance_valid(candidate) and not candidate.emitting:
			emitter = candidate
			break
	if emitter == null:
		emitter = _en_spills[_spill_index]
		_spill_index = (_spill_index + 1) % _en_spills.size()
	if not is_instance_valid(emitter):
		return
	var strength := clampf(float(overflow) * 2.0 / maxf(_en_bar.max_value, 1.0), 0.2, 1.0)
	var mat := emitter.process_material as ParticleProcessMaterial
	mat.initial_velocity_min = 20.0 + 25.0 * strength
	mat.initial_velocity_max = 45.0 + 45.0 * strength
	emitter.amount_ratio = strength
	emitter.restart()

func preview_en(current: int, after: int) -> void:
	if not (is_instance_valid(_en_bar) and is_instance_valid(_en_ghost_bar)):
		return
	if _en_tween != null and _en_tween.is_valid():
		_en_tween.kill()
	if _en_pulse != null and _en_pulse.is_valid():
		_en_pulse.kill()
	_en_ghost_bar.tint_progress = _en_ghost_tint
	if after == current:
		_en_bar.value = current
		_en_ghost_bar.value = current
		return
	_en_bar.value = mini(after, current)
	_en_ghost_bar.value = maxi(after, current)
	_en_ghost_bar.tint_progress.a = 0.8
	_en_pulse = get_tree().create_tween().set_loops()
	_en_pulse.tween_property(_en_ghost_bar, "tint_progress:a", 0.3, 0.5)
	_en_pulse.tween_property(_en_ghost_bar, "tint_progress:a", 0.8, 0.5)

# --- Slide-in -----------------------------------------------------------------

func _register_slide(node: Control, from_offset: Vector2) -> void:
	var target: Vector2 = node.position
	node.position = target + from_offset
	_ui_slides.append({"node": node, "target": target})

func slide_in() -> void:
	var tween := get_tree().create_tween().set_parallel(true)
	for slide: Dictionary in _ui_slides:
		var node: Control = slide["node"]
		if is_instance_valid(node):
			tween.tween_property(node, "position", slide["target"], 0.25) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
