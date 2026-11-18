extends Node
## Autoload "Sounds": plays sound effects. Anything can ask for one with
## EventBus.sound_requested.emit(id, world_position) (Vector2.INF = not positional, like a
## UI sound); the file is assets/sounds/<id>.wav (or .ogg). Missing files are silent, so
## a sound can be asked for before it exists. Placeholders come from
## tools/make_sounds.gd; Patrick's real sounds replace them with the same names
## (assets/ASSETS.md lists them). Volume: Settings "audio" (master_volume, sfx_volume).

const DIR := "res://assets/sounds/"

## The same sound won't start again within this many seconds (a beam mining 90 tiles a
## frame plays one hit, not 90).
@export var min_gap := 0.07
## Most sounds playing at once; past that the oldest is cut.
@export var max_voices := 14
## Positional sounds fade out by this distance from the camera (px).
@export var max_distance := 720.0
## Each play is pitched up or down by up to this much, so repeats don't sound identical.
@export var pitch_jitter := 0.06

var _streams: Dictionary[StringName, AudioStream] = {}
var _missing: Dictionary[StringName, bool] = {}
var _last: Dictionary[StringName, int] = {}
var _voices: Array[Node] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.sound_requested.connect(play)
	EventBus.item_picked_up.connect(func(_id: StringName, _n: int) -> void: play(&"item_pickup"))
	for i in max_voices:
		var flat := AudioStreamPlayer.new()
		add_child(flat)
		var placed := AudioStreamPlayer2D.new()
		placed.max_distance = max_distance
		placed.attenuation = 1.4
		add_child(placed)
		_voices.append(flat)
		_voices.append(placed)


## Plays sound `id` (at a world position, or anywhere with Vector2.INF). Returns true if
## it started.
func play(id: StringName, at: Vector2 = Vector2.INF) -> bool:
	var stream := stream_for(id)
	if stream == null:
		return false
	var now := Time.get_ticks_msec()
	if now - _last.get(id, -100000) < int(min_gap * 1000.0):
		return false
	_last[id] = now
	var positional := at != Vector2.INF and at.is_finite()
	var voice := _free_voice(positional)
	var volume := linear_to_db(clampf(float(Settings.get_value("audio", "sfx_volume")), 0.0, 1.0))
	var pitch := 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	if positional:
		var p := voice as AudioStreamPlayer2D
		p.global_position = at
		p.stream = stream
		p.volume_db = volume
		p.pitch_scale = pitch
		p.play()
	else:
		var p := voice as AudioStreamPlayer
		p.stream = stream
		p.volume_db = volume
		p.pitch_scale = pitch
		p.play()
	return true


## The sound file for an id, or null if there isn't one.
func stream_for(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	if _missing.has(id):
		return null
	for ext in ["wav", "ogg"]:
		var path := "%s%s.%s" % [DIR, id, ext]
		if ResourceLoader.exists(path):
			_streams[id] = load(path) as AudioStream
			return _streams[id]
	_missing[id] = true
	return null


func _free_voice(positional: bool) -> Node:
	for v in _voices:
		if (v is AudioStreamPlayer2D) == positional and not v.call(&"is_playing"):
			return v
	# All busy: take the next one round robin.
	for i in _voices.size():
		_next = (_next + 1) % _voices.size()
		if (_voices[_next] is AudioStreamPlayer2D) == positional:
			return _voices[_next]
	return _voices[0]
