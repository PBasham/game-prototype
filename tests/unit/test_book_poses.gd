extends GutTest
## Phase 30: where the spellbook is. On the hip when it isn't in use; in the back hand
## for HAND spells (a quick cast with a weapon out keeps the weapon in the front hand);
## floating in front for FLOAT spells; left on the hip, glowing, for HIP spells.

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
	w = null
	Game.world_info = null


func _hold(item_id: StringName) -> void:
	w.character.inventory.set_slot(0, item_id, 1)
	w.player.select_slot(0)


func test_spells_say_where_the_book_goes() -> void:
	var pose := func(id: StringName) -> int: return (Registry.get_def(&"spells", id) as SpellData).book_pose
	assert_eq(pose.call(&"spark"), SpellData.BookPose.HAND)
	assert_eq(pose.call(&"mining_spell"), SpellData.BookPose.HAND)
	assert_eq(pose.call(&"chain_spark"), SpellData.BookPose.FLOAT)
	assert_eq(pose.call(&"barrier"), SpellData.BookPose.HIP)
	for t: StringName in [&"spell_float", &"spell_hip", &"spell_offhand"]:
		assert_not_null(Registry.get_def(&"item_types", t), "%s motions" % t)


func test_book_on_the_hip_until_its_used() -> void:
	var p := w.player
	var doll := p.doll()
	_hold(&"copper_dagger")
	await wait_process_frames(3)
	assert_not_null(doll.book, "the equipped book")
	assert_true(doll.book_on_hip, "on the hip with a weapon out")
	assert_true(doll._book_hip.visible)
	p.ready_spell(&"spark")
	await wait_physics_frames(2)
	assert_eq(p.held.type, &"spell", "in the back hand")
	assert_false(doll.book_on_hip)
	p.ready_spell(&"chain_spark")
	await wait_physics_frames(2)
	assert_eq(p.held.type, &"spell_float", "floats for big casts")
	assert_false(doll.book_on_hip)
	p.ready_spell(&"barrier")
	await wait_physics_frames(2)
	assert_eq(p.held.type, &"spell_hip", "a gesture for buffs")
	assert_true(doll.book_on_hip)
	assert_false(doll._item_sprite.visible, "nothing in hand")
	assert_gt(doll.book_glow, 0.0, "the book glows")


func test_quick_cast_keeps_the_weapon_in_hand() -> void:
	var p := w.player
	var doll := p.doll()
	_hold(&"dual_storm_axes")
	w.item_user.cursor_override = p.global_position + Vector2(60, -10)
	assert_true(p.quick_cast(&"spark"))
	await wait_physics_frames(1)
	assert_eq(p.held.type, &"spell_offhand", "the book comes out in the back hand")
	assert_not_null(doll.offhand, "the axes stay in the front hand")
	assert_eq(doll.offhand.id, &"dual_storm_axes")
	await wait_process_frames(2)
	assert_true(doll._offhand_front.visible, "an axe in the front hand")
	assert_gt(doll.hands[&"back"].x, 10.0, "the book thrust toward the cursor")
	assert_false(doll.book_on_hip)
	assert_eq(p.weapon_in_hand().id, &"dual_storm_axes", "and still amplify Storm")
	for i in 60:
		await wait_physics_frames(1)
		if p.selected == 0:
			break
	assert_eq(p.held_item.id, &"dual_storm_axes", "back to the axes")
	assert_null(doll.offhand)
	assert_true(doll.book_on_hip)
