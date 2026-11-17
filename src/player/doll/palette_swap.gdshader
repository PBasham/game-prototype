shader_type canvas_item;
// Palette swap for paper doll parts: any pixel whose color is in row 0 of `swap`
// becomes the color below it in row 1. Everything else is untouched.

uniform sampler2D swap : filter_nearest;
uniform int count = 0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	for (int i = 0; i < count; i++) {
		vec4 s = texelFetch(swap, ivec2(i, 0), 0);
		if (distance(c.rgb, s.rgb) < 0.006) {
			c.rgb = texelFetch(swap, ivec2(i, 1), 0).rgb;
			break;
		}
	}
	COLOR = c * COLOR;
}
