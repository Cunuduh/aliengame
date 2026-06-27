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
var _stats: Dictionary[String, int] = {
	"health": 20,
	"attack": 1,
}
var _max_stats: Dictionary[String, int] = {
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
