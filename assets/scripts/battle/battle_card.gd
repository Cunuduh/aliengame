extends Control
class_name BattleCard

var character: Combatant
var char_name := ""
var hp := 20
var max_hp := 20
var _is_ready := false
var _pending_init := false

@onready var hp_label: Label = $HealthContainer/HPLabel
@onready var max_hp_label: Label = $HealthContainer/MaxHPLabel
@onready var hp_bar: TextureProgressBar = $HealthContainer/HPBar
@onready var icon_container: HBoxContainer = $IconContainer
var icons := {}

func initialize(new_character: Combatant) -> void:
  self.character = new_character
  self.char_name = new_character.combatant_name.to_lower()
  var stats = new_character.stats
  self.hp = stats.health
  self.max_hp = stats.max_health
  new_character.stats.connect("stat_changed", _on_stat_changed)
  
  if _is_ready:
    _complete_initialization()
  else:
    _pending_init = true

func _complete_initialization() -> void:
  setup_ability_icons()
  hp_label.text = str(hp) + " /"
  max_hp_label.text = str(max_hp)
  hp_bar.set_value_no_signal(float(hp))
  hp_bar.max_value = float(max_hp)
  hp_bar.value = float(hp)

func setup_ability_icons() -> void:
  for icon in icons.values():
    icon.queue_free()
  icons.clear()
  # create one icon per ability with unique node_base
  for i in range(character.abilities.size()):
    var ability = character.abilities[i]
    var node_base = "%s-%d" % [ability.name.to_pascal_case(), i]
    var icon = preload("res://assets/scenes/ability_icon.tscn").instantiate()
    icon.name = "%sIcon" % node_base
    icon.texture = ability.icon
    icon_container.add_child(icon)
    icons[node_base] = icon

    var avail_node = character.state_chart.get_node("Root/Battling/%s/Available" % node_base)
    avail_node.state_entered.connect(refresh_icon.bind(node_base))
    var cd_node = character.state_chart.get_node("Root/Battling/%s/Cooldown" % node_base)
    cd_node.transition_pending.connect(
      func(total: float, current: float): gray_out_icon(total, current, node_base)
    )

func _ready() -> void:
  await get_tree().process_frame
  _is_ready = true
  
  if _pending_init:
    _complete_initialization()
    _pending_init = false

func _exit_tree() -> void:
  for i in range(character.abilities.size()):
    var node_base = "%s-%d" % [character.abilities[i].name.to_pascal_case(), i]
    var avail_node = character.state_chart.get_node("Root/Battling/%s/Available" % node_base)
    avail_node.state_entered.disconnect(refresh_icon.bind(node_base))
    var cd_node = character.state_chart.get_node("Root/Battling/%s/Cooldown" % node_base)
    for connection in cd_node.transition_pending.get_connections():
      if connection["callable"].get_object() == self:
        cd_node.transition_pending.disconnect(connection["callable"])
  for icon in icons.values():
    icon.queue_free()
  icons.clear()

func _process(_delta: float) -> void:
  if Engine.is_editor_hint():
    hp_label.text = str(hp) + " /"
    max_hp_label.text = str(max_hp)
    hp_bar.set_value_no_signal(float(hp))
    hp_bar.max_value = float(max_hp)

func _on_stat_changed(stat: CharacterStats.StatType, value: int) -> void:
  match stat:
    CharacterStats.StatType.HEALTH:
      hp_label.text = "%d /" % value
      hp_bar.value = value
      hp = value
    CharacterStats.MaxStatType.HEALTH:
      max_hp = value
      max_hp_label.text = "%d" % max_hp
      hp_bar.max_value = float(max_hp)

func gray_out_icon(_total_time: float, current_time: float, icon_name: String) -> void:
  icons[icon_name].self_modulate = Color(0.5, 0.5, 0.5, 1)
  var cooldown_label: Label = icons[icon_name].get_child(0)
  if current_time > 0:
    cooldown_label.text = "%.1f" % current_time
    await get_tree().process_frame
  refresh_icon(icon_name)

func refresh_icon(icon_name: String) -> void:
  icons[icon_name].self_modulate = Color(1, 1, 1, 1)
  var cooldown_label: Label = icons[icon_name].get_child(0)
  cooldown_label.text = ""
