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
## A timed buff started or was refreshed (its spell).
signal buff_started(spell: SpellData)
## A buff ended: ran out, or `used` (Gel Cushion saving you from a fall).
signal buff_ended(effect: StringName, used: bool)
## A ritual finished (`completed`) or was cancelled.
signal ritual_finished(spell: SpellData, completed: bool)
## Health went down (any cause: falls, starving...).
signal hurt(amount: int, cause: StringName)
## Health reached 0. The World respawns the player.
signal died(cause: StringName)
## The held item's use landed (its impact_at point in the swing): mine, chop, place.
signal use_impact(item: ItemData)
## Ctrl + mouse wheel: change the mining / placing area (+1 bigger, -1 smaller).
signal area_scrolled(step: int)
## The selected hotbar slot changed.
signal selection_changed(slot: int)
## A concentration spell (Fly) was turned on (spell) or off (null).
signal concentration_changed(spell: SpellData)

const TILE := float(World.TILE)
const SHEET := "res://assets/sprites/scholar"
const PALETTE := "res://assets/sprites/scholar_palette.tres"
const DEFAULT_LOOK := "res://assets/sprites/scholar_look.tres"

## Colors and hairstyle. Null uses assets/sprites/scholar_look.tres.
@export var look: CharacterLook:
	set(v):
		look = v
		if _doll:
			_doll.look = v if v else load(DEFAULT_LOOK) as CharacterLook

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
## Seconds without ground before the animation shows falling (unless you jumped), so
## tiny drops and bumps don't flicker the run.
@export var air_grace_time := 0.08
## Pixels the upper body drops in the landing squash (when there's no "Land" tag).
@export var land_dip := 2.0

@export_group("Speed (tiles/s)")
@export var walk_speed := 10.0
@export var jog_speed := 18.0
@export var run_speed := 28.0
@export var climb_speed := 12.0
## Speed multiplier when moving away from where you're facing (aiming backwards).
@export_range(0.1, 1.0) var backpedal_speed := 0.8
## Empty hands punch (data/item_types/unarmed.tres: jab, cross, uppercut) on click.
@export var unarmed_attacks := true

@export_group("Mana")
@export var max_mana := 100.0
## Mana per second refilled...
@export var mana_regen := 15.0
## ...starting this many seconds after the last spell use.
@export var mana_regen_delay := 1.0
@export_group("")

@export_group("Health")
@export var max_health := 100.0
## Health per second refilled, once you've gone health_regen_delay seconds unhurt (and
## you're not starving).
@export var health_regen := 0.5
@export var health_regen_delay := 5.0
## Seconds you can't be hurt again after a hit (except by starving).
@export var hurt_cooldown := 0.66
@export_group("Hunger")
@export var max_hunger := 100.0
## In-game days a full hunger bar lasts (1.5 = 36 real minutes with 24 minute days),
## standing or walking. Spells (Fly included) don't make you hungry.
@export var hunger_full_days := 1.5
@export var hunger_run_multiplier := 2.0
## Starving (hunger 0): no health regen, and this much damage every starve_interval.
@export var starve_damage := 1.0
@export var starve_interval := 3.0
@export_group("")

@export_group("Flying (the Fly spell)")
## Tiles per second, when the spell doesn't set its own move_speed.
@export var fly_speed := 34.0
## Seconds to reach full speed or stop.
@export var fly_accel_time := 0.15
@export_group("")

@export_group("Levitating (the Levitate spell)")
## Seconds to reach full sideways speed or stop.
@export var levitate_accel_time := 0.12
## How quickly the height follows the ground (higher = snappier).
@export var levitate_follow := 7.0
## Fastest climb and drop toward the hover height (tiles/s).
@export var levitate_max_vertical := 30.0
## How far down (tiles) it looks for ground; past that you sink slowly.
@export var levitate_scan_tiles := 40
## Sinking speed with no ground below (tiles/s).
@export var levitate_sink := 10.0
@export_group("")

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
## Walking off a drop this high (tiles) keeps you on the ground instead of falling, the
## mirror of max_step_tiles. 0 = every drop is a fall.
@export var max_step_down_tiles := 1
## Seconds the sprite takes to catch up after a step up or down (the body moves a whole
## tile in one tick; the sprite eases into place so stairs look smooth).
@export var step_smooth_time := 0.06
## Draw the character on the smooth slope the terrain shows over 1-tile steps, instead
## of on the step the body stands on (so feet don't sink going up or float going down).
@export var follow_slopes := true
## Pixels: falling, the body lands on a block or platform whose top is this far above
## the collision box's bottom (the jump pose tucks the legs up, so the drawn feet are
## higher than the box). 0 = off.
@export var ledge_assist_px := 10.0
## Pixels each side of the center where the feet are, for slopes: the body is drawn
## at the higher of the two so no foot sinks into a hill (the other may hang a little).
@export var foot_spread_px := 4.0
## Walk up ledges this many tiles high without jumping.
@export var max_step_tiles := 2
## Longest that platforms are ignored after Down + Jump. They catch you again as soon
## as you're through the one you dropped from.
@export var platform_drop_time := 0.25

@export_group("Fall damage")
@export var fall_damage_start := 25.0
@export var fall_damage_per_tile := 5.0

## Set by the World before the player enters the tree.
var world: World
## The character being played (inventory). Set by the World.
var character: CharacterData
## Selected hotbar slot (0..9), or -1 while a spell picked on the spell wheel is ready.
var selected := 0
## The ItemData in hand (from the selected slot, or the readied spell), null for empty
## hands. A tome is held as itself; use_item() is the spell it casts.
var held_item: ItemData
## The current (or last) use is on the back layer (right click).
var use_back := false
## True while the mouse is over UI or a panel is open: clicks don't use items.
var input_blocked := false
## True while typing in the dev console: no movement or item input.
var typing := false
## The concentration spell that's on (Fly), or null. Only one at a time.
var concentration: SpellData
var mana := 100.0
## Dev console `mana`: spells cost nothing.
var infinite_mana := false
var _since_spell := 99.0
var health := 100.0
var hunger := 100.0
## Bonuses from equipment (CharacterData.equipment_stats()), and total defense.
var stat_bonus: Dictionary[StringName, float] = {}
var defense := 0
var _base := {}
## Dev: no damage (console `god`).
var invincible := false
## Hunger drains (the world's option).
var hunger_on := true
var _since_hurt := 99.0
var _starve_timer := 0.0
var dead := false
## The world's clock (for hunger in days). Null: 24 minute days.
var clock: WorldClock
## Optional: (back: bool) -> bool. False when using the held item now would do nothing
## (a block with nowhere to go), so the arm doesn't swing for nothing. Set by ItemUser.
var use_check: Callable
## Tiles/s a dropped stack (Q) is thrown at.
@export var throw_speed := 8.0
var walk_toggled := false
var facing := 1

var _coyote := 0.0
var _buffer := 0.0
var _rising_jump := false
var _climbing := false
var _drop_timer := 0.0
var _drop_from_y := 0.0
## Falling after Down + Jump (until landing): no ledge assist back onto that platform.
var _dropping := false
var _airborne := false
var _peak_y := 0.0
var _takeoff_timer := 0.0
var _land_timer := 0.0
var _air_time := 0.0
var _input_x := 0.0
## Sprite offset (pixels) easing back to 0 after a step.
var _step_offset := 0.0
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
## Spell readied with R (selected == -1), and the hotbar slot to go back to.
var _readied: ItemData
var _slot_before_book := 0
## The spell R takes out (the last one readied).
var last_spell: StringName = &""
## Quick cast or off-hand cast in progress: what to go back to afterwards
## [selected, readied spell, slot before the book, last_spell], or empty.
var _quick_return: Array = []
## The button that keeps a quick-cast beam going (&"" = none).
var _quick_button: StringName = &""
## Timed buffs on you (SpellData.Cast.BUFF): effect id to seconds left, and the spell
## that gave it. Not saved: they end when you leave the world.
var buffs: Dictionary[StringName, float] = {}
var buff_spells: Dictionary[StringName, SpellData] = {}
## Barrier's shield: damage it can still soak (0 = none). Shown as the
## &"barrier_shield" buff and a bubble.
var shield := 0.0
var _shield_fx: SpellEffect
## A ritual being performed (stand still until it's done), or null.
var ritual: SpellData
var ritual_left := 0.0
var _ritual_from := Vector2.ZERO
var _ritual_fx: SpellEffect
## Set when R was used for a quick cast, so letting go of R does nothing else.
var r_combo_used := false
## Seconds in the air since leaving the ground (for double jump).
var _airborne_for := 0.0
## Book looks for casting, per book id.
var _book_looks: Dictionary[StringName, HeldItemLook] = {}

@onready var _doll: PaperDoll = $Doll


## Gravity (px/s^2) and launch speed (px/s) that reach `height_tiles` in `apex_time`.
static func jump_values(height_tiles: float, apex_time: float) -> Vector2:
	var h := height_tiles * TILE
	return Vector2(2.0 * h / (apex_time * apex_time), 2.0 * h / apex_time)


func _ready() -> void:
	floor_snap_length = max_step_down_tiles * TILE + 2.0
	_base = {"max_health": max_health, "max_mana": max_mana, "mana_regen": mana_regen}
	health = max_health
	hunger = max_hunger
	mana = max_mana
	_doll.setup(DollRig.load_from(SHEET), load(PALETTE) as CharacterPalette)
	_doll.look = look if look else load(DEFAULT_LOOK) as CharacterLook


## Puts an item look in the player's hands (null = empty hands). The hotbar calls this
## through refresh_held(); tests call it directly.
func hold(item: HeldItemLook) -> void:
	if item == held and item != null:
		return
	held = item
	stowed = false
	_end_attack(false)
	_doll.item = item
	_doll.stowed = false


## Selects a hotbar slot and holds what's in it.
func select_slot(slot: int) -> void:
	selected = posmod(slot, Inventory.HOTBAR)
	_readied = null
	refresh_held()
	selection_changed.emit(selected)


## Readies a spell (the spellbook out, like Starbound's matter manipulator): it's cast
## with the clicks until a hotbar slot is picked again.
func ready_spell(spell_id: StringName) -> void:
	var spell := ItemData.find(ItemData.spell_key(spell_id))
	if spell == null:
		return
	if selected >= 0:
		_slot_before_book = selected
	selected = -1
	_readied = spell
	last_spell = spell_id
	refresh_held()
	selection_changed.emit(selected)


## R tapped: take the spellbook out (with the last spell used, or the book's first) or
## put it back and return to the hotbar slot you had.
func toggle_spellbook() -> void:
	if selected < 0:
		select_slot(_slot_before_book)
		return
	var spell := last_spell
	if character and not character.in_book(spell):
		spell = &""
		for book_spell in character.book_loadout():
			if book_spell != &"":
				spell = book_spell
				break
	if spell == &"":
		EventBus.debug_message.emit("No spells in your spellbook")
		return
	ready_spell(spell)


## Holds whatever is in the selected slot (after the inventory or equipment changed).
func refresh_held() -> void:
	var item: ItemData = _readied if selected < 0 else (character.inventory.item(selected) if character else null)
	var new_look := _look_for(item)
	if item == held_item and new_look == held:
		return
	held_item = item
	hold(new_look)


## The item that's actually used: the held item, or the spell a held tome casts.
func use_item() -> ItemData:
	if held_item and held_item.tome_spell != &"":
		return ItemData.find(ItemData.spell_key(held_item.tome_spell))
	return held_item


## How an item looks in hand. Spells show the equipped spellbook in the back hand.
func _look_for(item: ItemData) -> HeldItemLook:
	if item == null:
		return null
	if item.is_spell() and character:
		var book := character.book()
		if book == null or book.held == null:
			return null
		if not _book_looks.has(book.id):
			var book_look := HeldItemLook.new()
			book_look.id = book.id
			book_look.type = &"spell"
			book_look.texture = book.held.texture
			book_look.grip = book.held.grip
			_book_looks[book.id] = book_look
		return _book_looks[book.id]
	return item.held


## Throws the selected stack in front of the player (Q).
func drop_selected() -> void:
	if character == null or world == null or selected < 0 or character.inventory.is_empty(selected):
		return
	var inv := character.inventory
	var item_id := inv.ids[selected]
	var n := inv.take(selected, inv.counts[selected])
	world.request_spawn_drop(item_id, n, _body_center() + Vector2(facing * 10.0, 0.0),
		Vector2(facing * throw_speed * TILE, -6.0 * TILE), true)


func _unhandled_input(event: InputEvent) -> void:
	if character == null:
		return
	var wheel := 0
	if event.is_action_pressed("hotbar_next"):
		wheel = 1
	elif event.is_action_pressed("hotbar_prev"):
		wheel = -1
	if wheel != 0:
		if Input.is_key_pressed(KEY_CTRL):
			area_scrolled.emit(-wheel)  # wheel up = bigger
		elif not (world and world.brush and world.brush.active):
			select_slot(selected + wheel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("drop_item"):
		drop_selected()
		get_viewport().set_input_as_handled()


## True while an attack or use is playing (the beam mines while this is true).
func is_using() -> bool:
	return _attack != null


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
	if held == null and unarmed_attacks and not (world and world.brush and world.brush.active):
		var unarmed := load("res://data/item_types/unarmed.tres") as ItemTypeData
		if unarmed:
			return unarmed.attacks
	return []


func _combo_window() -> float:
	if held != null and held.item_type():
		return held.item_type().combo_window
	var unarmed := load("res://data/item_types/unarmed.tres") as ItemTypeData
	return unarmed.combo_window if unarmed else 0.35


func _repeats() -> bool:
	return held == null or held.item_type() == null or held.item_type().repeat_while_held


func _hold_motion() -> ItemMotion:
	if held == null or stowed:
		return null
	return held.hold_motion()


func _physics_process(delta: float) -> void:
	var input_x := _axis("move_left", "move_right")
	var input_y := _axis("move_up", "move_down")
	_input_x = input_x
	if _just("toggle_walk"):
		walk_toggled = not walk_toggled

	_coyote = coyote_time if is_on_floor() else maxf(_coyote - delta, 0.0)
	if is_on_floor() and _drop_timer <= 0.0:
		_dropping = false
	_buffer = jump_buffer_time if _just("jump") else maxf(_buffer - delta, 0.0)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		# Platforms collide again as soon as the feet are through the one we dropped
		# from, so a platform one tile lower catches us (Down + Jump again to keep going).
		if global_position.y > _drop_from_y + 4.0:
			_drop_timer = 0.0
		if _drop_timer <= 0.0:
			set_collision_mask_value(2, true)

	_update_mana(delta)
	_update_health(delta)
	if is_flying():
		_fly(input_x, input_y, delta)
	elif is_levitating():
		_levitate(input_x, input_y, delta)
	elif _climbing:
		_climb(input_x, input_y)
	elif input_y != 0.0 and world and world.is_climbable_at(_body_center()):
		_start_climb()
		_climb(input_x, input_y)
	else:
		_move(input_x, input_y, delta)

	_update_use(delta)
	if is_aiming():
		var dx := aim_point().x - global_position.x
		if absf(dx) > 2.0:
			facing = 1 if dx > 0.0 else -1
	elif input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	_track_fall()
	_animate(delta)
	_debug_watch()


func _move(input_x: float, input_y: float, delta: float) -> void:
	var jv := jump_values(_jump_height(), time_to_apex)
	var gravity := jv.x * (1.0 if velocity.y < 0.0 else fall_gravity_multiplier)
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed * TILE)

	# Holding Down + Jump keeps dropping through platform after platform.
	if _held("jump") and input_y > 0.0 and is_on_floor() and _drop_timer <= 0.0 and _standing_on_platform():
		_buffer = jump_buffer_time
	# Jump, or drop through a platform with Down + Jump.
	_airborne_for = 0.0 if is_on_floor() else _airborne_for + delta
	if _just("jump") and _coyote <= 0.0 and _airborne_for > 0.12 and not _climbing \
			and spell_option("double_jump") and concentration == null and movement_spell_id() != &"":
		_buffer = 0.0
		toggle_movement_spell()
		return
	if _buffer > 0.0 and _coyote > 0.0:
		_buffer = 0.0
		if input_y > 0.0 and _standing_on_platform():
			set_collision_mask_value(2, false)
			_drop_timer = platform_drop_time
			_drop_from_y = global_position.y
			_dropping = true
		else:
			velocity.y = -jv.y
			_rising_jump = true
			_takeoff_timer = takeoff_time
			_coyote = 0.0
	if _rising_jump and (velocity.y >= 0.0 or not _held("jump")):
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

	var y_before := global_position.y
	if not grounded:
		_ledge_assist()
	if grounded and input_x != 0.0 and max_step_tiles > 0:
		_try_step_up(signf(input_x), delta)
	move_and_slide()
	# A step up or down moves the body a whole tile in one tick: let the sprite ease.
	var dy := global_position.y - y_before
	if grounded and is_on_floor() and absf(dy) > 2.0:
		_step_offset = clampf(_step_offset - dy, -TILE * 3.0, TILE * 3.0)
		# With physics interpolation the body would be drawn sliding to the new height
		# over the next tick while the sprite offset already holds it in place: the
		# sprite dipped a tile and came back (the jitter on stairs). Snap the body's
		# drawn position instead; the offset does the smoothing.
		reset_physics_interpolation()


func _current_speed() -> float:
	return _base_speed() * (1.0 + stat(&"move_speed"))


func _base_speed() -> float:
	if _held("run"):
		return run_speed
	return walk_speed if walk_toggled else jog_speed


## If a low ledge blocks us and there's room above it, lift the body onto it.
## Only solid blocks count: platforms are ignored while testing, so walking through a
## stack of platforms never lifts you onto them.
func _try_step_up(dir: float, delta: float) -> void:
	var motion := Vector2(dir * maxf(absf(velocity.x) * delta, 2.0), 0.0)
	var platforms := get_collision_mask_value(2)
	set_collision_mask_value(2, false)
	if test_move(global_transform, motion):
		for step in range(1, max_step_tiles + 1):
			var up := Vector2(0.0, -TILE * step - 1.0)
			if test_move(global_transform, up):
				break
			if not test_move(global_transform.translated(up), motion):
				global_position += up
				velocity.y = maxf(velocity.y, 0.0)
				break
	set_collision_mask_value(2, platforms)


## Falling past a ledge or platform whose top is just below the drawn feet (the jump
## pose tucks the legs up): land on it instead of slipping past.
func _ledge_assist() -> void:
	if ledge_assist_px <= 0.0 or velocity.y < 0.0 or world == null:
		return
	var feet := global_position.y
	for dx: float in [-6.0, 0.0, 6.0]:
		var col := floori((global_position.x + dx) / TILE)
		var row := floori((feet - 0.5) / TILE)  # the tile the feet are in
		var top := float(row * TILE)
		if feet - top <= 0.5 or feet - top > ledge_assist_px:
			continue
		var b := world.data.get_block(col, row)
		var above := world.data.get_block(col, row - 1)
		var standable := b > 0 and world.blocks.collision(b) != TileDef.Collision.NONE
		if b > 0 and world.blocks.collision(b) == TileDef.Collision.PLATFORM \
				and (not get_collision_mask_value(2) or (_dropping and top <= _drop_from_y + 0.5)):
			standable = false  # dropping through this one
		var open := above == WorldData.AIR or (above > 0 and world.blocks.collision(above) != TileDef.Collision.SOLID)
		if standable and open:
			var lift := Vector2(0.0, top - feet - 0.5)
			var platforms := get_collision_mask_value(2)
			set_collision_mask_value(2, false)
			var blocked := test_move(global_transform, lift)
			set_collision_mask_value(2, platforms)
			if not blocked:
				global_position += lift
				velocity.y = 0.0
				return


## Spends mana if there's enough (always true with infinite mana). Using mana pauses
## the refill for mana_regen_delay.
func spend_mana(amount: float) -> bool:
	if amount <= 0.0 or infinite_mana:
		return true
	if mana < amount:
		return false
	mana -= amount
	_since_spell = 0.0
	return true


func has_mana(amount: float) -> bool:
	return infinite_mana or mana >= amount


func _update_mana(delta: float) -> void:
	_tick_buffs(delta)
	_update_ritual(delta)
	# A concentration spell drains while it's on; it ends when mana runs out.
	if concentration and concentration.effect == &"mend":
		heal(concentration.heal_per_second * spell_power() * delta)
	if concentration and concentration.mana_per_second > 0.0:
		var cost := concentration.mana_per_second * (concentration.boost_mana_mult if is_boosting() else 1.0)
		if not spend_mana(cost * delta):
			toggle_concentration(concentration)
			EventBus.debug_message.emit("Out of mana")
	_since_spell += delta
	if _since_spell >= mana_regen_delay:
		mana = minf(mana + mana_regen * delta, max_mana)


## Takes damage (ignored when invincible, dead, or just hurt, except starving). Emits
## hurt, and died at 0.
func take_damage(amount: float, cause: StringName = &"", knock_from: Variant = null, knock := 0.0) -> void:
	if amount <= 0.0 or dead or invincible:
		return
	if cause != &"starving" and _since_hurt < hurt_cooldown:
		return
	if cause == &"enemy":
		# Defense takes off half its value (at least 1 damage gets through).
		amount = maxf(1.0, amount - defense * 0.5)
	cancel_ritual("Interrupted")
	# Barrier pops when this hit would take you under its threshold; the shield soaks
	# damage first.
	if has_buff(&"barrier") and health - amount < max_health * buff_spells[&"barrier"].trigger_health:
		_pop_barrier()
	if shield > 0.0:
		var soak := minf(shield, amount)
		shield -= soak
		amount -= soak
		if shield <= 0.0:
			end_buff(&"barrier_shield", true)
		if amount <= 0.0:
			_since_hurt = 0.0
			if world and world.effects:
				FloatingText.spawn(world.effects, global_position + Vector2(0, -70), "blocked", Color("9fd8ff"))
			EventBus.sound_requested.emit(&"shield_block", global_position)
			return
	if knock_from is Vector2 and knock > 0.0:
		var dir := signf(global_position.x - (knock_from as Vector2).x)
		velocity = Vector2((dir if dir != 0.0 else 1.0) * knock * TILE, -knock * 0.6 * TILE)
	health = maxf(health - amount, 0.0)
	_since_hurt = 0.0
	hurt.emit(roundi(amount), cause)
	EventBus.sound_requested.emit(&"player_hurt", global_position)
	if world and world.effects:
		FloatingText.spawn(world.effects, global_position + Vector2(randf_range(-4, 4), -70), str(roundi(amount)),
			Color("ff6a5a"))
	_doll.modulate = Color(1.0, 0.45, 0.45)
	if health <= 0.0:
		dead = true
		died.emit(cause)


## The next hit lands even right after another (dev console).
func reset_hurt_cooldown() -> void:
	_since_hurt = 99.0


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)


## Eats: refills hunger (and a little health).
func eat(food: float, heal_amount: float = 0.0) -> void:
	hunger = minf(hunger + food, max_hunger)
	heal(heal_amount)


func _day_seconds() -> float:
	return clock.days(1.0) if clock else 24.0 * 60.0


## Equipment changed: recompute the stats it raises (max health and mana, regen, speed,
## jump, damage), defense, and how the armor looks. Max health going up doesn't refill
## health (regen does that).
func apply_stats() -> void:
	if _base.is_empty():
		_base = {"max_health": max_health, "max_mana": max_mana, "mana_regen": mana_regen}
	stat_bonus = character.equipment_stats() if character else {} as Dictionary[StringName, float]
	defense = character.defense() if character else 0
	max_health = float(_base["max_health"]) + stat(&"max_health")
	max_mana = float(_base["max_mana"]) + stat(&"max_mana")
	mana_regen = float(_base["mana_regen"]) + stat(&"mana_regen")
	health = minf(health, max_health)
	mana = minf(mana, max_mana)
	if _doll:
		_doll.wear(character.worn_items() if character else [] as Array[ItemData])


## An equipment bonus (0 when nothing raises it).
func stat(stat_name: StringName) -> float:
	return stat_bonus.get(stat_name, 0.0)


func _jump_height() -> float:
	return jump_height * (1.0 + stat(&"jump"))


## Forget the current fall (after a teleport: no fall damage for the jump).
func reset_fall() -> void:
	_airborne = false
	_peak_y = global_position.y


## Back to full after dying (the World moves the player to the spawn).
func revive() -> void:
	dead = false
	health = max_health
	hunger = max_hunger
	mana = max_mana
	_since_hurt = 99.0
	_starve_timer = 0.0
	velocity = Vector2.ZERO
	if concentration:
		toggle_concentration(concentration)


func _update_health(delta: float) -> void:
	_since_hurt += delta
	_doll.modulate = _doll.modulate.lerp(Color.WHITE, minf(delta * 8.0, 1.0))
	if dead:
		return
	if hunger_on:
		var running := _held("run") and absf(velocity.x) > 1.0 and is_on_floor()
		var rate := max_hunger / maxf(_day_seconds() * hunger_full_days, 1.0) * (hunger_run_multiplier if running else 1.0)
		hunger = maxf(hunger - rate * delta, 0.0)
	else:
		hunger = max_hunger
	if hunger <= 0.0:
		_starve_timer += delta
		if _starve_timer >= starve_interval:
			_starve_timer = 0.0
			take_damage(starve_damage, &"starving")
		return
	_starve_timer = 0.0
	if _since_hurt >= health_regen_delay:
		heal(health_regen * delta)


## Stops the current use (a beam that ran out of mana).
func stop_using() -> void:
	if _attack != null:
		_end_attack(true)


## Turns a concentration spell on, or off if it's the one already on. Turning one on
## ends the previous one.
func toggle_concentration(spell: SpellData) -> void:
	concentration = null if concentration == spell else spell
	EventBus.sound_requested.emit(&"toggle_on" if concentration else &"toggle_off", global_position)
	if character and concentration and concentration.effect in [&"fly", &"levitate"]:
		character.movement_spell = concentration.id
	if not is_flying() and not is_levitating():
		_rising_jump = false
		_peak_y = global_position.y  # no fall damage from where the flight ended
	concentration_changed.emit(concentration)


func is_flying() -> bool:
	return concentration != null and concentration.effect == &"fly"


func is_levitating() -> bool:
	return concentration != null and concentration.effect == &"levitate"


## Flying with the run key held while moving (Fly's boost): faster, more mana.
func is_boosting() -> bool:
	return is_flying() and concentration.boost_speed_mult > 1.0 and _held("run") \
		and (_axis("move_left", "move_right") != 0.0 or _axis("move_up", "move_down") != 0.0 or _held("jump"))


## Spell strength from the book, conduit and gear (for heals; ItemUser has its own for
## the held spell, which also counts a tome).
func spell_power() -> float:
	return (character.spell_power(null) if character else 1.0) * (1.0 + stat(&"magic_damage"))


## Flying: no gravity, WASD in every direction, Space also goes up. Shift boosts.
func _fly(input_x: float, input_y: float, delta: float) -> void:
	_climbing = false
	if _held("jump"):
		input_y = -1.0
	var speed := concentration.move_speed if concentration.move_speed > 0.0 else fly_speed
	if is_boosting():
		speed *= concentration.boost_speed_mult
	var target := Vector2(input_x, input_y).limit_length(1.0) * speed * TILE
	velocity = velocity.move_toward(target, speed * TILE / maxf(fly_accel_time, 0.01) * delta)
	_peak_y = global_position.y
	move_and_slide()


## Levitating: hovers `hover_tiles` above the ground below and follows it; fast, smooth
## sideways movement. Down lowers you to the ground; you can't go above the hover height.
## Over a drop with no ground in reach you sink slowly.
func _levitate(input_x: float, input_y: float, delta: float) -> void:
	_climbing = false
	var spell := concentration
	var speed := spell.move_speed if spell.move_speed > 0.0 else fly_speed
	velocity.x = move_toward(velocity.x, input_x * speed * TILE, speed * TILE / maxf(levitate_accel_time, 0.01) * delta)
	var ground := ground_below()
	var vy := levitate_sink * TILE
	if ground != INF:
		var hover := 0.0 if input_y > 0.0 else spell.hover_tiles * TILE
		var target := ground - hover
		vy = clampf((target - global_position.y) * levitate_follow, -levitate_max_vertical * TILE, levitate_max_vertical * TILE)
	velocity.y = vy
	_peak_y = global_position.y
	move_and_slide()


## The y (px) of the top of the first solid ground under the player's feet, within
## levitate_scan_tiles, or INF. Checks under both edges of the body.
func ground_below() -> float:
	if world == null:
		return INF
	var best := INF
	for dx: float in [-6.0, 0.0, 6.0]:
		var start := world.world_to_tile(global_position + Vector2(dx, -1.0))
		for i in levitate_scan_tiles:
			var t := start + Vector2i(0, i)
			if world.is_solid(t):
				best = minf(best, float(t.y * TILE))
				break
	return best


## Blink: moves to the farthest free spot along the line toward `target` (the body's
## middle goes there), up to `max_tiles`. Returns true if you moved.
func blink_toward(target: Vector2, max_tiles: float) -> bool:
	if world == null:
		return false
	var start := global_position
	var center_offset := Vector2(0.0, -30.0)
	var to := target - center_offset - start
	if to.length() > max_tiles * TILE:
		to = to.normalized() * max_tiles * TILE
	var steps := maxi(1, ceili(to.length() / (TILE * 0.5)))
	var best := start
	for i in range(1, steps + 1):
		var at := start + to * (float(i) / steps)
		if body_fits(at):
			best = at
	if best.distance_to(start) < TILE:
		return false
	global_position = best
	velocity = Vector2.ZERO
	reset_fall()
	reset_physics_interpolation()
	return true


## Whether the body fits with its feet at `feet` (no solid tile in the way).
func body_fits(feet: Vector2) -> bool:
	var r := Rect2(feet + Vector2(-8.0, -60.0), Vector2(16.0, 59.5))
	var a := world.world_to_tile(r.position)
	var b := world.world_to_tile(r.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if world.is_solid(Vector2i(x, y)):
				return false
	return true


func _start_climb() -> void:
	_climbing = true
	set_collision_mask_value(2, false)  # climb through platforms
	_rising_jump = false
	_peak_y = global_position.y


func _climb(input_x: float, input_y: float) -> void:
	if not world.is_climbable_at(_body_center()) or _just("jump"):
		_climbing = false
		if _drop_timer <= 0.0:
			set_collision_mask_value(2, true)
		if _just("jump"):
			velocity.y = -jump_values(_jump_height(), time_to_apex).y * 0.7
		return
	velocity = Vector2(input_x * walk_speed * 0.5, input_y * climb_speed) * TILE
	_peak_y = global_position.y
	move_and_slide()


func _update_use(delta: float) -> void:
	# Number keys pick a hotbar slot (polled, so scripted runs can tap them too).
	if character:
		for i in Inventory.HOTBAR:
			if _just("hotbar_%d" % (i + 1)):
				_number_key(i)
	if _just("movement_spell") and spell_option("movement_key"):
		toggle_movement_spell()
	if _just("put_away"):
		toggle_stowed()
	_hold_time += delta
	_combo_left = maxf(_combo_left - delta, 0.0)
	if _attack != null:
		_attack_time += delta
		var t0 := (_attack_time - delta) / maxf(_attack.duration, 0.001)
		var t1 := _attack_time / maxf(_attack.duration, 0.001)
		var used := use_item()
		if used and not stowed and t0 < used.impact_at and t1 >= used.impact_at:
			use_impact.emit(used)
		# The impact can end the attack (placing the last block of a stack changes what's
		# held, which cancels the attack), so check again.
		if _attack == null:
			pass
		elif _attack_time >= _attack.duration:
			_end_attack(true)
		elif used and used.beam and not _held(_quick_button if not _quick_return.is_empty() else _button()):
			_end_attack(true)  # a beam stops when the button is let go
	if _just("interact") and world:
		world.try_interact_near(self)
	if _attack == null and not input_blocked:
		# Left click: front layer (or punch). Right click: interact with what's under the
		# cursor, otherwise the back layer.
		var back := false
		var clicked := _just("use_primary")
		if not clicked and _just("use_secondary"):
			if world and world.try_interact_at(aim_point(), self):
				return
			if _offhand_cast():
				return
			back = held_item != null and not stowed
			clicked = back
		var held_down := false
		if not clicked and _repeats() and _combo_left > 0.0:
			back = use_back
			held_down = _held(_button(back))
		if (clicked or held_down) and (not use_check.is_valid() or use_check.call(back)):
			use_back = back
			_start_attack()


func _button(back: bool = use_back) -> StringName:
	return &"use_secondary" if back else &"use_primary"


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
	if not _quick_return.is_empty():
		_combo_left = 0.0
		_restore_quick()


# --- spell controls (options in Settings, section "spells") ---------------------------

## A spell control option (Settings "spells": movement_key, double_jump, book_numbers,
## quick_cast, two_hands).
static func spell_option(key: String) -> bool:
	return bool(Settings.get_value("spells", key))


## Number key `i`: R held = quick cast book slot i; spellbook out = ready book slot i;
## otherwise the hotbar slot.
func _number_key(i: int) -> void:
	if spell_option("quick_cast") and _held("spellbook"):
		r_combo_used = true
		var loadout := character.book_loadout()
		if i < loadout.size() and loadout[i] != &"":
			quick_cast(loadout[i])
		else:
			EventBus.debug_message.emit("Book slot %d is empty" % (i + 1))
		return
	if selected < 0 and spell_option("book_numbers"):
		var loadout := character.book_loadout()
		if i < loadout.size() and loadout[i] != &"":
			ready_spell(loadout[i])
		else:
			EventBus.debug_message.emit("Book slot %d is empty" % (i + 1))
		return
	select_slot(i)


## The spell the movement key and double jump turn on: the last movement spell used,
## else Fly, else Levitate (among the ones you know).
func movement_spell_id() -> StringName:
	if character == null:
		return &""
	if character.movement_spell != &"" and character.knows(character.movement_spell):
		return character.movement_spell
	for id: StringName in [&"fly", &"levitate"]:
		if character.knows(id):
			return id
	return &""


## Turns the movement spell on (or off if it's on). Same rules as casting it: it must
## be in your book, with the mana for it. Returns true if something changed.
func toggle_movement_spell() -> bool:
	var id := movement_spell_id()
	if id == &"":
		EventBus.debug_message.emit("You don't know a movement spell")
		return false
	var spell := ItemData.find(ItemData.spell_key(id)) as SpellData
	if concentration == spell:
		toggle_concentration(spell)
		return true
	var problem := character.cast_problem(spell, false)
	if problem == "" and not has_mana(maxf(spell.mana_per_second * 0.1, 1.0)):
		problem = "Not enough mana"
	if problem != "":
		EventBus.debug_message.emit(problem)
		return false
	toggle_concentration(spell)
	return true


## Casts a book spell once right now and goes back to what you were holding (R + number,
## or the off-hand). Concentration spells just toggle. `hold_button`: a beam keeps going
## while this button is held. Returns true if it cast.
func quick_cast(spell_id: StringName, hold_button: StringName = &"") -> bool:
	var spell := ItemData.find(ItemData.spell_key(spell_id)) as SpellData
	if spell == null or character == null or dead:
		return false
	if not character.in_book(spell_id):
		EventBus.debug_message.emit("Not in your spellbook")
		return false
	var problem := character.cast_problem(spell, false)
	if problem != "":
		EventBus.debug_message.emit(problem)
		return false
	if spell.cast == SpellData.Cast.TOGGLE:
		if concentration != spell and not has_mana(maxf(spell.mana_per_second * 0.1, 1.0)):
			EventBus.debug_message.emit("Not enough mana")
			return false
		toggle_concentration(spell)
		return true
	if _attack != null:
		return false
	var back_to := [selected, _readied, _slot_before_book, last_spell]
	ready_spell(spell_id)
	_quick_return = back_to
	_quick_button = hold_button
	use_back = false
	if use_check.is_valid() and not use_check.call(false):
		_restore_quick()
		return false
	_start_attack()
	if _attack == null:
		_restore_quick()
		return false
	return true


func _restore_quick() -> void:
	var r := _quick_return
	_quick_return = []
	_quick_button = &""
	if r.is_empty():
		return
	var was_selected: int = r[0]
	var was_readied: ItemData = r[1]
	_slot_before_book = r[2]
	if was_selected >= 0:
		select_slot(was_selected)
	elif was_readied:
		_readied = was_readied
		refresh_held()
		selection_changed.emit(selected)
	last_spell = r[3]


## The off-hand spell (two hands option): book slot 2, or slot 1 when slot 2 is in hand.
func offhand_spell() -> StringName:
	if character == null:
		return &""
	var loadout := character.book_loadout()
	var main_id: StringName = _readied.id if _readied else &""
	var pick := 1 if loadout.size() > 1 and loadout[1] != main_id else 0
	return loadout[pick] if pick < loadout.size() else &""


## Right click with the spellbook out (two hands option): casts the off-hand spell,
## unless the spell in hand mines or chops (then right click is the back layer).
func _offhand_cast() -> bool:
	if not spell_option("two_hands") or selected >= 0 or _readied == null or stowed:
		return false
	if _readied.mining_damage > 0.0 or _readied.axe_damage > 0.0:
		return false
	var off := offhand_spell()
	if off == &"":
		return false
	quick_cast(off, &"use_secondary")
	return true


func _animate(delta: float) -> void:
	_takeoff_timer = maxf(_takeoff_timer - delta, 0.0)
	_land_timer = maxf(_land_timer - delta, 0.0)
	_air_time = 0.0 if is_on_floor() else _air_time + delta
	# Ease toward where the feet should be: on flat ground that's the body; on stairs
	# it's the smooth slope the terrain is drawn as (see _slope_offset).
	var target := _slope_offset() if follow_slopes and is_on_floor() and not _climbing and not is_flying() and not is_levitating() else 0.0
	var gap := absf(_step_offset - target)
	_step_offset = move_toward(_step_offset, target, maxf(gap / maxf(step_smooth_time, 0.001), 30.0) * delta)
	_doll.position.y = _step_offset
	# Moving = actually moving, or steering while not against a wall (so turning around
	# doesn't flash the idle). Pushing into a wall counts as standing still.
	var moving := absf(get_real_velocity().x) > 4.0 or (_input_x != 0.0 and is_on_floor() and not is_on_wall())
	# Falling = off the ground a moment, or jumped. Brief bumps keep the run going.
	var airborne := not is_on_floor() and (_air_time > air_grace_time or velocity.y < 0.0)
	_doll.scale.x = float(facing)
	_doll.speed_scale = 1.0
	_doll.reverse = is_aiming() and velocity.x != 0.0 and signf(velocity.x) != float(facing)
	_doll.dip = 0.0
	if is_flying() or (is_levitating() and not is_on_floor()):
		_doll.play(&"Jump")
		_doll.pause()
		_doll.frame = clampi(jump_apex_frame - 1, 0, maxi(_doll.frame_count(&"Jump") - 1, 0))
	elif _climbing:
		_doll.play(&"Idle Pose")
	elif airborne:
		_show_jump_frame()
	elif moving:
		_doll.play(&"Jog")
		_doll.speed_scale = clampf(absf(velocity.x) / (jog_speed * TILE), 0.5, 1.8)
	elif _land_timer > 0.0 and not _in_stance():
		if _doll.has_animation(&"Land"):
			_doll.play(&"Land")
		else:
			_doll.play(&"Breath")
			_doll.dip = land_dip
	elif _in_stance():
		_show_stance()
	else:
		_doll.play(&"Breath")
	_animate_arms()


## Standing with an item out or attacking plays "Stand" instead of Breath, if the art
## has a Stand tag (optional: a side-view stance). Without one, Breath is used.
func _in_stance() -> bool:
	return _doll.has_animation(&"Stand") and (_attack != null or (held != null and not stowed))


func _show_stance() -> void:
	_doll.play(&"Stand")


func _animate_arms() -> void:
	_doll.aim_global = aim_point()
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
		var launch := jump_values(_jump_height(), time_to_apex).y / TILE
		var t := clampf((-vy - apex_band) / maxf(launch - apex_band, 0.001), 0.0, 1.0)
		return apex - 1 - mini(int(t * rising), rising - 1)
	# Falling: frames apex+1 .. last, slowest first.
	var falling := count - 1 - apex
	if falling <= 0:
		return apex
	var f := clampf((vy - apex_band) / maxf(jump_frame_speed - apex_band, 0.001), 0.0, 1.0)
	return apex + 1 + mini(int(f * falling), falling - 1)


## Pixels to draw the body lower (+) or higher (-) so the feet sit on the slope: the
## ground height is interpolated between the two nearest tile columns, which is how
## the terrain shader draws 1-tile steps (as a slope). 0 on flat ground and at cliffs.
func _slope_offset() -> float:
	if world == null:
		return 0.0
	var feet := global_position
	var best := INF
	for dx: float in [-foot_spread_px, foot_spread_px]:
		var h := _ramp_at(feet.x + dx, feet.y)
		if is_inf(h):
			return 0.0
		best = minf(best, h)  # the higher foot (smaller y)
	return clampf(best - feet.y, -TILE, TILE)


## Ground height (px) at x, interpolated between the two nearest tile columns; INF at
## a cliff (more than one tile between them) or with no ground nearby.
func _ramp_at(x: float, feet_y: float) -> float:
	var u := x / TILE - 0.5
	var c0 := floori(u)
	var h0 := _ground_top(c0, feet_y)
	var h1 := _ground_top(c0 + 1, feet_y)
	if is_inf(h0) or is_inf(h1) or absf(h0 - h1) > TILE + 0.5:
		return INF
	return lerpf(h0, h1, u - c0)


## Top (px) of the ground in a tile column near the feet: a solid block one tile up
## (a step), at the feet, or one tile down; platforms only at or below the feet (not
## ones overhead). INF if there's none.
func _ground_top(col: int, feet_y: float) -> float:
	var r := floori((feet_y - 1.0) / TILE)  # the tile the feet are in
	for row in range(r, r + 3):
		var b := world.data.get_block(col, row)
		var above := world.data.get_block(col, row - 1)
		var standable := b == WorldData.OUT_OF_BOUNDS or (b > 0 and world.blocks.collision(b) == TileDef.Collision.SOLID) \
			or (row > r and b > 0 and world.blocks.collision(b) == TileDef.Collision.PLATFORM)
		var open_above := above == WorldData.AIR or (above > 0 and world.blocks.collision(above) != TileDef.Collision.SOLID)
		if standable and open_above:
			return float(row * TILE)
	return INF


func _standing_on_platform() -> bool:
	for dx: float in [-6.0, 0.0, 6.0]:
		if world.collision_at(global_position + Vector2(dx, 2.0)) == TileDef.Collision.PLATFORM:
			return true
	return false


## The collision box in world space (blocks can't be placed into it).
func body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-8.0, -60.0), Vector2(16.0, 60.0))


## Where the held item is drawn (the beam starts here).
func doll_item_position() -> Vector2:
	return _doll.item_global_position()


## The front (casting) hand, in world space: spell beams start here.
func casting_hand_position() -> Vector2:
	return _doll.to_global(_doll.hands[&"front"]) if _doll.hands.has(&"front") else chest()


## Input, ignored while typing (the dev console).
func _just(action: StringName) -> bool:
	return not typing and Input.is_action_just_pressed(action)


func _held(action: StringName) -> bool:
	return not typing and Input.is_action_pressed(action)


func _axis(negative: StringName, positive: StringName) -> float:
	return 0.0 if typing else Input.get_axis(negative, positive)


## Where the player aims: the mouse, or ItemUser.cursor_override (tests, scripted runs).
func aim_point() -> Vector2:
	if world and world.item_user and world.item_user.cursor_override.is_finite():
		return world.item_user.cursor_override
	return get_global_mouse_position()


## Where reach is measured from (the chest).
func chest() -> Vector2:
	return global_position + Vector2(0.0, -36.0)


func _body_center() -> Vector2:
	return global_position + Vector2(0.0, -30.0)


func _track_fall() -> void:
	if is_on_floor() or _climbing:
		if _airborne and not _climbing:
			var fall := (global_position.y - _peak_y) / TILE
			landed.emit(fall)
			if fall >= 2.0:
				_land_timer = land_time
			if fall > fall_damage_start and has_buff(&"gel_cushion"):
				_cushion_landing(fall)
			elif fall > fall_damage_start:
				var amount := roundi((fall - fall_damage_start) * fall_damage_per_tile)
				fall_damage_taken.emit(amount)
				take_damage(amount, &"fall")
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


# --- buffs --------------------------------------------------------------------------

## Starts a timed buff from a BUFF spell, or refreshes its timer.
func add_buff(spell: SpellData) -> void:
	buffs[spell.effect] = spell.duration
	buff_spells[spell.effect] = spell
	buff_started.emit(spell)


func has_buff(effect: StringName) -> bool:
	return buffs.get(effect, 0.0) > 0.0


## Ends a buff now (`used`: it did its job, e.g. a cushioned fall).
func end_buff(effect: StringName, used: bool = false) -> void:
	if not buffs.has(effect):
		return
	buffs.erase(effect)
	buff_spells.erase(effect)
	if effect == &"barrier_shield":
		shield = 0.0
		if is_instance_valid(_shield_fx):
			_shield_fx.queue_free()
	buff_ended.emit(effect, used)
	if not used:
		EventBus.sound_requested.emit(&"buff_end", global_position)


## Barrier goes off: the barrier buff ends and a shield takes its place.
func _pop_barrier() -> void:
	var spell: SpellData = buff_spells[&"barrier"]
	end_buff(&"barrier", true)
	shield = spell.shield_amount
	buffs[&"barrier_shield"] = spell.shield_seconds
	buff_spells[&"barrier_shield"] = spell
	if world and world.effects:
		_shield_fx = SpellEffect.spawn(world.effects, SpellEffect.Kind.SHIELD, global_position, Vector2.ZERO,
			spell.projectile_color)
		_shield_fx.lifetime = spell.shield_seconds
		_shield_fx.follow = self
	EventBus.sound_requested.emit(&"shield_pop", global_position)


# --- rituals ------------------------------------------------------------------------

## Starts a ritual: stand still for its `ritual_seconds`. False if one is going already.
func start_ritual(spell: SpellData) -> bool:
	if ritual:
		return false
	ritual = spell
	ritual_left = spell.ritual_seconds
	_ritual_from = global_position
	if world and world.effects:
		_ritual_fx = SpellEffect.spawn(world.effects, SpellEffect.Kind.RITUAL, global_position, Vector2.ZERO,
			spell.projectile_color)
		_ritual_fx.lifetime = spell.ritual_seconds
		_ritual_fx.follow = self
	EventBus.sound_requested.emit(&"ritual_start", global_position)
	return true


func cancel_ritual(reason: String) -> void:
	if ritual == null:
		return
	var spell := ritual
	ritual = null
	if is_instance_valid(_ritual_fx):
		_ritual_fx.queue_free()
	EventBus.debug_message.emit("%s: %s" % [spell.display_name, reason])
	ritual_finished.emit(spell, false)


func _update_ritual(delta: float) -> void:
	if ritual == null:
		return
	var moving := _axis("move_left", "move_right") != 0.0 or _held("jump") \
		or global_position.distance_to(_ritual_from) > 3.0
	if moving:
		cancel_ritual("You moved")
		return
	ritual_left -= delta
	if ritual_left <= 0.0:
		_complete_ritual()


func _complete_ritual() -> void:
	var spell := ritual
	ritual = null
	if is_instance_valid(_ritual_fx):
		_ritual_fx.queue_free()
	if not spend_mana(spell.mana_cost):
		EventBus.debug_message.emit("%s: not enough mana" % spell.display_name)
		ritual_finished.emit(spell, false)
		return
	match spell.effect:
		&"recall":
			if world:
				SpellEffect.spawn(world.effects, SpellEffect.Kind.BURST, chest(), Vector2.ZERO, spell.projectile_color)
				global_position = world.respawn_position()
				velocity = Vector2.ZERO
				reset_fall()
				reset_physics_interpolation()
				SpellEffect.spawn(world.effects, SpellEffect.Kind.BURST, chest(), Vector2.ZERO, spell.projectile_color)
	EventBus.sound_requested.emit(&"ritual_done", global_position)
	ritual_finished.emit(spell, true)


func _tick_buffs(delta: float) -> void:
	for effect: StringName in buffs.keys():
		buffs[effect] -= delta
		if buffs[effect] <= 0.0:
			end_buff(effect)


## Gel Cushion takes a fall that would hurt: no damage, a green splat and "*squish*",
## and the buff is used up.
func _cushion_landing(fall: float) -> void:
	end_buff(&"gel_cushion", true)
	DebugOverlay.watch("last fall", "%.1f tiles, cushioned" % fall)
	if world:
		SpellEffect.spawn(world.effects, SpellEffect.Kind.SPLAT, global_position, Vector2.ZERO, Color(0.55, 1.0, 0.45))
		FloatingText.spawn(world.effects, global_position + Vector2(0, -70), "*squish*", Color(0.6, 1.0, 0.5))
	EventBus.sound_requested.emit(&"gel_cushion_used", global_position)


func _debug_watch() -> void:
	if not DebugOverlay.visible:
		return
	var t := world.wrap_tile(world.world_to_tile(global_position)) if world else Vector2i.ZERO
	var pace := "run" if _held("run") else ("walk" if walk_toggled else "jog")
	DebugOverlay.watch("tile", "%d, %d" % [t.x, t.y])
	DebugOverlay.watch("move", "%s %.1f t/s%s%s" % [pace, absf(velocity.x) / TILE,
		"  climbing" if _climbing else "", "  floor" if is_on_floor() else ""])
	DebugOverlay.watch("anim", "%s %d%s  vy %.0f  arms %s%s" % [_doll.animation, _doll.frame + 1,
		" rev" if _doll.reverse else "", velocity.y / TILE, (_doll.motion.name if _doll.motion else "-"),
		" #%d" % (_combo_index + 1) if _attack else ""])
