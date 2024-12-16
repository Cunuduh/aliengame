extends Control
class_name BattleScene
enum Action {
  ATTACK,
  DIVINE,
  REACH,
  SELECT,
  ORDER
}

var _battle_card_scene := preload("res://assets/scenes/battle_card.tscn")
var _player_in_area := false
var card: BattleCard

var _total_enemy_health := 0
var _max_total_enemy_health := 0

func _ready() -> void:
  _calculate_total_enemy_health()
  $TotalHealth/Label.text = "100%"
  $TotalHealth.material.set_shader_parameter("edge_offset", 1.0)
  var tween := get_tree().create_tween().set_parallel(true)
  tween.tween_method(_set_background_modulation, Color(0.0, 0.0, 0.0, 0.0), Color(1, 1, 1, 1), 0.75)
  card = _battle_card_scene.instantiate()
  card.initialize(Globals.player)
  card.name = Globals.player.combatant_name
  $CanvasLayer/BattleCardContainer.add_child(card)
  $CanvasLayer/BattleCardContainer.position.y += 100
  tween.tween_property($CanvasLayer/BattleCardContainer, "position", Vector2($CanvasLayer/BattleCardContainer.position.x, $CanvasLayer/BattleCardContainer.position.y - 100), 0.5) \
    .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
  await tween.finished

func fade_out() -> void:
  var tween := get_tree().create_tween().set_parallel(true)
  tween.tween_property($CanvasLayer/BattleCardContainer, "position", Vector2($CanvasLayer/BattleCardContainer.position.x, $CanvasLayer/BattleCardContainer.position.y + 100), 0.5) \
    .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
  tween.tween_method(_set_background_modulation, Color(1, 1, 1, 1), Color(0.0, 0.0, 0.0, 0.0), 0.75)
  await tween.finished

func introduce_combatants() -> void:
  var label := preload("res://assets/scenes/battle_label.tscn").instantiate()
  for combatant in _get_combatants():
    combatant.add_child(label)
    label.position = Vector2(0, -combatant.get_node("Sprite").texture.get_height())
    label.text = combatant.combatant_name

func _set_background_modulation(colour: Color) -> void:
  $Background.material.set_shader_parameter("colour_modulation", colour)

func set_health_bar_modulation(colour: Color) -> void:
  card.hp_bar.material.set_shader_parameter("colour_modulation", colour)

func _get_combatants() -> Array[Combatant]:
  var enemies := Globals.encountered_enemies
  return enemies + [Globals.player]

func _on_visibility_area_body_entered(body: PhysicsBody2D) -> void:
  if body == Globals.player:
    _player_in_area = true
    _update_battle_card_container_opacity()

func _on_visibility_area_body_exited(body: PhysicsBody2D) -> void:
  if body == Globals.player:
    _player_in_area = false
    _update_battle_card_container_opacity()

func _update_battle_card_container_opacity() -> void:
  var tween := get_tree().create_tween().set_parallel(true)
  if _player_in_area:
    tween.tween_property($CanvasLayer/BattleCardContainer, "modulate", Color(1, 1, 1, 0.25), 0.25) \
      .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_method(set_health_bar_modulation, Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), 0.25)
  else:
    tween.tween_property($CanvasLayer/BattleCardContainer, "modulate", Color(1, 1, 1, 1), 0.25) \
      .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_method(set_health_bar_modulation, Color(1, 1, 1, 0.25), Color(1, 1, 1, 1), 0.25)

func _calculate_total_enemy_health() -> void:
  _total_enemy_health = 0
  _max_total_enemy_health = 0
  
  for enemy in Globals.encountered_enemies:
    _total_enemy_health += enemy.stats.health
    _max_total_enemy_health += enemy.stats.max_health
    enemy.stats.connect("stat_changed", _on_enemy_stat_changed)
  
  $TotalHealth.max_value = _max_total_enemy_health
  $TotalHealth.value = _total_enemy_health

func _on_enemy_stat_changed(stat: CharacterStats.StatType, value: int) -> void:
  if stat == CharacterStats.StatType.HEALTH:
    var new_total := 0
    for enemy in Globals.encountered_enemies:
      new_total += enemy.stats.health
    _total_enemy_health = new_total
    
    $TotalHealth.value = _total_enemy_health
    $TotalHealth/Label.text = str(int(100 * (_total_enemy_health / float(_max_total_enemy_health)))) + "%"
    $TotalHealth.material.set_shader_parameter("edge_offset", -(1.0 - (_total_enemy_health / float(_max_total_enemy_health))) * 0.9)