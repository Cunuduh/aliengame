extends Control
class_name BattleCard

var character: Combatant
var char_name := ""
var hp := 20
var max_hp := 20

@onready var hp_label: Label = $HealthContainer/HPLabel
@onready var max_hp_label: Label = $HealthContainer/MaxHPLabel
@onready var hp_bar: TextureProgressBar = $HealthContainer/HPBar
@onready var icons := {
  "attack": $IconContainer/AttackIcon,
  "ability_1": $IconContainer/Ability1Icon,
  "ability_2": $IconContainer/Ability2Icon,
}

func initialize(new_character: Combatant) -> void:
  self.character = new_character
  self.char_name = new_character.combatant_name.to_lower()
  var stats = new_character.stats
  self.hp = stats.health
  self.max_hp = stats.max_health
  new_character.stats.connect("stat_changed", _on_stat_changed)

func _ready() -> void:
  await get_tree().process_frame
  hp_label.text = str(hp) + " /"
  max_hp_label.text = str(max_hp)
  hp_bar.set_value_no_signal(float(hp))
  hp_bar.max_value = float(max_hp)
  hp_bar.value = float(hp)
  for icon in icons:
    icons[icon].texture = load("res://assets/sprites/ui/battle/" + char_name + "/" + char_name + "_" + icon + "_icon" + ".png")
    character.state_chart.get_node("Root/Battling/" + icon.to_pascal_case() + "/Available").state_entered.connect(refresh_icon.bind(icon))
    character.state_chart.get_node("Root/Battling/" + icon.to_pascal_case() + "/Cooldown").transition_pending.connect(Callable(character, "set_" + icon + "_cooldown"))
    character.state_chart.get_node("Root/Battling/" + icon.to_pascal_case() + "/Cooldown").transition_pending.connect(gray_out_icon.bind(icon))

func _exit_tree() -> void:
  for icon in icons:
    character.state_chart.get_node("Root/Battling/" + icon.to_pascal_case() + "/Available").state_entered.disconnect(refresh_icon.bind(icon))
    character.state_chart.get_node("Root/Battling/" + icon.to_pascal_case() + "/Cooldown").transition_pending.disconnect(Callable(character, "set_" + icon + "_cooldown"))
    character.state_chart.get_node("Root/Battling/" + icon.to_pascal_case() + "/Cooldown").transition_pending.disconnect(gray_out_icon.bind(icon))
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
      hp_bar.material.set_shader_parameter("edge_offset", -(1.0 - (value / float(max_hp))))
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
