extends Node
class_name CharacterStats

signal stat_changed(stat: int, value: int)

enum StatType {
  HEALTH,
  ATTACK,
}
enum MaxStatType {
  HEALTH,
  ATTACK,
}
var level := 1
var experience := 0
var _stats: Dictionary = {
  "health": 20,
  "attack": 1,
}
var _max_stats = {
  "health": 20,
  "attack": 1,
}
@export var max_health: int:
  get:
    return _max_stats["health"]
  set(value):
    _max_stats["health"] = value
    emit_signal("stat_changed", StatType.HEALTH, value)
@export var max_attack: int:
  get:
    return _max_stats["attack"]
  set(value):
    _max_stats["attack"] = value
    emit_signal("stat_changed", StatType.ATTACK, value)
@export var health: int:
  get:
    return _stats["health"]
  set(value):
    var v := clampi(value, 0, max_health)
    _stats["health"] = v
    emit_signal("stat_changed", StatType.HEALTH, v)
@export var attack: int:
  get:
    return _stats["attack"]
  set(value):
    var v := clampi(value, 0, max_attack)
    _stats["attack"] = v
    emit_signal("stat_changed", StatType.ATTACK, v)

func calculate_max_health() -> int:
  return 20 + (level * 16)

static func sort_by_stat(array: Array, stat: StatType) -> void:
  var stat_name = StatType.keys()[stat].to_lower()
  for i in range(1, len(array)):
    var key = array[i]
    var j = i - 1
    while j >= 0 and array[j].stats.stats[stat_name] < key.stats.stats[stat_name]:
      array[j + 1] = array[j]
      j -= 1
    array[j + 1] = key
