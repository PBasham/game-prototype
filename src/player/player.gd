class_name Player
extends CharacterBody2D
## Player movement: Starbound-style feel on Terraria-size tiles.
##
## Default pace is a jog. Hold Run (Shift) to run; Toggle Walk (C) switches the
## default pace to a walk. Every number below is exported: select the Player in the
## running game's Remote tree (or in player.tscn) and tune it live.
## Distances are in tiles (16 px), speeds in tiles per second.

## Landed after being airborne. `fall_tiles` = distance from the highest point.
signal landed(fall_tiles: float)
## Fall damage to apply. Health arrives in Phase 6; for now it's shown in the overlay.
signal fall_damage_taken(amount: int)

const TILE := 16.0

@export_group("Speed (tiles/s)")
@export var walk_speed := 5.0
@export var jog_speed := 9.0
@export var run_speed := 14.0
@export var climb_speed := 6.0

@export_group("Acceleration (seconds to full speed / to stop)")
@export var ground_accel_time := 0.10
@export var ground_decel_time := 0.14
## Higher = less steering in the air.
@export var air_accel_time := 0.35
@export var air_decel_time := 0.8

@export_group("Jump")
@export var jump_height := 5.5
@export var time_to_apex := 0.42
## Falling is faster than rising: less floaty landings.
@export var fall_gravity_multiplier := 1.35
## Velocity kept when Jump is released early (short hop).
@export var jump_cut := 0.45
@export var max_fall_speed := 45.0
## Can still jump this long after running off a ledge.
@export var coyote_time := 0.1
## A jump pressed this long before landing still counts.
@export var jump_buffer_time := 0.12

@export_group("Terrain")
## Walk up 1-tile steps without jumping.
@export var auto_step := true
@export var platform_drop_time := 0.25

@export_group("Fall damage")
@export var fall_damage_start := 25.0
@export var fall_damage_per_tile := 10.0

## Set by the World before the player enters the tree.
var world: World
var walk_toggled := false
var facing := 1

var _coyote := 0.0
var _buffer := 0.0
var _rising_jump := false
var _climbing := false
var _drop_timer := 0.0
var _airborne := false
var _peak_y := 0.0

@onready var _sprite: Sprite2D = $Sprite


## Gravity (px/s^2) and launch speed (px/s) that reach `height_tiles` in `apex_time`.
static func jump_values(height_tiles: float, apex_time: float) -> Vector2:
	var h := height_tiles * TILE
	return Vector2(2.0 * h / (apex_time * apex_time), 2.0 * h / apex_time)


func _physics_process(delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	var input_y := Input.get_axis("move_up", "move_down")
	if Input.is_action_just_pressed("toggle_walk"):
		walk_toggled = not walk_toggled

	_coyote = coyote_time if is_on_floor() else maxf(_coyote - delta, 0.0)
	_buffer = jump_buffer_time if Input.is_action_just_pressed("jump") else maxf(_buffer - delta, 0.0)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(2, true)

	if _climbing:
		_climb(input_x, input_y)
	else:
		if input_y != 0.0 and world and world.is_climbable_at(_body_center()):
			_start_climb()
			_climb(input_x, input_y)
		else:
			_move(input_x, input_y, delta)

	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
		_sprite.flip_h = facing < 0
	_track_fall()
	_debug_watch()


func _move(input_x: float, input_y: float, delta: float) -> void:
	var jv := jump_values(jump_height, time_to_apex)
	var gravity := jv.x * (1.0 if velocity.y < 0.0 else fall_gravity_multiplier)
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed * TILE)

	# Jump, or drop through a platform with Down + Jump.
	if _buffer > 0.0 and _coyote > 0.0:
		_buffer = 0.0
		if input_y > 0.0 and _standing_on_platform():
			set_collision_mask_value(2, false)
			_drop_timer = platform_drop_time
		else:
			velocity.y = -jv.y
			_rising_jump = true
			_coyote = 0.0
	if _rising_jump and (velocity.y >= 0.0 or not Input.is_action_pressed("jump")):
		if velocity.y < 0.0:
			velocity.y *= jump_cut
		_rising_jump = false

	var top := _current_speed() * TILE
	var target := input_x * top
	var grounded := is_on_floor()
	var accel_time := ground_accel_time if grounded else air_accel_time
	var decel_time := ground_decel_time if grounded else air_decel_time
	var speeding_up := target != 0.0 and (signf(target) == signf(velocity.x) or velocity.x == 0.0) and absf(target) >= absf(velocity.x)
	var turning := target != 0.0 and velocity.x != 0.0 and signf(target) != signf(velocity.x)
	var rate := top / (accel_time if speeding_up or (turning and grounded) else decel_time)
	velocity.x = move_toward(velocity.x, target, rate * delta)

	if auto_step and grounded and input_x != 0.0:
		_try_step_up(signf(input_x), delta)
	move_and_slide()


func _current_speed() -> float:
	if Input.is_action_pressed("run"):
		return run_speed
	return walk_speed if walk_toggled else jog_speed


## If a 1-tile ledge blocks us and there's room above it, hop the body up onto it.
func _try_step_up(dir: float, delta: float) -> void:
	var motion := Vector2(dir * maxf(absf(velocity.x) * delta, 2.0), 0.0)
	if not test_move(global_transform, motion):
		return
	var up := Vector2(0.0, -TILE - 1.0)
	if test_move(global_transform, up):
		return
	if test_move(global_transform.translated(up), motion):
		return
	global_position += up
	velocity.y = maxf(velocity.y, 0.0)


func _start_climb() -> void:
	_climbing = true
	_rising_jump = false
	_peak_y = global_position.y


func _climb(input_x: float, input_y: float) -> void:
	if not world.is_climbable_at(_body_center()) or Input.is_action_just_pressed("jump"):
		_climbing = false
		if Input.is_action_just_pressed("jump"):
			velocity.y = -jump_values(jump_height, time_to_apex).y * 0.7
		return
	velocity = Vector2(input_x * walk_speed * 0.5, input_y * climb_speed) * TILE
	_peak_y = global_position.y
	move_and_slide()


func _standing_on_platform() -> bool:
	for dx in [-10.0, 0.0, 10.0]:
		if world.collision_at(global_position + Vector2(dx, 2.0)) == TileDef.Collision.PLATFORM:
			return true
	return false


func _body_center() -> Vector2:
	return global_position + Vector2(0.0, -30.0)


func _track_fall() -> void:
	if is_on_floor() or _climbing:
		if _airborne and not _climbing:
			var fall := (global_position.y - _peak_y) / TILE
			landed.emit(fall)
			if fall > fall_damage_start:
				var amount := roundi((fall - fall_damage_start) * fall_damage_per_tile)
				fall_damage_taken.emit(amount)
				DebugOverlay.watch("last fall", "%.1f tiles, %d damage" % [fall, amount])
			elif fall >= 1.0:
				DebugOverlay.watch("last fall", "%.1f tiles" % fall)
		_airborne = false
		_peak_y = global_position.y
	else:
		if not _airborne:
			_airborne = true
			_peak_y = global_position.y
		_peak_y = minf(_peak_y, global_position.y)


func _debug_watch() -> void:
	if not DebugOverlay.visible:
		return
	var t := world.wrap_tile(world.world_to_tile(global_position)) if world else Vector2i.ZERO
	var pace := "run" if Input.is_action_pressed("run") else ("walk" if walk_toggled else "jog")
	DebugOverlay.watch("tile", "%d, %d" % [t.x, t.y])
	DebugOverlay.watch("move", "%s %.1f t/s%s%s" % [pace, absf(velocity.x) / TILE,
		"  climbing" if _climbing else "", "  floor" if is_on_floor() else ""])
