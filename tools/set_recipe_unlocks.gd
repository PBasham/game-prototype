extends SceneTree
## Phase 70: hides recipes behind their key items. For every recipe in data/recipes with
## no `unlock_items` yet, sets them to its inputs minus the basics everyone has
## (make_items.gd COMMON_INPUTS); a recipe that only uses basics stays always shown.
## Recipes that already have unlock_items (Patrick's or earlier) are left alone.
##
##   godot --headless --path . --script res://tools/set_recipe_unlocks.gd [-- --dry]

const MakeItems := preload("res://tools/make_items.gd")


func _init() -> void:
	var dry := OS.get_cmdline_user_args().has("--dry")
	var dir := DirAccess.open("res://data/recipes")
	var changed := 0
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var path := "res://data/recipes/" + f
		var r := load(path) as RecipeData
		if r == null or not r.unlock_items.is_empty():
			continue
		var keys := MakeItems.key_items(r.inputs)
		if keys.is_empty():
			continue
		print("%s: %s" % [r.id, ", ".join(keys)])
		if not dry:
			r.unlock_items.assign(keys)
			ResourceSaver.save(r, path)
		changed += 1
	print("set_recipe_unlocks: %d recipe%s %s" % [changed, "" if changed == 1 else "s", "would change" if dry else "changed"])
	quit()
