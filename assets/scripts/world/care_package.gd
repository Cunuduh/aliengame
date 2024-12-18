extends Sprite2D
class_name CarePackage
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label = $Label
@onready var cooldown: Sprite2D = $Cooldown
@onready var health: Sprite2D = $Health 
@onready var damage: Sprite2D = $Damage
@onready var next: TextureRect = get_parent().get_node("Next")
var opened := false
var looted := false
var player_in_cooldown := false
var player_in_health := false 
var player_in_damage := false
var original_cooldowns: Array[float] = [0.5, 10.0, 7.5]
var applied_upgrades_count: Dictionary = {
  "cooldown": 0,
  "health": 0,
  "damage": 0
}
func _ready() -> void:
  refresh()

func refresh() -> void:
  looted = false
  opened = false
  animation_player.play("idle")
  label.visible = false
  next.visible = false
  player_in_cooldown = false
  player_in_health = false
  player_in_damage = false
  for sprite in [cooldown, health, damage]:
    sprite.modulate.a = 1.0
    sprite.modulate.v = 1.0
    sprite.visible = false
  label.modulate.a = 1.0

func _process(_delta: float) -> void:
  if Input.is_action_just_pressed("attack") and not looted:
    if player_in_cooldown:
      _apply_upgrade(cooldown, _apply_cooldown_upgrade)
    elif player_in_health:
      _apply_upgrade(health, _apply_health_upgrade)
    elif player_in_damage:
      _apply_upgrade(damage, _apply_damage_upgrade)

func _apply_upgrade(sprite: Sprite2D, upgrade_func: Callable) -> void:
  looted = true
  var tween = get_tree().create_tween().set_parallel(true)
  
  tween.tween_property(sprite, "modulate:v", 5.0, 0.5)
  tween.tween_property(label, "modulate:a", 0.0, 0.5)
  for other_sprite in [cooldown, health, damage]:
    if other_sprite != sprite:
      tween.tween_property(other_sprite, "modulate:a", 0.0, 0.5)
  tween.tween_property(self, "modulate:a", 0.0, 2.5)
  await tween.finished
  upgrade_func.call()
  next.visible = true
  next.get_node("AnimationPlayer").play("idle")
  visible = false

func _apply_cooldown_upgrade() -> void:
  var player = Globals.player
  var attack_node = player.state_chart.get_node("Root/Battling/Attack/Cooldown/Refresh")
  var ability1_node = player.state_chart.get_node("Root/Battling/Ability1/Cooldown/Refresh")
  var ability2_node = player.state_chart.get_node("Root/Battling/Ability2/Cooldown/Refresh")
  attack_node.delay_seconds = max(0.1, original_cooldowns[0] - applied_upgrades_count["cooldown"] * 0.05)
  ability1_node.delay_seconds = max(0.1, original_cooldowns[1] - applied_upgrades_count["cooldown"] * 0.05)
  ability2_node.delay_seconds = max(0.1, original_cooldowns[2] - applied_upgrades_count["cooldown"] * 0.05)
  applied_upgrades_count["cooldown"] += 1

func _apply_health_upgrade() -> void:
  var player = Globals.player
  player.stats.max_health += 2
  player.stats.health += 2
  applied_upgrades_count["health"] += 1

func _apply_damage_upgrade() -> void:
  var player = Globals.player
  player.stats.max_attack += 2
  player.stats.attack += 2
  applied_upgrades_count["damage"] += 1

func _on_area_2d_body_entered(body: Node2D) -> void:
  if body.is_in_group("player") and not opened:
    animation_player.play("open")
    label.visible = true
    opened = true

func _on_cooldown_area_2d_body_entered(_body: Node2D) -> void:
  player_in_cooldown = true
  label.text = "-5% COOLDOWN"
  label.visible = true

func _on_health_area_2d_body_entered(_body: Node2D) -> void:
  player_in_health = true
  label.text = "+2 HEALTH" 
  label.visible = true

func _on_damage_area_2d_body_entered(_body: Node2D) -> void:
  player_in_damage = true
  label.text = "+2 DAMAGE"
  label.visible = true

func _on_cooldown_area_2d_body_exited(_body: Node2D) -> void:
  player_in_cooldown = false
  if not (player_in_health or player_in_damage):
    label.text = "Z TO CHOOSE UPGRADE"

func _on_health_area_2d_body_exited(_body: Node2D) -> void:
  player_in_health = false
  if not (player_in_cooldown or player_in_damage):
    label.text = "Z TO CHOOSE UPGRADE"

func _on_damage_area_2d_body_exited(_body: Node2D) -> void:
  player_in_damage = false
  if not (player_in_cooldown or player_in_health):
    label.text = "Z TO CHOOSE UPGRADE"
