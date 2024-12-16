shader_type canvas_item;

uniform float texture_width;
uniform float texture_height;
uniform float frame_width;
uniform float frame_height;

void vertex() {
    UV *= vec2(frame_width / texture_width, frame_height / texture_height);
    UV += INSTANCE_CUSTOM.xy;
    float visible = INSTANCE_CUSTOM.z;
    COLOR.a *= visible;
}