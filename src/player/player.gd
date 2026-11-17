class_name Player
extends CharacterBody2D
## Player movement: fluid, not floaty. Walk / jog (default) / run, a snappy jump with
## variable height, and partial air control: mid-jump you can slow down and drift back
## a little, but not turn around instantly.
##
## Hold Run (Shift) to run; Toggle Walk (C) switches the default pace to a walk.
## Drawn as a PaperDoll (separate body parts): see src/player/doll/paper_doll.gd.
## Holding an item: left click attacks/uses it (clicking again soon after continues a
## combo), H puts it away / takes it out. While aiming or attacking you face the cursor;
## moving away from it walks backwards at backpedal_speed.
## Every number is exported: select the Player in the running game's Remote tree and
## tune it live. Distances are in tiles (8 px), speeds in tiles per second.

## Landed after being airborne. `fall_tiles` = distance from the highest point.
signal landed(fall_tiles: float)
## Fall damage to apply. Health arrives in Phase 6; for now it's shown in the overlay.
signal fall_damage_taken(amount: int)

const TILE := float(World.TILE)
const SHEET := "res://assets/sprites/scholar"
const PALETTE := "res://assets/sprites/scholar_palette.tres"
const DEFAULT_LOOK := "res://assets/sprites/scholar_look.tres"

## Colors and hairstyle. Null uses assets/sprites/scholar_look.tres.
@export var look: CharacterLook

@export_group("Animation")
## Seconds the first Jump frame (takeoff) shows after a jump starts.
@export var takeoff_time := 0.07
## Which Jump frame is the apex (knees tucked), numbered like Aseprite (1 = first).
@export var jump_apex_frame := 4
## The apex frame shows while vertical speed is within this many tiles/s of zero.
@export var apex_band := 12.0
## Frames after the apex are spread from apex_band up to this falling speed (tiles/s);
## falling faster holds the last frame.
@export var jump_frame_speed := 50.0
## Seconds the landing squash shows when landing without moving.
@export var land_time := 0.1
## Pixels the upper body drops in the landing squash (when there's no "Land" tag).
@export var land_dip := 2.0

@export_group("Speed (tiles/s)")
@export var walk_speed := 10.0
@export var jog_speed := 18.0
@export var run_speed := 28.0
@export var climb_speed := 12.0
## Speed multiplier when moving away from where you're facing (aiming backwards).
@export_range(0.1, 1.0) var backpedal_speed := 0.8
## Empty hands punch (data/item_types/unarmed.tres combo) on click. Off for now.
@export var unarmed_attacks := false

@export_group("Ground (seconds to full speed / to stop)")
@export var ground_accel_time := 0.1
@export var ground_decel_time := 0.12

@export_group("Air control (seconds)")
## Time to reach full speed in the air from standing still.
@export var air_accel_time := 0.55
## Time to cancel full speed when holding the opposite direction mid-air.
## Lower = more control. Around half a second lets you slow down and drift back a bit.
@export var air_turn_time := 0.4
## Time to lose full speed in the air with no input (momentum carries).
@export var air_drag_time := 1.6

@export_group("Jump")
@export var jump_height := 11.0
@export var time_to_apex := 0.36
## Falling is faster than rising, so landings feel grounded, not floaty.
@export var fall_gravity_multiplier := 1.5
## Velocity kept when Jump is released early (short hop).
@export var jump_cut := 0.45
@export var max_fall_speed := 90.0
## Can still jump this long after running off a ledge.
@export var coyote_time := 0.1
## A jump pressed this long before landing still counts.
@export var jump_buffer_time := 0.12

@export_group("Terrain")
## Walk up ledges this many tiles high without jumping.
@export var max_step_tiles := 2
@export var platform_drop_time := 0.25

@export_group("Fall damage")
@export var fall_damage_start := 50.0
@export var fall_damage_per_tile := 5.0

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
var _takeoff_timer := 0.0
var _land_timer := 0.0
## Held item (null = empty hands) and whether it's put away.
var held: HeldItemLook
var stowed := false
## The attack playing (null = none), seconds into it, and its place in the combo.
var _attack: ItemMotion
var _attack_time := 0.0
var _combo_index := -1
## Seconds left to continue the combo after an attack ends.
var _combo_left := 0.0
var _hold_time := 0.0

@onready var _doll: PaperDoll = $Doll


## Gravity (px/s^2) and launch speed (px/s) that reach `height_tiles` in `apex_time`.
static func jump_values(height_tiles: float, apex_time: float) -> Vector2:
	var h := height_tiles * TILE
	return Vector2(2.0 * h / (apex_time * apex_time), 2.0 * h / apex_time)


func _ready() -> void:
	_doll.setup(DollRig.load_from(SHEET), load(PALETTE) as CharacterPalette)
	_doll.look = look if look else load(DEFAULT_LOOK) as CharacterLook


## Puts an item in the player's hands (null = empty hands). Inventory and hotbar call
## this in Phase 4; debug builds use DevHeldItems (keys 1 to 4).
func hold(item: HeldItemLook) -> void:
	held = item
	stowed = false
	_end_attack(false)
	_doll.item = item
	_doll.stowed = false


## Puts the held item away or takes it back out (H).
func toggle_stowed() -> void:
	if held == null:
		return
	stowed = not stowed
	_end_attack(false)
	_doll.stowed = stowed


## True while facing the cursor: attacking, or holding something that aims.
func is_aiming() -> bool:
	if _attack != null:
		return true
	var m := _hold_motion()
	return m != null and m.aims


## The item type whose attacks a click plays: the held item's, or unarmed (if enabled).
func _attacks() -> Array[ItemMotion]:
	if held != null and not stowed:
		return held.attacks()
	if held == null and unarmed_attacks:
		var unarmed := load("res://data/item_types/unarmed.tres") as ItemTypeData
		if unarmed:
			return unarmed.attacks
	return []


func _combo_window() -> float:
	if held != null and held.item_type():
		return held.item_type().combo_window
	return 0.35


func _repeats() -> bool:
	return held == null or held.item_type() == null or held.item_type().repeat_while_held


func _hold_motion() -> ItemMotion:
	if held == null or stowed:
		return null
	return held.hold_motion()


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
	elif input_y != 0.0 and world and world.is_climbable_at(_body_center()):
		_start_climb()
		_climb(input_x, input_y)
	else:
		_move(input_x, input_y, delta)

	_update_use(delta)
	if is_aiming():
		var dx := get_global_mouse_position().x - global_position.x
		if absf(dx) > 2.0:
			facing = 1 if dx > 0.0 else -1
	elif input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	_track_fall()
	_animate(delta)
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
			_takeoff_timer = takeoff_time
			_coyote = 0.0
	if _rising_jump and (velocity.y >= 0.0 or not Input.is_action_pressed("jump")):
		if velocity.y < 0.0:
			velocity.y *= jump_cut
		_rising_jump = false

	var top := _current_speed() * TILE
	if input_x != 0.0 and signf(input_x) != float(facing):
		top *= backpedal_speed  # walking backwards (aiming the other way)
	var target := input_x * top
	var grounded := is_on_floor()
	var rate: float
	if grounded:
		var speeding_up := target != 0.0 and (velocity.x == 0.0 or signf(target) == signf(velocity.x)) and absf(target) >= absf(velocity.x)
		var turning := target != 0.0 and velocity.x != 0.0 and signf(target) != signf(velocity.x)
		rate = top / (ground_accel_time if speeding_up or turning else ground_decel_time)
	elif input_x == 0.0:
		rate = top / air_drag_time
	elif velocity.x != 0.0 and signf(target) != signf(velocity.x):
		rate = top / air_turn_time
	elif absf(velocity.x) > absf(target):
		# Holding the same way but slower than your momentum: keep the momentum.
		rate = top / air_drag_time
	else:
		rate = top / air_accel_time
	velocity.x = move_toward(velocity.x, target, rate * delta)

	if grounded and input_x != 0.0 and max_step_tiles > 0:
		_try_step_up(signf(input_x), delta)
	move_and_slide()


func _current_speed() -> float:
	if Input.is_action_pressed("run"):
		return run_speed
	return walk_speed if walk_toggled else jog_speed


## If a low ledge blocks us and there's room above it, lift the body onto it.
func _try_step_up(dir: float, delta: float) -> void:
	var motion := Vector2(dir * maxf(absf(velocity.x) * delta, 2.0), 0.0)
	if not test_move(global_transform, motion):
		return
	for step in range(1, max_step_tiles + 1):
		var up := Vector2(0.0, -TILE * step - 1.0)
		if test_move(global_transform, up):
			return
		if not test_move(global_transform.translated(up), motion):
			global_position += up
			velocity.y = maxf(velocity.y, 0.0)
			return


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


func _update_use(delta: float) -> void:
	if Input.is_action_just_pressed("put_away"):
		toggle_stowed()
	_hold_time += delta
	_combo_left = maxf(_combo_left - delta, 0.0)
	if _attack != null:
		_attack_time += delta
		if _attack_time >= _attack.duration:
			_end_attack(true)
	if _attack == null:
		var clicked := Input.is_action_just_pressed("use_primary")
		var held_down := Input.is_action_pressed("use_primary") and _repeats() and _combo_left > 0.0
		if clicked or held_down:
			_start_attack()


func _start_attack() -> void:
	var chain := _attacks()
	if chain.is_empty():
		return
	_combo_index = (_combo_index + 1) % chain.size() if _combo_left > 0.0 else 0
	_attack = chain[_combo_index]
	_attack_time = 0.0


## `finished`: ran to the end (opens the combo window); false: interrupted.
func _end_attack(finished: bool) -> void:
	_attack = null
	_attack_time = 0.0
	_combo_left = _combo_window() if finished else 0.0
	if not finished:
		_combo_index = -1


func _animate(delta: float) -> void:
	_takeoff_timer = maxf(_takeoff_timer - delta, 0.0)
	_land_timer = maxf(_land_timer - delta, 0.0)
	_doll.scale.x = float(facing)
	_doll.speed_scale = 1.0
	_doll.reverse = is_aiming() and velocity.x != 0.0 and signf(velocity.x) != float(facing)
	_doll.dip = 0.0
	if _climbing:
		_doll.play(&"Idle Pose")
	elif not is_on_floor():
		_show_jump_frame()
	elif absf(velocity.x) > 4.0:
		_doll.play(&"Jog")
		_doll.speed_scale = clampf(absf(velocity.x) / (jog_speed * TILE), 0.5, 1.8)
	elif _land_timer > 0.0:
		if _doll.has_animation(&"Land"):
			_doll.play(&"Land")
		else:
			_doll.play(&"Breath")
			_doll.dip = land_dip
	else:
		_doll.play(&"Breath")
	_animate_arms()


func _animate_arms() -> void:
	_doll.aim_global = get_global_mouse_position()
	if _attack != null:
		_doll.motion = _attack
		_doll.motion_t = clampf(_attack_time / maxf(_attack.duration, 0.01), 0.0, 1.0)
	else:
		var m := _hold_motion()
		_doll.motion = m
		_doll.motion_t = fposmod(_hold_time, m.duration) / m.duration if m else 0.0


## Picks the Jump frame from the arc instead of a timer. Frame 1 is the takeoff. Frames
## between it and the apex follow rising speed, the apex frame holds around the top, and
## the frames after it follow falling speed.
func _show_jump_frame() -> void:
	_doll.play(&"Jump")
	_doll.pause()
	_doll.frame = jump_frame_for(_doll.frame_count(&"Jump"))


func jump_frame_for(count: int) -> int:
	if count <= 1 or _takeoff_timer > 0.0:
		return 0
	var apex := clampi(jump_apex_frame - 1, 1, count - 1)
	var vy := velocity.y / TILE
	if absf(vy) <= apex_band:
		return apex
	if vy < 0.0:
		# Rising: frames 1 .. apex-1, fastest first.
		var rising := apex - 1
		if rising <= 0:
			return apex
		var launch := jump_values(jump_height, time_to_apex).y / TILE
		var t := clampf((-vy - apex_band) / maxf(launch - apex_band, 0.001), 0.0, 1.0)
		return apex - 1 - mini(int(t * rising), rising - 1)
	# Falling: frames apex+1 .. last, slowest first.
	var falling := count - 1 - apex
	if falling <= 0:
		return apex
	var f := clampf((vy - apex_band) / maxf(jump_frame_speed - apex_band, 0.001), 0.0, 1.0)
	return apex + 1 + mini(int(f * falling), falling - 1)


func _standing_on_platform() -> bool:
	for dx in [-6.0, 0.0, 6.0]:
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
			if fall >= 2.0:
				_land_timer = land_time
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
	DebugOverlay.watch("anim", "%s %d%s  vy %.0f  arms %s%s" % [_doll.animation, _doll.frame + 1,
		" rev" if _doll.reverse else "", velocity.y / TILE, (_doll.motion.name if _doll.motion else "-"),
		" #%d" % (_combo_index + 1) if _attack else ""])
