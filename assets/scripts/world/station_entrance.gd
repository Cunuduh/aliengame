class_name StationEntrance
extends Area2D

var _inside := false
var _prompt: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt = Label.new()
	_prompt.text = "Z"
	_prompt.visible = false
	_prompt.position = Vector2(-4, -34)
	var settings := LabelSettings.new()
	settings.font = load("res://assets/fonts/cozy-quill-bold.otf")
	settings.font_size = 9
	settings.font_color = Color("#f5c518")
	settings.outline_size = 3
	settings.outline_color = Color(0, 0, 0, 0.8)
	_prompt.label_settings = settings
	add_child(_prompt)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("cora"):
		_inside = true
		_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("cora"):
		_inside = false
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _inside or not event.is_action_pressed("interact"):
		return
	if get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	_prompt.visible = false
	var menu: CanvasLayer = (load("res://assets/scripts/world/fast_travel.gd") as GDScript).new()
	get_tree().root.add_child(menu)
