shader_type canvas_item;

// Existing uniforms
uniform float time_scale = 0.5;
uniform float star_density = 640.0;
uniform vec2 quantize_resolution = vec2(64, 64);
uniform vec2 direction = vec2(0.0, 1.0);

// New uniforms for background
uniform vec4 background_colour : source_color = vec4(0.05, 0.05, 0.1, 1.0);
uniform sampler2D background_texture : filter_nearest;
uniform bool use_texture = false;
uniform bool monochromatic = false;

float hash(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

float blink_level(int size, float frame_num) {
  if (size == 1) {
    return floor(mod(frame_num, 2.0));
  } else if (size == 2) {
    float num = ceil(mod(frame_num, 4.0));
    return num > 2.0 ? 4.0 - num : num;
  }
  return 0.0;
}

vec3 blink_colour(int id) {
  if (monochromatic) return vec3(1.0);
  if (id == 0) return vec3(0.8, 0.0, 0.0);
  else if (id == 1) return vec3(1.0, 0.2, 0.8);
  else if (id == 2) return vec3(0.0, 0.8, 0.0);
  else if (id == 3) return vec3(0.4, 1.0, 0.4);
  else if (id == 4) return vec3(0.0, 0.0, 1.0);
  else if (id == 5) return vec3(0.0, 0.8, 1.0);
  else if (id == 6) return vec3(1.0, 1.0, 0.0);
  return vec3(0.0);
}

vec4 blink(vec2 p, vec2 resolution) {
  vec2 pixel_unit = vec2(1.0) / resolution;
  vec2 wh_ratio = vec2(resolution.x / resolution.y, 1.0);
  vec4 l = vec4(0.0);
  float wh_avg = (resolution.x + resolution.y) / resolution.y * 128.0;

  for (float i = 0.0; i < star_density; i += 1.0) {
    float z = hash(i * 0.1);
    l.rgb = blink_colour(int(hash(i * 0.4) * 7.0));
    float offset = hash(i * 0.5) * 3.0;
    int size = int(3.0 * z * z);
    int depth = (3 - size) * 100;
    float level = blink_level(size, TIME / 0.2 + offset) + 1.0;
    float inv_depth = 1.0 / float(depth);
    vec2 movement = direction * TIME * time_scale * inv_depth;
    vec2 pos = floor(fract(vec2(hash(i * 0.2), hash(i * 0.3)) + 100.0 * movement) * resolution) / resolution;
    pos -= mod(pos, pixel_unit);
    vec2 delta = (p - pos) * wh_ratio;
    float range = abs(delta.x) + abs(delta.y);
    float in_range = (level - 2.0) / wh_avg;
    float out_range = level / wh_avg;
    l.a = step(in_range, range) * step(range, out_range);
    if (l.a > 0.0) {
      return l;
    }
  }
  return vec4(0.0);
}

void fragment() {
  vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;

  // Quantize the UV coordinates
  vec2 quantized_uv = floor(UV * quantize_resolution) / quantize_resolution;

  // Get star color
  vec4 star_colour = blink(quantized_uv, resolution);

  // Get background color based on whether we're using texture or solid color
  vec4 bg = use_texture ? texture(background_texture, UV) : background_colour;

  // Mix background with stars
  COLOR = vec4(mix(bg.rgb, star_colour.rgb, star_colour.a), texture(TEXTURE, UV).a);
}
