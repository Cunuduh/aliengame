shader_type canvas_item;

uniform sampler2D noise_texture: repeat_enable;
uniform float noise_tiling = 2;
uniform float progress : hint_range(0, 1);
uniform float edge_thickness = 0.01;
uniform vec4 edge_colour : source_color;
uniform vec2 texture_size; // Uniform for the texture size

void fragment()
{
    vec4 original_texture = texture(TEXTURE, UV);
    vec2 quantized_UV = floor(UV * texture_size) / texture_size;
    vec4 dissolve_noise = texture(noise_texture, quantized_UV * noise_tiling);
    
    // Calculate a quantized vertical gradient
    float gradient_steps = texture_size.y; // Number of steps in the gradient equal to texture height in pixels
    float quantized_gradient_value = floor(UV.y * gradient_steps) / gradient_steps;
    float vertical_gradient = 1.0 - quantized_gradient_value;
    
    // Apply the quantized gradient to the dissolve noise
    dissolve_noise.rgb *= vertical_gradient; // Apply gradient to RGB, preserving alpha
    
    float remapped_dissolve = progress * (1.01  + edge_thickness) - edge_thickness;
    vec4 step1 = step(remapped_dissolve, dissolve_noise);
    vec4 step2 = step(remapped_dissolve + edge_thickness, dissolve_noise);
    
    vec4 edge_area = step1 - step2;
    edge_area.a = 1.0;
    
    edge_area.a *= original_texture.a;
    original_texture.a *= step1.r;
    
    vec4 coloured_edge = edge_area * edge_colour;
    
    vec4 combined_colour = mix(original_texture, coloured_edge, edge_area.r);
    COLOR = combined_colour;
}
	