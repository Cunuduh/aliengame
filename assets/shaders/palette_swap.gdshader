shader_type canvas_item;

uniform vec4 original_colour1 : source_color;
uniform vec4 replacement_colour1 : source_color;
uniform vec4 original_colour2 : source_color;
uniform vec4 replacement_colour2 : source_color;
uniform vec4 original_colour3 : source_color;
uniform vec4 replacement_colour3 : source_color;
uniform vec4 original_colour4 : source_color;
uniform vec4 replacement_colour4 : source_color;
uniform float tolerance : hint_range(0.0, 1.0) = 0.05;

vec4 swap_colour(vec4 colour, vec4 original, vec4 replacement) {
  if (distance(colour, original) < tolerance) {
    return replacement;
  }
  return colour;
}

void fragment() {
  vec4 colour = texture(TEXTURE, UV);

  colour = swap_colour(colour, original_colour1, replacement_colour1);
  colour = swap_colour(colour, original_colour2, replacement_colour2);
  colour = swap_colour(colour, original_colour3, replacement_colour3);
  colour = swap_colour(colour, original_colour4, replacement_colour4);

  COLOR = colour;
}
