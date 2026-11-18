class_name WorldClock
extends Node
## The world's time of day. A day is `day_minutes` real minutes (24 by default, like
## Terraria): daytime from sunrise_hour to sunset_hour (15 hours: 4:30 to 19:30), night
## the rest. Dawn and dusk blend over `twilight_hours`. Saved with the world.
##
## Growth (trees, bushes, crops later) and hunger are set in in-game days; days()
## turns them into real seconds.

## A day passed midnight (day is the new day's number, from 1).
signal day_started(day: int)

## Real minutes per in-game day.
@export var day_minutes := 24.0
@export var sunrise_hour := 4.5
@export var sunset_hour := 19.5
## Hours that dawn and dusk take (the light fades over this).
@export var twilight_hours := 1.0
## A new world starts at this hour.
@export var start_hour := 6.5
## Sunlight at the darkest of night (0 = pitch black, 1 = day).
@export_range(0.0, 1.0) var night_light := 0.28
## Tint of the light: day, dusk and dawn, night.
@export var day_color := Color(1.0, 1.0, 1.0)
@export var twilight_color := Color(1.0, 0.78, 0.6)
@export var night_color := Color(0.55, 0.62, 0.95)
## Multiplies how fast time passes (dev: console `time fast`).
@export var speed := 1.0

## Fraction of the day: 0 = midnight, 0.5 = noon.
var time := 0.0
## Day number, from 1.
var day := 1
var _loaded := false


func _ready() -> void:
	if not _loaded:
		set_hour(start_hour)


func _process(delta: float) -> void:
	advance(delta)


func advance(seconds: float) -> void:
	time += seconds * speed / (day_minutes * 60.0)
	while time >= 1.0:
		time -= 1.0
		day += 1
		day_started.emit(day)


## Real seconds for a number of in-game days.
func days(n: float) -> float:
	return n * day_minutes * 60.0


func hour() -> float:
	return time * 24.0


func set_hour(h: float) -> void:
	time = fposmod(h, 24.0) / 24.0


func is_night() -> bool:
	return daylight() < 0.5


## 0 at night, 1 in the day, blending through dawn and dusk.
func daylight() -> float:
	var h := hour()
	var half := twilight_hours * 0.5
	if h < sunrise_hour - half or h > sunset_hour + half:
		return 0.0
	if h < sunrise_hour + half:
		return smoothstep(sunrise_hour - half, sunrise_hour + half, h)
	if h > sunset_hour - half:
		return 1.0 - smoothstep(sunset_hour - half, sunset_hour + half, h)
	return 1.0


## How warm the light is: 1 at sunrise and sunset, 0 otherwise.
func twilight() -> float:
	var d := daylight()
	return 1.0 - absf(d * 2.0 - 1.0)


## The sky light's color and brightness right now (multiplies sunlit tiles).
func sun_light() -> Color:
	var d := daylight()
	var base := night_color.lerp(day_color, d)
	base = base.lerp(twilight_color, twilight() * 0.6)
	var level := lerpf(night_light, 1.0, d)
	return Color(base.r * level, base.g * level, base.b * level)


## "Day 3, 14:20".
func label() -> String:
	var h := hour()
	return "Day %d, %d:%02d" % [day, int(h), int(fposmod(h, 1.0) * 60.0)]


func to_dict() -> Dictionary:
	return {"time": time, "day": day}


func from_dict(d: Dictionary) -> void:
	if d.has("time"):
		_loaded = true
		time = float(d["time"])
		day = int(d.get("day", 1))
