#include "voxel_step.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <algorithm>
#include <chrono>

namespace godot {

void VoxelStep::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "settings"), &VoxelStep::configure);
	ClassDB::bind_method(D_METHOD("set_kind_provider", "fn"), &VoxelStep::set_kind_provider);
	ClassDB::bind_method(D_METHOD("forget_kind", "tile"), &VoxelStep::forget_kind);
	ClassDB::bind_method(D_METHOD("forget_kinds"), &VoxelStep::forget_kinds);
	ClassDB::bind_method(D_METHOD("step", "tiles", "active", "center", "tick"), &VoxelStep::step);
	ClassDB::bind_method(D_METHOD("reset_pass"), &VoxelStep::reset_pass);
	ClassDB::bind_method(D_METHOD("pending_left"), &VoxelStep::pending_left);
}

void VoxelStep::configure(const Dictionary &s) {
	width_tiles = int(s.get("width_tiles", 1));
	height_tiles = int(s.get("height_tiles", 1));
	fall_cells = int(s.get("fall_cells", 2));
	water_spread = int(s.get("water_spread", 32));
	sand_sink_chance = double(s.get("sand_sink_chance", 0.35));
	settle_steps = int(s.get("settle_steps", 20));
	sleep_steps = int(s.get("sleep_steps", 30));
	solidify = bool(s.get("solidify_piles", false));
	bubble_reach = int(s.get("bubble_reach", 64));
	sim_radius = int(s.get("sim_radius_tiles", 96));
	budget_ms = double(s.get("step_budget_ms", 5.0));
	PackedInt32Array b = s.get("behavior", PackedInt32Array());
	for (int i = 0; i < 16; i++) {
		behavior[i] = i < b.size() ? b[i] : -1;
	}
	int64_t seed = int64_t(s.get("seed", 12345));
	rng.seed(uint32_t(seed));
}

void VoxelStep::set_kind_provider(const Callable &fn) { kind_fn = fn; }

void VoxelStep::forget_kind(const Vector2i &t) { kinds.erase(key(wrap_x(t.x), t.y)); }

void VoxelStep::forget_kinds() { kinds.clear(); }

void VoxelStep::reset_pass() {
	pending.clear();
	pending_at = 0;
}

int64_t VoxelStep::pending_left() const { return int64_t(pending.size() - pending_at); }

// --- cells -------------------------------------------------------------------------------

int VoxelStep::wrap_x(int x) const {
	int w = width_tiles;
	int r = x % w;
	return r < 0 ? r + w : r;
}

Vector2i VoxelStep::tile_of(int cx, int cy) const {
	int wc = width_tiles * N;
	int x = cx % wc;
	if (x < 0) {
		x += wc;
	}
	return Vector2i(x >> 2, cy >> 2);
}

VoxelStep::Tile &VoxelStep::tile(const Vector2i &t) {
	int64_t k = key(t.x, t.y);
	auto it = cache.find(k);
	if (it != cache.end()) {
		return it->second;
	}
	Tile &out = cache[k];
	Variant v = tiles_->get(t, Variant());
	if (v.get_type() == Variant::PACKED_BYTE_ARRAY) {
		PackedByteArray arr = v;
		if (arr.size() == CELLS) {
			const uint8_t *p = arr.ptr();
			for (int i = 0; i < CELLS; i++) {
				out.c[i] = p[i];
			}
			out.exists = true;
		}
	}
	return out;
}

int VoxelStep::kind(const Vector2i &t) {
	if (t.y < 0 || t.y >= height_tiles) {
		return 1;
	}
	int64_t k = key(t.x, t.y);
	auto it = kinds.find(k);
	if (it != kinds.end()) {
		return it->second;
	}
	int v = kind_fn.is_valid() ? int(kind_fn.call(t)) : 0;
	if (v & 8) {
		return v & ~8;  // not generated yet: solid for now, ask again later
	}
	kinds[k] = v;
	return v;
}

bool VoxelStep::in_shape(int s, double x, double y) {
	switch (s) {
		case 1: return y >= 4.0;
		case 2: return y < 4.0;
		case 3: return y >= x;
		case 4: return x + y >= 8.0;
		case 5: return x + y < 8.0;
		case 6: return y < x;
	}
	return true;
}

bool VoxelStep::terrain_blocks(int cx, int cy) {
	if (cy < 0 || cy >= height_tiles * N) {
		return true;
	}
	int k = kind(tile_of(cx, cy));
	switch (k & 7) {
		case 1: return true;
		case 2: return in_shape((k >> 4) & 7, (cx & 3) * 2 + 1.0, (cy & 3) * 2 + 1.0);
		case 3: return (cy & 3) == 0;
	}
	return false;
}

int VoxelStep::cell(int cx, int cy) {
	if (cy < 0 || cy >= height_tiles * N) {
		return 0;
	}
	Tile &t = tile(tile_of(cx, cy));
	return t.c[(cy & 3) * N + (cx & 3)];
}

void VoxelStep::set_cell(int cx, int cy, int b) {
	Vector2i at = tile_of(cx, cy);
	Tile &t = tile(at);
	t.c[(cy & 3) * N + (cx & 3)] = uint8_t(b);
	if (!t.dirty) {
		t.dirty = true;
		changed_list.push_back(at);
	}
}

bool VoxelStep::is_free(int cx, int cy) { return !terrain_blocks(cx, cy) && cell(cx, cy) == 0; }

bool VoxelStep::is_liquid(int cx, int cy) { return behavior[cell(cx, cy) & 15] == LIQUID; }

bool VoxelStep::chance(double p) { return std::uniform_real_distribution<double>(0.0, 1.0)(rng) < p; }

bool VoxelStep::coin() { return (rng() & 1) == 0; }

// --- the step ----------------------------------------------------------------------------

void VoxelStep::build_pass(Dictionary &active, const Vector2i &center) {
	pending.clear();
	pending_at = 0;
	Array keys = active.keys();
	int64_t n = keys.size();
	pending.reserve(size_t(n));
	int w = width_tiles;
	for (int64_t i = 0; i < n; i++) {
		Vector2i t = keys[i];
		if (sim_radius > 0 && center.y > -(1 << 29)) {  // no player: everything
			int dx = ((t.x - center.x + w / 2) % w + w) % w - w / 2;
			if (std::abs(dx) > sim_radius || std::abs(t.y - center.y) > sim_radius) {
				continue;
			}
		}
		pending.push_back(t);
	}
	std::sort(pending.begin(), pending.end(), [](const Vector2i &a, const Vector2i &b) { return a.y > b.y; });
}

Dictionary VoxelStep::step(Dictionary tiles, Dictionary active, const Vector2i &center, int64_t tick) {
	Dictionary out;
	Array emptied;
	Array settled;
	tiles_ = &tiles;
	cache.clear();
	moved.clear();
	changed_list.clear();
	if (pending_at >= pending.size()) {
		build_pass(active, center);
	}
	bool flip = (tick & 1) == 0;
	auto deadline = std::chrono::steady_clock::now() + std::chrono::microseconds(int64_t(budget_ms * 1000.0));
	int k = 0;
	while (pending_at < pending.size()) {
		k++;
		if ((k & 63) == 0 && std::chrono::steady_clock::now() > deadline) {
			break;  // the rest of the pass goes next step
		}
		Vector2i t = pending[pending_at++];
		if (!active.has(t)) {
			continue;
		}
		Tile &tt = tile(t);
		bool any = false;
		for (int i = 0; i < CELLS; i++) {
			any = any || tt.c[i] != 0;
		}
		if (!any) {
			active.erase(t);
			emptied.push_back(t);
			continue;
		}
		bool did = false;
		int fast = fast_tile(t);
		if (fast == 1) {
			active[t] = 0;
			continue;
		}
		if (fast == 0) {
			did = step_cells(t, flip);
		}
		if (did) {
			active[t] = 0;
			continue;
		}
		int idle = int(active.get(t, 0)) + 1;
		active[t] = idle;
		if (solidify && idle >= settle_steps) {
			settled.push_back(t);
		}
		if (idle >= sleep_steps) {
			active.erase(t);
		}
	}
	// Write the changed tiles back.
	Array changed;
	for (const Vector2i &t : changed_list) {
		Tile &tt = cache[key(t.x, t.y)];
		bool any = false;
		for (int i = 0; i < CELLS; i++) {
			any = any || tt.c[i] != 0;
		}
		if (any) {
			PackedByteArray arr;
			arr.resize(CELLS);
			uint8_t *p = arr.ptrw();
			for (int i = 0; i < CELLS; i++) {
				p[i] = tt.c[i];
			}
			tiles[t] = arr;
		} else {
			tiles.erase(t);
		}
		changed.push_back(t);
		// Wake it and its neighbors (VoxelLayer._wake_around).
		static const int D[7][2] = { { 0, 0 }, { 0, -1 }, { -1, 0 }, { 1, 0 }, { -1, -1 }, { 1, -1 }, { 0, 1 } };
		for (const auto &d : D) {
			int ny = t.y + d[1];
			if (ny >= 0 && ny < height_tiles) {
				active[Vector2i(wrap_x(t.x + d[0]), ny)] = 0;
			}
		}
	}
	tiles_ = nullptr;
	cache.clear();
	out["changed"] = changed;
	out["emptied"] = emptied;
	out["settled"] = settled;
	out["done"] = pending_at >= pending.size();
	return out;
}

bool VoxelStep::full_or_rock(const Vector2i &t) {
	if (t.y >= height_tiles) {
		return true;
	}
	if ((kind(t) & 7) == 1) {
		return true;
	}
	Tile &tt = tile(t);
	for (int i = 0; i < CELLS; i++) {
		if (tt.c[i] == 0) {
			return false;
		}
	}
	return true;
}

bool VoxelStep::holds_up(const Vector2i &t) {
	if (t.y >= height_tiles) {
		return true;
	}
	if ((kind(t) & 7) == 1) {
		return true;
	}
	Tile &tt = tile(t);
	for (int i = 0; i < CELLS; i++) {
		if (tt.c[i] == 0 || behavior[tt.c[i] & 15] == LIQUID) {
			return false;
		}
	}
	return true;
}

// 1 = the whole tile shifted down, 2 = nothing in it can move, 0 = cell by cell.
int VoxelStep::fast_tile(const Vector2i &t) {
	Vector2i below(t.x, t.y + 1);
	if (below.y >= height_tiles) {
		return 2;
	}
	Tile &tt = tile(t);
	int empties = 0;
	bool all_solid = true;
	bool all_static = true;
	for (int i = 0; i < CELLS; i++) {
		int b = tt.c[i];
		if (b == 0) {
			empties++;
			continue;
		}
		int kb = behavior[b & 15];
		if (kb == LIQUID) {
			all_solid = false;
		}
		if (kb != STATIC) {
			all_static = false;
		}
	}
	if (all_static) {
		return 2;
	}
	Vector2i l(wrap_x(t.x - 1), t.y), r(wrap_x(t.x + 1), t.y);
	Vector2i lb(wrap_x(t.x - 1), t.y + 1), rb(wrap_x(t.x + 1), t.y + 1);
	if (empties == 0 && full_or_rock(below) && full_or_rock(l) && full_or_rock(r) && full_or_rock(lb) &&
			full_or_rock(rb)) {
		return 2;
	}
	if (empties == 0 && all_solid && holds_up(below) && holds_up(lb) && holds_up(rb)) {
		return 2;
	}
	if (kind(below) != 0) {
		return 0;
	}
	for (int i = 0; i < CELLS; i++) {
		if (tt.c[i] != 0 && behavior[tt.c[i] & 15] == STATIC) {
			return 0;
		}
	}
	Tile &bt = tile(below);
	for (int i = 0; i < fall_cells * N; i++) {
		if (bt.c[i] != 0) {
			return 0;
		}
	}
	std::array<uint8_t, CELLS> up{};
	std::array<uint8_t, CELLS> down = bt.c;
	for (int ly = 0; ly < N; ly++) {
		for (int lx = 0; lx < N; lx++) {
			uint8_t b = tt.c[ly * N + lx];
			if (b == 0) {
				continue;
			}
			int ny = ly + fall_cells;
			if (ny < N) {
				up[ny * N + lx] = b;
			} else {
				down[(ny - N) * N + lx] = b;
			}
		}
	}
	tt.c = up;
	bt.c = down;
	if (!tt.dirty) {
		tt.dirty = true;
		changed_list.push_back(t);
	}
	if (!bt.dirty) {
		bt.dirty = true;
		changed_list.push_back(below);
	}
	return 1;
}

bool VoxelStep::step_cells(const Vector2i &t, bool flip) {
	bool did = false;
	for (int ly = N - 1; ly >= 0; ly--) {
		for (int i = 0; i < N; i++) {
			int lx = flip ? i : N - 1 - i;
			int cx = t.x * N + lx, cy = t.y * N + ly;
			if (moved.count(key(cx, cy))) {
				continue;
			}
			int b = cell(cx, cy);
			if (b == 0) {
				continue;
			}
			switch (behavior[b & 15]) {
				case POWDER:
					did = step_powder(cx, cy, b) || did;
					break;
				case LIQUID:
					did = step_liquid(cx, cy, b) || did;
					break;
			}
		}
	}
	return did;
}

void VoxelStep::move(int fx, int fy, int tx, int ty, int b) {
	int there = cell(tx, ty);
	set_cell(tx, ty, b);
	set_cell(fx, fy, there);
	int wc = width_tiles * N;
	moved.insert(key(((tx % wc) + wc) % wc, ty));
	if (there != 0) {
		moved.insert(key(((fx % wc) + wc) % wc, fy));
	}
}

bool VoxelStep::fall(int cx, int cy, int b, int &ox, int &oy) {
	int ty = cy;
	for (int i = 0; i < fall_cells; i++) {
		if (!is_free(cx, ty + 1)) {
			break;
		}
		ty++;
	}
	ox = cx;
	oy = ty;
	if (ty != cy) {
		move(cx, cy, cx, ty, b);
		return true;
	}
	return false;
}

bool VoxelStep::step_powder(int cx, int cy, int b) {
	int ox, oy;
	if (fall(cx, cy, b, ox, oy)) {
		return true;
	}
	if (is_liquid(cx, cy + 1) && chance(sand_sink_chance)) {
		move(cx, cy, cx, cy + 1, b);
		return true;
	}
	int d = coin() ? 1 : -1;
	for (int dd : {d, -d}) {
		if (terrain_blocks(cx + dd, cy)) {
			continue;
		}
		if (is_free(cx + dd, cy + 1) || (is_liquid(cx + dd, cy + 1) && chance(sand_sink_chance))) {
			move(cx, cy, cx + dd, cy + 1, b);
			return true;
		}
	}
	return false;
}

bool VoxelStep::step_liquid(int cx, int cy, int b) {
	if (bubble_reach > 0 && is_liquid(cx, cy - 1) && is_free(cx, cy + 1)) {
		bubble(cx, cy);
		return true;
	}
	int ox, oy;
	if (fall(cx, cy, b, ox, oy)) {
		return true;
	}
	int d = coin() ? 1 : -1;
	for (int dd : {d, -d}) {
		if (!terrain_blocks(cx + dd, cy) && is_free(cx + dd, cy + 1)) {
			move(cx, cy, cx + dd, cy + 1, b);
			return true;
		}
	}
	for (int dd : {d, -d}) {
		for (int k = 1; k <= water_spread; k++) {
			int tx = cx + dd * k;
			if (!is_free(tx, cy)) {
				break;
			}
			if (is_free(tx, cy + 1)) {
				move(cx, cy, tx, cy, b);
				return true;
			}
		}
	}
	return false;
}

// Under water with open cells below: the liquid column above drops into them as a whole
// (up to fall_cells), so the air goes straight to the top of the column.
void VoxelStep::bubble(int cx, int cy) {
	int f = 0;
	while (f < fall_cells && is_free(cx, cy + f + 1)) {
		f++;
	}
	int length = 1;
	while (length < bubble_reach && is_liquid(cx, cy - length)) {
		length++;
	}
	int wc = width_tiles * N;
	int wx = ((cx % wc) + wc) % wc;
	for (int i = 0; i < length; i++) {
		int sy = cy - i;
		set_cell(cx, sy + f, cell(cx, sy));
		moved.insert(key(wx, sy + f));
	}
	for (int i = 0; i < std::min(f, length); i++) {
		set_cell(cx, cy - (length - 1) + i, 0);
	}
}

} // namespace godot
