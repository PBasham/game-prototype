extends GutTest
## Phase 54: swimming, breath, thirst, water bottles, Siphon Liquid, Liquid Barrels.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World
var v: VoxelLayer
var floor_tile: Vector2i


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	v = w.voxels
	var feet := w.world_to_tile(w.player.global_position)
	floor_tile = Vector2i(feet.x + 12, feet.y - 30)


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


## A stone tank 10 wide and 14 tall high in the air, its floor's left end at floor_tile,
## optionally full of water `depth` tiles deep.
func _tank(depth: int) -> void:
	var stone := w.blocks.index_of(&"stone")
	for x in range(-1, 11):
		w.request_set_block(floor_tile + Vector2i(x, 0), stone)
	for y in range(1, 15):
		w.request_set_block(floor_tile + Vector2i(-1, -y), stone)
		w.request_set_block(floor_tile + Vector2i(10, -y), stone)
	for y in range(1, depth + 1):
		for x in 10:
			v.request_fill(floor_tile + Vector2i(x, -y), &"water")


func _into_tank() -> void:
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(5, 0)))
	await wait_physics_frames(3)


func test_you_swim_and_sink_slowly() -> void:
	_tank(12)
	await _into_tank()
	await wait_physics_frames(5)
	assert_true(w.player.swimming, "deep water: swimming")
	assert_true(w.player.head_under)
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(5, -4)))
	await wait_physics_frames(30)
	assert_lte(w.player.velocity.y, w.player.swim_sink_speed * World.TILE + 1.0, "sinks slowly")


func test_shallow_water_isnt_swimming() -> void:
	_tank(1)
	await _into_tank()
	await wait_physics_frames(5)
	assert_false(w.player.swimming)
	assert_false(w.player.head_under)


func test_breath_runs_out_then_you_drown() -> void:
	_tank(12)
	w.player.max_breath = 0.5
	w.player.breath = 0.5
	await _into_tank()
	var hp := w.player.health
	await wait_seconds(2.0)
	assert_eq(w.player.breath, 0.0)
	assert_lt(w.player.health, hp, "drowning hurts")
	w.player.invincible = true
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(5, -20)))
	w.player.invincible = false
	await wait_seconds(0.5)
	assert_gt(w.player.breath, 0.0, "breath comes back out of the water")


func test_thirst_drains_and_parched_hurts() -> void:
	var p := w.player
	p.thirst_on = true
	var before := p.thirst
	p.thirst_full_days = 0.0005
	await wait_seconds(0.5)
	assert_lt(p.thirst, before)
	p.thirst = 0.0
	p.parched_interval = 0.2
	var hp := p.health
	await wait_seconds(0.5)
	assert_lt(p.health, hp, "parched hurts")


func test_drinking_water_quenches_and_gives_the_bottle_back() -> void:
	var item := ItemData.find(&"water_glass_vial")
	assert_eq(item.thirst_value, 20.0)
	assert_eq(item.leaves_item, &"glass_vial")
	var p := w.player
	var inv := w.character.inventory
	p.thirst = 50.0
	inv.add(&"water_glass_vial", 1)
	var vials := inv.count_of(&"glass_vial")
	assert_true(w.item_user.eat_from(_slot_of(inv, &"water_glass_vial")))
	assert_eq(p.thirst, 70.0)
	assert_eq(inv.count_of(&"glass_vial"), vials + 1, "the empty vial back")
	assert_eq(p.cant_consume(item), "", "still thirsty")
	p.thirst = p.max_thirst
	assert_eq(p.cant_consume(item), "You're not thirsty")


func _slot_of(inv: Inventory, id: StringName) -> int:
	for i in inv.size:
		if inv.item(i) and inv.item(i).id == id:
			return i
	return -1


func test_siphon_draws_and_pours() -> void:
	_tank(2)
	await _into_tank()
	var spell := ItemData.find(ItemData.spell_key(&"siphon_liquid")) as SpellData
	assert_true(spell.siphons)
	w.character.water = 0
	var box := Rect2i(floor_tile + Vector2i(0, -2), Vector2i(10, 2))
	var before := v.liquid_in(box)
	assert_eq(before, 320)
	assert_eq(v.take_liquid(box, 40), 40)
	assert_eq(v.liquid_in(box), 280)
	assert_eq(v.pour_liquid(Rect2i(floor_tile + Vector2i(2, -6), Vector2i(1, 1)), 40), 16, "one tile has room for 16")


func test_siphon_spell_in_hand() -> void:
	_tank(2)
	await _into_tank()
	w.character.learn_spell(&"siphon_liquid")
	w.player.toggle_tool_spell(&"siphon_liquid")
	w.character.water = 0
	w.item_user.cursor_override = w.tile_to_world(floor_tile + Vector2i(6, -1)) + Vector2(4, 4)
	Input.action_press("use_primary")
	await wait_seconds(1.0)
	Input.action_release("use_primary")
	await wait_physics_frames(2)
	assert_gt(w.character.water, 10, "drew water up")


func test_barrels_hold_water_and_spill_when_broken() -> void:
	_tank(0)
	var spot := floor_tile + Vector2i(3, -1)
	assert_true(w.request_place_object(spot, w.objects.index_of(&"liquid_barrel")))
	assert_eq(w.request_barrel_water(spot, 100), 100)
	assert_eq(w.barrel_water(spot), 100)
	assert_eq(w.request_barrel_water(spot, 1000), 300, "only up to its capacity")
	assert_eq(w.request_barrel_water(spot, -50), -50)
	assert_true(w.request_remove_object(spot))
	var spilled := v.liquid_in(Rect2i(floor_tile + Vector2i(0, -8), Vector2i(10, 8)))
	assert_eq(spilled, 350, "the water spilled out")


func test_crafting_water_from_around_you() -> void:
	_tank(2)
	await _into_tank()
	w.character.water = 0
	var r := Registry.get_def(&"recipes", &"water_glass_vial") as RecipeData
	assert_eq(r.inputs[&"water"], 1, "a cell a sip")
	var inv := w.character.inventory
	inv.add(&"glass_vial", 3)
	var stock := CraftStock.new([inv])
	stock.water_count = func() -> int: return w.water_for_crafting(w.player.chest())
	stock.water_take = func(n: int) -> int: return w.take_water_for_crafting(w.player.chest(), n)
	assert_gt(Crafting.times_craftable(stock, r), 0, "standing in water")
	var before := v.liquid_in(Rect2i(floor_tile + Vector2i(0, -2), Vector2i(10, 2)))
	assert_eq(Crafting.craft(stock, r, 1)[0], 1)
	assert_eq(v.liquid_in(Rect2i(floor_tile + Vector2i(0, -2), Vector2i(10, 2))), before - 1)
	assert_eq(inv.count_of(&"water_glass_vial"), 1)
	# Out of the water: only the reservoir counts.
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(5, -25)))
	await wait_physics_frames(2)
	w.character.water = 20
	assert_eq(w.water_for_crafting(w.player.chest()), 20)
	assert_eq(Crafting.craft(stock, r, 1)[0], 1)
	assert_eq(w.character.water, 19, "used the Siphon's water")


func test_water_shows_on_the_map() -> void:
	_tank(4)
	var m := w.world_map
	var t := floor_tile + Vector2i(4, -2)
	var c := m.cell_color(t.x / WorldMap.CELL, t.y / WorldMap.CELL)
	assert_gt(c.b, c.r + 0.2, "blue: water")
	var dry := floor_tile + Vector2i(4, -10)
	assert_ne(m.cell_color(dry.x / WorldMap.CELL, dry.y / WorldMap.CELL), c, "air above it isn't")
