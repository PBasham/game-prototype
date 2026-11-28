extends GutTest
## Phase 73: the Command spell and the middle mouse quick slot.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	w.spawner.peaceful = true


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


func test_everyone_has_command_on_the_middle_mouse() -> void:
	var c := CharacterData.create("Test")
	assert_true(c.knows(&"command"))
	assert_eq(c.quick_spell(CharacterData.MIDDLE), &"command")
	assert_true(InputMap.has_action(&"quick_m"), "the middle mouse button's action")
	var ev := InputMap.action_get_events(&"quick_m")[0] as InputEventMouseButton
	assert_eq(ev.button_index, MOUSE_BUTTON_MIDDLE)
	# An older character gets it too (on load), unless the slot is taken.
	c.quick.erase(CharacterData.MIDDLE)
	c._give_command_slot()
	assert_eq(c.quick_spell(CharacterData.MIDDLE), &"command")
	c.quick[CharacterData.MIDDLE] = &"mining_spell"
	c._give_command_slot()
	assert_eq(c.quick_spell(CharacterData.MIDDLE), &"mining_spell", "yours stays")
	assert_true(c.to_dict()["command_slot"], "only once")
	assert_eq(Hud.quick_key_label(&"m"), "Mid")
	assert_eq(Player.quick_label(&"m"), "Middle mouse")


func test_command_points_your_summons_at_an_enemy() -> void:
	var slime := Registry.get_def(&"enemies", &"green_slime") as EnemyData
	var near := w.request_spawn_enemy(slime, w.player.global_position + Vector2(4 * World.TILE, 0))
	var far := w.request_spawn_enemy(slime, w.player.global_position + Vector2(-10 * World.TILE, 0))
	near.process_mode = Node.PROCESS_MODE_DISABLED
	far.process_mode = Node.PROCESS_MODE_DISABLED
	var spell := ItemData.find(ItemData.spell_key(&"summon_slime")) as SpellData
	var mine := w.request_spell_effect(spell, w.player.chest(), 1.0) as Enemy
	assert_eq(mine._summon_target(), near, "the nearest, as usual")
	assert_eq(w.command_summons(far.hit_rect().get_center()), far)
	assert_eq(mine._summon_target(), far, "now the one you pointed at")
	assert_null(w.command_summons(w.player.global_position + Vector2(0, -20 * World.TILE)), "pointing at nothing")
	assert_eq(mine._summon_target(), near, "back to the nearest")
	w.command_summons(far.hit_rect().get_center())
	far.process_mode = Node.PROCESS_MODE_INHERIT
	far.kill()
	await wait_physics_frames(2)
	assert_null(w.commanded_target(), "it ends when the target dies")
