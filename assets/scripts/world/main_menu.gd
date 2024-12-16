extends Control

var lobby_scene := preload("res://assets/scenes/lobby.tscn")

func _on_start_pressed() -> void:
  get_tree().change_scene_to_file("res://assets/scenes/lobby.tscn")
