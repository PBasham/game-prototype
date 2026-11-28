extends GutTest
## Phase 82: bigger bucket, rarer Summon Slime page, cooked food worth cooking, more
## reach and crafting range, the Lumber Rack's two sides.


func test_lumber_rack_sides() -> void:
	var def := Registry.get_def(&"objects", &"lumber_rack") as ObjectDef
	assert_eq(def.split_slots, 5)
	var inv := Inventory.new(10)
	inv.accepts_tag = &"lumber"
	inv.split_at = 5
	assert_eq(inv.add(&"log", 300), 0)
	assert_eq(inv.add(&"wood", 120), 0)
	for i in 10:
		if not inv.is_empty(i):
			assert_eq(i >= 5, inv.ids[i] == &"log", "slot %d: logs right, boards left" % i)
	assert_true(inv.fits_slot(7, &"dark_log"))
	assert_false(inv.fits_slot(2, &"dark_log"))
	assert_true(inv.fits_slot(2, &"reinforced_wood"))


func test_cooked_food_beats_raw() -> void:
	# [cooked, raw, how many raw]
	for row: Array in [[&"roasted_berries", &"berries", 3], [&"blueberry_mash", &"blueberries", 4],
			[&"raspberry_compote", &"raspberries", 4], [&"cooked_mushroom", &"field_mushroom", 1]]:
		var cooked := ItemData.find(row[0])
		var raw := ItemData.find(row[1])
		assert_gt(cooked.food_value, raw.food_value * row[2], String(row[0]))
		assert_true(("+%d hunger" % int(cooked.food_value)) in cooked.description, "tooltip matches")


func test_summon_slime_page_is_rare() -> void:
	for e: StringName in [&"green_slime", &"blue_slime"]:
		var line := Catalog.loot_line(Registry.get_def(&"enemies", e) as EnemyData, &"page_summon_slime")
		assert_almost_eq(line.chance, 0.004, 0.0001, String(e))


func test_bucket_holds_four_tiles() -> void:
	assert_eq(ItemData.find(&"clay_bucket").fill_takes, 64)
	assert_eq(ItemData.find(&"clay_bucket_water").pours_water, 64)
	assert_eq(ItemData.find(&"clay_bucket_salt_water").pours_water, 64)
