shader_type spatial;
// Pixel art shading for the 3D body: unshaded, with the light worked out here so the
// colors are exactly the shades Body3D picks from the palette (deep shadow, shadow,
// base, light; hue shifted), in hard bands.
render_mode unshaded, cull_back;

// Colors as the renderer needs them (Body3D converts: see its color_space).
uniform vec3 deep = vec3(0.2);
uniform vec3 dark = vec3(0.35);
uniform vec3 mid = vec3(0.6);
uniform vec3 light = vec3(0.9);
// Direction toward the light, in view space (the camera looks straight at the side).
uniform vec3 light_dir = vec3(0.55, 0.7, 0.3);
// 2: shadow and light. 3: shadow, base, light. 4: deep shadow too.
uniform int bands = 4;
// Where the bands split (0 = facing away from the light, 1 = facing it).
uniform vec3 cuts = vec3(0.3, 0.5, 0.78);
// Flat faces (each face one shade, like pixel art panels) instead of smooth.
uniform bool flat_faces = true;

void fragment() {
	vec3 nrm = normalize(NORMAL);
	if (flat_faces) {
		nrm = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (nrm.z < 0.0) {
			nrm = -nrm;
		}
	}
	float n = dot(nrm, normalize(light_dir)) * 0.5 + 0.5;
	vec3 c;
	if (bands <= 2) {
		c = n < cuts.y ? dark : light;
	} else if (bands == 3) {
		c = n < cuts.y ? dark : (n < cuts.z ? mid : light);
	} else {
		c = n < cuts.x ? deep : (n < cuts.y ? dark : (n < cuts.z ? mid : light));
	}
	ALBEDO = c;
}
