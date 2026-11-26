extends Node
## Autoload "DevCli": scripted runs for screenshots and smoke tests. Does nothing
## unless arguments are passed after `--` on the command line:
##
##   godot --path . -- --shot=90:/tmp/a.png --hold=move_right:20:120 --tap=jump:60 --quit=200
##
##   --shot=FRAME:PATH       save a screenshot at that frame
##   --hold=ACTION:FROM:TO   hold an input action between two frames
##   --tap=ACTION:FRAME      press an action for one frame
##   --quit=FRAME            quit at that frame
##   --watch=KEY             print a DebugOverlay value at every screenshot / log line
##   --log=EVERY             print watched values every EVERY frames
##   --spawn=X               spawn the player at tile column X (on the surface)
##   --perf                  print PerfStats (frames, chunks, lighting) on quit
##   --world=KIND            world generator: forest (default) or course (test course)
##   --seed=N                world seed (default 1337); any word works too
##   --size=NAME             tiny, small (default), medium, large
##   --console=FRAME:CMD     run a dev console command at a frame (output also printed)
##   --aim=DX:DY             aim at this offset (px) from the player's chest instead of
##                           the mouse (mining, placing, facing)
##   --mouse=X:Y             put the mouse here (window pixels) every frame: hover the UI
##                           in screenshots (tooltips)
##   --scene=doll            open a dev scene instead of a world (doll = Doll Viewer)
##   --menu                  stay on the main menu (otherwise any of these arguments
##                           skips the menu and starts a temporary, unsaved world)
##   --menu=PAGE             open a menu page: characters, new_character, worlds, new_world
##   --overlay=off           hide the F3 debug overlay for this run (screenshots)

var _frame := 0
var _shots: Array[Array] = []
var _holds: Array[Array] = []
var _quit_at := -1
var _watch: PackedStringArray = []
var _log_every := 0
## Tile column to spawn at, or -1. Read by World.
var spawn_x := -1
var _aim := Vector2.INF
var _mouse := Vector2.INF
var _console: Array[Array] = []
var _perf := false
var _world_kind := "forest"
var _seed_text := "1337"
var _size_name := "small"
var _menu := false
## Menu page to open (--menu=PAGE), or "".
var menu_page := ""
## Hide the debug overlay (--overlay=off).
var hide_overlay := false
## Dev scene to open instead of a world ("doll"), or "".
var scene_override := ""
var _any_args := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_any_args = true
		if parts[0] == "perf":
			_perf = true
			continue
		if parts[0] == "menu" and parts.size() == 1:
			_menu = true
			continue
		if parts.size() < 2:
			continue
		var v := parts[1].split(":")
		match parts[0]:
			"shot":
				_shots.append([int(v[0]), ":".join(v.slice(1))])
			"hold":
				_holds.append([v[0], int(v[1]), int(v[2])])
			"tap":
				_holds.append([v[0], int(v[1]), int(v[1]) + 1])
			"quit":
				_quit_at = int(v[0])
			"watch":
				_watch.append(parts[1])
			"spawn":
				spawn_x = int(v[0])
			"log":
				_log_every = int(v[0])
			"world":
				_world_kind = parts[1]
			"seed":
				_seed_text = parts[1]
			"size":
				_size_name = parts[1]
			"scene":
				scene_override = parts[1]
			"console":
				_console.append([int(v[0]), ":".join(v.slice(1))])
			"menu":
				_menu = true
				menu_page = parts[1]
			"overlay":
				hide_overlay = parts[1] == "off"
			"aim":
				_aim = Vector2(float(v[0]), float(v[1]))
			"mouse":
				_mouse = Vector2(float(v[0]), float(v[1]))
	set_physics_process(not (_shots.is_empty() and _holds.is_empty() and _quit_at < 0 and _log_every == 0
		and not _aim.is_finite() and not _mouse.is_finite() and _console.is_empty()))


## True when the command line asks for a scripted run, so the menu should be skipped.
func wants_world() -> bool:
	return _any_args and not _menu and scene_override == ""


## Scripted runs play a throwaway character with the dev kit (never saved).
func character() -> CharacterData:
	var c := CharacterData.create_dev(CharacterData.DEFAULT_NAME)
	c.temporary = true
	return c


## The temporary world a scripted run plays in.
func world_info() -> WorldInfo:
	var size: WorldData.Size = WorldData.Size.get(_size_name.to_upper(), WorldData.Size.SMALL)
	var info := WorldInfo.create("Scripted run", size, WorldInfo.seed_from_text(_seed_text))
	info.kind = StringName(_world_kind)
	info.temporary = true
	return info


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _mouse.is_finite():
		get_viewport().warp_mouse(_mouse)
	if _aim.is_finite():
		var w := get_tree().current_scene as World
		if w and w.item_user:
			w.item_user.cursor_override = w.player.chest() + _aim
	for h in _holds:
		if _frame == h[1]:
			Input.action_press(h[0])
		elif _frame == h[2]:
			Input.action_release(h[0])
	for c in _console:
		var cw := get_tree().current_scene as World
		if _frame == c[0] and cw and cw.console:
			cw.console.run(c[1])  # without opening it, so inputs still reach the player
	for s in _shots:
		if _frame == s[0]:
			_take(s[1])
	if _log_every > 0 and _frame % _log_every == 0:
		print("frame %d %s" % [_frame, _watched()])
	if _frame == _quit_at:
		if _perf:
			print("PerfStats after %d physics frames:" % _frame)
			print(PerfStats.summary())
		get_tree().quit()


func _take(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("DevCli shot frame %d -> %s %s" % [_frame, path, _watched()])


func _watched() -> String:
	var info := PackedStringArray()
	for key in _watch:
		info.append("%s=%s" % [key, DebugOverlay.get_watch(key)])
	return " ".join(info)
