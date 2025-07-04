extends Ability
class_name BasicAttackAbility

var charge := 0.0
var closest_enemy_position := Vector2.ZERO
func _init():
  cooldown = 0.5
  name = "basic_attack"
  icon = preload("res://assets/sprites/ui/battle/player/basic_attack_icon.png")

func pre_execute(player: Player) -> void:
  charge = player.speed
  #player.animation_player.play("attack_transition")
  #await player.get_tree().create_timer(player.animation_player.get_animation("attack_transition").length).timeout
  #player.animation_player.play("attack_wait")
  
  while Input.is_action_pressed("attack"):
    charge += 70 * player.get_process_delta_time()
    await player.get_tree().process_frame
    
func execute(player: Player) -> void:
  var idx = player.get_ability_index(self)
  player.state_chart.send_event("end_%s-%d" % [name, idx])
  #player.animation_player.play("attack_action")
  
  var projectile: Sprite2D = preload("res://assets/scenes/player_attack_projectile.tscn").instantiate()
  BattleManager.battle_scene.add_child(projectile)

  closest_enemy_position = Globals.encountered_enemies.front().global_position
  for enemy in Globals.encountered_enemies:
    if player.global_position.distance_to(enemy.global_position) < player.global_position.distance_to(closest_enemy_position):
      closest_enemy_position = enemy.global_position
  projectile.global_position = player.global_position
  projectile.launch(closest_enemy_position, min(floori(charge), player.speed * 2))

  #await player.get_tree().create_timer(player.animation_player.get_animation("attack_action").length).timeout
  #player.animation_player.play("battle_stance")
