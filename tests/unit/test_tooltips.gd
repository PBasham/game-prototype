extends GutTest
## Tooltips wrap at a set width and stay on screen; spell pages say "Already known".

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


func test_long_tooltips_wrap_and_stay_on_screen() -> void:
	var hud := w.hud
	hud._tooltip.visible = true
	hud._tooltip_title.text = "Mining Spell"
	hud._tooltip_text.text = Hud.spell_tooltip(Registry.get_def(&"spells", &"mining_spell") as SpellData, w.character)
	var view := hud._view_size()
	hud._layout_tooltip(Vector2(view.x - 5, view.y - 5))  # the bottom right corner
	var font := hud._tooltip_text.get_theme_font(&"font")
	for line in hud._tooltip_text.text.split("\n"):
		assert_lte(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, hud.tooltip_font_size).x,
			hud.tooltip_max_width, "wrapped: %s" % line)
	assert_lte(hud._tooltip.size.x, hud.tooltip_max_width + 40.0, "a narrow box")
	assert_gte(hud._tooltip.position.x, 2.0, "not off the left")
	assert_lte(hud._tooltip.position.x + hud._tooltip.size.x, view.x, "not off the right")
	assert_lte(hud._tooltip.position.y + hud._tooltip.size.y, view.y, "not off the bottom")
	hud._tooltip_text.text = "Short"
	hud._tooltip_title.text = "Wood"
	hud._layout_tooltip(Vector2(20, 20))
	assert_lt(hud._tooltip.size.x, 80.0, "short text keeps a small box")


func test_spell_pages_say_already_known() -> void:
	var page := ItemData.find(&"page_spark")
	assert_not_null(page)
	var c := w.character
	c.known_spells.erase(&"spark")
	assert_false(Hud.tooltip_for(page, c).contains("Already known"))
	c.learn_spell(&"spark")
	assert_true(Hud.tooltip_for(page, c).contains("Already known"))


func test_clicking_with_a_spell_on_the_mouse_doesnt_use_your_hand() -> void:
	var hud := w.hud
	hud.set_open(true)
	hud.cursor_id = ItemData.spell_key(&"spark")
	hud.cursor_count = 1
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(hud._view_size().x * 0.5, hud._view_size().y * 0.3)
	hud._input(press)
	assert_true(hud._press_on_ui, "the click is the UI's")
	hud.cursor_count = 0
	await wait_process_frames(2)
	assert_true(w.player.input_blocked, "still blocked until the button comes up")
