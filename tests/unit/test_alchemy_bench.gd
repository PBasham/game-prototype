extends GutTest
## Phase 67: the Alchemist's Bench rules (AlchemyBench): vial spot, bowl, mortar, Mix
## (recipes, ground ingredients, Murky Mixture, discovering), the preview, the window.

var inv: Inventory
var c: CharacterData
var b: AlchemyBench


func before_each() -> void:
	c = CharacterData.new()
	inv = c.inventory
	b = AlchemyBench.new()


func test_healing_from_whole_red_caps() -> void:
	inv.add(&"clay_flask", 1)
	inv.add(&"red_cap", 2)
	assert_true(b.set_vial(inv, &"clay_flask"))
	assert_true(b.add_to_bowl(inv, 0, &"red_cap"))
	assert_true(b.add_to_bowl(inv, 0, &"red_cap"))
	assert_false(b.add_to_bowl(inv, 1, &"red_cap"), "none left to set out")
	assert_eq(b.available(inv, &"red_cap"), 0)
	assert_eq(inv.count_of(&"red_cap"), 2, "nothing leaves the inventory before Mix")
	var r := b.mix(inv, c)
	assert_eq(r["item"], &"healing_potion")
	assert_false(r["new"], "known from the start")
	assert_eq(inv.count_of(&"healing_potion"), 1)
	assert_eq(inv.count_of(&"red_cap"), 0)
	assert_eq(inv.count_of(&"clay_flask"), 0)


func test_mana_needs_ground_glowcap_glow_doesnt() -> void:
	inv.add(&"clay_flask", 3)
	inv.add(&"glowcap", 5)
	# Whole Glowcap x2: no recipe (Mana wants it ground) -> murky.
	b.set_vial(inv, &"clay_flask")
	b.add_to_bowl(inv, 0, &"glowcap")
	b.add_to_bowl(inv, 0, &"glowcap")
	assert_null(b.matching())
	assert_eq(b.mix(inv, c)["item"], AlchemyBench.MURKY)
	assert_eq(inv.count_of(&"murky_mixture"), 1)
	assert_eq(inv.count_of(&"glowcap"), 3, "the wrong mix used them up")
	# Ground x2: Mana.
	b.set_vial(inv, &"clay_flask")
	b.add_to_mortar(inv, &"glowcap")
	b.add_to_mortar(inv, &"glowcap")
	assert_true(b.grind())
	assert_true(b.mortar_to_bowl())
	assert_eq(b.matching().output, &"mana_potion")
	b.mix(inv, c)
	# Whole x1: Glow.
	b.set_vial(inv, &"clay_flask")
	b.add_to_bowl(inv, 0, &"glowcap")
	assert_eq(b.mix(inv, c)["item"], &"glow_potion")


func test_a_new_mix_teaches_the_recipe() -> void:
	inv.add(&"clay_flask", 1)
	inv.add(&"duskcap", 2)
	var coating: RecipeData
	for r in AlchemyBench.recipes():
		if r.id == &"poison_coating":
			coating = r
	assert_false(AlchemyBench.knows(c, coating), "Coatings are found by experimenting")
	b.set_vial(inv, &"clay_flask")
	b.add_to_mortar(inv, &"duskcap")
	b.add_to_mortar(inv, &"duskcap")
	b.grind()
	b.mortar_to_bowl()
	var r := b.mix(inv, c)
	assert_eq(r["item"], &"poison_coating")
	assert_true(r["new"])
	assert_true(AlchemyBench.knows(c, coating))
	assert_true(c.to_dict()["brews"].has("poison_coating"), "saved with the character")


func test_water_breathing_by_bottle_size() -> void:
	inv.add(&"water_clay_jug", 1)
	inv.add(&"kelp", 2)
	assert_false(b.set_vial(inv, &"kelp"), "only bottles on the vial spot")
	assert_true(b.set_vial(inv, &"water_clay_jug"))
	b.add_to_mortar(inv, &"kelp")
	b.add_to_mortar(inv, &"kelp")
	b.grind()
	b.mortar_to_bowl()
	assert_eq(b.mix(inv, c)["item"], &"water_breathing_clay_jug")


func test_mix_needs_a_bottle_and_ingredients() -> void:
	inv.add(&"red_cap", 2)
	b.add_to_bowl(inv, 0, &"red_cap")
	assert_ne(b.mix_problem(), "")
	assert_true(b.mix(inv, c).is_empty())
	assert_eq(inv.count_of(&"red_cap"), 2, "nothing used")


func test_the_preview_shows_known_recipes_only() -> void:
	inv.add(&"clay_flask", 2)
	inv.add(&"red_cap", 2)
	inv.add(&"duskcap", 2)
	assert_eq(b.preview(c), &"", "nothing to mix")
	b.set_vial(inv, &"clay_flask")
	b.add_to_bowl(inv, 0, &"red_cap")
	b.add_to_bowl(inv, 0, &"red_cap")
	assert_eq(b.preview(c), &"healing_potion")
	b.clear()
	b.set_vial(inv, &"clay_flask")
	b.add_to_bowl(inv, 0, &"duskcap")
	assert_eq(b.preview(c), &"?", "not known: a surprise")


func test_the_shelf_lists_bottles_then_ingredients() -> void:
	inv.add(&"mana_potion", 2)
	inv.add(&"kelp", 4)
	inv.add(&"glass_vial", 1)
	inv.add(&"wood", 10)
	assert_eq(AlchemyBench.shelf(inv), [&"glass_vial", &"kelp"] as Array[StringName])


## The window: dropping list items on the table pieces, Mix, the book.
func test_the_window_drag_and_drop() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	var w := (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	var inv := w.character.inventory
	inv.add(&"clay_flask", 1)
	inv.add(&"red_cap", 2)
	w.hud.open_virtual_station(w.objects.def(w.objects.index_of(&"alchemists_bench")) as ObjectDef)
	var win := w.hud._bench
	assert_true(win.visible, "the bench window opens")
	win._drag = {"from": "list", "id": &"clay_flask"}
	win.drop(BenchWindow.STAND.get_center())
	win._drag = {"from": "list", "id": &"red_cap"}
	win.drop(win.bowl_slot(1).get_center(), true)
	assert_eq(win.bench.vial, &"clay_flask")
	assert_eq(int(win.bench.bowl[1]["count"]), 2, "Shift drops all you have")
	win.do_mix()
	assert_eq(inv.count_of(&"healing_potion"), 1)
	assert_true(win.book_lines()[0].contains(":"), "the book lists recipes")
	assert_eq(win.bench.preview(w.character), &"", "the table is empty after a mix")
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null
