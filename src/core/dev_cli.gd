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

var _frame := 0
var _shots: Array[Array] = []
var _holds: Array[Array] = []
var _quit_at := -1
var _watch: PackedStringArray = []
var _log_every := 0
## Tile column to spawn at, or -1. Read by World.
var spawn_x := -1
var _perf := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts[0] == "perf":
			_perf = true
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
	set_physics_process(not (_shots.is_empty() and _holds.is_empty() and _quit_at < 0 and _log_every == 0))


func _physics_process(_delta: float) -> void:
	_frame += 1
	for h in _holds:
		if _frame == h[1]:
			Input.action_press(h[0])
		elif _frame == h[2]:
			Input.action_release(h[0])
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
