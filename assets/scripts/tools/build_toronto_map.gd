# Bakes the Toronto downtown room scenes from toronto_map_data.json (flattened OSM grid).
# Run: godot --headless --path . --script res://assets/scripts/tools/build_toronto_map.gd
extends SceneTree

const TILE := 16
const SCALE := 2  # data tables below are in pre-scale master tiles
const WIDTHS := {4: 8, 6: 10, 8: 14, 10: 18}  # asphalt tiles after scaling
const DATA_PATH := "res://assets/scripts/tools/toronto_map_data.json"
const ATLAS_PATH := "res://assets/sprites/tilesets/kenney_rpg_urban/tilemap_packed.png"
const TILESET_PATH := "res://assets/resources/toronto_tileset.tres"
const CORA_SCENE := "res://assets/scenes/cora.tscn"
const EXIT_SCRIPT := "res://assets/scripts/world/room_exit.gd"
const TILESET_UID := "uid://c7q2v8xk4m3ns"

const GRASS := Vector2i(1, 1)
const PAVE := Vector2i(9, 1)
const PATH_TAN := Vector2i(1, 4)
const ASPHALT := Vector2i(1, 15)
const DASH := Vector2i(1, 16)
const CROSS := Vector2i(0, 16)
const DOOR := Vector2i(15, 9)
const DOOR_WIDE := Vector2i(15, 10)
const TREES: Array[Vector2i] = [Vector2i(16, 10), Vector2i(17, 10), Vector2i(21, 10), Vector2i(22, 10)]
const TALL_TREE_TOP := Vector2i(16, 8)
const TALL_TREE_TRUNK := Vector2i(16, 9)

const SOLID_TILES: Array[Vector2i] = [
	Vector2i(16, 10), Vector2i(17, 10), Vector2i(21, 10), Vector2i(22, 10), Vector2i(16, 9),
	Vector2i(17, 0), Vector2i(18, 0), Vector2i(19, 0),
	Vector2i(17, 2), Vector2i(18, 2), Vector2i(19, 2),
	Vector2i(17, 3), Vector2i(18, 3), Vector2i(19, 3),
	Vector2i(17, 4), Vector2i(18, 4), Vector2i(19, 4),
	Vector2i(17, 6), Vector2i(18, 6), Vector2i(19, 6),
	Vector2i(17, 7), Vector2i(18, 7), Vector2i(19, 7),
	Vector2i(15, 9), Vector2i(15, 10),
]

# rooms are cut from the master grid; "rot": 90 lays the room out rotated so its
# main corridor runs horizontally (streets/buildings re-laid, sprites stay upright)
const ROOMS: Dictionary = {
	"annex": {
		"rect": Rect2i(0, 0, 51, 157), "rot": 0, "spawn": Vector2i(25, 65),
		"scene": "res://assets/scenes/toronto_annex.tscn", "uid": "uid://c7q2v8xk4m3n1",
	},
	"campus": {
		"rect": Rect2i(51, 0, 45, 157), "rot": 0, "spawn": Vector2i(75, 65),
		"scene": "res://assets/scenes/toronto_campus.tscn", "uid": "uid://c7q2v8xk4m3n2",
	},
	"queens_park": {
		"rect": Rect2i(96, 0, 71, 157), "rot": 0, "spawn": Vector2i(163, 81),
		"scene": "res://assets/scenes/toronto_queens_park.tscn", "uid": "uid://dq0g0ehudnepa",
	},
	"yonge": {
		"rect": Rect2i(167, 0, 38, 157), "rot": 90, "spawn": Vector2i(193, 13),
		"scene": "res://assets/scenes/toronto_yonge.tscn", "uid": "uid://c7q2v8xk4m3n4",
	},
}

# vertical cuts between adjacent rooms, at master x (all lie on/along streets or parkland)
const CUTS: Array = [
	["annex", "campus", 51],
	["campus", "queens_park", 96],
	["queens_park", "yonge", 167],
]

# label -> aerial sprite in assets/sprites/landmarks (unlisted landmarks keep 9-patch tiles)
const LANDMARK_SPRITE_DIR := "res://assets/sprites/landmarks/"
const LANDMARK_SPRITES := {
	"Royal Ontario Museum": "rom",
	"Gardiner Museum": "gardiner",
	"Victoria College": "victoria_college",
	"Robarts Library": "robarts",
	"Trinity College": "trinity",
	"Hart House": "hart_house",
	"Sidney Smith": "sidney_smith",
	"Legislative Assembly": "legislative",
	"University College": "university_college",
	"Gerstein Library": "gerstein",
	"Knox College": "knox",
	"Convocation Hall": "convocation_hall",
	"Sandford Fleming": "sandford_fleming",
	"Medical Sciences": "medical_sciences",
	"Toronto General Hospital": "tgh",
}

# rect, red roof, label text, label master tile pos (master coords)
const LANDMARKS: Array = [
	[Rect2i(97, 14, 13, 16), true, "Royal Ontario Museum", Vector2i(97, 31)],
	[Rect2i(122, 16, 8, 8), false, "Gardiner Museum", Vector2i(121, 25)],
	[Rect2i(134, 16, 12, 12), true, "Victoria College", Vector2i(134, 29)],
	[Rect2i(35, 42, 10, 17), true, "Robarts Library", Vector2i(34, 60)],
	[Rect2i(72, 44, 12, 12), false, "Trinity College", Vector2i(72, 57)],
	[Rect2i(74, 68, 12, 8), false, "Hart House", Vector2i(74, 77)],
	[Rect2i(38, 93, 8, 8), false, "Sidney Smith", Vector2i(37, 102)],
	[Rect2i(109, 100, 12, 14), true, "Legislative Assembly", Vector2i(107, 115)],
	[Rect2i(68, 108, 12, 8), true, "University College", Vector2i(67, 107)],
	[Rect2i(87, 107, 8, 9), false, "Gerstein Library", Vector2i(86, 105)],
	[Rect2i(58, 118, 7, 7), true, "Knox College", Vector2i(57, 126)],
	[Rect2i(62, 128, 8, 8), false, "Convocation Hall", Vector2i(60, 137)],
	[Rect2i(72, 128, 5, 8), true, "Sandford Fleming", Vector2i(71, 126)],
	[Rect2i(85, 122, 10, 12), false, "Medical Sciences", Vector2i(84, 135)],
	[Rect2i(122, 149, 40, 6), true, "Toronto General Hospital", Vector2i(126, 148)],
	[Rect2i(154, 76, 8, 9), true, "", Vector2i.ZERO],  # U Condo, 1080 Bay
]

# tree zones (master coords)
const ZONES: Array = [
	Rect2i(107, 68, 16, 69),   # Queen's Park
	Rect2i(86, 14, 6, 45),     # Philosopher's Walk
	Rect2i(72, 14, 13, 24),    # Varsity
	Rect2i(56, 68, 9, 19),     # back campus
	Rect2i(57, 118, 38, 19),   # front campus
]

const PATHS: Array = [
	Rect2i(88, 14, 2, 45),     # Philosopher's Walk
	Rect2i(114, 68, 2, 32),    # Queen's Park
]

const EXTRA_LABELS: Array = [
	["Varsity Centre", Vector2i(72, 25), "park", false],
	["Philosopher's Walk", Vector2i(85, 48), "park", false],
	["Queen's Park", Vector2i(108, 88), "park", false],
	["Back Campus", Vector2i(55, 78), "park", false],
	["University of Toronto", Vector2i(57, 108), "place", true],
	["U Condo", Vector2i(148, 71), "home", true],
	["1080 Bay St", Vector2i(149, 73), "home", false],
]

const STATIONS: Array = [
	["StGeorge", Vector2i(46, 13)],
	["Museum", Vector2i(109, 31)],
	["Bay", Vector2i(162, 13)],
	["BloorYonge", Vector2i(192, 13)],
	["Wellesley", Vector2i(192, 91)],
	["QueensPark", Vector2i(108, 137)],
]

const HOME_MARKER_TILE := Vector2i(158, 76)

const STREET_LABELS := {
	"bloor": "Bloor St W", "charles": "Charles St W", "sussex": "Sussex Ave",
	"st_mary": "St Mary St", "harbord": "Harbord St", "hoskin": "Hoskin Ave",
	"irwin": "Irwin Ave", "st_joseph": "St Joseph St", "willcocks": "Willcocks St",
	"wellesley": "Wellesley St W", "breadalbane": "Breadalbane St",
	"ursula_franklin": "Ursula Franklin St", "grosvenor": "Grosvenor St",
	"grenville": "Grenville St", "college": "College St", "spadina": "Spadina Ave",
	"huron": "Huron St", "st_george": "St George St", "devonshire": "Devonshire Pl",
	"kings_college": "King's College Rd", "queens_park_n": "Queen's Park",
	"qp_cres_w": "Queen's Park Cres W", "qp_cres_e": "Queen's Park Cres E",
	"university": "University Ave", "st_thomas": "St Thomas St", "bay": "Bay St",
	"st_nicholas": "St Nicholas St", "yonge": "Yonge St",
}

const STREET_LABEL_COLOR := Color("8a919c")
const PLACE_LABEL_COLOR := Color("4a5058")
const PARK_LABEL_COLOR := Color("4f9e5f")
const STATION_COLOR := Color("4a5058")
const HOME_COLOR := Color("f2b632")
const HOME_BORDER := Color("a87b12")

var master_streets: Dictionary = {}
var master_h: int = 0
var rooms: Dictionary = {}
var cuts: Array = []
var landmarks: Array = []
var zones: Array[Rect2i] = []
var paths: Array[Rect2i] = []
var stations: Array = []
var extra_labels: Array = []
var home_marker_tile := Vector2i.ZERO

var room_rect: Rect2i
var room_rot: int = 0
var streets: Dictionary = {}
var map_w: int = 0
var map_h: int = 0
var grid: PackedByteArray = []  # 0 open, 1 sidewalk, 2 asphalt, 3 reserved, 4 building
var park_zones: Array[Rect2i] = []
var rng := RandomNumberGenerator.new()
var body_font: Font
var bold_font: Font
var tile_set: TileSet

var ground: TileMapLayer
var pavement: TileMapLayer
var road: TileMapLayer
var scenery: TileMapLayer
var buildings: TileMapLayer


func _init() -> void:
	body_font = load("res://assets/fonts/cozy-quill.otf")
	bold_font = load("res://assets/fonts/cozy-quill-bold.otf")
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	master_streets = json["streets"]
	master_h = int(json["height"]) * SCALE + 6 * SCALE  # room for the hospital row south of College
	for key: String in master_streets:
		var s: Dictionary = master_streets[key]
		s["pos"] = int(s["pos"]) * SCALE
		s["start"] = int(s["start"]) * SCALE
		s["end"] = int(s["end"]) * SCALE
		s["width"] = WIDTHS[int(s["width"])]
	for key: String in ["spadina", "yonge", "university"]:
		master_streets[key]["end"] = master_h
	for room: String in ROOMS:
		var cfg: Dictionary = ROOMS[room]
		rooms[room] = {
			"rect": _sr(cfg["rect"]), "rot": cfg["rot"], "spawn": _sp(cfg["spawn"]),
			"scene": cfg["scene"], "uid": cfg["uid"],
		}
	for cut: Array in CUTS:
		cuts.append([cut[0], cut[1], int(cut[2]) * SCALE])
	for lm: Array in LANDMARKS:
		landmarks.append([_sr(lm[0]), lm[1], lm[2], _sp(lm[3])])
	for zone: Rect2i in ZONES:
		zones.append(_sr(zone))
	for path: Rect2i in PATHS:
		paths.append(_sr(path))
	for spot: Array in STATIONS:
		stations.append([spot[0], _sp(spot[1])])
	for extra: Array in EXTRA_LABELS:
		extra_labels.append([extra[0], _sp(extra[1]), extra[2], extra[3]])
	home_marker_tile = _sp(HOME_MARKER_TILE)
	tile_set = _build_tileset()
	for room: String in rooms:
		_bake_room(room)
	quit()


func _sp(p: Vector2i) -> Vector2i:
	return p * SCALE


func _sr(r: Rect2i) -> Rect2i:
	return Rect2i(r.position * SCALE, r.size * SCALE)


func _bake_room(room: String) -> void:
	var cfg: Dictionary = rooms[room]
	room_rect = cfg["rect"]
	room_rot = int(cfg["rot"])
	map_w = room_rect.size.x if room_rot == 0 else room_rect.size.y
	map_h = room_rect.size.y if room_rot == 0 else room_rect.size.x
	grid.clear()
	grid.resize(map_w * map_h)
	park_zones.clear()
	rng.seed = hash(room)
	streets = {}
	for key: String in master_streets:
		var s := _t_street(master_streets[key])
		if not s.is_empty():
			streets[key] = s

	var root := Node2D.new()
	root.name = "Toronto" + room.to_pascal_case()
	root.y_sort_enabled = true
	root.add_to_group("world", true)

	ground = _make_layer("Ground", root)
	pavement = _make_layer("Pavement", root)
	road = _make_layer("Road", root)
	scenery = _make_layer("Scenery", root)
	buildings = _make_layer("Buildings", root)

	_paint_ground()
	_paint_streets()
	_reserve_zones()
	_paint_filler_blocks()
	_paint_landmarks(root)
	_paint_parks()
	_add_labels(root)
	_add_stations(root)
	_add_home_marker(root)
	_add_exits(room, root)
	_add_map_edge(root)

	_own_children(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, cfg["scene"])
	_patch_uid(cfg["scene"], "[gd_scene", cfg["uid"])
	_append_cora(room)
	print("saved %s (%s), %dx%d tiles" % [cfg["scene"], error_string(err), map_w, map_h])
	root.free()


# ---- master -> room-local transforms -------------------------------------

func _t_pt(p: Vector2i) -> Vector2i:
	var l := p - room_rect.position
	if room_rot == 0:
		return l
	return Vector2i(room_rect.size.y - 1 - l.y, l.x)


func _t_rect(r: Rect2i) -> Rect2i:
	var a := _t_pt(r.position)
	var b := _t_pt(r.position + r.size - Vector2i.ONE)
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	return Rect2i(lo, Vector2i(abs(b.x - a.x) + 1, abs(b.y - a.y) + 1))


func _t_street(s: Dictionary) -> Dictionary:
	var master_ew: bool = s["orient"] == "EW"
	var pos := int(s["pos"])
	var half := int(s["width"]) / 2 + _sidewalk_width(s)
	var lo := int(s["start"])
	var hi := int(s["end"])
	if master_ew:
		if pos + half <= room_rect.position.y or pos - half >= room_rect.end.y:
			return {}
		lo = maxi(lo, room_rect.position.x)
		hi = mini(hi, room_rect.end.x)
	else:
		if pos + half <= room_rect.position.x or pos - half >= room_rect.end.x:
			return {}
		lo = maxi(lo, room_rect.position.y)
		hi = mini(hi, room_rect.end.y)
	if hi - lo < 2:
		return {}
	var a := _t_pt(Vector2i(lo, pos) if master_ew else Vector2i(pos, lo))
	var b := _t_pt(Vector2i(hi - 1, pos) if master_ew else Vector2i(pos, hi - 1))
	var room_ew := master_ew if room_rot == 0 else not master_ew
	return {
		"orient": "EW" if room_ew else "NS",
		"width": s["width"],
		"pos": a.y if room_ew else a.x,
		"start": mini(a.x, b.x) if room_ew else mini(a.y, b.y),
		"end": (maxi(a.x, b.x) if room_ew else maxi(a.y, b.y)) + 1,
	}


func _clip_to_room(r: Rect2i) -> Rect2i:
	var c := r.intersection(room_rect)
	return Rect2i() if c.size.x <= 0 or c.size.y <= 0 else _t_rect(c)


func _in_room_pt(p: Vector2i) -> bool:
	return room_rect.has_point(p)


# ---- tileset --------------------------------------------------------------

func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(ATLAS_PATH)
	atlas.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(atlas, 0)
	for x: int in 27:
		for y: int in 18:
			atlas.create_tile(Vector2i(x, y))
	var square := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	for coords: Vector2i in SOLID_TILES:
		var td := atlas.get_tile_data(coords, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, square)
	ResourceSaver.save(ts, TILESET_PATH)
	_patch_uid(TILESET_PATH, "[gd_resource", TILESET_UID)
	ts.take_over_path(TILESET_PATH)
	return ts


func _make_layer(layer_name: String, root: Node2D) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(layer)
	return layer


# ---- grid helpers ---------------------------------------------------------

func _cell(x: int, y: int) -> int:
	return grid[y * map_w + x]


func _set_grid(x: int, y: int, v: int) -> void:
	grid[y * map_w + x] = v


func _sidewalk_width(s: Dictionary) -> int:
	var w := int(s["width"])
	return 4 if w >= 14 else (3 if w >= 10 else 2)


func _band(s: Dictionary, extra: int = 0) -> Vector2i:
	var w := int(s["width"]) + extra * 2
	var lo := int(s["pos"]) - w / 2
	return Vector2i(lo, lo + w)


func _in_asphalt(s: Dictionary, x: int, y: int) -> bool:
	var b := _band(s)
	var lo := int(s["start"])
	var hi := int(s["end"])
	if s["orient"] == "EW":
		return y >= b.x and y < b.y and x >= lo and x < hi
	return x >= b.x and x < b.y and y >= lo and y < hi


# ---- painting -------------------------------------------------------------

func _paint_ground() -> void:
	for y: int in map_h:
		for x: int in map_w:
			ground.set_cell(Vector2i(x, y), 0, GRASS)


func _paint_streets() -> void:
	for key: String in streets:
		var s: Dictionary = streets[key]
		_fill_street(pavement, s, _band(s, _sidewalk_width(s)), PAVE, 1)
	for key: String in streets:
		_fill_street(road, streets[key], _band(streets[key]), ASPHALT, 2)
	for key: String in streets:
		_paint_center_line(key)
	_paint_crosswalks()
	_paint_curbs()


func _fill_street(layer: TileMapLayer, s: Dictionary, band: Vector2i, tile: Vector2i, mark: int) -> void:
	for a: int in range(band.x, band.y):
		for b: int in range(int(s["start"]), int(s["end"])):
			var p := Vector2i(b, a) if s["orient"] == "EW" else Vector2i(a, b)
			if p.x < 0 or p.y < 0 or p.x >= map_w or p.y >= map_h:
				continue
			layer.set_cell(p, 0, tile)
			if _cell(p.x, p.y) < mark:
				_set_grid(p.x, p.y, mark)


func _paint_center_line(street_key: String) -> void:
	var s: Dictionary = streets[street_key]
	var ew: bool = s["orient"] == "EW"
	var alt := 0 if ew else TileSetAtlasSource.TRANSFORM_TRANSPOSE
	var w := int(s["width"])
	var offsets: Array[int] = [0]
	if w >= 10:
		offsets = [-w / 4, 0, w / 4]
	for off: int in offsets:
		var pos := int(s["pos"]) + off
		for c: int in range(int(s["start"]) + 1, int(s["end"]) - 1):
			var p := Vector2i(c, pos) if ew else Vector2i(pos, c)
			if p.x < 0 or p.y < 0 or p.x >= map_w or p.y >= map_h:
				continue
			if _crossed_by_other(street_key, p.x, p.y):
				continue
			road.set_cell(p, 0, DASH, alt)


func _crossed_by_other(street_key: String, x: int, y: int) -> bool:
	var s: Dictionary = streets[street_key]
	for key: String in streets:
		if key == street_key or streets[key]["orient"] == s["orient"]:
			continue
		if _in_asphalt(streets[key], x, y):
			return true
	return false


func _paint_crosswalks() -> void:
	for ka: String in streets:
		var a: Dictionary = streets[ka]
		if a["orient"] != "EW":
			continue
		for kb: String in streets:
			var b: Dictionary = streets[kb]
			if b["orient"] != "NS":
				continue
			if int(a["pos"]) < int(b["start"]) or int(a["pos"]) >= int(b["end"]):
				continue
			if int(b["pos"]) < int(a["start"]) or int(b["pos"]) >= int(a["end"]):
				continue
			var row_band := _band(a)
			var col_band := _band(b)
			for y: int in range(row_band.x, row_band.y):
				for x: int in [col_band.x - 2, col_band.x - 1, col_band.y, col_band.y + 1]:
					_try_crosswalk(ka, kb, x, y, 0)
			for x: int in range(col_band.x, col_band.y):
				for y: int in [row_band.x - 2, row_band.x - 1, row_band.y, row_band.y + 1]:
					_try_crosswalk(kb, ka, x, y, TileSetAtlasSource.TRANSFORM_TRANSPOSE)


func _try_crosswalk(along_key: String, other_key: String, x: int, y: int, alt: int) -> void:
	if x < 0 or y < 0 or x >= map_w or y >= map_h:
		return
	if not _in_asphalt(streets[along_key], x, y) or _in_asphalt(streets[other_key], x, y):
		return
	if _crossed_by_other(along_key, x, y):
		return
	road.set_cell(Vector2i(x, y), 0, CROSS, alt)


func _paint_curbs() -> void:
	for y: int in map_h:
		for x: int in map_w:
			if pavement.get_cell_atlas_coords(Vector2i(x, y)) != PAVE:
				continue
			var asp_n := y > 0 and _cell(x, y - 1) == 2
			var asp_s := y < map_h - 1 and _cell(x, y + 1) == 2
			var asp_w := x > 0 and _cell(x - 1, y) == 2
			var asp_e := x < map_w - 1 and _cell(x + 1, y) == 2
			var tile := PAVE
			if asp_n and asp_w:
				tile = Vector2i(8, 0)
			elif asp_n and asp_e:
				tile = Vector2i(10, 0)
			elif asp_s and asp_w:
				tile = Vector2i(8, 2)
			elif asp_s and asp_e:
				tile = Vector2i(10, 2)
			elif asp_n:
				tile = Vector2i(9, 0)
			elif asp_s:
				tile = Vector2i(9, 2)
			elif asp_w:
				tile = Vector2i(8, 1)
			elif asp_e:
				tile = Vector2i(10, 1)
			if tile != PAVE:
				pavement.set_cell(Vector2i(x, y), 0, tile)


# ---- zones, blocks, buildings ---------------------------------------------

func _reserve(rect: Rect2i) -> void:
	for y: int in range(maxi(rect.position.y, 0), mini(rect.end.y, map_h)):
		for x: int in range(maxi(rect.position.x, 0), mini(rect.end.x, map_w)):
			if _cell(x, y) == 0:
				_set_grid(x, y, 3)


func _reserve_zones() -> void:
	for zone: Rect2i in zones:
		var local := _clip_to_room(zone)
		if local != Rect2i():
			park_zones.append(local)
			_reserve(local)
	for lm: Array in landmarks:
		var local := _clip_to_room(lm[0])
		if local != Rect2i():
			_reserve(local)


func _paint_filler_blocks() -> void:
	var seen := PackedByteArray()
	seen.resize(map_w * map_h)
	for y: int in map_h:
		for x: int in map_w:
			if _cell(x, y) != 0 or seen[y * map_w + x] != 0:
				continue
			var region := _flood(x, y, seen)
			if region != Rect2i():
				_fill_block(region)


func _flood(sx: int, sy: int, seen: PackedByteArray) -> Rect2i:
	var stack: Array[Vector2i] = [Vector2i(sx, sy)]
	seen[sy * map_w + sx] = 1
	var lo := Vector2i(sx, sy)
	var hi := Vector2i(sx, sy)
	var touches_edge := false
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
		if p.x == 0 or p.y == 0 or p.x == map_w - 1 or p.y == map_h - 1:
			touches_edge = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := p + d
			if n.x < 0 or n.y < 0 or n.x >= map_w or n.y >= map_h:
				continue
			if _cell(n.x, n.y) != 0 or seen[n.y * map_w + n.x] != 0:
				continue
			seen[n.y * map_w + n.x] = 1
			stack.push_back(n)
	if touches_edge:
		return Rect2i()
	var rect := Rect2i(lo, hi - lo + Vector2i.ONE)
	if rect.size.x < 8 or rect.size.y < 8:
		return Rect2i()
	return rect


func _fill_block(block: Rect2i) -> void:
	var inner := block.grow(-1)
	var nx := clampi(inner.size.x / 10, 1, 4)
	var ny := clampi(inner.size.y / 10, 1, 4)
	var placed := 0
	for iy: int in ny:
		for ix: int in nx:
			if rng.randf() < 0.12:
				continue
			var x0 := inner.position.x + ix * inner.size.x / nx
			var x1 := inner.position.x + (ix + 1) * inner.size.x / nx
			var y0 := inner.position.y + iy * inner.size.y / ny
			var y1 := inner.position.y + (iy + 1) * inner.size.y / ny
			var r := Rect2i(x0, y0, x1 - x0 - 2, y1 - y0 - 2)
			if r.size.x < 4 or r.size.y < 4:
				continue
			if not _rect_open(r.grow(1)):
				continue
			_paint_building(r, rng.randi() % 2 == 0)
			placed += 1
	if placed == 0:
		var size := Vector2i(mini(inner.size.x - 2, 12), mini(inner.size.y - 2, 12))
		var r := Rect2i(inner.position + (inner.size - size) / 2, size)
		if r.size.x >= 4 and r.size.y >= 4 and _rect_open(r.grow(1)):
			_paint_building(r, rng.randi() % 2 == 0)


func _rect_open(rect: Rect2i) -> bool:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if x < 0 or y < 0 or x >= map_w or y >= map_h:
				return false
			if _cell(x, y) != 0:
				return false
	return true


func _paint_building(rect: Rect2i, red: bool, door: bool = true) -> void:
	var base := 0 if red else 4
	var x1 := rect.end.x - 1
	var y1 := rect.end.y - 1
	for y: int in range(maxi(rect.position.y, 0), mini(rect.end.y, map_h)):
		for x: int in range(maxi(rect.position.x, 0), mini(rect.end.x, map_w)):
			var col := 17 if x == rect.position.x else (19 if x == x1 else 18)
			var row := base if y == rect.position.y else (base + 3 if y == y1 else base + 2)
			buildings.set_cell(Vector2i(x, y), 0, Vector2i(col, row))
			_set_grid(x, y, 4)
	if door and rect.size.x >= 3 and y1 < map_h:
		var door_tile := DOOR_WIDE if rect.size.x >= 8 else DOOR
		buildings.set_cell(Vector2i(rect.position.x + rect.size.x / 2, y1), 0, door_tile)


func _paint_landmarks(root: Node2D) -> void:
	var holder := Node2D.new()
	holder.name = "Landmarks"
	root.add_child(holder)
	for lm: Array in landmarks:
		var local := _clip_to_room(lm[0])
		if local == Rect2i():
			continue
		if LANDMARK_SPRITES.has(lm[2]):
			_add_landmark_sprite(holder, String(lm[2]), local)
		else:
			_paint_building(local, lm[1])


func _add_landmark_sprite(holder: Node2D, label_text: String, local: Rect2i) -> void:
	var tex: Texture2D = load(LANDMARK_SPRITE_DIR + String(LANDMARK_SPRITES[label_text]) + ".png")
	var body := StaticBody2D.new()
	body.name = label_text.to_pascal_case()
	body.position = (Vector2(local.position) + Vector2(local.size) * 0.5) * TILE
	if room_rot != 0:
		body.rotation_degrees = 90.0
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	body.add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = tex.get_size() - Vector2(4, 4)
	shape.shape = rect_shape
	body.add_child(shape)
	holder.add_child(body)
	for y: int in range(local.position.y, local.end.y):
		for x: int in range(local.position.x, local.end.x):
			_set_grid(x, y, 4)


func _paint_parks() -> void:
	for path: Rect2i in paths:
		var local := _clip_to_room(path)
		for y: int in range(local.position.y, local.end.y):
			for x: int in range(local.position.x, local.end.x):
				pavement.set_cell(Vector2i(x, y), 0, PATH_TAN)
	for zone: Rect2i in park_zones:
		var count := zone.get_area() / 14
		for i: int in count:
			var p := Vector2i(
				rng.randi_range(zone.position.x, zone.end.x - 1),
				rng.randi_range(zone.position.y, zone.end.y - 1)
			)
			if p.x >= map_w or p.y >= map_h:
				continue
			if _cell(p.x, p.y) != 3 or pavement.get_cell_source_id(p) != -1:
				continue
			if rng.randf() < 0.4 and p.y > zone.position.y and _cell(p.x, p.y - 1) == 3 \
					and pavement.get_cell_source_id(p + Vector2i.UP) == -1 \
					and scenery.get_cell_source_id(p + Vector2i.UP) == -1:
				scenery.set_cell(p, 0, TALL_TREE_TRUNK)
				scenery.set_cell(p + Vector2i.UP, 0, TALL_TREE_TOP)
			else:
				scenery.set_cell(p, 0, TREES[rng.randi() % TREES.size()])


# ---- labels, stations, marker, exits --------------------------------------

func _label(text: String, pos: Vector2, color: Color, bold: bool = false, rot: float = 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.rotation_degrees = rot
	var settings := LabelSettings.new()
	settings.font = bold_font if bold else body_font
	settings.font_size = 13 if bold else 10
	settings.font_color = color
	settings.shadow_color = Color(1, 1, 1, 0.6)
	settings.shadow_offset = Vector2(1, 1)
	label.label_settings = settings
	return label


func _add_labels(root: Node2D) -> void:
	var holder := Node2D.new()
	holder.name = "Labels"
	root.add_child(holder)
	for key: String in streets:
		if not STREET_LABELS.has(key):
			continue
		var s: Dictionary = streets[key]
		var band := _band(s, _sidewalk_width(s))
		var fractions: Array = [0.5]
		if int(s["end"]) - int(s["start"]) > 100:
			fractions = [0.25, 0.75]
		for f: float in fractions:
			var along := (int(s["start"]) + (int(s["end"]) - int(s["start"])) * f) * TILE
			if s["orient"] == "EW":
				holder.add_child(_label(STREET_LABELS[key], Vector2(along - 40, (band.x - 2) * TILE), STREET_LABEL_COLOR), true)
			else:
				holder.add_child(_label(STREET_LABELS[key], Vector2((band.x - 1) * TILE, along + 40), STREET_LABEL_COLOR, false, -90.0), true)
	for lm: Array in landmarks:
		if lm[2] == "" or not _in_room_pt(lm[3]):
			continue
		holder.add_child(_label(lm[2], Vector2(_t_pt(lm[3])) * TILE, PLACE_LABEL_COLOR), true)
	for extra: Array in extra_labels:
		if not _in_room_pt(extra[1]):
			continue
		var color: Color = PARK_LABEL_COLOR if extra[2] == "park" else (HOME_BORDER if extra[2] == "home" else PLACE_LABEL_COLOR)
		holder.add_child(_label(extra[0], Vector2(_t_pt(extra[1])) * TILE, color, extra[3]), true)


func _add_stations(root: Node2D) -> void:
	var holder := Node2D.new()
	holder.name = "Stations"
	root.add_child(holder)
	var circle := PackedVector2Array()
	for i: int in 12:
		circle.append(Vector2.from_angle(TAU * i / 12) * 13.0)
	for spot: Array in stations:
		if not _in_room_pt(spot[1]):
			continue
		var station := Node2D.new()
		station.name = spot[0]
		station.position = Vector2(_t_pt(spot[1])) * TILE + Vector2(8, 8)
		var poly := Polygon2D.new()
		poly.name = "Disc"
		poly.polygon = circle
		poly.color = STATION_COLOR
		station.add_child(poly)
		var m := _label("M", Vector2(-4, -8), Color.WHITE, true)
		m.name = "M"
		m.label_settings.font_size = 8
		station.add_child(m)
		holder.add_child(station)


func _add_home_marker(root: Node2D) -> void:
	if not _in_room_pt(home_marker_tile):
		return
	var marker := Node2D.new()
	marker.name = "HomeMarker"
	marker.position = Vector2(_t_pt(home_marker_tile)) * TILE - Vector2(0, 28)
	var points := PackedVector2Array([
		Vector2(0, 21), Vector2(-13, 0), Vector2(0, -27), Vector2(13, 0),
	])
	var poly := Polygon2D.new()
	poly.name = "Diamond"
	poly.polygon = points
	poly.color = HOME_COLOR
	marker.add_child(poly)
	var outline := Line2D.new()
	outline.name = "Outline"
	outline.points = points
	outline.closed = true
	outline.width = 2.0
	outline.default_color = HOME_BORDER
	marker.add_child(outline)
	var anim := Animation.new()
	anim.length = 1.6
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:position:y"))
	var base_y := marker.position.y
	anim.track_insert_key(track, 0.0, base_y - 3.0)
	anim.track_insert_key(track, 0.8, base_y + 3.0)
	anim.track_insert_key(track, 1.6, base_y - 3.0)
	var lib := AnimationLibrary.new()
	lib.add_animation("bob", anim)
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	anim_player.add_animation_library("", lib)
	anim_player.autoplay = "bob"
	marker.add_child(anim_player)
	root.add_child(marker)


func _add_exits(room: String, root: Node2D) -> void:
	var holder := Node2D.new()
	holder.name = "Exits"
	root.add_child(holder)
	var exit_script: Script = load(EXIT_SCRIPT)
	for cut: Array in cuts:
		var cx := int(cut[2])
		var is_left: bool = cut[0] == room
		var is_right: bool = cut[1] == room
		if not is_left and not is_right:
			continue
		var other: String = cut[1] if is_left else cut[0]
		for key: String in master_streets:
			var s: Dictionary = master_streets[key]
			if s["orient"] != "EW":
				continue
			if int(s["start"]) > cx - 10 or int(s["end"]) < cx + 10:
				continue
			var band := _band(s, _sidewalk_width(s))
			var master_rect := Rect2i(cx - 4 if is_left else cx, band.x, 4, band.y - band.x)
			var inter := master_rect.intersection(room_rect)
			if inter.size.x <= 0 or inter.size.y <= 0:
				continue
			var local := _t_rect(inter)
			var spawn_master := Vector2i(cx + 10 if is_left else cx - 11, int(s["pos"]))
			var target_cfg: Dictionary = rooms[other]
			var exit := Area2D.new()
			exit.name = "%s_%s" % [key.to_pascal_case(), other.to_pascal_case()]
			exit.set_script(exit_script)
			exit.set("target_scene", target_cfg["scene"])
			exit.set("spawn_position", _spawn_px(other, spawn_master))
			exit.position = Vector2(local.position * TILE) + Vector2(local.size * TILE) * 0.5
			var shape := CollisionShape2D.new()
			shape.name = "Shape"
			var rect_shape := RectangleShape2D.new()
			rect_shape.size = Vector2(local.size * TILE)
			shape.shape = rect_shape
			exit.add_child(shape)
			holder.add_child(exit)


func _spawn_px(room: String, master_tile: Vector2i) -> Vector2:
	var cfg: Dictionary = rooms[room]
	var saved_rect := room_rect
	var saved_rot := room_rot
	room_rect = cfg["rect"]
	room_rot = int(cfg["rot"])
	var p := _t_pt(master_tile)
	room_rect = saved_rect
	room_rot = saved_rot
	return Vector2(p) * TILE + Vector2(8, 8)


func _add_map_edge(root: Node2D) -> void:
	var body := StaticBody2D.new()
	body.name = "MapEdge"
	root.add_child(body)
	var w := map_w * TILE
	var h := map_h * TILE
	var walls: Array = [
		[Vector2(w * 0.5, -16), Vector2(w * 0.5 + 32, 16)],
		[Vector2(w * 0.5, h + 16), Vector2(w * 0.5 + 32, 16)],
		[Vector2(-16, h * 0.5), Vector2(16, h * 0.5 + 32)],
		[Vector2(w + 16, h * 0.5), Vector2(16, h * 0.5 + 32)],
	]
	for i: int in walls.size():
		var shape := CollisionShape2D.new()
		shape.name = "Wall%d" % (i + 1)
		var rect := RectangleShape2D.new()
		rect.size = Vector2(walls[i][1]) * 2.0
		shape.shape = rect
		shape.position = walls[i][0]
		body.add_child(shape)


func _own_children(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_own_children(child, root)
		else:
			for sub: Node in child.get_children():
				if sub.owner == null:
					sub.owner = root


# cora.tscn's scripts reference autoloads, which don't exist in --script mode,
# so the instance is spliced into the saved text instead of being instantiated
func _append_cora(room: String) -> void:
	var cfg: Dictionary = rooms[room]
	var scene_path: String = cfg["scene"]
	var spawn := _spawn_px(room, Vector2i(cfg["spawn"]))
	var txt := FileAccess.get_file_as_string(scene_path)
	var header_end := txt.find("\n")
	var header := txt.substr(0, header_end)
	var ext := "\n\n[ext_resource type=\"PackedScene\" uid=\"uid://cy7o8s575kcm7\" path=\"%s\" id=\"90_cora\"]" % CORA_SCENE
	txt = header + ext + txt.substr(header_end)
	txt += "\n[node name=\"Cora\" parent=\".\" instance=ExtResource(\"90_cora\")]\n"
	txt += "position = Vector2(%d, %d)\n" % [int(spawn.x), int(spawn.y)]
	txt += "\n[node name=\"Camera2D\" type=\"Camera2D\" parent=\"Cora\"]\n"
	txt += "limit_left = 0\nlimit_top = 0\n"
	txt += "limit_right = %d\nlimit_bottom = %d\n" % [map_w * TILE, map_h * TILE]
	var f := FileAccess.open(scene_path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()


func _patch_uid(path: String, tag: String, uid: String) -> void:
	var txt := FileAccess.get_file_as_string(path)
	if txt.begins_with(tag) and not txt.get_slice("\n", 0).contains("uid="):
		txt = txt.replace(tag, "%s uid=\"%s\"" % [tag, uid])
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(txt)
		f.close()
