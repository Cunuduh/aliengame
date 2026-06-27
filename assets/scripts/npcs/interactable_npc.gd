extends CharacterBody2D
class_name InteractableNPC

@export var dialogue_timeline: String = "test_npc_dialogue"
@export var interaction_text: String = "Press Z to talk"
@export var interaction_range: float = 50.0

var player_in_range: bool = false
var is_talking: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_shape: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var label: Label = $InteractionLabel

func _ready() -> void:
	# Set up interaction area
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	# Set up the interaction area size
	if interaction_shape and interaction_shape.shape is CircleShape2D:
		var circle_shape: CircleShape2D = interaction_shape.shape as CircleShape2D
		circle_shape.radius = interaction_range

	# Initially hide the label
	if label:
		label.visible = false
		label.text = interaction_text
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)

func _input(event: InputEvent) -> void:
	if player_in_range and not is_talking and event.is_action_pressed("attack"):
		start_dialogue()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if label:
			label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if label:
			label.visible = false

func start_dialogue() -> void:
	if is_talking:
		return

	is_talking = true
	if label:
		label.visible = false

	if Dialogic and not dialogue_timeline.is_empty():
		Dialogic.start(dialogue_timeline)
		await Dialogic.timeline_ended

	is_talking = false
	if player_in_range and label:
		label.visible = true
