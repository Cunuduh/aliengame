extends Resource
class_name Ability

var cooldown: float = 1.0
var icon: Texture2D
var name: String

func execute(player: Player) -> void:
  pass

func pre_execute(player: Player) -> void:
  pass

func exit(player: Player) -> void:
  pass