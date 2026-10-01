extends Node
## Autoload `Dialogue`. In-house dialogue system: loads .dlg files
## (see DialogueParser), resolves lines through tr() so text can live in
## localization CSVs, substitutes {variable} placeholders, and drives the
## DialogueBox UI entry by entry — lines, choices, labels, and jumps —
## so dialogues can branch. The world is paused while a dialogue runs.
##
## Usage:
##   Dialogue.start("test_npc")
##   await Dialogue.finished

signal started
signal finished

const DIALOGUE_DIR := "res://assets/resources/dialogues"
const DIALOGUE_BOX_SCENE := preload("res://assets/scenes/dialogue_box.tscn")

## speaker_id -> display name (translation key or literal) and name color.
const SPEAKERS: Dictionary = {
	"cora": {"name": "Cora", "color": Color(1.0, 0.78, 0.45)},
	"test": {"name": "SPK_TEST", "color": Color(0.5, 0.83, 1.0)},
}

## Substituted into lines as {key}. Add story flags/names here as needed.
## `player_name` is the human at the keyboard, not Cora — for fourth-wall lines.
var variables: Dictionary = {
	"player_name": "Player",
}

var _box: DialogueBox = null
var _entries: Array[Dictionary] = []
var _labels: Dictionary = {}
var _index := 0


func is_active() -> bool:
	return _box != null


func start(id: String) -> void:
	if _box != null:
		push_warning("Dialogue \"%s\" requested while another dialogue is running." % id)
		return
	_entries = DialogueParser.parse_file("%s/%s.dlg" % [DIALOGUE_DIR, id])
	if _entries.is_empty():
		push_warning("Dialogue \"%s\" is empty or missing." % id)
		finished.emit.call_deferred()
		return
	_labels.clear()
	for i: int in _entries.size():
		var entry: Dictionary = _entries[i]
		if entry["type"] == "label":
			_labels[entry["name"]] = i
	_index = 0
	_box = DIALOGUE_BOX_SCENE.instantiate() as DialogueBox
	add_child(_box)
	get_tree().paused = true
	started.emit()
	_run()


func set_variable(key: String, value: Variant) -> void:
	variables[key] = value


func speaker_display_name(id: String) -> String:
	if id.is_empty():
		return ""
	if SPEAKERS.has(id):
		var key: String = SPEAKERS[id]["name"]
		return tr(key)
	return id


func speaker_color(id: String) -> Color:
	if SPEAKERS.has(id):
		var color: Color = SPEAKERS[id]["color"]
		return color
	return Color.WHITE


## Translates a line (keys fall through unchanged) and fills {placeholders}.
## Unknown {tags} are left intact — DialogueBox parses {pause=}/{speed=} later.
func resolve_text(raw: String) -> String:
	var text := tr(raw)
	var subs := _substitutions()
	var keys: Array = subs.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for key: String in keys:
		text = text.replace("{%s}" % key, str(subs[key]))
	return text


func _substitutions() -> Dictionary:
	var subs: Dictionary = {}
	for key: String in variables:
		subs[key] = variables[key]
	return subs


func _run() -> void:
	while _index < _entries.size():
		var entry: Dictionary = _entries[_index]
		match String(entry["type"]):
			"label":
				_index += 1
			"jump":
				if not _goto(String(entry["target"])):
					return
			"line":
				var speaker := String(entry["speaker"])
				_box.show_line({
					"name": speaker_display_name(speaker),
					"color": speaker_color(speaker),
					"text": resolve_text(String(entry["text"])),
				})
				await _box.advanced
				_index += 1
			"choice":
				var options: Array = entry["options"]
				var texts: Array[String] = []
				for option: Dictionary in options:
					texts.append(resolve_text(String(option["text"])))
				_box.show_choices(texts)
				var picked: int = await _box.choice_selected
				var target := String(options[picked]["target"])
				if target.is_empty():
					_index += 1
				elif not _goto(target):
					return
	_finish()


## Moves _index to the label. Returns false if the dialogue ended instead
## ("end" target or unknown label).
func _goto(target: String) -> bool:
	if target == "end":
		_finish()
		return false
	if _labels.has(target):
		_index = int(_labels[target])
		return true
	push_warning("Dialogue jump to unknown label \"%s\"." % target)
	_finish()
	return false


func _finish() -> void:
	_box.queue_free()
	_box = null
	get_tree().paused = false
	finished.emit()
