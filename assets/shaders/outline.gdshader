shader_type canvas_item;

// Pixel-perfect 1px outline: a transparent texel next to an opaque texel
// becomes line_color. Hard alpha threshold, no blending, so it stays crisp
// at any zoom. Outline pixels outside the sprite's rect can't be drawn, so
// art that touches the frame edge gets a clipped outline there.

uniform vec4 line_color : source_color = vec4(1.0);
uniform bool diagonals = false;

const vec2 DIRS[8] = vec2[8](
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0)
);

void fragment() {
	if (texture(TEXTURE, UV).a < 0.5) {
		int count = diagonals ? 8 : 4;
		float hit = 0.0;
		for (int i = 0; i < count; i++) {
			vec2 uv = UV + DIRS[i] * TEXTURE_PIXEL_SIZE;
			if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
				continue;
			}
			hit += step(0.5, texture(TEXTURE, uv).a);
		}
		if (hit > 0.0) {
			COLOR = line_color;
		} else {
			COLOR.a = 0.0;
		}
	}
}
