extends GutTest
## Phase 24: tools are spells. Mining and Chopping from the start, free, ranked up with
## bars at the Empower tab; a phantom tool that lands once per swing.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World


func after_each() -> void:
	ItemData.set_empowered([])
	if w:
		w.queue_free()
		await wait_physics_frames(2)
		w = null
	Game.world_info = null
	Game.character = null


func _world(c: CharacterData) -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = c
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)


func test_no_pickaxes_or_axes_and_gathering_is_free() -> void:
	for id: StringName in [&"copper_pickaxe", &"iron_pickaxe", &"stone_pickaxe", &"copper_axe", &"iron_axe",
			&"stone_axe", &"hand_hammer", &"flint"]:
		assert_null(Registry.get_def(&"items", id), "%s is gone" % id)
	for id: StringName in CharacterData.STARTING_SPELLS:
		var s := Registry.get_def(&"spells", id) as SpellData
		assert_eq(s.mana_per_second, 0.0, "%s is free" % id)
		assert_eq(s.mana_cost, 0.0)
		assert_not_null(s.phantom_texture, "%s conjures a phantom tool" % id)
		assert_string_contains(Hud.spell_tooltip(s), "Mana: Free")
	assert_not_null(Registry.get_def(&"recipes", &"copper_dagger"), "the dagger is craftable")


func test_old_characters_learn_the_gathering_spells() -> void:
	var c := CharacterData.new()
	c.name = "GatherTest"
	assert_eq(c.save(), OK)
	var path := SaveManager.character_path(c.name)
	var back := CharacterData.load_file(path)
	DirAccess.remove_absolute(path)
	for id in CharacterData.STARTING_SPELLS:
		assert_true(back.knows(id))


func test_power_reach_and_sharpness_ranks() -> void:
	var c := CharacterData.create("Ranks")
	var mining := Registry.get_def(&"spells", &"mining_spell") as SpellData
	var chop := Registry.get_def(&"spells", &"chopping_spell") as SpellData
	var nodes := EmpowerNode.for_spell(mining).map(func(n: EmpowerNode) -> StringName: return n.id)
	assert_eq(nodes, [&"mining_power", &"gather_reach"], "Power, then Reach (no Efficient: it's free)")
	assert_has(EmpowerNode.for_spell(chop).map(func(n: EmpowerNode) -> StringName: return n.id), &"chopping_power")
	c.empower[&"mining_spell"] = {&"mining_power": 2, &"gather_reach": 3}
	c.empower[&"chopping_spell"] = {&"chopping_power": 1}
	c.apply_empower()
	var m := ItemData.find(ItemData.spell_key(&"mining_spell")) as SpellData
	assert_eq(m.mining_power, mining.mining_power + 20)
	assert_eq(m.mining_area_max, 4, "iron rank: up to 4x4")
	assert_almost_eq(m.mining_damage, mining.mining_damage * 1.6, 0.01)
	assert_almost_eq(m.reach_tiles, mining.reach_tiles + 6.0, 0.01)
	assert_eq(m.gather_rank, 2, "glows like iron")
	var ch := ItemData.find(ItemData.spell_key(&"chopping_spell")) as SpellData
	assert_almost_eq(ch.axe_damage, chop.axe_damage * 1.4, 0.01)
	assert_eq(mining.mining_power, 30, "the data itself is untouched")
	ItemData.set_empowered([])
	assert_eq(ItemData.find(ItemData.spell_key(&"mining_spell")), mining)


func test_more_spells_have_tiers() -> void:
	var c := CharacterData.create("Tiers")
	var spark := Registry.get_def(&"spells", &"spark") as SpellData
	var chain := Registry.get_def(&"spells", &"chain_spark") as SpellData
	var blink := Registry.get_def(&"spells", &"blink") as SpellData
	c.empower[&"spark"] = {&"potency": 3}
	c.empower[&"chain_spark"] = {&"arc": 2}
	c.empower[&"blink"] = {&"distance": 1}
	c.apply_empower()
	assert_almost_eq((ItemData.find(ItemData.spell_key(&"spark")) as SpellData).damage, spark.damage * 1.3, 0.01)
	assert_eq((ItemData.find(ItemData.spell_key(&"chain_spark")) as SpellData).chain_jumps, chain.chain_jumps + 2)
	assert_almost_eq((ItemData.find(ItemData.spell_key(&"blink")) as SpellData).blink_tiles, blink.blink_tiles + 3.0, 0.01)
	for d in Registry.get_all(&"empower"):
		assert_eq((d as EmpowerNode).validate(), PackedStringArray(), "%s valid" % d.id)


func test_the_phantom_pickaxe_lands_once_per_swing() -> void:
	await _world(CharacterData.create("Swing"))
	var p := w.player
	var u := w.item_user
	p.toggle_tool_spell(&"mining_spell")
	var feet := w.world_to_tile(p.global_position)
	var t := Vector2i(feet.x + 3, feet.y + 1)
	w.request_set_block(t, w.blocks.index_of(&"stone"))
	u.cursor_override = Vector2(t * World.TILE) + Vector2(4, 4)
	p.area_scrolled.emit(-1)  # 1x1
	Input.action_press("use_primary")
	var swing := (p.use_item() as SpellData).phantom_swing_time
	await wait_seconds(swing * 0.5)
	assert_eq(w.block_damage(t), 0.0, "nothing until the tool lands")
	await wait_seconds(swing)
	Input.action_release("use_primary")
	assert_gt(w.block_damage(t), 0.0, "the swing landed")


func test_glowing_box_and_the_tool_lands_on_the_middle() -> void:
	await _world(CharacterData.create("Box"))
	var p := w.player
	var u := w.item_user
	p.toggle_tool_spell(&"mining_spell")
	var feet := w.world_to_tile(p.global_position)
	var t := Vector2i(feet.x + 3, feet.y + 1)
	w.request_set_block(t, w.blocks.index_of(&"stone"))
	u.cursor_override = Vector2(t * World.TILE) + Vector2(4, 4)
	await wait_process_frames(3)
	var pt := u._phantom_node
	assert_true(pt.box_shown, "the glowing blue box while aiming")
	assert_false(pt.swinging, "no tool until you mine")
	assert_true(pt.box_ok)
	for style in 3:
		pt.style = style as PhantomTool.Style
		pt.side = 1.0
		pt.target = Vector2(100, 50)
		if style != PhantomTool.Style.COMET:
			var tip := pt._tip_at(pt._grip(), pt._angle(1.0))
			assert_almost_eq(tip.distance_to(pt.target), 0.0, 0.01, "the point lands on the middle")
	# The test spells for the other styles (debug builds).
	if OS.is_debug_build():
		for id: StringName in [&"dev_mining_echo", &"dev_mining_comet", &"dev_chopping_echo", &"dev_chopping_comet"]:
			assert_not_null(ItemData.find(ItemData.spell_key(id)), "%s exists" % id)
	w.console.run("phantom comet")
	assert_eq((p.use_item() as SpellData).phantom_style, PhantomTool.Style.COMET)
	w.console.run("phantom arc")
