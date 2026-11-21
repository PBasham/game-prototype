shader_type canvas_item;
// A light trim on the edge of the 3D body's picture (like the Scholar's drawn trim):
// a pixel with an empty neighbour is tinted toward the trim color.

uniform vec4 trim_color : source_color = vec4(0.73, 0.83, 0.97, 1.0);
uniform float strength = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (strength > 0.0 && c.a > 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float edge = 0.0;
		edge = max(edge, 1.0 - texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		edge = max(edge, 1.0 - texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		edge = max(edge, 1.0 - texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		edge = max(edge, 1.0 - texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		if (edge > 0.5) {
			c.rgb = mix(c.rgb, trim_color.rgb, strength);
		}
	}
	COLOR = c * COLOR;
}
