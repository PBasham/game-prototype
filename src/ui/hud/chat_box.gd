class_name ChatBox
extends Control
## The chat (like Terraria's): Enter opens a line at the bottom left, Enter sends, Esc
## closes. Lines starting with "/" are commands: /sit, /wave, /cheer, /stand, /emotes.
## Anything else is said out loud: it goes in the log and shows over your head for a
## few seconds. The log fades after a while and shows again while you type.

## How long a line stays in the log (seconds), how many lines show, and how long a
## said line stays over your head.
@export var line_seconds := 10.0
@export var max_lines := 8
@export var bubble_seconds := 4.0
@export var max_length := 120

var hud: Hud
## Typing a line right now.
var open := false
var text := ""
## [[text, color, age]] newest last.
var _lines: Array[Array] = []
var _bubble := ""
var _bubble_left := 0.0


func _init(owner_hud: Hud) -> void:
	hud = owner_hud
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open_chat() -> void:
	open = true
	text = ""
	queue_redraw()


func close_chat() -> void:
	open = false
	text = ""
	queue_redraw()


## Adds a line to the log (system lines are dimmer).
func add_line(line: String, color: Color = UiSkin.TEXT) -> void:
	_lines.append([line, color, 0.0])
	while _lines.size() > 40:
		_lines.pop_front()
	queue_redraw()


## Sends what's typed: a /command, or something said.
func send(line: String) -> void:
	line = line.strip_edges()
	if line == "":
		return
	var p := hud.world.player
	if line.begins_with("/"):
		var cmd := StringName(line.substr(1).strip_edges().to_lower())
		match cmd:
			&"help", &"emotes":
				add_line("Emotes: /%s, /stand. Right click a chair to sit on it." % " /".join(Player.EMOTES.keys()), UiSkin.DIM)
			&"stand":
				p.stop_emote()
			_:
				var problem := p.start_emote(cmd)
				if problem != "":
					add_line(problem, UiSkin.BAD)
		return
	var who := hud.world.character.name if hud.world.character else "You"
	add_line("%s: %s" % [who, line])
	_bubble = line
	_bubble_left = bubble_seconds


## Typing keys while open. Returns true if the key was used.
func handle_key(k: InputEventKey) -> bool:
	if not open or k == null or not k.pressed:
		return false
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			var line := text
			close_chat()
			send(line)
		KEY_ESCAPE:
			close_chat()
		KEY_BACKSPACE:
			text = text.substr(0, maxi(text.length() - 1, 0))
		_:
			if k.unicode >= 32 and text.length() < max_length:
				text += char(k.unicode)
	queue_redraw()
	return true


func _process(delta: float) -> void:
	var changed := false
	for l in _lines:
		l[2] += delta
	if _bubble_left > 0.0:
		_bubble_left -= delta
		changed = true
	if changed or open or not _lines.is_empty():
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var fs := 8
	var base := Vector2(6.0, size.y - 70.0)
	# The log, newest at the bottom.
	var shown := 0
	for i in range(_lines.size() - 1, -1, -1):
		if shown >= max_lines:
			break
		var l: Array = _lines[i]
		var age: float = l[2]
		var a := 1.0 if open else clampf((line_seconds - age) / 2.0, 0.0, 1.0)
		if a <= 0.0:
			continue
		var y := base.y - shown * 10.0
		var c: Color = l[1]
		draw_string(font, Vector2(base.x + 1, y + 1), l[0], HORIZONTAL_ALIGNMENT_LEFT, 260, fs, Color(0, 0, 0, 0.7 * a))
		draw_string(font, Vector2(base.x, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, 260, fs, Color(c, a))
		shown += 1
	if open:
		var r := Rect2(base.x - 3, base.y + 4, 264, 14)
		UiSkin.slot(self, r, UiSkin.SlotLook.SELECTED)
		var caret := "_" if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0 else ""
		draw_string(font, Vector2(r.position.x + 4, r.position.y + 10), text + caret, HORIZONTAL_ALIGNMENT_LEFT, 256, fs, UiSkin.TEXT)
	# What you said, over your head.
	if _bubble_left > 0.0 and hud.world.player:
		var p := hud.world.player
		# Above the head: world point to screen, then into this layer.
		var head := p.get_viewport().get_canvas_transform() * (p.global_position + Vector2(0, -74))
		var at := get_global_transform_with_canvas().affine_inverse() * head
		var w := minf(font.get_string_size(_bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 160.0)
		var a := clampf(_bubble_left / 0.5, 0.0, 1.0)
		var box := Rect2(at.x - w * 0.5 - 4, at.y - 13, w + 8, 13)
		draw_rect(box, Color(0.05, 0.05, 0.1, 0.7 * a))
		draw_string(font, box.position + Vector2(4, 10), _bubble, HORIZONTAL_ALIGNMENT_LEFT, 160, fs, Color(1, 1, 1, a))
