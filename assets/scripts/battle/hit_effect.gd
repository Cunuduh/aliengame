extends Node2D
class_name HitEffect

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func play_hit_effect(hit_type: String, target: Combatant) -> void:
	if not animation_player.has_animation(hit_type):
		return
	global_position = target.global_position
	animation_player.play(hit_type)
	await get_tree().process_frame
	visible = true
	if animation_player.get_animation(hit_type).loop_mode == Animation.LoopMode.LOOP_NONE:
		await animation_player.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout