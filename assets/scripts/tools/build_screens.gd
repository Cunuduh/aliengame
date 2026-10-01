# Bakes the location screen scenes from screen_data.json and the massing plates.
# Run: godot --headless --path . --script res://assets/scripts/tools/build_screens.gd
extends SceneTree

const DATA_PATH := "res://assets/scripts/tools/screen_data.json"
const PLATE_DIR := "res://assets/sprites/screens/"
const OUT_DIR := "res://assets/scenes/screens/"
const CORA_SCENE := "res://assets/scenes/cora.tscn"
const PLAYER_UID := "uid://cy7o8s575kcm7"
const STATION_RADIUS := 18.0
const WALL := 32.0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var screens: Dictionary = json["screens"]
	for key: String in screens:
		_bake(key, screens[key])
	quit()


func _bake(key: String, cfg: Dictionary) -> void:
	var px: Array = cfg["px"]
	var w := int(px[0])
	var h := int(px[1])

	var root := Node2D.new()
	root.name = "Screen" + key.to_pascal_case()
	root.y_sort_enabled = true
	root.add_to_group("world", true)
	root.set_meta("screen_key", key)

	var plate := Sprite2D.new()
	plate.name = "Plate"
	plate.texture = load(PLATE_DIR + key + ".png")
	plate.centered = false
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(plate)

	var solids := StaticBody2D.new()
	solids.name = "Solids"
	solids.collision_layer = 1
	root.add_child(solids)
	var i := 0
	for rect: Array in cfg["collision"]:
		var x0 := float(rect[0])
		var y0 := float(rect[1])
		var x1 := float(rect[2])
		var y1 := float(rect[3])
		var shape := CollisionShape2D.new()
		shape.name = "Solid%d" % i
		var box := RectangleShape2D.new()
		box.size = Vector2(x1 - x0, y1 - y0)
		shape.shape = box
		shape.position = Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
		solids.add_child(shape)
		i += 1

	_add_walls(root, w, h)

	var stations := Node2D.new()
	stations.name = "Stations"
	root.add_child(stations)
	var s := 0
	for spot: Array in cfg["stations"]:
		var area := Area2D.new()
		area.name = "Station%d" % s
		area.position = Vector2(float(spot[0]), float(spot[1]))
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitorable = false
		area.set_script(load("res://assets/scripts/world/station_entrance.gd"))
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var circle := CircleShape2D.new()
		circle.radius = STATION_RADIUS
		shape.shape = circle
		area.add_child(shape)
		stations.add_child(area)
		s += 1

	_own_children(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var path := OUT_DIR + key + ".tscn"
	var err := ResourceSaver.save(packed, path)
	_append_cora(path, cfg, w, h)
	print("saved %s (%s), %dx%d, %d solids, %d stations"
		% [path, error_string(err), w, h, cfg["collision"].size(), cfg["stations"].size()])
	root.free()


func _add_walls(root: Node2D, w: int, h: int) -> void:
	var body := StaticBody2D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	root.add_child(body)
	var spans: Array = [
		[Vector2(w * 0.5, -WALL * 0.5), Vector2(w + WALL * 2, WALL)],
		[Vector2(w * 0.5, h + WALL * 0.5), Vector2(w + WALL * 2, WALL)],
		[Vector2(-WALL * 0.5, h * 0.5), Vector2(WALL, h + WALL * 2)],
		[Vector2(w + WALL * 0.5, h * 0.5), Vector2(WALL, h + WALL * 2)],
	]
	var i := 0
	for span: Array in spans:
		var shape := CollisionShape2D.new()
		shape.name = "Wall%d" % i
		var box := RectangleShape2D.new()
		box.size = span[1]
		shape.shape = box
		shape.position = span[0]
		body.add_child(shape)
		i += 1


func _own_children(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_own_children(child, root)


# cora.tscn's scripts reference autoloads, which don't exist in --script mode,
# so the instance is spliced into the saved text instead of being instantiated
func _append_cora(path: String, cfg: Dictionary, w: int, h: int) -> void:
	var spawn: Array = cfg["spawn"]
	var txt := FileAccess.get_file_as_string(path)
	var header_end := txt.find("\n")
	var header := txt.substr(0, header_end)
	var ext := "\n\n[ext_resource type=\"PackedScene\" uid=\"%s\" path=\"%s\" id=\"90_cora\"]" \
		% [PLAYER_UID, CORA_SCENE]
	txt = header + ext + txt.substr(header_end)
	txt += "\n[node name=\"Cora\" parent=\".\" instance=ExtResource(\"90_cora\")]\n"
	txt += "position = Vector2(%d, %d)\n" % [int(spawn[0]), int(spawn[1])]
	txt += "\n[node name=\"Camera2D\" type=\"Camera2D\" parent=\"Cora\"]\n"
	txt += "limit_left = 0\nlimit_top = 0\n"
	txt += "limit_right = %d\nlimit_bottom = %d\n" % [w, h]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()
