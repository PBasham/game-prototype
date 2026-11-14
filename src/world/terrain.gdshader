shader_type canvas_item;
render_mode unshaded;

// Draws one 32x32-tile chunk of terrain per pixel, so blocks blend instead of
// showing a tile grid:
// - The solid outline is a smoothed version of the block grid plus noise, so slopes
//   and corners come out diagonal and rounded.
// - Where two materials meet, the boundary is shifted by noise so it's wavy.
// - Exposed tops get a lit rim, undersides a soft shadow. No dark outlines.
// - Grass covers the top of grass blocks, drapes down sides, and pokes blades up.
// - Background walls show where there is no block.
//
// `tiles` holds the chunk plus a 2-tile border: R = block terrain slot, G = wall slot
// (0 = none). Slot N uses the 64x64 strip cell at x = (N - 1) * 64 in each strip.

uniform sampler2D tiles : filter_nearest, repeat_disable;
uniform sampler2D materials : filter_nearest, repeat_disable;
uniform sampler2D overlays : filter_nearest, repeat_disable;
uniform sampler2D wall_tex : filter_nearest, repeat_disable;
uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform float grass_slots[16];
uniform vec3 grass_0 : source_color;
uniform vec3 grass_1 : source_color;
uniform vec3 grass_2 : source_color;
uniform vec3 grass_3 : source_color;
uniform vec3 grass_4 : source_color;
uniform vec3 grass_5 : source_color;
uniform vec2 origin;

const float T = 8.0;
const float TEXP = 64.0;
const int B = 2;
const int SIZE = 36;

int blk(ivec2 t) {
	return int(round(texelFetch(tiles, clamp(t, ivec2(0), ivec2(SIZE - 1)), 0).r * 255.0));
}

int wal(ivec2 t) {
	return int(round(texelFetch(tiles, clamp(t, ivec2(0), ivec2(SIZE - 1)), 0).g * 255.0));
}

float occ_b(ivec2 t) { return blk(t) > 0 ? 1.0 : 0.0; }
float occ_w(ivec2 t) { return wal(t) > 0 ? 1.0 : 0.0; }

vec4 nzv(vec2 p) { return texture(noise_tex, (mod(p, TEXP) + 0.5) / TEXP); }

float nz(vec2 p) {
	vec4 n = nzv(p);
	return (n.r - 0.5) * 0.45 + (n.g - 0.5) * 0.15;
}

float field_b(vec2 p) {
	vec2 f = (p + 0.5) / T - 0.5 + float(B);
	vec2 i = floor(f);
	vec2 fr = smoothstep(0.0, 1.0, f - i);
	ivec2 ii = ivec2(i);
	float a = mix(occ_b(ii), occ_b(ii + ivec2(1, 0)), fr.x);
	float b = mix(occ_b(ii + ivec2(0, 1)), occ_b(ii + ivec2(1, 1)), fr.x);
	return mix(a, b, fr.y);
}

float field_w(vec2 p) {
	vec2 f = (p + 0.5) / T - 0.5 + float(B);
	vec2 i = floor(f);
	vec2 fr = smoothstep(0.0, 1.0, f - i);
	ivec2 ii = ivec2(i);
	float a = mix(occ_w(ii), occ_w(ii + ivec2(1, 0)), fr.x);
	float b = mix(occ_w(ii + ivec2(0, 1)), occ_w(ii + ivec2(1, 1)), fr.x);
	return mix(a, b, fr.y);
}

bool solid(vec2 p) { return field_b(p) + nz(p) > 0.5; }

ivec2 tile_of(vec2 p) { return ivec2(floor(p / T)) + ivec2(B); }

int mat_at(vec2 p) {
	vec4 n = nzv(p);
	vec2 off = round((n.ba - 0.5) * 9.0);
	int m = blk(tile_of(p + off));
	if (m > 0) return m;
	ivec2 t = tile_of(p);
	m = blk(t);
	if (m > 0) return m;
	m = blk(t + ivec2(0, 1));
	if (m > 0) return m;
	m = blk(t + ivec2(1, 0));
	if (m > 0) return m;
	m = blk(t + ivec2(-1, 0));
	if (m > 0) return m;
	m = blk(t + ivec2(0, -1));
	if (m > 0) return m;
	m = blk(t + ivec2(1, 1));
	if (m > 0) return m;
	return max(blk(t + ivec2(-1, 1)), 1);
}

int wall_at(vec2 p) {
	ivec2 t = tile_of(p);
	int w = wal(t);
	if (w > 0) return w;
	w = wal(t + ivec2(0, 1));
	if (w > 0) return w;
	w = wal(t + ivec2(1, 0));
	if (w > 0) return w;
	w = wal(t + ivec2(-1, 0));
	if (w > 0) return w;
	return wal(t + ivec2(0, -1));
}

vec4 strip(sampler2D s, int slot, vec2 p) {
	ivec2 q = ivec2(mod(p, TEXP));
	return texelFetch(s, ivec2((slot - 1) * 64 + q.x, q.y), 0);
}

float hash(float x) { return fract(sin(x * 12.9898 + 78.233) * 43758.5453); }

void fragment() {
	vec2 p = floor((UV * float(SIZE) - float(B)) * T);
	vec2 wp = origin + p;
	vec4 col = vec4(0.0);
	if (solid(p)) {
		int m = mat_at(p);
		vec3 c = strip(materials, m, p).rgb;
		vec4 ov = strip(overlays, m, p);
		c = mix(c, ov.rgb, ov.a);
		int top = 99;
		for (int k = 1; k <= 9; k++) {
			if (!solid(p - vec2(0.0, float(k)))) { top = k; break; }
		}
		int below = 99;
		for (int k = 1; k <= 3; k++) {
			if (!solid(p + vec2(0.0, float(k)))) { below = k; break; }
		}
		bool lo = !solid(p - vec2(1.0, 0.0));
		bool ro = !solid(p + vec2(1.0, 0.0));
		bool grass = grass_slots[m] > 0.5;
		int lim = 3 + int(hash(wp.x) * 2.0);
		int side_lim = 4 + int(hash(wp.x * 0.37 + floor(wp.y / 3.0)) * 4.0);
		if (grass && top <= lim) {
			c = top == 1 ? grass_5 : (top == 2 ? grass_4 : (top < lim ? grass_3 : grass_1));
		} else if (grass && (lo || ro) && below > 1 && top - 1 < side_lim) {
			c = top - 1 > 2 ? grass_2 : grass_3;
		} else {
			if (top == 1) {
				c = mix(c, min(c * 1.4, vec3(1.0)), 0.6);
			} else if (top == 2) {
				c = mix(c, c * 1.12, 0.5);
			}
			if (lo) {
				c *= 1.05;
			} else if (ro) {
				c *= 0.9;
			}
		}
		if (below == 1) {
			c = mix(c, c * 0.45, 0.6);
		} else if (below == 2) {
			c = mix(c, c * 0.6, 0.35);
		} else if (below == 3) {
			c = mix(c, c * 0.8, 0.2);
		}
		col = vec4(c, 1.0);
	} else {
		bool done = false;
		for (int k = 1; k <= 5; k++) {
			vec2 q = p + vec2(0.0, float(k));
			if (solid(q)) {
				if (grass_slots[mat_at(q)] > 0.5) {
					int tall = hash(wp.x * 1.31 + 7.0) > 0.25 ? 1 + int(hash(wp.x * 2.17 + 3.0) * 5.0) : 0;
					if (k <= tall) {
						col = vec4(k == tall ? grass_5 : (k > 1 ? grass_4 : grass_3), 1.0);
						done = true;
					}
				}
				break;
			}
		}
		if (!done && field_w(p) + nz(p) * 0.6 > 0.5) {
			int w = wall_at(p);
			if (w > 0) {
				col = vec4(strip(wall_tex, w, p).rgb, 1.0);
			}
		}
	}
	COLOR = col;
}
