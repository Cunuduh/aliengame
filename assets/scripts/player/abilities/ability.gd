extends Resource
class_name Ability

var cooldown: float = 1.0
var icon: Texture2D
var name: String
var current_state := "wait"

func update_current_anim(new_direction: Vector2, player: Player) -> String:
	var animation := "%s_%s_%s" % [
		name,
		current_state,
		"left" if new_direction.x < 0.0 else "right",
	]
	player.animation_player.play(animation)
	return animation

func execute(_player: Player) -> void:
	pass

func pre_execute(_player: Player) -> void:
	pass

func exit(_player: Player) -> void:
	pass