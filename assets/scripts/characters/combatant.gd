extends CharacterBody2D
class_name Combatant

@onready var stats: CharacterStats = $CharacterStats
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite
@export var combatant_name := "Combatant"
@export var abilities: Array[Ability] = []

var in_battle := false
var hit_type := ""

const VEC_TO_INT := {
	Vector2.RIGHT: 0,
	Vector2.LEFT: 1,
	Vector2.UP: 2,
	Vector2.DOWN: 3
}
const IDLE_POSE_STEP := 0.25
const HURT_HOLD := 0.35
const KNOCKBACK_DIST := 6.0
const KNOCKBACK_OUT := 0.08
const KNOCKBACK_BACK := 0.22
const OUTLINE_SHADER := preload("res://assets/shaders/outline.gdshader")

var _knockback_home := Vector2.ZERO
var _knockback_tween: Tween
var _outline_material: ShaderMaterial
var _pre_outline_material: Material
var _outline_tween: Tween
var _outline_color := Color.WHITE

func pose_idle(facing: int) -> void:
	if not is_instance_valid(animation_player) or not animation_player.has_animation("idle"):
		return
	animation_player.play("idle")
	animation_player.pause()
	animation_player.seek(0, true)
	animation_player.seek(IDLE_POSE_STEP * facing, true)

func is_alive() -> bool:
	return stats.health > 0

func can_pay_hp() -> bool:
	return stats.health > 0

func revive() -> void:
	if stats.health <= 0:
		stats.health = 1

func ko_message() -> String:
	return tr("* %s was defeated!") % combatant_name

func play_hurt(fatal: bool) -> void:
	if not is_instance_valid(animation_player):
		return
	var current := String(animation_player.current_animation)
	var looping := current != "" and animation_player.get_animation(current).loop_mode != Animation.LoopMode.LOOP_NONE
	var hurt_anim := "hurt"
	if current.ends_with("_loop"):
		var variant := current.trim_suffix("_loop") + "_hurt"
		if animation_player.has_animation(variant):
			hurt_anim = variant
	if not animation_player.has_animation(hurt_anim):
		return
	var resume := current
	if not looping or resume == "":
		resume = "idle_battle" if animation_player.has_animation("idle_battle") else "idle"
	var clip := animation_player.get_animation(hurt_anim)
	animation_player.play(hurt_anim)
	if fatal:
		return
	if clip.loop_mode == Animation.LoopMode.LOOP_NONE and clip.length > 0.0:
		var done: StringName = await animation_player.animation_finished
		if String(done) != hurt_anim:
			return
	else:
		await get_tree().create_timer(maxf(clip.length, HURT_HOLD)).timeout
		if String(animation_player.current_animation) != hurt_anim:
			return
	if animation_player.has_animation(resume):
		animation_player.play(resume)

func on_turn_start(battle: BattleScene) -> void:
	await battle.get_tree().process_frame

func set_outline(color: Color) -> void:
	if not is_instance_valid(sprite):
		return
	_kill_outline_tween()
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = OUTLINE_SHADER
	_outline_color = color
	_outline_material.set_shader_parameter("line_color", color)
	if sprite.material != _outline_material:
		_pre_outline_material = sprite.material
		sprite.material = _outline_material

func fade_outline(duration: float) -> void:
	if not is_instance_valid(sprite) or _outline_material == null:
		return
	if sprite.material != _outline_material:
		return
	_kill_outline_tween()
	_outline_tween = create_tween()
	_outline_tween.tween_method(_set_outline_alpha, _outline_color.a, 0.0, duration)
	_outline_tween.tween_callback(_restore_outline_material)

func clear_outline() -> void:
	_kill_outline_tween()
	_restore_outline_material()

func _set_outline_alpha(alpha: float) -> void:
	if _outline_material != null:
		_outline_material.set_shader_parameter("line_color", Color(_outline_color, alpha))

func _kill_outline_tween() -> void:
	if _outline_tween != null and _outline_tween.is_valid():
		_outline_tween.kill()
	_outline_tween = null

func _restore_outline_material() -> void:
	if is_instance_valid(sprite) and sprite.material == _outline_material:
		sprite.material = _pre_outline_material
	_pre_outline_material = null
	_outline_tween = null

func knockback() -> void:
	if not is_instance_valid(sprite):
		return
	if _knockback_tween and _knockback_tween.is_valid():
		_knockback_tween.kill()
		sprite.position = _knockback_home
	_knockback_home = sprite.position
	var dir := 1.0 if is_in_group("enemy") else -1.0
	_knockback_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_knockback_tween.tween_property(sprite, "position", _knockback_home + Vector2(dir * KNOCKBACK_DIST, 0.0), KNOCKBACK_OUT)
	_knockback_tween.tween_property(sprite, "position", _knockback_home, KNOCKBACK_BACK)

func on_queue_attack(_battle: BattleScene) -> void:
	if is_instance_valid(animation_player) and animation_player.has_animation("attack_loop"):
		animation_player.play("attack_loop")

func attack(battle: BattleScene, target: Combatant) -> void:
	if not is_instance_valid(target):
		return
	battle.set_message(tr("* %s attacks %s!") % [combatant_name, target.combatant_name])
	await battle.get_tree().create_timer(0.4).timeout
	await _play_attack_anim()
	await battle.spawn_hit_effect(hit_type, target)
	var killed := battle.apply_damage(self, target)
	await battle.get_tree().create_timer(1.4 if killed else 0.6).timeout
	face(target.global_position)
	battle.return_to_idle(self)

func _play_attack_anim() -> void:
	if not is_instance_valid(animation_player):
		return
	for anim: String in ["attack_cast", "attack", "idle_battle"]:
		if not animation_player.has_animation(anim):
			continue
		var clip := animation_player.get_animation(anim)
		animation_player.play(anim)
		if clip.loop_mode == Animation.LoopMode.LOOP_NONE and clip.length > 0.0:
			await animation_player.animation_finished
		else:
			await get_tree().create_timer(0.5).timeout
		return

func face(_point: Vector2) -> void:
	pass
