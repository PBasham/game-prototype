shader_type spatial;
// The light trim around the tunic, drawn like the Scholar's: a slightly bigger copy of
// the shape, inside out, in the trim color (an "inverted hull"). It shows only past
// the shape's edges, as a line around it. Grown in view space, so stretched shapes get
// the same line width.
render_mode unshaded, cull_front, skip_vertex_transform;

uniform vec3 color = vec3(0.73, 0.83, 0.97);
// Line width in art pixels.
uniform float width = 0.6;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	VERTEX += n * width;
	NORMAL = n;
}

void fragment() {
	ALBEDO = color;
}
