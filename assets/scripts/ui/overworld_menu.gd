extends CanvasLayer
class_name OverworldMenu

signal closed

enum Mode { TABS, CONFIG, KEYS, REBIND, ITEMS, ITEM_TARGET }

const SELECTED_COLOR := Color(1.0, 1.0, 1.0)
const TAB_SELECTED_COLOR := Color("#ffd93b")
const UNSELECTED_COLOR := Color(0.45, 0.45, 0.45)
const KEY_ACTIONS: Array[String] = ["interact", "cancel", "menu", "attack", "show_turn_order"]
const VOLUME_STEP := 0.1
const CONFIG_KEYBINDS := 0
const CONFIG_VOLUME := 1
const CONFIG_LANGUAGE := 2
const CONFIG_QUIT := 3
const LOCALE_NAMES := {"en": "ENGLISH", "fr_CA": "FRANÇAIS (CA)"}
const TAB_PARTY := 0
const TAB_ITEMS := 1
const TAB_CONFIG := 2
const SLIDE_TIME := 0.25

var _mode := Mode.TABS
var _index := 0
var _config_index := 0
var _key_index := 0
var _item_index := 0
var _target_index := 0
var _rebind_frame := 0
var _spawn_frame := 0
var _closing := false
var _menu_items: Array[Item] = []
var _members: Array[Combatant] = []

@onready var _caret: TextureRect = %Caret
@onready var _banner: Control = $Root/Banner
@onready var _content: Control = $Root/ContentPanel
@onready var _dimmer: ColorRect = %Dimmer
@onready var _panel_title: Label = %PanelTitle
@onready var _item_desc: Label = %ItemDesc
@onready var _options: Array[Label] = [%PartyOption, %ItemsOption, %ConfigOption]
@onready var _pages: Array[Control] = [%PartyPage, %ItemsPage, %ConfigPage]
@onready var _member_blocks: Array[VBoxContainer] = [%Member1, %Member2, %Member3]
@onready var _items_list: RichTextLabel = %ItemsList
@onready var _entries: VBoxContainer = %Entries
@onready var _config_hint: Label = %ConfigHint
@onready var _items_hint: Label = %ItemsHint
@onready var _party_hint: Label = %PartyHint
@onready var _keybind_panel: Control = %KeybindPanel
@onready var _config_rows: Array[HBoxContainer] = [
	%Entries.get_node("KeybindsRow"), %Entries.get_node("VolumeRow"),
	%Entries.get_node("LanguageRow"), %Entries.get_node("QuitRow"),
]
@onready var _key_rows: Array[HBoxContainer] = [
	%Rows.get_node("InteractRow"), %Rows.get_node("CancelRow"), %Rows.get_node("MenuRow"),
	%Rows.get_node("AttackRow"), %Rows.get_node("TurnOrderRow"),
]

func open() -> void:
	get_tree().paused = true
	_spawn_frame = Engine.get_process_frames()
	_refresh()
	_refresh_config_values()
	_select(0)
	_paint_config()
	_caret.visible = false
	await _slide_in()
	_update_caret()

func close() -> void:
	if _closing:
		return
	_closing = true
	await _slide_out()
	get_tree().paused = false
	closed.emit()
	queue_free()

func _slide_in() -> void:
	var banner_y := _banner.position.y
	var content_y := _content.position.y
	_banner.position.y = banner_y - _banner.size.y - 8.0
	_content.position.y = 240.0
	_dimmer.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_banner, "position:y", banner_y, SLIDE_TIME)
	tween.tween_property(_content, "position:y", content_y, SLIDE_TIME)
	tween.tween_property(_dimmer, "modulate:a", 1.0, SLIDE_TIME)
	await tween.finished

func _slide_out() -> void:
	_caret.visible = false
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_banner, "position:y", _banner.position.y - _banner.size.y - 8.0, SLIDE_TIME)
	tween.tween_property(_content, "position:y", 240.0, SLIDE_TIME)
	tween.tween_property(_dimmer, "modulate:a", 0.0, SLIDE_TIME)
	await tween.finished

func _unhandled_input(event: InputEvent) -> void:
	if Engine.get_process_frames() == _spawn_frame or _closing:
		return
	match _mode:
		Mode.TABS:
			_tabs_input(event)
		Mode.CONFIG:
			_config_input(event)
		Mode.KEYS:
			_keys_input(event)
		Mode.REBIND:
			_rebind_input(event)
		Mode.ITEMS:
			_items_input(event)
		Mode.ITEM_TARGET:
			_target_input(event)

func _tabs_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("right"):
		get_viewport().set_input_as_handled()
		_select((_index + 1) % _options.size())
	elif event.is_action_pressed("left"):
		get_viewport().set_input_as_handled()
		_select((_index - 1 + _options.size()) % _options.size())
	elif event.is_action_pressed("interact") or event.is_action_pressed("down"):
		if _index == TAB_CONFIG:
			get_viewport().set_input_as_handled()
			_set_mode(Mode.CONFIG)
		elif _index == TAB_ITEMS and not Inventory.entries().is_empty():
			get_viewport().set_input_as_handled()
			_item_index = 0
			_set_mode(Mode.ITEMS)

func _config_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_set_mode(Mode.TABS)
	elif event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("down"):
		get_viewport().set_input_as_handled()
		_config_index = (_config_index + 1) % _config_rows.size()
		_paint_config()
	elif event.is_action_pressed("up"):
		get_viewport().set_input_as_handled()
		_config_index = (_config_index - 1 + _config_rows.size()) % _config_rows.size()
		_paint_config()
	elif event.is_action_pressed("right") or event.is_action_pressed("left"):
		get_viewport().set_input_as_handled()
		var dir := 1 if event.is_action_pressed("right") else -1
		if _config_index == CONFIG_VOLUME:
			Settings.set_volume(Settings.volume + VOLUME_STEP * dir)
			_refresh_config_values()
		elif _config_index == CONFIG_LANGUAGE:
			var i := Settings.LOCALES.find(Settings.locale)
			Settings.set_locale(Settings.LOCALES[(i + dir + Settings.LOCALES.size()) % Settings.LOCALES.size()])
			_refresh_config_values()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		match _config_index:
			CONFIG_KEYBINDS:
				_set_mode(Mode.KEYS)
			CONFIG_QUIT:
				get_tree().quit()

func _keys_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_set_mode(Mode.CONFIG)
	elif event.is_action_pressed("down"):
		get_viewport().set_input_as_handled()
		_key_index = (_key_index + 1) % _key_rows.size()
		_paint_keys()
	elif event.is_action_pressed("up"):
		get_viewport().set_input_as_handled()
		_key_index = (_key_index - 1 + _key_rows.size()) % _key_rows.size()
		_paint_keys()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_mode = Mode.REBIND
		_rebind_frame = Engine.get_process_frames()
		(_key_rows[_key_index].get_node("Value") as Label).text = "PRESS KEY"

func _rebind_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed()):
		return
	get_viewport().set_input_as_handled()
	if Engine.get_process_frames() == _rebind_frame:
		return
	var key := event as InputEventKey
	if key.physical_keycode != KEY_ESCAPE:
		Settings.rebind(KEY_ACTIONS[_key_index], key)
	_mode = Mode.KEYS
	_refresh_key_values()

func _items_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_set_mode(Mode.TABS)
	elif event.is_action_pressed("down"):
		get_viewport().set_input_as_handled()
		_item_index = (_item_index + 1) % _menu_items.size()
		_render_items(_item_index)
	elif event.is_action_pressed("up"):
		get_viewport().set_input_as_handled()
		_item_index = (_item_index - 1 + _menu_items.size()) % _menu_items.size()
		_render_items(_item_index)
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _menu_items[_item_index].targets_allies:
			_target_index = 0
			_set_mode(Mode.ITEM_TARGET)

func _target_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_set_mode(Mode.ITEMS)
	elif event.is_action_pressed("down"):
		get_viewport().set_input_as_handled()
		_target_index = (_target_index + 1) % _members.size()
		_paint_members(_target_index)
	elif event.is_action_pressed("up"):
		get_viewport().set_input_as_handled()
		_target_index = (_target_index - 1 + _members.size()) % _members.size()
		_paint_members(_target_index)
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		var item := _menu_items[_item_index]
		var target := _members[_target_index]
		if not is_instance_valid(target) or not item.use_in_overworld(target):
			return
		Inventory.remove(item)
		_refresh()
		if Inventory.count(item) > 0:
			_paint_members(_target_index)
		elif _menu_items.is_empty():
			_set_mode(Mode.TABS)
		else:
			_item_index = clampi(_item_index, 0, _menu_items.size() - 1)
			_set_mode(Mode.ITEMS)

func _set_mode(mode: Mode) -> void:
	_mode = mode
	_entries.visible = mode == Mode.TABS or mode == Mode.CONFIG
	_config_hint.visible = _entries.visible
	_keybind_panel.visible = mode == Mode.KEYS or mode == Mode.REBIND
	_items_hint.visible = mode == Mode.ITEMS
	_party_hint.visible = mode == Mode.ITEM_TARGET
	if mode == Mode.TABS:
		_paint_rows(_config_rows, -1)
		_render_items(-1)
		_show_page(_index)
	elif mode == Mode.CONFIG:
		_paint_config()
		_refresh_config_values()
	elif mode == Mode.KEYS:
		_paint_keys()
		_refresh_key_values()
	elif mode == Mode.ITEMS:
		_item_index = clampi(_item_index, 0, maxi(0, _menu_items.size() - 1))
		_render_items(_item_index)
		_paint_members(-1)
		_show_page(TAB_ITEMS)
	elif mode == Mode.ITEM_TARGET:
		_paint_members(_target_index)
		_show_page(TAB_PARTY)
	_update_title()
	_update_caret()

func _update_title() -> void:
	match _mode:
		Mode.TABS:
			_panel_title.text = ["PARTY", "ITEMS", "CONFIG"][_index]
		Mode.CONFIG:
			_panel_title.text = "CONFIG"
		Mode.KEYS, Mode.REBIND:
			_panel_title.text = "CONTROLS"
		Mode.ITEMS:
			_panel_title.text = "ITEMS"
		Mode.ITEM_TARGET:
			_panel_title.text = "PARTY"

func _update_caret() -> void:
	if _closing:
		_caret.visible = false
		return
	match _mode:
		Mode.TABS:
			_caret_at(_options[_index])
		Mode.CONFIG:
			_caret_at(_config_rows[_config_index])
		Mode.KEYS, Mode.REBIND:
			_caret_at(_key_rows[_key_index])
		Mode.ITEMS:
			_caret_at_item(_item_index)
		Mode.ITEM_TARGET:
			if _target_index < _member_blocks.size():
				_caret_at(_member_blocks[_target_index].get_node("Name") as Control)

func _caret_at(control: Control) -> void:
	var sz := _caret.size
	_caret.global_position = Vector2(
		control.global_position.x - sz.x - 3.0,
		control.global_position.y + (control.size.y - sz.y) * 0.5
	)
	_caret.visible = true

func _caret_at_item(idx: int) -> void:
	if _menu_items.is_empty():
		_caret.visible = false
		return
	var font := _items_list.get_theme_font("normal_font")
	var fsize := _items_list.get_theme_font_size("normal_font_size")
	var line_height: float = font.get_height(fsize) if font else 9.0
	var sz := _caret.size
	_caret.global_position = Vector2(
		_items_list.global_position.x - sz.x - 3.0,
		_items_list.global_position.y + idx * line_height + (line_height - sz.y) * 0.5
	)
	_caret.visible = true

func _show_page(page: int) -> void:
	for i in range(_pages.size()):
		_pages[i].visible = i == page

func _paint_rows(rows: Array[HBoxContainer], idx: int) -> void:
	for i in range(rows.size()):
		var color := SELECTED_COLOR if i == idx else UNSELECTED_COLOR
		for child: Node in rows[i].get_children():
			if child is Label:
				(child as Label).add_theme_color_override("font_color", color)

func _paint_config() -> void:
	_paint_rows(_config_rows, _config_index)
	_update_caret()

func _paint_keys() -> void:
	_paint_rows(_key_rows, _key_index)
	_update_caret()

func _paint_members(idx: int) -> void:
	for i in range(_member_blocks.size()):
		var color := SELECTED_COLOR if i == idx or idx == -1 else UNSELECTED_COLOR
		for child: Node in _member_blocks[i].get_children():
			if child is Label:
				(child as Label).add_theme_color_override("font_color", color)
	if _mode == Mode.ITEM_TARGET:
		_update_caret()

func _refresh_config_values() -> void:
	(_config_rows[CONFIG_VOLUME].get_node("Value") as Label).text = "%d%%" % roundi(Settings.volume * 100.0)
	(_config_rows[CONFIG_LANGUAGE].get_node("Value") as Label).text = str(LOCALE_NAMES.get(Settings.locale, Settings.locale))

func _refresh_key_values() -> void:
	for i in range(_key_rows.size()):
		(_key_rows[i].get_node("Value") as Label).text = Settings.key_name(KEY_ACTIONS[i])

func _select(idx: int) -> void:
	_index = idx
	_show_page(idx)
	for i in range(_options.size()):
		_options[i].add_theme_color_override("font_color", TAB_SELECTED_COLOR if i == idx else UNSELECTED_COLOR)
	if _mode == Mode.TABS:
		_update_title()
		_update_caret()

func _render_items(selected: int) -> void:
	_menu_items = Inventory.entries()
	var txt := ""
	for i in range(_menu_items.size()):
		var item := _menu_items[i]
		var color := "#ffffff"
		if selected != -1:
			color = "#ffffff" if i == selected else "#777777"
		if not item.targets_allies:
			color = "#666666"
		txt += "[color=%s]%s  x%d[/color]\n" % [color, item.name.capitalize(), Inventory.count(item)]
	if txt.is_empty():
		txt = "[color=#999999]%s[/color]" % tr("No items.")
	_items_list.text = txt
	if is_instance_valid(_item_desc):
		var show_desc := selected >= 0 and selected < _menu_items.size()
		_item_desc.text = _menu_items[selected].description if show_desc else ""
	if _mode == Mode.ITEMS:
		_update_caret()

func _refresh() -> void:
	_members.clear()
	if is_instance_valid(Globals.cora):
		_members.append(Globals.cora)
	for node: Node in get_tree().get_nodes_in_group("party"):
		if node is Combatant and not _members.has(node):
			_members.append(node)
	for i in range(_member_blocks.size()):
		var block := _member_blocks[i]
		if i >= _members.size():
			block.visible = false
			continue
		block.visible = true
		var m := _members[i]
		(block.get_node("Name") as Label).text = m.combatant_name.to_upper()
		(block.get_node("HP") as Label).text = tr("HP  %d / %d") % [m.stats.health, m.stats.max_health]
		(block.get_node("Stats") as Label).text = tr("ATK %d   DEF %d   AGI %d") % [m.stats.attack, m.stats.defense, m.stats.agility]
	_render_items(-1)
