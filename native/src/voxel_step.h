// Phase 94: the water and sand simulation step in C++ (VoxelLayer.step in GDScript is the
// same rules; this is the fast one). VoxelLayer keeps the cells (tiles: Vector2i ->
// PackedByteArray of 16), the active tiles and everything else; this only moves cells.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <array>
#include <cstdint>
#include <random>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace godot {

class VoxelStep : public RefCounted {
	GDCLASS(VoxelStep, RefCounted)

public:
	static constexpr int N = 4;
	static constexpr int CELLS = 16;
	enum { POWDER = 0, LIQUID = 1, STATIC = 2 };

	// Settings (VoxelLayer's exports, copied in by configure()).
	void configure(const Dictionary &settings);
	// fn(tile: Vector2i) -> int: 0 open, 1 solid, 2 | shape << 4 shaped, 3 platform; add 8
	// when it mustn't be remembered (land not generated yet).
	void set_kind_provider(const Callable &fn);
	// A block or its shape changed: forget its terrain kind.
	void forget_kind(const Vector2i &tile);
	void forget_kinds();
	// One step (or part of a pass): moves cells in `tiles`, updates `active`. Returns
	// {changed: Array[Vector2i] tiles whose cells changed (they and their neighbors are
	// woken in `active` already), emptied: tiles active but
	// without cells, settled: tiles idle settle_steps long, done: the pass finished}.
	Dictionary step(Dictionary tiles, Dictionary active, const Vector2i &center, int64_t tick);
	// Starts a new pass next step (tests; a world reload).
	void reset_pass();
	int64_t pending_left() const;

protected:
	static void _bind_methods();

private:
	struct Tile {
		std::array<uint8_t, CELLS> c{};
		bool exists = false;  // in `tiles`
		bool dirty = false;
	};

	// Settings.
	int width_tiles = 1;
	int height_tiles = 1;
	int fall_cells = 2;
	int water_spread = 32;
	double sand_sink_chance = 0.35;
	int settle_steps = 20;
	int sleep_steps = 30;
	bool solidify = false;
	int bubble_reach = 64;
	int sim_radius = 96;
	double budget_ms = 5.0;
	int behavior[16];

	Callable kind_fn;
	std::unordered_map<int64_t, int> kinds;
	std::mt19937 rng{12345};

	// Per step.
	Dictionary *tiles_ = nullptr;
	std::unordered_map<int64_t, Tile> cache;
	std::unordered_set<int64_t> moved;
	std::vector<Vector2i> changed_list;

	// The pass.
	std::vector<Vector2i> pending;
	size_t pending_at = 0;

	static inline int64_t key(int x, int y) { return (int64_t(uint32_t(x)) << 32) | uint32_t(y); }
	int wrap_x(int x) const;
	Vector2i tile_of(int cx, int cy) const;
	Tile &tile(const Vector2i &t);
	int kind(const Vector2i &t);
	bool terrain_blocks(int cx, int cy);
	int cell(int cx, int cy);
	void set_cell(int cx, int cy, int b);
	bool is_free(int cx, int cy);
	bool is_liquid(int cx, int cy);
	bool chance(double p);
	bool coin();

	void build_pass(Dictionary &active, const Vector2i &center);
	int fast_tile(const Vector2i &t);
	bool full_or_rock(const Vector2i &t);
	bool holds_up(const Vector2i &t);
	bool step_cells(const Vector2i &t, bool flip);
	void move(int fx, int fy, int tx, int ty, int b);
	bool fall(int cx, int cy, int b, int &ox, int &oy);
	bool step_powder(int cx, int cy, int b);
	bool step_liquid(int cx, int cy, int b);
	void bubble(int cx, int cy);
	static bool in_shape(int s, double x, double y);
};

} // namespace godot
