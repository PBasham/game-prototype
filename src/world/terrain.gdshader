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
uniform float grass_slots[32];
uniform float built_slots[32];
uniform float built_walls[32];
uniform float overhang_slots[32];
// Back walls whose runs end sticking out with rounded tips (log walls), and blocks that
// stand upright when stacked in a single column (logs).
uniform float overhang_walls[32];
uniform float turn_slots[32];
// Per wall slot: brightness so every wall is the same step darker than its block.
uniform float wall_mult[32];
// See-through (glass) blocks and walls: a light rim instead of the dark edge line.
uniform float clear_slots[32];
uniform float clear_walls[32];
// Background walls are drawn this much darker than blocks (and a little greyer), so
// the front layer stands out. 1 = same as the art.
uniform float wall_shade = 1.0;
uniform float built_wall_shade = 1.35;
// Built blocks (bricks, planks) drawn this much brighter, so they stand out from a back
// wall of the same stuff; and a soft shadow on walls next to and under built blocks.
uniform float built_block_shade = 1.12;
uniform float block_shadow = 0.72;
uniform float block_shadow_px = 2.0;
uniform float wall_desat = 0.2;
uniform vec3 grass_0 : source_color;
uniform vec3 grass_1 : source_color;
uniform vec3 grass_2 : source_color;
uniform vec3 grass_3 : source_color;
uniform vec3 grass_4 : source_color;
uniform vec3 grass_5 : source_color;
// The dark grass palette (Dark Forest Grass: grass_slots = 2).
uniform vec3 dgrass_1 : source_color;
uniform vec3 dgrass_2 : source_color;
uniform vec3 dgrass_3 : source_color;
uniform vec3 dgrass_4 : source_color;
uniform vec3 dgrass_5 : source_color;

// Grass shade i (1 to 5) for material m, from its palette.
vec3 gc(int m, int i) {
	bool d = grass_slots[m] > 1.5;
	if (i == 1) return d ? dgrass_1 : grass_1;
	if (i == 2) return d ? dgrass_2 : grass_2;
	if (i == 3) return d ? dgrass_3 : grass_3;
	if (i == 4) return d ? dgrass_4 : grass_4;
	return d ? dgrass_5 : grass_5;
}
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

// The Shaping Spell's shape of a tile (the B channel): bits 0-2 the block's shape
// (0 full, 1 bottom half, 2 top half, 3 to 6 slopes solid toward the bottom left,
// bottom right, top left, top right), bit 3 a log turned the other way, bits 4-5 the
// back wall's shape (0 full, 1 bottom half, 2 top half).
int shape_of(ivec2 t) {
	return int(round(texelFetch(tiles, clamp(t, ivec2(0), ivec2(SIZE - 1)), 0).b * 255.0));
}

// Whether a pixel (lp: 0 to 8 inside its tile) is part of a block of this shape.
bool in_shape(int s, vec2 lp) {
	vec2 c = lp + 0.5;
	if (s == 1) return c.y >= 4.0;
	if (s == 2) return c.y < 4.0;
	if (s == 3) return c.y >= c.x;
	if (s == 4) return c.x + c.y >= 8.0;
	if (s == 5) return c.x + c.y < 8.0;
	if (s == 6) return c.y < c.x;
	return true;
}

// Natural material at a tile (built blocks count as none).
int nat(ivec2 t) {
	int m = blk(t);
	return is_built(m) ? 0 : m;
}

float occ_b(ivec2 t) { return blk(t) > 0 ? 1.0 : 0.0; }
float occ_w(ivec2 t) { return wal(t) > 0 ? 1.0 : 0.0; }
float occ_n(ivec2 t) { return nat(t) > 0 ? 1.0 : 0.0; }

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

// Like field_b, but only natural blocks count: a built block (wood planks) next to
// grass or stone doesn't grow a natural bump into the open tile above it.
float field_n(vec2 p) {
	vec2 f = (p + 0.5) / T - 0.5 + float(B);
	vec2 i = floor(f);
	vec2 fr = smoothstep(0.0, 1.0, f - i);
	ivec2 ii = ivec2(i);
	float a = mix(occ_n(ii), occ_n(ii + ivec2(1, 0)), fr.x);
	float b = mix(occ_n(ii + ivec2(0, 1)), occ_n(ii + ivec2(1, 1)), fr.x);
	return mix(a, b, fr.y);
}

bool solid_nat(vec2 p) { return field_n(p) + nz(p) > 0.5; }

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

// The same, turned a quarter (an upright log).
vec4 strip_t(sampler2D s, int slot, vec2 p, bool turn) {
	ivec2 q = ivec2(mod(floor(p * DET), float(CELL)));
	if (turn) q = q.yx;
	return texelFetch(s, ivec2((slot - 1) * CELL + q.x, q.y), 0);
}

// A log wall (overhang_walls) in a single column: drawn upright too.
bool upright_wall(ivec2 t) {
	int w = wal(t);
	return w > 0 && overhang_walls[w] > 0.5 && wal(t + ivec2(-1, 0)) != w && wal(t + ivec2(1, 0)) != w
		&& (wal(t + ivec2(0, -1)) == w || wal(t + ivec2(0, 1)) == w);
}

// A log (turn_slots) standing in a single column: drawn upright. The Shaping Spell's
// turn (shape bit 3) flips it the other way.
bool upright(ivec2 t) {
	int b = blk(t);
	if (b <= 0 || turn_slots[b] < 0.5) return false;
	bool column = blk(t + ivec2(-1, 0)) != b && blk(t + ivec2(1, 0)) != b
		&& (blk(t + ivec2(0, -1)) == b || blk(t + ivec2(0, 1)) == b);
	return column != ((shape_of(t) & 8) != 0);
}

// Crisp square tile with a dark edge line where it meets open space. `cut` rounds an
// outer corner by one pixel, only where the diagonal neighbor is open too.
vec4 built_px(sampler2D tex, int slot, vec2 p, bool up, bool down, bool left, bool right, float edge_dark, bool cut, bvec4 diag, bool clear, float ovh, bool turn) {
	vec2 lp = p - floor(p / T) * T;
	if (ovh > 0.5 && !turn) {
		left = false;  // the run's end sticks out instead (overhang_px)
		right = false;
	}
	if (cut && ((up && left && diag.x && lp.x < 1.0 && lp.y < 1.0) || (up && right && diag.y && lp.x >= 7.0 && lp.y < 1.0)
			|| (down && left && diag.z && lp.x < 1.0 && lp.y >= 7.0) || (down && right && diag.w && lp.x >= 7.0 && lp.y >= 7.0))) {
		return vec4(0.0);
	}
	vec3 c = strip_t(tex, slot, p, turn).rgb;
	bool edge = (up && lp.y < 1.0) || (down && lp.y >= 7.0) || (left && lp.x < 1.0) || (right && lp.x >= 7.0);
	if (edge && clear) {
		c = mix(c, vec3(0.86, 0.94, 0.97), 0.7);  // glass: a light rim, no dark line
	} else if (edge) {
		c *= edge_dark;
	} else {
		if (up && lp.y < 2.0) c = mix(c, min(c * 1.3, vec3(1.0)), 0.5);
		if (down && lp.y >= 6.0) c *= 0.8;
		if (left && lp.x < 2.0) c *= 1.06;
		if (right && lp.x >= 6.0) c *= 0.88;
	}
	return vec4(c, edge ? 1.0 : strip_t(tex, slot, p, turn).a);
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
	int shp = shape_of(here_t);
	vec2 tile_lp = p - floor(p / T) * T;
	bool shape_cut = false;
	bool shape_rim = false;
	if (here != 0 && (shp & 7) != 0) {
		if (!in_shape(shp & 7, tile_lp)) {
			here = 0;  // hammered away: what's behind shows
			shape_cut = true;
		} else if (!in_shape(shp & 7, tile_lp + vec2(1.0, 0.0)) || !in_shape(shp & 7, tile_lp - vec2(1.0, 0.0))
				|| !in_shape(shp & 7, tile_lp + vec2(0.0, 1.0)) || !in_shape(shp & 7, tile_lp - vec2(0.0, 1.0))) {
			shape_rim = true;  // the cut edge gets the edge line
		}
	}
	int m = 0;
	// In an open tile, only natural blocks round out into it (see field_n).
	if (!shape_cut && !is_built(here) && solid(p) && (here != 0 || solid_nat(p))) {
		m = mat_at(p);
	}
	bool drew = false;
	vec4 pane = vec4(0.0);
	if (is_built(here)) {
		bvec4 diag = bvec4(blk(here_t + ivec2(-1, -1)) == 0, blk(here_t + ivec2(1, -1)) == 0,
			blk(here_t + ivec2(-1, 1)) == 0, blk(here_t + ivec2(1, 1)) == 0);
		col = built_px(materials, here, p, blk(here_t + ivec2(0, -1)) == 0, blk(here_t + ivec2(0, 1)) == 0,
			blk(here_t + ivec2(-1, 0)) == 0, blk(here_t + ivec2(1, 0)) == 0, 0.38, true, diag, clear_slots[here] > 0.5, overhang_slots[here], upright(here_t));
		col.rgb = min(col.rgb * built_block_shade, vec3(1.0));
		if (shape_rim) col.rgb *= 0.38;
		drew = col.a > 0.99;
		if (!drew && col.a > 0.0) {
			pane = col;  // see-through (glass): drawn over what's behind it below
			col = vec4(0.0);
		}
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
			c = top == 1 ? gc(m, 5) : (top == 2 ? gc(m, 4) : (top < lim ? gc(m, 3) : gc(m, 1)));
		} else if (grass && (lo || ro) && below > 1 && top - 1 < side_lim) {
			c = top - 1 > 2 ? gc(m, 2) : gc(m, 3);
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
	if (!drew && here == 0 && !shape_cut) {
		vec2 lp = p - floor(p / T) * T;
		int lm = blk(here_t + ivec2(-1, 0));
		int rm = blk(here_t + ivec2(1, 0));
		float ln = is_built(lm) && !upright(here_t + ivec2(-1, 0)) ? overhang_slots[lm] : 0.0;
		float rn = is_built(rm) && !upright(here_t + ivec2(1, 0)) ? overhang_slots[rm] : 0.0;
		int sm = 0;
		bool tip = false;
		if (lp.x < ln) { sm = lm; tip = lp.x >= ln - 1.0; }
		else if (lp.x >= 8.0 - rn) { sm = rm; tip = lp.x < 9.0 - rn; }
		if (sm > 0 && lp.y >= 1.0 && lp.y < 7.0 && !(tip && (lp.y < 2.0 || lp.y >= 6.0))) {
			vec3 c = strip(materials, sm, p).rgb * built_block_shade;
			// The same dark edge line as the block, around the rounded end.
			bool rim = tip || lp.y < 2.0 || lp.y >= 6.0
				|| (sm == lm ? lp.x >= ln - 2.0 : lp.x < 10.0 - rn) && (lp.y < 3.0 || lp.y >= 5.0);
			col = vec4(min(rim ? c * 0.38 : c, vec3(1.0)), 1.0);
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
				// Blades grow from grass, not from the top of a built block next to it.
				if (solid_nat(q) && grass_slots[mat_at(q)] > 0.5) {
					int tall = hash(wp.x * 1.31 + 7.0) > 0.25 ? 1 + int(hash(wp.x * 2.17 + 3.0) * 5.0) : 0;
					if (k <= tall) {
						int gm = mat_at(q);
						col = vec4(k == tall ? gc(gm, 5) : (k > 1 ? gc(gm, 4) : gc(gm, 3)), 1.0);
						done = true;
					}
				}
				break;
			}
		}
		int wh = wal(here_t);
		int wsh = (shp >> 4) & 3;
		if (wh > 0 && wsh != 0 && !in_shape(wsh, tile_lp)) {
			wh = 0;
			done = true;  // a half wall: nothing behind this half
		}
		if (!done && wh > 0 && built_walls[wh] > 0.5) {
			col = built_px(wall_tex, wh, p, wall_open(here_t + ivec2(0, -1)), wall_open(here_t + ivec2(0, 1)),
				wall_open(here_t + ivec2(-1, 0)), wall_open(here_t + ivec2(1, 0)), 0.6, false, bvec4(false), clear_walls[wh] > 0.5,
				overhang_walls[wh], upright_wall(here_t));
			col.rgb = min(shade_wall(col.rgb) * built_wall_shade * wall_mult[wh], vec3(1.0));
		} else if (!done && field_w(p) + nz(p) * 0.6 > 0.5) {
			int w = wall_at(p);
			if (w > 0 && built_walls[w] < 0.5) {
				col = vec4(min(shade_wall(strip(wall_tex, w, p).rgb) * wall_mult[w], vec3(1.0)), 1.0);
			}
		}
		if (!done && wh == 0 && here == 0 && col.a == 0.0) {
			// A log wall's end sticking out into this open tile, rounded like the blocks'.
			vec2 lp = p - floor(p / T) * T;
			int lw = wal(here_t + ivec2(-1, 0));
			int rw = wal(here_t + ivec2(1, 0));
			float ln = lw > 0 && built_walls[lw] > 0.5 && !upright_wall(here_t + ivec2(-1, 0)) ? overhang_walls[lw] : 0.0;
			float rn = rw > 0 && built_walls[rw] > 0.5 && !upright_wall(here_t + ivec2(1, 0)) ? overhang_walls[rw] : 0.0;
			int sw = 0;
			bool tip = false;
			if (lp.x < ln) { sw = lw; tip = lp.x >= ln - 1.0; }
			else if (lp.x >= 8.0 - rn) { sw = rw; tip = lp.x < 9.0 - rn; }
			if (sw > 0 && lp.y >= 1.0 && lp.y < 7.0 && !(tip && (lp.y < 2.0 || lp.y >= 6.0))) {
				vec3 c = strip(wall_tex, sw, p).rgb;
				bool rim = tip || lp.y < 2.0 || lp.y >= 6.0
					|| (sw == lw ? lp.x >= ln - 2.0 : lp.x < 10.0 - rn) && (lp.y < 3.0 || lp.y >= 5.0);
				col = vec4(min(shade_wall(rim ? c * 0.6 : c) * built_wall_shade * wall_mult[sw], vec3(1.0)), 1.0);
			}
		}
	}
	if (!drew && here == 0 && col.a > 0.0) {
		// A back wall: shaded where a block stands right above or to either side.
		vec2 lp = p - floor(p / T) * T;
		float near = 99.0;
		if (is_built(blk(here_t + ivec2(0, -1)))) near = min(near, lp.y);
		if (is_built(blk(here_t + ivec2(-1, 0)))) near = min(near, lp.x);
		if (is_built(blk(here_t + ivec2(1, 0)))) near = min(near, 7.999 - lp.x);
		if (near < block_shadow_px) {
			col.rgb *= mix(block_shadow, 1.0, near / block_shadow_px);
		}
	}
	if (pane.a > 0.0) {
		col = vec4(mix(col.rgb, pane.rgb, col.a > 0.0 ? pane.a : 1.0), max(col.a, pane.a));
	}
	COLOR = col;
}
