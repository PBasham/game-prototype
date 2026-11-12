extends SceneTree
## Writes the default input map and physics layer names into project.godot.
## Edit the lists below, then run:
##   godot --headless --path . --script res://tools/setup_project_settings.gd

func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.device = -1
	return e

func mouse(btn: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.device = -1
	return e

func add(action: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})

func _init() -> void:
	add("move_left", [key(KEY_A), key(KEY_LEFT)])
	add("move_right", [key(KEY_D), key(KEY_RIGHT)])
	add("move_up", [key(KEY_W), key(KEY_UP)])
	add("move_down", [key(KEY_S), key(KEY_DOWN)])
	add("jump", [key(KEY_SPACE)])
	add("run", [key(KEY_SHIFT)])
	add("toggle_walk", [key(KEY_C)])
	add("use_primary", [mouse(MOUSE_BUTTON_LEFT)])
	add("use_secondary", [mouse(MOUSE_BUTTON_RIGHT)])
	add("interact", [key(KEY_E)])
	add("inventory", [key(KEY_I), key(KEY_TAB)])
	add("drop_item", [key(KEY_Q)])
	add("quick_heal", [key(KEY_H)])
	add("quick_mana", [key(KEY_M)])
	add("quick_buff", [key(KEY_B)])
	add("hotbar_next", [mouse(MOUSE_BUTTON_WHEEL_DOWN)])
	add("hotbar_prev", [mouse(MOUSE_BUTTON_WHEEL_UP)])
	var digits := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
	for i in 10:
		add("hotbar_%d" % (i + 1), [key(digits[i])])
	add("pause", [key(KEY_ESCAPE)])
	add("toggle_debug", [key(KEY_F3)])

	var layers := ["world", "platforms", "player", "enemies", "player_attacks", "enemy_attacks", "dropped_items", "npcs", "triggers"]
	for i in layers.size():
		ProjectSettings.set_setting("layer_names/2d_physics/layer_%d" % (i + 1), layers[i])

	var err := ProjectSettings.save()
	print("saved: ", err)
	quit()
