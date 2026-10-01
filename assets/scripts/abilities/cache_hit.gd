extends Ability
class_name CacheHit

func _init() -> void:
	name = "cache_hit"
	targets_allies = true
	link_bonus = 1

func apply_effect(battle: BattleScene, _user: Combatant, target: Combatant) -> void:
	await battle.spawn_hit_effect("buff", target, BattleScene.OUTLINE_QUEUE_COLOR)
	battle.queue_cache_hit(target)
	await battle.get_tree().create_timer(0.8).timeout
