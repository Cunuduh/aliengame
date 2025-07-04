extends Ability
class_name BasicAbility1

func _init():
  cooldown = 10.0
  name = "basic_ability_1"
  icon = preload("res://assets/sprites/ui/battle/player/basic_ability_1_icon.png")

func execute(player: Player) -> void:
  var explosion = preload("res://assets/scenes/explosion.tscn").instantiate()
  BattleManager.battle_scene.add_child(explosion)
  explosion.global_position = player.global_position
  explosion.visible = true
  explosion.frame = 0
  explosion.play("default")
  
  var enemies = Globals.encountered_enemies
  for enemy in enemies:
    enemy.stats.health -= player.stats.attack * 0.5
      
  await player.get_tree().create_timer(0.6).timeout
  explosion.queue_free()
  
  var idx = player.get_ability_index(self)
  player.state_chart.send_event("end_%s-%d" % [name, idx])