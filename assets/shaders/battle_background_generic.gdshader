shader_type canvas_item;

uniform vec4 background_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 colour_modulation : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float line_thickness : hint_range(0.0, 10.0) = 2.0;
uniform float grid_spacing = 50.0;
uniform vec4 grid_colour : source_color = vec4(0.0, 0.5, 0.5, 1.0);
uniform float speed : hint_range(-100.0, 100.0) = 20.0;

uniform float second_line_thickness : hint_range(0.0, 10.0) = 1.0;
uniform float second_grid_spacing = 25.0;
uniform vec4 second_grid_colour : source_color = vec4(0.0, 0.25, 0.25, 0.5);
uniform float second_speed : hint_range(-100.0, 100.0) = 10.0;

void fragment() {
  COLOR = background_colour;
  vec2 second_pos = FRAGCOORD.xy - vec2(TIME * second_speed, TIME * second_speed);
  float second_modX = mod(second_pos.x, second_grid_spacing);
  float second_modY = mod(second_pos.y, second_grid_spacing);
  if (second_modX < second_line_thickness || second_modY < second_line_thickness) {
    COLOR = second_grid_colour;
  } else {
    COLOR = background_colour;
  }
  vec2 pos = FRAGCOORD.xy + vec2(TIME * speed, TIME * speed);
  float modX = mod(pos.x, grid_spacing);
  float modY = mod(pos.y, grid_spacing);
  if (modX < line_thickness || modY < line_thickness) {
    COLOR = mix(COLOR, grid_colour, grid_colour.a);
  }
  COLOR *= colour_modulation;
}