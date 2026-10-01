extends CharacterBody2D
class_name InteractableNPC

@export var dialogue_id: String = "test_npc"
@export var interaction_range: float = 50.0

var cora_in_range: bool = false
var is_talking: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_shape: CollisionShape2D = $InteractionArea/CollisionShape2D

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	if interaction_shape and interaction_shape.shape is CircleShape2D:
		var circle_shape: CircleShape2D = interaction_shape.shape as CircleShape2D
		circle_shape.radius = interaction_range

func _input(event: InputEvent) -> void:
	if cora_in_range and not is_talking and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		start_dialogue()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("cora"):
		cora_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("cora"):
		cora_in_range = false

func start_dialogue() -> void:
	if is_talking:
		return

	is_talking = true

	if not dialogue_id.is_empty():
		Dialogue.start(dialogue_id)
		await Dialogue.finished

	is_talking = false
