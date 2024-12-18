extends Control
class_name Lobby
@onready var care_package: CarePackage = $CarePackage
@onready var levels_cleared: Label = $LevelsCleared
func refresh_package() -> void:
  care_package.opened = false
  care_package.visible = true
  care_package.modulate.a = 1.0
  care_package.refresh()

func _on_next_area_body_entered(body: Node2D) -> void:
  if body.is_in_group("player") and care_package.opened and not care_package.visible:
    var player = Globals.player
    player.global_position.x = player.sprite.texture.get_width() / player.sprite.hframes / 2
    Globals.construct_battle_scene()
