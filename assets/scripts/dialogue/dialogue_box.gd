class_name DialogueBox
extends CanvasLayer
## Typewriter dialogue box. Reveals text via RichTextLabel.visible_characters
## with cadence pauses on punctuation/whitespace and inline {pause=seconds} /
## {speed=multiplier} tags. Runs with the tree paused (PROCESS_MODE_ALWAYS).
## "interact" skips the reveal, then advances to the next line.
## Driven by the Dialogue autoload: show_line() -> advanced,
## show_choices() -> choice_selected(index).

signal advanced
signal choice_selected(index: int)

## Seconds between characters at speed 1.0.
const CHAR_DELAY := 0.03
## Extra seconds added after revealing these characters. Punctuation only
## pauses when followed by whitespace or end of line (so "3.14" flows).
const EXTRA_DELAYS: Dictionary = {
	" ": 0.0,
	",": 0.1,
	";": 0.14,
	":": 0.14,
	".": 0.24,
	"!": 0.24,
	"?": 0.24,
	"…": 0.4,
	"\n": 0.24,
}
const BLINK_PERIOD := 0.8
const SKIP_LINE_DELAY := 0.08
const CHOICE_FONT := preload("res://assets/fonts/cozy-quill.otf")
const CHOICE_FONT_SIZE := 9
const CHOICE_COLOR_SELECTED := Color(1, 1, 1)
const CHOICE_COLOR_NORMAL := Color(0.55, 0.55, 0.55)

var _typing := false
var _idle := false
var _wait := 0.0
var _speed := 1.0
var _parsed_text := ""
var _pause_tags: Dictionary = {}  # visible char index -> extra wait before it
var _speed_tags: Dictionary = {}  # visible char index -> speed multiplier
var _blink := 0.0
var _spawn_frame := 0
var _skip_wait := 0.0
var _choice_labels: Array[Label] = []
var _choice_index := 0

@onready var text_label: RichTextLabel = %Text
@onready var advance_icon: TextureRect = %AdvanceIcon
@onready var choice_panel: Panel = %ChoicePanel
@onready var choice_list: VBoxContainer = %ChoiceList


func _ready() -> void:
	_spawn_frame = Engine.get_process_frames()


func show_line(line: Dictionary) -> void:
	_idle = false
	text_label.text = _prepare_text(line["text"])
	text_label.visible_characters = 0
	_parsed_text = text_label.get_parsed_text()
	_speed = 1.0
	_wait = float(_pause_tags.get(0, 0.0))
	_typing = true
	advance_icon.visible = false


func show_choices(options: Array[String]) -> void:
	for label: Label in _choice_labels:
		label.queue_free()
	_choice_labels.clear()
	for text: String in options:
		var label := Label.new()
		label.text = text
		label.add_theme_font_override("font", CHOICE_FONT)
		label.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
		choice_list.add_child(label)
		_choice_labels.append(label)
	_choice_index = 0
	_update_choice_highlight()
	var content := choice_list.get_combined_minimum_size()
	choice_panel.offset_left = choice_panel.offset_right - (content.x + 16.0)
	choice_panel.offset_top = choice_panel.offset_bottom - (content.y + 10.0)
	choice_panel.visible = true
	advance_icon.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if choice_panel.visible:
		if event.is_action_pressed("up"):
			get_viewport().set_input_as_handled()
			_choice_index = wrapi(_choice_index - 1, 0, _choice_labels.size())
			_update_choice_highlight()
		elif event.is_action_pressed("down"):
			get_viewport().set_input_as_handled()
			_choice_index = wrapi(_choice_index + 1, 0, _choice_labels.size())
			_update_choice_highlight()
		elif event.is_action_pressed("interact") and Engine.get_process_frames() != _spawn_frame:
			get_viewport().set_input_as_handled()
			choice_panel.visible = false
			choice_selected.emit(_choice_index)
		return
	if _typing and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_reveal_all()
	elif _idle and event.is_action_pressed("interact") and Engine.get_process_frames() != _spawn_frame:
		get_viewport().set_input_as_handled()
		_advance()


func _process(delta: float) -> void:
	if choice_panel.visible:
		return
	if Input.is_action_pressed("menu") and Engine.get_process_frames() != _spawn_frame:
		if _typing:
			_reveal_all()
			_skip_wait = SKIP_LINE_DELAY
		_skip_wait -= delta
		if _skip_wait <= 0.0:
			_skip_wait = SKIP_LINE_DELAY
			if _idle:
				_advance()
		return
	_skip_wait = 0.0
	if not _typing:
		_blink += delta
		advance_icon.visible = _idle and fmod(_blink, BLINK_PERIOD) < BLINK_PERIOD * 0.6
		return
	_wait -= delta
	while _wait <= 0.0 and _typing:
		_reveal_next()


func _advance() -> void:
	_idle = false
	advance_icon.visible = false
	advanced.emit()


func _update_choice_highlight() -> void:
	for i: int in _choice_labels.size():
		var color := CHOICE_COLOR_SELECTED if i == _choice_index else CHOICE_COLOR_NORMAL
		_choice_labels[i].add_theme_color_override("font_color", color)


func _reveal_next() -> void:
	var total := text_label.get_total_character_count()
	var next := text_label.visible_characters
	if next >= total:
		_finish_typing()
		return
	if _speed_tags.has(next):
		_speed = maxf(float(_speed_tags[next]), 0.01)
	text_label.visible_characters = next + 1
	if next + 1 >= total:
		_finish_typing()
		return
	var delay := CHAR_DELAY / _speed
	if next < _parsed_text.length():
		var shown := _parsed_text[next]
		if EXTRA_DELAYS.has(shown) and _cadence_applies(next):
			delay += float(EXTRA_DELAYS[shown])
	delay += float(_pause_tags.get(next + 1, 0.0))
	_wait += delay


func _reveal_all() -> void:
	text_label.visible_characters = -1
	_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_idle = true
	_blink = 0.0


## Punctuation pauses only before whitespace/end; whitespace always applies.
func _cadence_applies(idx: int) -> bool:
	var shown := _parsed_text[idx]
	if shown == " " or shown == "\n":
		return true
	if idx + 1 >= _parsed_text.length():
		return true
	var following := _parsed_text[idx + 1]
	return following == " " or following == "\n"


## Strips {pause=}/{speed=} tags, recording them against the index of the
## visible character they precede. BBCode passes through (its tags don't
## count as visible characters). Unknown {tags} are left as literal text.
func _prepare_text(source: String) -> String:
	_pause_tags.clear()
	_speed_tags.clear()
	var out := ""
	var visible := 0
	var in_bbcode := false
	var i := 0
	while i < source.length():
		var c := source[i]
		if in_bbcode:
			out += c
			if c == "]":
				in_bbcode = false
			i += 1
			continue
		if c == "[":
			in_bbcode = true
			out += c
			i += 1
			continue
		if c == "{":
			var close := source.find("}", i)
			if close != -1:
				var tag := source.substr(i + 1, close - i - 1)
				if tag.begins_with("pause="):
					_pause_tags[visible] = float(_pause_tags.get(visible, 0.0)) + float(tag.trim_prefix("pause="))
					i = close + 1
					continue
				if tag.begins_with("speed="):
					_speed_tags[visible] = float(tag.trim_prefix("speed="))
					i = close + 1
					continue
		out += c
		visible += 1
		i += 1
	return out
