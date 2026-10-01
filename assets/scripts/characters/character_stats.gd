extends Node
class_name CharacterStats

signal stat_changed(stat: int, value: int)

enum StatType {
	HEALTH,
	ATTACK,
	DEFENSE,
	AGILITY,
}
enum MaxStatType {
	HEALTH,
	ATTACK,
	DEFENSE,
}
const STAGE_STEP := 0.33
const STAGE_MAX := 3

var level := 1
var experience := 0
var _stages: Dictionary[String, int] = {
	"attack": 0,
	"defense": 0,
	"agility": 0,
}
var _stats: Dictionary[String, int] = {
	"health": 20,
	"attack": 1,
	"defense": 0,
	"agility": 10,
}
var _max_stats: Dictionary[String, int] = {
	"health": 20,
	"attack": 1,
	"defense": 0,
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
@export var can_go_negative := false
@export var health: int:
	get:
		return _stats["health"]
	set(value):
		var v := clampi(value, min_health(), max_health)
		_stats["health"] = v
		emit_signal("stat_changed", StatType.HEALTH, v)
@export var attack: int:
	get:
		return _stats["attack"]
	set(value):
		var v := clampi(value, 0, max_attack)
		_stats["attack"] = v
		emit_signal("stat_changed", StatType.ATTACK, v)
@export var max_defense: int:
	get:
		return _max_stats["defense"]
	set(value):
		_max_stats["defense"] = value
		emit_signal("stat_changed", StatType.DEFENSE, value)
@export var defense: int:
	get:
		return _stats["defense"]
	set(value):
		var v := clampi(value, 0, max_defense)
		_stats["defense"] = v
		emit_signal("stat_changed", StatType.DEFENSE, v)
@export var agility: int:
	get:
		return _stats["agility"]
	set(value):
		_stats["agility"] = value
		emit_signal("stat_changed", StatType.AGILITY, value)

func calculate_max_health() -> int:
	return 20 + (level * 16)

func min_health() -> int:
	return -max_health if can_go_negative else 0

func get_stage(stat: StatType) -> int:
	return _stages.get(_stage_key(stat), 0)

func modify_stage(stat: StatType, delta: int) -> int:
	var key := _stage_key(stat)
	if key == "":
		return 0
	_stages[key] = clampi(_stages[key] + delta, -STAGE_MAX, STAGE_MAX)
	return _stages[key]

func reset_stages() -> void:
	for key: String in _stages:
		_stages[key] = 0

func effective_attack() -> int:
	return maxi(0, roundi(attack * _stage_multiplier(_stages["attack"])))

func effective_defense() -> int:
	return maxi(0, roundi(defense * _stage_multiplier(_stages["defense"])))

func effective_agility() -> int:
	return maxi(1, roundi(agility * _stage_multiplier(_stages["agility"])))

func _stage_multiplier(stage: int) -> float:
	return 1.0 + STAGE_STEP * stage

func _stage_key(stat: StatType) -> String:
	match stat:
		StatType.ATTACK:
			return "attack"
		StatType.DEFENSE:
			return "defense"
		StatType.AGILITY:
			return "agility"
	return ""
