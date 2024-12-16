extends CharacterBody2D
class_name Combatant

@onready var state_chart: StateChart = $StateChart
@onready var stats: CharacterStats = $CharacterStats
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite
@export var combatant_name := "Combatant"

var in_battle := false
