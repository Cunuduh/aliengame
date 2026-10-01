class_name RoomExit
extends Area2D

@export_file("*.tscn") var target_scene: String
@export var spawn_position := Vector2.ZERO

var _fired := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _fired or not body.is_in_group("cora"):
		return
	_fired = true
	# autoload referenced by path so the map bake tool can load this script
	get_node("/root/Globals").set("pending_spawn", spawn_position)
	body.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	var fade: CanvasLayer = (load("res://assets/scripts/world/room_fade.gd") as GDScript).new()
	fade.set("target_scene", target_scene)
	get_tree().root.add_child.call_deferred(fade)
