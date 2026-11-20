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
// - Built blocks and walls (planks) skip all of that: crisp square edges with a dark
//   edge line and a lit top row, like hand-placed tiles.
//
// `tiles` holds the chunk plus a 2-tile border: R = block terrain slot, G = wall slot
// (0 = none). Slot N uses the CELL x CELL strip cell at x = (N - 1) * CELL in each strip.
//
// Detail: art is drawn at DET art pixels per world pixel (a block is 8 world pixels, so
// 16 art pixels across). `p` steps in 1/DET world pixels; shapes, rims and grass are
// still measured in world pixels, so they look the same, just finer.

uniform sampler2D tiles : filter_nearest, repeat_disable;
uniform sampler2D materials : filter_nearest, repeat_disable;
uniform sampler2D overlays : filter_nearest, repeat_disable;
uniform sampler2D wall_tex : filter_nearest, repeat_disable;
uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform float grass_slots[16];
uniform float built_slots[16];
uniform float built_walls[16];
uniform float overhang_slots[16];
// Background walls are drawn this much darker than blocks (and a little greyer), so
// the front layer stands out. 1 = same as the art.
uniform float wall_shade = 0.75;
uniform float wall_desat = 0.2;
uniform vec3 grass_0 : source_color;
uniform vec3 grass_1 : source_color;
uniform vec3 grass_2 : source_color;
uniform vec3 grass_3 : source_color;
uniform vec3 grass_4 : source_color;
uniform vec3 grass_5 : source_color;
uniform vec2 origin;

const float T = 8.0;
const float TEXP = 64.0;
const float DET = 2.0;
const int CELL = 128;
const int B = 2;
const int SIZE = 36;

int blk(ivec2 t) {
	return int(round(texelFetch(tiles, clamp(t, ivec2(0), ivec2(SIZE - 1)), 0).r * 255.0));
}

int wal(ivec2 t) {
	return int(round(texelFetch(tiles, clamp(t, ivec2(0), ivec2(SIZE - 1)), 0).g * 255.0));
}

bool is_built(int m) { return m > 0 && built_slots[m] > 0.5; }

// Natural material at a tile (built blocks count as none).
int nat(ivec2 t) {
	int m = blk(t);
	return is_built(m) ? 0 : m;
}

float occ_b(ivec2 t) { return blk(t) > 0 ? 1.0 : 0.0; }
float occ_w(ivec2 t) { return wal(t) > 0 ? 1.0 : 0.0; }

// The noise is per world pixel, read with texelFetch: with detailed art `p` moves in
// half pixels, and sampling at a texel's edge made some GPUs pick either side, which
// speckled the dirt / stone mixing and the edges into a checkerboard.
vec4 nzv(vec2 p) { return texelFetch(noise_tex, ivec2(mod(floor(p), TEXP)), 0); }

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

// Natural material for a solid pixel, or 0 if only built blocks are nearby.
int mat_at(vec2 p) {
	vec4 n = nzv(p);
	vec2 off = round((n.ba - 0.5) * 9.0);
	int m = nat(tile_of(p + off));
	if (m > 0) return m;
	ivec2 t = tile_of(p);
	m = nat(t);
	if (m > 0) return m;
	m = nat(t + ivec2(0, 1));
	if (m > 0) return m;
	m = nat(t + ivec2(1, 0));
	if (m > 0) return m;
	m = nat(t + ivec2(-1, 0));
	if (m > 0) return m;
	m = nat(t + ivec2(0, -1));
	if (m > 0) return m;
	m = nat(t + ivec2(1, 1));
	if (m > 0) return m;
	return nat(t + ivec2(-1, 1));
}

vec3 shade_wall(vec3 c) {
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(c, vec3(grey), wall_desat) * wall_shade;
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
	ivec2 q = ivec2(mod(floor(p * DET), float(CELL)));
	return texelFetch(s, ivec2((slot - 1) * CELL + q.x, q.y), 0);
}

// Crisp square tile with a dark edge line where it meets open space. `cut` rounds an
// outer corner by one pixel, only where the diagonal neighbor is open too.
vec4 built_px(sampler2D tex, int slot, vec2 p, bool up, bool down, bool left, bool right, float edge_dark, bool cut, bvec4 diag) {
	vec2 lp = p - floor(p / T) * T;
	if (overhang_slots[slot] > 0.5 && edge_dark < 0.5) {
		left = false;  // the run's end sticks out instead (overhang_px)
		right = false;
	}
	if (cut && ((up && left && diag.x && lp.x < 1.0 && lp.y < 1.0) || (up && right && diag.y && lp.x >= 7.0 && lp.y < 1.0)
			|| (down && left && diag.z && lp.x < 1.0 && lp.y >= 7.0) || (down && right && diag.w && lp.x >= 7.0 && lp.y >= 7.0))) {
		return vec4(0.0);
	}
	vec3 c = strip(tex, slot, p).rgb;
	bool edge = (up && lp.y < 1.0) || (down && lp.y >= 7.0) || (left && lp.x < 1.0) || (right && lp.x >= 7.0);
	if (edge) {
		c *= edge_dark;
	} else {
		if (up && lp.y < 2.0) c = mix(c, min(c * 1.3, vec3(1.0)), 0.5);
		if (down && lp.y >= 6.0) c *= 0.8;
		if (left && lp.x < 2.0) c *= 1.06;
		if (right && lp.x >= 6.0) c *= 0.88;
	}
	return vec4(c, 1.0);
}

// A wall edge only counts as open where there is neither a wall nor a block.
bool wall_open(ivec2 t) { return wal(t) == 0 && blk(t) == 0; }

float hash(float x) { return fract(sin(x * 12.9898 + 78.233) * 43758.5453); }

void fragment() {
	vec2 p = floor((UV * float(SIZE) - float(B)) * T * DET) / DET;
	vec2 wp = origin + floor(p);
	vec4 col = vec4(0.0);
	ivec2 here_t = tile_of(p);
	int here = blk(here_t);
	int m = 0;
	if (!is_built(here) && solid(p)) {
		m = mat_at(p);
	}
	bool drew = false;
	if (is_built(here)) {
		bvec4 diag = bvec4(blk(here_t + ivec2(-1, -1)) == 0, blk(here_t + ivec2(1, -1)) == 0,
			blk(here_t + ivec2(-1, 1)) == 0, blk(here_t + ivec2(1, 1)) == 0);
		col = built_px(materials, here, p, blk(here_t + ivec2(0, -1)) == 0, blk(here_t + ivec2(0, 1)) == 0,
			blk(here_t + ivec2(-1, 0)) == 0, blk(here_t + ivec2(1, 0)) == 0, 0.38, true, diag);
		drew = col.a > 0.5;
	} else if (m > 0) {
		drew = true;
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
	}
	// A built block's end sticking out into this open tile (log cabin corners).
	if (!drew && here == 0) {
		vec2 lp = p - floor(p / T) * T;
		int lm = blk(here_t + ivec2(-1, 0));
		int rm = blk(here_t + ivec2(1, 0));
		float ln = is_built(lm) ? overhang_slots[lm] : 0.0;
		float rn = is_built(rm) ? overhang_slots[rm] : 0.0;
		int sm = 0;
		bool tip = false;
		if (lp.x < ln) { sm = lm; tip = lp.x >= ln - 1.0; }
		else if (lp.x >= 8.0 - rn) { sm = rm; tip = lp.x < 9.0 - rn; }
		if (sm > 0 && lp.y >= 1.0 && lp.y < 7.0 && !(tip && (lp.y < 2.0 || lp.y >= 6.0))) {
			vec3 c = strip(materials, sm, p).rgb;
			col = vec4(tip ? c * 0.85 : c, 1.0);
			drew = true;
		}
	}
	if (!drew) {
		bool done = false;
		// Grass blades poke up into open tiles, not into rooms (a built back wall).
		int wb = wal(here_t);
		bool indoors = wb > 0 && built_walls[wb] > 0.5;
		for (int k = 1; k <= (indoors ? 0 : 5); k++) {
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
		int wh = wal(here_t);
		if (!done && wh > 0 && built_walls[wh] > 0.5) {
			col = built_px(wall_tex, wh, p, wall_open(here_t + ivec2(0, -1)), wall_open(here_t + ivec2(0, 1)),
				wall_open(here_t + ivec2(-1, 0)), wall_open(here_t + ivec2(1, 0)), 0.6, false, bvec4(false));
			col.rgb = shade_wall(col.rgb);
		} else if (!done && field_w(p) + nz(p) * 0.6 > 0.5) {
			int w = wall_at(p);
			if (w > 0 && built_walls[w] < 0.5) {
				col = vec4(shade_wall(strip(wall_tex, w, p).rgb), 1.0);
			}
		}
	}
	COLOR = col;
}
