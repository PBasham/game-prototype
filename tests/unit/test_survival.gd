extends GutTest
## Health, hunger, food, berry bushes, dying and the magic bag, in a running test-course
## world.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


func test_damage_regen_and_god_mode() -> void:
	var p := w.player
	assert_eq(p.health, p.max_health)
	p.take_damage(30.0, &"test")
	assert_eq(p.health, p.max_health - 30.0)
	p.take_damage(30.0, &"test")
	assert_eq(p.health, p.max_health - 30.0, "a moment of safety after a hit")
	p._since_hurt = p.health_regen_delay
	var before := p.health
	p._update_health(2.0)
	assert_almost_eq(p.health, before + p.health_regen * 2.0, 0.01, "regenerates after the delay")
	p.invincible = true
	p._since_hurt = 99.0
	p.take_damage(50.0, &"test")
	assert_almost_eq(p.health, before + p.health_regen * 2.0, 0.01, "god mode")


func test_hunger_drains_and_running_is_faster() -> void:
	var p := w.player
	p.hunger = 50.0
	p._update_health(p.hunger_seconds_per_point * 4.0)
	assert_almost_eq(p.hunger, 46.0, 0.01, "one point per hunger_seconds_per_point")
	p.hunger_on = false
	p._update_health(100.0)
	assert_eq(p.hunger, p.max_hunger, "world option off: always full")


func test_starving_hurts_and_stops_regen() -> void:
	var p := w.player
	p.hunger = 0.0
	p.health = 50.0
	p._since_hurt = 99.0
	for i in 4:
		p._update_health(p.starve_interval / 3.0 + 0.01)
	assert_lt(p.health, 50.0, "starving takes health")
	assert_false(p.dead)


func test_eating_berries() -> void:
	var p := w.player
	var inv := w.character.inventory
	inv.set_slot(0, &"berries", 3)
	p.select_slot(0)
	p.hunger = 20.0
	p.health = 50.0
	assert_true(w.item_user.eat_held())
	assert_almost_eq(p.hunger, 30.0, 0.01)
	assert_almost_eq(p.health, 52.0, 0.01)
	assert_eq(inv.counts[0], 2)
	p.hunger = p.max_hunger
	p.health = p.max_health
	assert_false(w.item_user.eat_held(), "full: doesn't eat")
	assert_eq(inv.counts[0], 2)


func test_berry_bushes_pick_and_regrow() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var ground := Vector2i(feet.x + 4, feet.y)
	w.data.set_block(ground.x, ground.y, w.blocks.index_of(&"grass"))
	w.plants._add(w.wrap_tile(ground), PlantLayer.Kind.BUSH, 0)
	assert_true(w.plants.is_ripe(ground))
	var inv := w.character.inventory
	var before := inv.count_of(&"berries")
	assert_true(w.plants.request_pick_up(ground + Vector2i(0, -2), w.player), "right click on the bush")
	var got := inv.count_of(&"berries") - before
	assert_between(got, w.plants.berries_min, w.plants.berries_max)
	assert_false(w.plants.is_ripe(ground), "picked")
	assert_false(w.plants.request_pick_berries(ground, w.player), "nothing left")
	w.plants._regrow(w.plants.regrow_max_seconds + 1.0)
	assert_true(w.plants.is_ripe(ground), "grew back")


func test_dying_drops_a_magic_bag_and_respawns() -> void:
	var p := w.player
	var inv := w.character.inventory
	inv.set_slot(12, &"stone", 25)
	var items := 0
	for i in inv.size:
		if not inv.is_empty(i) and not String(inv.ids[i]).begins_with(ItemData.SPELL_PREFIX):
			items += 1
	w.respawn_seconds = 0.2
	p.take_damage(p.health + 1.0, &"test")
	assert_true(p.dead)
	assert_eq(w.bags().size(), 1, "a magic bag where you died")
	var bag := w.bags()[0]
	assert_eq(bag.inventory.count_of(&"stone"), 25)
	var in_bag := 0
	for i in bag.inventory.size:
		if not bag.inventory.is_empty(i):
			in_bag += 1
	assert_eq(in_bag, items, "everything but spell shortcuts")
	await wait_seconds(0.5)
	assert_false(p.dead, "respawned")
	assert_eq(p.health, p.max_health)
	# The bag fell and settled.
	await wait_seconds(2.0)
	assert_true(bag.resting)
	# Saved with the world.
	var list := w.bags_to_list()
	assert_eq(list.size(), 1)
	var back := ItemBag.from_dict(w, list[0])
	assert_eq(back.inventory.count_of(&"stone"), 25)
	back.free()
	# Take all empties it, and it vanishes.
	w.teleport_player(bag.global_position)
	await wait_physics_frames(2)
	w.hud._on_bag_opened(bag)
	assert_true(w.hud._chest.visible)
	for i in bag.inventory.size:
		w.hud._move_stack(bag.inventory, i, inv)
	await wait_physics_frames(2)
	assert_eq(w.bags().size(), 0, "empty: gone")
	assert_eq(inv.count_of(&"stone"), 25)


func test_keep_items_option() -> void:
	w.info.death_drop = WorldInfo.DeathDrop.KEEP
	w.character.inventory.set_slot(12, &"stone", 5)
	w.respawn_seconds = 0.1
	w.player.take_damage(1000.0, &"test")
	assert_eq(w.bags().size(), 0)
	assert_eq(w.character.inventory.count_of(&"stone"), 5)
	await wait_seconds(0.3)


func test_world_options_save() -> void:
	var info := WorldInfo.create("x", WorldData.Size.SMALL, 1)
	info.hunger = false
	info.death_drop = WorldInfo.DeathDrop.KEEP
	var back := WorldInfo.from_dict(info.to_dict())
	assert_false(back.hunger)
	assert_eq(back.death_drop, WorldInfo.DeathDrop.KEEP)
	var old := WorldInfo.from_dict({"name": "old"})
	assert_true(old.hunger, "older worlds: hunger on")
	assert_eq(old.death_drop, WorldInfo.DeathDrop.BAG)
