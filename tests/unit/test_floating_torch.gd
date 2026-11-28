extends GutTest
## Phase 75: the Floating Torch spell, its Empower tree (Brighter, Kindled: the last
## rank never runs out), and Magic Essence from slimes.

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


func _torch() -> SpellData:
	return ItemData.find(ItemData.spell_key(&"floating_torch")) as SpellData


func test_it_follows_you_as_a_torch() -> void:
	var spell := _torch()
	assert_not_null(spell)
	assert_eq(spell.cast, SpellData.Cast.LIGHT)
	assert_eq(spell.learn_cost, {&"torch": 10, &"paper": 5, &"magic_essence": 2} as Dictionary[StringName, int])
	assert_true(spell.learnable_at_table)
	var orb := w.summon_light_orb(ItemData.find(ItemData.spell_key(&"light_orb")) as SpellData)
	var t := w.summon_light_orb(spell)
	assert_true(t.torch, "drawn as a torch")
	assert_almost_eq(t.time_left, 300.0, 0.1)
	assert_false(orb.is_queued_for_deletion(), "a Light Orb and a Floating Torch can both be out")
	var again := w.summon_light_orb(spell)
	assert_true(t.is_queued_for_deletion(), "casting again replaces it")
	assert_false(again.placed)


func test_brighter_and_kindled() -> void:
	var nodes := EmpowerNode.for_spell(_torch()).map(func(n: EmpowerNode) -> StringName: return n.id)
	assert_has(nodes, &"torch_brighter")
	assert_has(nodes, &"torch_kindled")
	assert_does_not_have(nodes, &"lasting", "its own Kindled instead of the shared Lasting")
	var c := w.character
	c.empower[&"floating_torch"] = {&"torch_brighter": 3, &"torch_kindled": 2}
	c.apply_empower()
	var s := _torch()
	assert_almost_eq(s.light_radius, 41.0, 0.01, "+5 a rank")
	assert_almost_eq(s.duration, 600.0, 0.1, "10 minutes at rank 2")
	assert_eq(s.light_endless, 0)
	c.empower[&"floating_torch"][&"torch_kindled"] = 3
	c.apply_empower()
	assert_eq(_torch().light_endless, 1, "the last rank: never runs out")
	var t := w.summon_light_orb(_torch())
	assert_eq(t.time_left, INF)
	var kindled := Registry.get_def(&"empower", &"torch_kindled") as EmpowerNode
	assert_gt(int(kindled.cost_for(2).get(&"magic_essence", 0)), int(kindled.cost_for(1).get(&"magic_essence", 0)) * 2,
		"the last rank is expensive")


func test_slimes_drop_magic_essence_and_the_page() -> void:
	for id: StringName in [&"green_slime", &"blue_slime"]:
		var l := Catalog.loot_line(Registry.get_def(&"enemies", id) as EnemyData, &"magic_essence")
		assert_not_null(l, "%s drops Magic Essence" % id)
		assert_almost_eq(l.chance, 0.1, 0.0001)
	var page := Catalog.loot_line(Registry.get_def(&"enemies", &"green_slime") as EnemyData, &"page_floating_torch")
	assert_not_null(page)
	assert_eq((ItemData.find(&"page_floating_torch")).learns_spell, &"floating_torch")
	var spirit := Catalog.loot_line(Registry.get_def(&"enemies", &"forest_spirit") as EnemyData, &"magic_essence")
	assert_eq(spirit.chance, 1.0, "Forest Spirits still always drop it")
