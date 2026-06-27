@tool
extends DialogicLayoutLayer

enum Alignments {LEFT, CENTER, RIGHT}
enum LimitedAlignments {LEFT=0, RIGHT=1}

@export_group('Text')
@export_subgroup("Text")
@export var text_alignment: Alignments = Alignments.LEFT
@export_subgroup('Size')
@export var text_use_global_size: bool = true
@export var text_custom_size: int = 15
@export_subgroup('Color')
@export var text_use_global_color: bool = true
@export var text_custom_color: Color = Color.WHITE
@export_subgroup('Fonts')
@export var use_global_fonts: bool = true
@export_file('*.ttf', '*.tres') var custom_normal_font: String = ""
@export_file('*.ttf', '*.tres') var custom_bold_font: String = ""
@export_file('*.ttf', '*.tres') var custom_italic_font: String = ""
@export_file('*.ttf', '*.tres') var custom_bold_italic_font: String = ""

@export_group('Box')
@export_subgroup("Box")
@export_file('*.tres') var box_panel: String = this_folder.path_join("default_stylebox.tres")
@export var box_modulate_global_color: bool = true
@export var box_modulate_custom_color: Color = Color(0.47247135639191, 0.31728461384773, 0.16592600941658)
@export var box_size: Vector2 = Vector2(600, 160)
@export var box_distance: int = 25

@export_group('Portrait')
@export_subgroup('Portrait')
@export var portrait_enabled: bool = true
@export var portrait_stretch_factor: float = 0.3
@export var portrait_position: LimitedAlignments = LimitedAlignments.LEFT
@export var portrait_bg_modulate: Color = Color(0, 0, 0, 0.5137255191803)


## Called by dialogic whenever export overrides might change
func _apply_export_overrides() -> void:
  ## FONT SETTINGS
  var dialog_text: DialogicNode_DialogText = %DialogicNode_DialogText
  dialog_text.alignment = text_alignment as DialogicNode_DialogText.Alignment

  var text_size: int = text_custom_size
  if text_use_global_size:
	text_size = get_global_setting(&'font_size', text_custom_size)

  dialog_text.add_theme_font_size_override(&"normal_font_size", text_size)
  dialog_text.add_theme_font_size_override(&"bold_font_size", text_size)
  dialog_text.add_theme_font_size_override(&"italics_font_size", text_size)
  dialog_text.add_theme_font_size_override(&"bold_italics_font_size", text_size)


  var text_color: Color = text_custom_color
  if text_use_global_color:
	text_color = get_global_setting(&'font_color', text_custom_color)
  dialog_text.add_theme_color_override(&"default_color", text_color)

  var normal_font: String = custom_normal_font
  if use_global_fonts and ResourceLoader.exists(get_global_setting(&'font', '') as String):
	normal_font = get_global_setting(&'font', '')

  if !normal_font.is_empty():
	dialog_text.add_theme_font_override(&"normal_font", load(normal_font) as Font)
  if !custom_bold_font.is_empty():
	dialog_text.add_theme_font_override(&"bold_font", load(custom_bold_font) as Font)
  if !custom_italic_font.is_empty():
	dialog_text.add_theme_font_override(&"italics_font", load(custom_italic_font) as Font)
  if !custom_bold_italic_font.is_empty():
	dialog_text.add_theme_font_override(&"bold_italics_font", load(custom_bold_italic_font) as Font)

  ## BOX SETTINGS
  var panel: PanelContainer = %Panel
  var portrait_panel: Panel = %PortraitPanel
  if box_modulate_global_color:
	panel.self_modulate = get_global_setting(&'bg_color', box_modulate_custom_color)
  else:
	panel.self_modulate = box_modulate_custom_color
  panel.size = box_size
  panel.position = Vector2(-box_size.x/2, -box_size.y-box_distance)
  portrait_panel.size_flags_stretch_ratio = portrait_stretch_factor

  var stylebox: StyleBox = load(box_panel)
  panel.add_theme_stylebox_override(&'panel', stylebox)

  ## PORTRAIT SETTINGS
  if portrait_enabled:
	var portrait_background_color: ColorRect = %PortraitBackgroundColor
	portrait_background_color.color = portrait_bg_modulate
	portrait_panel.get_parent().move_child(portrait_panel, portrait_position)
	portrait_panel.visible = true
  else:
	portrait_panel.visible = false
