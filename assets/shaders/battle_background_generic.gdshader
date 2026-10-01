shader_type canvas_item;

uniform vec4 background_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 colour_modulation : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float line_thickness : hint_range(0.0, 10.0) = 2.0;
uniform float grid_spacing = 50.0;
uniform vec4 grid_colour : source_color = vec4(0.0, 0.5, 0.5, 1.0);
uniform float speed : hint_range(-100.0, 100.0) = 20.0;
uniform float grid_angle : hint_range(0.0, 360.0) = 45.0;

uniform float second_line_thickness : hint_range(0.0, 10.0) = 1.0;
uniform float second_grid_spacing = 25.0;
uniform vec4 second_grid_colour : source_color = vec4(0.0, 0.25, 0.25, 0.5);
uniform float second_speed : hint_range(-100.0, 100.0) = 10.0;
uniform float second_grid_angle : hint_range(0.0, 360.0) = 225.0;

uniform float pinch_strength : hint_range(-0.5, 0.5) = 0.18;
uniform vec2 pinch_center = vec2(0.5, 0.5);

void fragment() {
  vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
  float aspect = resolution.x / resolution.y;
  vec2 offset = UV - pinch_center;
  offset.x *= aspect;
  float r2 = dot(offset, offset);
  offset *= 1.0 + pinch_strength * r2;
  offset.x /= aspect;
  vec2 frag = (offset + pinch_center) * resolution;

  vec2 ddx = dFdx(frag);
  vec2 ddy = dFdy(frag);

  COLOR = background_colour;

  vec2 second_dir = vec2(cos(radians(second_grid_angle)), sin(radians(second_grid_angle)));
  vec2 second_pos = frag + second_dir * (TIME * second_speed);
  bool s_vline = floor(second_pos.x / second_grid_spacing) != floor((second_pos.x + second_line_thickness * ddx.x) / second_grid_spacing);
  bool s_hline = floor(second_pos.y / second_grid_spacing) != floor((second_pos.y + second_line_thickness * ddy.y) / second_grid_spacing);
  if (s_vline || s_hline) {
    COLOR = second_grid_colour;
  }

  vec2 dir = vec2(cos(radians(grid_angle)), sin(radians(grid_angle)));
  vec2 pos = frag + dir * (TIME * speed);
  bool vline = floor(pos.x / grid_spacing) != floor((pos.x + line_thickness * ddx.x) / grid_spacing);
  bool hline = floor(pos.y / grid_spacing) != floor((pos.y + line_thickness * ddy.y) / grid_spacing);
  if (vline || hline) {
    COLOR = mix(COLOR, grid_colour, grid_colour.a);
  }

  COLOR *= colour_modulation;
}