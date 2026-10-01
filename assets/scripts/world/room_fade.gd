extends CanvasLayer

var target_scene: String

var _rect: ColorRect


func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 1.0, 0.25)
	tween.tween_callback(_switch)


func _switch() -> void:
	get_tree().change_scene_to_file(target_scene)
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_property(_rect, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
