extends Control
class_name MemberCard

const BAR_EDGE_PX := 1.0
const BAR_EDGE_SHADER_CODE := "shader_type canvas_item;\nvoid fragment() { COLOR.rgb = vec3(1.0); }"

static var _bar_edge_shader: Shader

var member: Combatant
var _tween: Tween

@onready var _name_label: RichTextLabel = $Name
@onready var _hp_value: Label = $HP
@onready var _hp_bar: TextureProgressBar = $HPBar
@onready var _hp_ghost_bar: TextureProgressBar = $HPBarGhost

func _ready() -> void:
	add_bar_edge(_hp_bar)
	add_bar_edge(_hp_ghost_bar)

func setup(new_member: Combatant) -> void:
	member = new_member
	_name_label.text = _fit_name(member.combatant_name)
	_hp_bar.max_value = member.stats.max_health
	_hp_ghost_bar.max_value = member.stats.max_health
	_hp_bar.value = member.stats.health
	_hp_ghost_bar.value = member.stats.health
	_hp_value.text = "%d/%d" % [member.stats.health, member.stats.max_health]

func refresh() -> void:
	if not is_instance_valid(member):
		return
	_hp_value.text = "%d/%d" % [member.stats.health, member.stats.max_health]
	_hp_value.modulate = Color(1.0, 0.35, 0.4) if member.stats.health <= 0 else Color.WHITE
	_hp_bar.max_value = member.stats.max_health
	_hp_ghost_bar.max_value = member.stats.max_health
	if float(member.stats.health) != _hp_bar.value:
		_tween = ghost_update(_hp_bar, _hp_ghost_bar, float(member.stats.health), _tween)

func set_focused(focused: bool) -> void:
	modulate = Color.WHITE if focused else Color(0.5, 0.5, 0.5, 0.5)

func wait_tween() -> void:
	if _tween != null and _tween.is_running():
		await _tween.finished

func _fit_name(raw: String) -> String:
	var upper := raw.to_upper()
	var font := _name_label.get_theme_font("normal_font")
	if font == null:
		return upper
	var fsize := _name_label.get_theme_font_size("normal_font_size")
	var avail := _hp_value.position.x - _name_label.position.x - 1.0
	if font.get_string_size(upper, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x <= avail:
		return upper
	var cut := upper.length()
	while cut > 1 and font.get_string_size(upper.substr(0, cut) + ".", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > avail:
		cut -= 1
	return upper.substr(0, cut) + "."

static func ghost_update(main: TextureProgressBar, ghost: TextureProgressBar, value: float, existing: Tween) -> Tween:
	if existing != null and existing.is_valid():
		existing.kill()
	var t := main.create_tween()
	if value >= main.value:
		ghost.value = value
		t.tween_interval(0.2)
		t.tween_property(main, "value", value, 0.33).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		main.value = value
		t.tween_interval(0.2)
		t.tween_property(ghost, "value", value, 0.33).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return t

static func add_bar_edge(bar: TextureProgressBar) -> Control:
	var window := Control.new()
	window.clip_contents = true
	var clone := TextureProgressBar.new()
	clone.size = bar.size
	clone.fill_mode = bar.fill_mode
	clone.nine_patch_stretch = bar.nine_patch_stretch
	clone.texture_progress = bar.texture_progress
	var mat := ShaderMaterial.new()
	mat.shader = _shared_bar_edge_shader()
	clone.material = mat
	clone.max_value = 1.0
	clone.value = 1.0
	window.add_child(clone)
	bar.add_child(window)
	var vertical := bar.fill_mode == TextureProgressBar.FILL_TOP_TO_BOTTOM \
		or bar.fill_mode == TextureProgressBar.FILL_BOTTOM_TO_TOP
	var length := bar.size.y if vertical else bar.size.x
	var band_lo := 0.0
	var band_hi := length - BAR_EDGE_PX
	var update := func() -> void:
		var ratio := 0.0 if bar.max_value <= 0.0 else bar.value / bar.max_value
		window.visible = ratio > 0.0
		if vertical:
			var fill_top := clampf(floorf(bar.size.y * (1.0 - float(ratio))), band_lo, band_hi)
			window.position = Vector2(0.0, fill_top)
			window.size = Vector2(bar.size.x, BAR_EDGE_PX)
		else:
			var edge_x := clampf(ceilf(bar.size.x * float(ratio)) - BAR_EDGE_PX, band_lo, band_hi)
			window.position = Vector2(edge_x, 0.0)
			window.size = Vector2(BAR_EDGE_PX, bar.size.y)
		clone.position = -window.position
	bar.value_changed.connect(func(_v: float) -> void: update.call())
	bar.changed.connect(update)
	update.call()
	return window

static func _shared_bar_edge_shader() -> Shader:
	if _bar_edge_shader == null:
		_bar_edge_shader = Shader.new()
		_bar_edge_shader.code = BAR_EDGE_SHADER_CODE
	return _bar_edge_shader
