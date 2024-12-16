shader_type canvas_item;

// Uniforms to control the white edge
uniform float white_edge_width : hint_range(0.0, 1.0) = 0.05; // Width of the white edge
uniform float edge_offset : hint_range(-1.0, 1.0) = 0.1; // Offset of the edge
uniform vec2 texture_size; // Size of the texture
uniform vec4 colour_modulation : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Modulation color
void fragment() {
    // Sample the original texture color
    vec4 original_colour = texture(TEXTURE, UV);

    // Calculate the luminance of the original color
    float luminance = dot(original_colour.rgb, vec3(0.299, 0.587, 0.114));

    // Calculate the size of a single pixel in UV space
    vec2 pixel_size = 1.0 / texture_size;

    // Calculate the start and end of the white edge with offset, adjusted to snap to pixel boundaries
    float edge_start = clamp(1.0 - white_edge_width + edge_offset, 0.0, 1.0);
    float edge_end = clamp(1.0 + edge_offset, edge_start, 1.0);

    // Snap edge_start and edge_end to the nearest pixel boundary
    edge_start = floor(edge_start / pixel_size.x) * pixel_size.x;
    edge_end = ceil(edge_end / pixel_size.x) * pixel_size.x;

    // Determine if the current fragment is within the white edge region
    bool is_within_edge = UV.x >= edge_start && UV.x <= edge_end;

    // Use a step function for a crisp edge, applied only within the edge region
    float blend_factor = is_within_edge ? 1.0 : 0.0;

    // Modify blend_factor based on luminance
    if (luminance < 0.5) {
        blend_factor = 0.0; // Do not apply the white edge for low luminance
    }

    // Blend the original color with white based on the blend factor
    vec4 final_colour = mix(original_colour, vec4(1.0, 1.0, 1.0, original_colour.a), blend_factor);

    COLOR = final_colour * colour_modulation;
}