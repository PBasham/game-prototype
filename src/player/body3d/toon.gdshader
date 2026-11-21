shader_type spatial;
// Pixel art shading for the 3D body: unshaded, with the light worked out here so the
// colors are exactly the palette's shades (dark, middle, light), in hard bands.
render_mode unshaded, cull_back;

// Colors as the renderer needs them (Body3D converts: see its color_space).
uniform vec3 dark = vec3(0.3);
uniform vec3 mid = vec3(0.6);
uniform vec3 light = vec3(0.9);
// Direction toward the light, in view space (the camera looks straight at the side).
uniform vec3 light_dir = vec3(-0.35, 0.75, 0.55);
// 2: dark and light only. 3: dark, middle, light.
uniform int bands = 3;
// Where the bands split (0 = facing away from the light, 1 = facing it).
uniform vec2 cuts = vec2(0.42, 0.72);

void fragment() {
	float n = dot(normalize(NORMAL), normalize(light_dir)) * 0.5 + 0.5;
	vec3 c;
	if (bands <= 2) {
		c = n < cuts.x + (cuts.y - cuts.x) * 0.5 ? dark : light;
	} else {
		c = n < cuts.x ? dark : (n < cuts.y ? mid : light);
	}
	ALBEDO = c;
}
