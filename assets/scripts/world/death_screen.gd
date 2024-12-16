extends TextureRect
var main_menu := preload("res://assets/scenes/main_menu.tscn")
func _on_retry_pressed() -> void:
  get_tree().change_scene_to_packed(main_menu)