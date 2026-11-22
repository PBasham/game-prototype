shader_type canvas_item;
// The light overlay (multiply): fades from the previous light map to the new one over
// LightMap.fade_seconds, so moving lights and changes slide instead of popping.
render_mode blend_mul;

uniform sampler2D prev_tex : filter_linear, repeat_disable;
uniform float fade = 1.0;
// Sizes of the new and previous maps (tiles), and where the new one's corner is on the
// previous one (tiles), so they line up when the lit area moved.
uniform vec2 cur_size = vec2(1.0);
uniform vec2 prev_size = vec2(1.0);
uniform vec2 shift = vec2(0.0);

void fragment() {
	vec4 cur = texture(TEXTURE, UV);
	vec4 prev = cur;
	if (fade < 1.0) {
		vec2 pp = (UV * cur_size + shift) / prev_size;
		if (pp.x >= 0.0 && pp.y >= 0.0 && pp.x <= 1.0 && pp.y <= 1.0) {
			prev = texture(prev_tex, pp);
		}
	}
	COLOR = mix(prev, cur, fade);
}
