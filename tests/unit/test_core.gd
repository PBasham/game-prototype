extends GutTest
## Core autoload behavior.


func test_single_player_is_authority() -> void:
	assert_true(Game.is_authority())
	assert_false(Game.is_networked())


func test_set_state_emits_change() -> void:
	watch_signals(EventBus)
	var before: Game.State = Game.state
	var target := Game.State.LOADING if before != Game.State.LOADING else Game.State.PLAYING
	Game.set_state(target)
	assert_signal_emitted(EventBus, "game_state_changed")
	Game.set_state(before)


func test_settings_fall_back_to_defaults() -> void:
	assert_eq(Settings.get_value("display", "vsync"), true)
	assert_null(Settings.get_value("nope", "nothing"))


func test_save_paths_are_sanitized() -> void:
	var p := SaveManager.world_path("my:world/name")
	assert_true(p.begins_with(SaveManager.WORLD_DIR))
	assert_false(p.get_file().contains("/"))
	assert_true(p.ends_with(SaveManager.WORLD_EXT))
