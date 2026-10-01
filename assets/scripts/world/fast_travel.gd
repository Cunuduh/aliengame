extends CanvasLayer
class_name FastTravel

signal closed

const DATA_PATH := "res://assets/scripts/tools/screen_data.json"
const SCREEN_DIR := "res://assets/scenes/screens/"

const SELECTED_COLOR := Color(1.0, 1.0, 1.0)
const UNSELECTED_COLOR := Color(0.45, 0.45, 0.45)
const LINE_COLOR := Color("#f5c518")
const PIN_COLOR := Color(0.42, 0.42, 0.46)
const PIN_HERE := Color("#5bb85b")
const PIN_SELECTED := Color("#f5c518")

# ordered destination list: screen key -> display name
const DESTINATIONS: Array = [
	["stn_st_george", "ST GEORGE"],
	["stn_museum", "MUSEUM"],
	["stn_bay", "BAY"],
	["stn_bloor_yonge", "BLOOR-YONGE"],
	["stn_wellesley", "WELLESLEY"],
	["stn_queens_park", "QUEEN'S PARK"],
	["eaton_dundas", "DUNDAS"],
	["eaton_mid", "EATON CENTRE"],
	["eaton_queen", "QUEEN"],
	["rom", "ROYAL ONTARIO MUSEUM"],
	["victoria_college", "VICTORIA COLLEGE"],
	["robarts", "ROBARTS LIBRARY"],
	["sidney_smith", "SIDNEY SMITH"],
	["university_college", "UNIVERSITY COLLEGE"],
	["convocation", "CONVOCATION HALL"],
	["queens_park_lawn", "LEGISLATURE"],
]

var _index := 0
var _closing := false
var _screens: Dictionary = {}
var _rows: Array[Label] = []
var _map: Control
var _hint: Label
var _title: Label


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_screens = json["screens"]
	_build()
	_index = maxi(0, _current_index())
	_refresh()
	get_tree().paused = true


func _current_index() -> int:
	var here := _here()
	for i: int in DESTINATIONS.size():
		if String(DESTINATIONS[i][0]) == here:
			return i
	return 0


func _here() -> String:
	var root := get_tree().current_scene
	if root == null:
		return ""
	return String(root.get_meta("screen_key", ""))


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := ColorRect.new()
	panel.color = Color("#14141a")
	panel.position = Vector2(6, 4)
	panel.size = Vector2(308, 232)
	root.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color("#3a3a46")
	edge.position = Vector2(6, 20)
	edge.size = Vector2(308, 1)
	root.add_child(edge)

	_title = _make_label("TTC — FAST TRAVEL", 9, Color("#f5c518"))
	_title.position = Vector2(10, 6)
	root.add_child(_title)

	var list := VBoxContainer.new()
	list.position = Vector2(14, 24)
	list.add_theme_constant_override("separation", -2)
	root.add_child(list)
	for entry: Array in DESTINATIONS:
		var row := _make_label(String(entry[1]), 7, UNSELECTED_COLOR)
		list.add_child(row)
		_rows.append(row)

	_map = Control.new()
	_map.position = Vector2(214, 24)
	_map.custom_minimum_size = Vector2(96, 180)
	_map.draw.connect(_draw_map)
	root.add_child(_map)

	_hint = _make_label("↑↓ SELECT    Z GO    X BACK", 7, Color(0.55, 0.55, 0.58))
	_hint.position = Vector2(14, 224)
	root.add_child(_hint)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font = load("res://assets/fonts/cozy-quill-bold.otf")
	settings.font_size = size
	settings.font_color = color
	label.label_settings = settings
	return label


func _draw_map() -> void:
	var pts: Array[Vector2] = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for entry: Array in DESTINATIONS:
		var key: String = entry[0]
		if not _screens.has(key):
			pts.append(Vector2.ZERO)
			continue
		var c: Array = _screens[key]["world_center"]
		var p := Vector2(float(c[0]), float(c[1]))
		pts.append(p)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := hi - lo
	if span.x <= 0.0 or span.y <= 0.0:
		return
	var size := _map.custom_minimum_size - Vector2(16, 16)
	var scale := minf(size.x / span.x, size.y / span.y)
	var offset := Vector2(8, 8) + (size - span * scale) * 0.5

	var here := _here()
	var screen_pts: Array[Vector2] = []
	for p: Vector2 in pts:
		screen_pts.append(offset + (p - lo) * scale)

	# schematic lines: Bloor across the top, Yonge down the east side
	if screen_pts.size() >= 9:
		_map.draw_line(screen_pts[0], screen_pts[3], LINE_COLOR, 1.0)
		_map.draw_line(screen_pts[3], screen_pts[8], LINE_COLOR, 1.0)

	for i: int in screen_pts.size():
		var key: String = DESTINATIONS[i][0]
		var color := PIN_COLOR
		if key == here:
			color = PIN_HERE
		if i == _index:
			color = PIN_SELECTED
		var r := 3.0 if i == _index else 2.0
		_map.draw_circle(screen_pts[i], r, color)


func _refresh() -> void:
	for i: int in _rows.size():
		var key: String = DESTINATIONS[i][0]
		var available: bool = _screens.has(key) and key != _here()
		var row := _rows[i]
		if i == _index:
			row.label_settings.font_color = SELECTED_COLOR if available else Color("#8a5a5a")
		else:
			row.label_settings.font_color = UNSELECTED_COLOR
		row.text = ("> " if i == _index else "  ") + String(DESTINATIONS[i][1]) \
			+ ("  (HERE)" if key == _here() else "")
	_map.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _closing or not event.is_pressed():
		return
	if event.is_action("cancel") or event.is_action("menu"):
		get_viewport().set_input_as_handled()
		_close()
	elif event.is_action("up"):
		get_viewport().set_input_as_handled()
		_index = (_index - 1 + DESTINATIONS.size()) % DESTINATIONS.size()
		_refresh()
	elif event.is_action("down"):
		get_viewport().set_input_as_handled()
		_index = (_index + 1) % DESTINATIONS.size()
		_refresh()
	elif event.is_action("interact"):
		get_viewport().set_input_as_handled()
		_travel()


func _travel() -> void:
	var key: String = DESTINATIONS[_index][0]
	if not _screens.has(key) or key == _here():
		return
	_closing = true
	var spawn: Array = _screens[key]["spawn"]
	Globals.pending_spawn = Vector2(float(spawn[0]), float(spawn[1]))
	get_tree().paused = false
	var fade: CanvasLayer = (load("res://assets/scripts/world/room_fade.gd") as GDScript).new()
	fade.set("target_scene", SCREEN_DIR + key + ".tscn")
	get_tree().root.add_child(fade)
	queue_free()


func _close() -> void:
	_closing = true
	get_tree().paused = false
	closed.emit()
	queue_free()
